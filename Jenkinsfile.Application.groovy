/*
 * Builds the backend and frontend images, pushes them to ECR, and rolls the
 * matching ECS services. Terraform must already have created the cluster,
 * repositories, load balancer, and services.
 *
 * The agent is assumed to have AWS CLI v2, Docker, curl, jq, nodejs, and terraform.
 */

pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'stage', 'prod'], description: 'Which ECS services to roll')
        string(name: 'IMAGE_TAG', defaultValue: '', description: 'Image tag. Leave empty to use the Jenkins build number.')
        string(name: 'DESIRED_COUNT', defaultValue: '1', description: 'Tasks to run after the deploy. Use 0 to scale a service back down.')
        string(name: 'AWS_REGION', defaultValue: 'us-east-1', description: 'AWS region')
        string(name: 'PROJECT', defaultValue: 'lightfeather', description: 'Name prefix. Must match the Terraform project variable.')
    }

    environment {
        AWS_DEFAULT_REGION = "${params.AWS_REGION}"
        AWS_REGION         = "${params.AWS_REGION}"
        PROJECT            = "${params.PROJECT}"
        ENVIRONMENT        = "${params.ENVIRONMENT}"
        DESIRED_COUNT      = "${params.DESIRED_COUNT}"
    }

    stages {
        stage('Build Backend Image') {
            steps {
                script {
                    def requestedTag = params.IMAGE_TAG?.trim()
                    env.IMAGE_TAG = requestedTag ? requestedTag : env.BUILD_NUMBER
                    env.ACCOUNT_ID = sh(
                        script: 'aws sts get-caller-identity --query Account --output text',
                        returnStdout: true
                    ).trim()
                    env.ECR_REGISTRY = "${env.ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    env.BACKEND_IMAGE = "${env.ECR_REGISTRY}/${env.PROJECT}-backend:${env.IMAGE_TAG}"
                    env.FRONTEND_IMAGE = "${env.ECR_REGISTRY}/${env.PROJECT}-frontend:${env.IMAGE_TAG}"
                    env.ALB_DNS = sh(
                        script: "aws elbv2 describe-load-balancers --names ${env.PROJECT} --query 'LoadBalancers[0].DNSName' --output text",
                        returnStdout: true
                    ).trim()
                    if (!env.ALB_DNS || env.ALB_DNS == 'None') {
                        error("Load balancer ${env.PROJECT} was not found. Apply the Terraform stack before building images.")
                    }
                    env.VITE_BASE = "/${env.ENVIRONMENT}/"
                    env.VITE_API_URL = "http://${env.ALB_DNS}/${env.ENVIRONMENT}/api/"
                }
                sh 'docker build --platform linux/amd64 -t "$BACKEND_IMAGE" backend'
            }
        }

        stage('Build Frontend Image') {
            steps {
                sh '''
                    echo "Baking VITE_API_URL=$VITE_API_URL and VITE_BASE=$VITE_BASE"
                    docker build --platform linux/amd64 \
                      --build-arg VITE_API_URL="$VITE_API_URL" \
                      --build-arg VITE_BASE="$VITE_BASE" \
                      -t "$FRONTEND_IMAGE" \
                      frontend
                '''
            }
        }

        stage('Upload Backend Image to ECR') {
            steps {
                sh '''
                    aws ecr get-login-password --region "$AWS_REGION" \
                      | docker login --username AWS --password-stdin "$ECR_REGISTRY"
                    docker push "$BACKEND_IMAGE"
                '''
            }
        }

        stage('Upload Frontend Image to ECR') {
            steps {
                sh '''
                    aws ecr get-login-password --region "$AWS_REGION" \
                      | docker login --username AWS --password-stdin "$ECR_REGISTRY"
                    docker push "$FRONTEND_IMAGE"
                '''
            }
        }

        stage('Deploy Backend ECS') {
            steps {
                script {
                    deployService('backend', env.BACKEND_IMAGE)
                }
            }
        }

        stage('Deploy Frontend ECS') {
            steps {
                script {
                    deployService('frontend', env.FRONTEND_IMAGE)
                }
            }
        }
    }
}

def deployService(String appName, String image) {
    withEnv(["APP_NAME=${appName}", "IMAGE=${image}"]) {
        sh '''
            set -eu
            SERVICE="${PROJECT}-${ENVIRONMENT}-${APP_NAME}"

            CURRENT=$(aws ecs describe-services \
              --cluster "$PROJECT" \
              --services "$SERVICE" \
              --query 'services[0].taskDefinition' \
              --output text)

            if [ -z "$CURRENT" ] || [ "$CURRENT" = "None" ]; then
              echo "ECS service ${SERVICE} was not found. Apply the Terraform stack before this pipeline."
              exit 1
            fi

            aws ecs describe-task-definition \
              --task-definition "$CURRENT" \
              --query taskDefinition \
              > task-def.json

            jq --arg image "$IMAGE" --arg name "$APP_NAME" '
              del(
                .taskDefinitionArn,
                .revision,
                .status,
                .requiresAttributes,
                .compatibilities,
                .registeredAt,
                .registeredBy
              )
              | .containerDefinitions |= map(
                  if .name == $name then .image = $image else . end
                )
            ' task-def.json > task-def-new.json

            NEW=$(aws ecs register-task-definition \
              --cli-input-json file://task-def-new.json \
              --query 'taskDefinition.taskDefinitionArn' \
              --output text)

            aws ecs update-service \
              --cluster "$PROJECT" \
              --service "$SERVICE" \
              --task-definition "$NEW" \
              --desired-count "$DESIRED_COUNT"

            aws ecs wait services-stable \
              --cluster "$PROJECT" \
              --services "$SERVICE"
        '''
    }
}
