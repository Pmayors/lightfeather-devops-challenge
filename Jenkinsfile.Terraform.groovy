/*
 * Plans the stack in live/ and applies that same plan only when asked.
 * Leave APPLY unchecked to plan only.
 *
 * The agent is assumed to have AWS CLI v2, Docker, curl, jq, nodejs, and terraform.
 */

pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    parameters {
        booleanParam(name: 'APPLY', defaultValue: false, description: 'Apply the saved plan. Leave unchecked to plan only.')
    }

    environment {
        TF_IN_AUTOMATION   = '1'
        TF_INPUT           = '0'
        AWS_DEFAULT_REGION = 'us-east-1'
    }

    stages {
        stage('Format') {
            steps {
                sh 'terraform fmt -check -recursive'
            }
        }

        stage('Init') {
            steps {
                dir('live') {
                    sh 'terraform init -input=false'
                }
            }
        }

        stage('Validate') {
            steps {
                dir('live') {
                    sh 'terraform validate'
                }
            }
        }

        stage('Plan') {
            steps {
                dir('live') {
                    sh 'terraform plan -input=false -no-color -out=tfplan'
                    sh 'terraform show -no-color tfplan'
                }
            }
        }

        stage('Apply') {
            when {
                expression { return params.APPLY }
            }
            steps {
                input message: 'Apply this Terraform plan in us-east-1?', ok: 'Apply'
                dir('live') {
                    sh 'terraform apply -input=false -auto-approve tfplan'
                }
            }
        }
    }
}
