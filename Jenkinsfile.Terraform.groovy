/*
 * Please structure the Jenkins pipeline below with the Jenkins DSL and code to 
 * complete the required steps documented below.
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
        // Build out a CICD pipeline to deploy your terraform infrastructure
        // Requirements:
        // 1. It needs to init
        // 2. It needs to plan
        // 3. It needs to apply
        // 4. Devise a way to run a plan only
    }
}
