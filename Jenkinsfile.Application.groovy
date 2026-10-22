/*
 * Please fill out the Jenkins pipeline below with the code to complete the 
 * required steps commented in each stage. 
 *
 * Assumptions
 * You may make the following assumptions about the specific node this code will
 * be running on.
 *
 * - AWS CLI v2 installed and configured
 * - Docker is installed 
 * - The following packages are installed and available
 *   curl, jq, nodejs, terraform, kubectl
 * 
 * You may remove this comment for cleaner code.
 */

pipeline {
	agent any

    stages {
        stage("Build Backend Image") {
            // Enter groovy script here to build image
        }

        stage("Build Frontend Image") {
            // Enter groovy script here to build image
        }

        stage("Upload Backend Image to ECR") {
            // Enter groovy script here to upload image
        }

        stage("Upload Frontend Image to ECR") {
            // Enter groovy script here to upload image
        }

        stage("Deploy Backend ECS") {
            // Enter groovy script to deploy image to ECS container
        }

        stage("Deploy Frontend ECS") {
            // Enter groovy script to deploy image to ECS container
        }
    }
}
