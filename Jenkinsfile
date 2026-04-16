pipeline {
    agent any

    environment {
        REGISTRY       = 'docker.io'
        IMAGE_NAME     = 'furahajustine/cicd-demo-app'
        IMAGE_TAG      = "${env.BUILD_NUMBER}"
        FULL_IMAGE     = "${REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
        LATEST_IMAGE   = "${REGISTRY}/${IMAGE_NAME}:latest"
        APP_PORT       = '3000'
        CONTAINER_NAME = 'cicd-demo-app'
        PROJECT_NAME   = 'cicd-demo'
        AWS_REGION     = 'eu-west-1'
    }

    options {
        timeout(time: 20, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                echo "Branch: ${env.GIT_BRANCH}  |  Commit: ${env.GIT_COMMIT?.take(7)}"
            }
        }

        stage('Install / Build') {
            steps {
                dir('app') {
                    sh 'node --version && npm --version'
                    sh 'npm ci'
                }
            }
        }

        stage('Test') {
            steps {
                dir('app') {
                    sh 'npm test'
                }
            }
            post {
                always {
                    junit testResults: 'app/coverage/junit.xml', allowEmptyResults: true
                    publishHTML([
                        allowMissing: false, alwaysLinkToLastBuild: true,
                        keepAll: true, reportDir: 'app/coverage/lcov-report',
                        reportFiles: 'index.html', reportName: 'Coverage Report'
                    ])
                }
            }
        }

        stage('Docker Build') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'registry_creds',
                    usernameVariable: 'REG_USER',
                    passwordVariable: 'REG_PASS'
                )]) {
                    sh 'echo $REG_PASS | docker login $REGISTRY -u $REG_USER --password-stdin'
                    dir('app') {
                        sh """
                            docker build \
                                --build-arg APP_VERSION=${IMAGE_TAG} \
                                -t ${FULL_IMAGE} \
                                -t ${LATEST_IMAGE} \
                                .
                        """
                    }
                }
            }
        }

        stage('Push Image') {
            steps {
                sh """
                    docker push ${FULL_IMAGE}
                    docker push ${LATEST_IMAGE}
                """
            }
        }

        stage('Deploy') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'registry_creds',
                        usernameVariable: 'REG_USER',
                        passwordVariable: 'REG_PASS'
                    ),
                    sshUserPrivateKey(
                        credentialsId: 'ec2_ssh',
                        keyFileVariable: 'SSH_KEY'
                    )
                ]) {
                    script {
                        def ec2Host = sh(
                            script: """
                                aws ec2 describe-instances \
                                    --region ${AWS_REGION} \
                                    --filters \
                                        "Name=tag:Name,Values=${PROJECT_NAME}-app" \
                                        "Name=instance-state-name,Values=running" \
                                    --query "Reservations[0].Instances[0].PublicIpAddress" \
                                    --output text
                            """,
                            returnStdout: true
                        ).trim()

                        if (!ec2Host || ec2Host == 'None') {
                            error "Could not find running App EC2 tagged: ${PROJECT_NAME}-app"
                        }

                        echo "Deploying to App EC2: ${ec2Host}"

                       
                        writeFile file: '/tmp/deploy.sh', text: """#!/bin/bash
set -e
echo "${REG_PASS}" | docker login docker.io -u "${REG_USER}" --password-stdin
docker pull ${FULL_IMAGE}
docker stop ${CONTAINER_NAME} 2>/dev/null || true
docker rm   ${CONTAINER_NAME} 2>/dev/null || true
docker run -d \\
    --name ${CONTAINER_NAME} \\
    --restart unless-stopped \\
    -p ${APP_PORT}:3000 \\
    -e APP_VERSION=${IMAGE_TAG} \\
    ${FULL_IMAGE}
sleep 5
curl -sf http://localhost:${APP_PORT}/health || exit 1
docker image prune -af --filter "until=24h"
echo "Deploy OK — build ${IMAGE_TAG} live"
"""
                        sh """
                            scp -o StrictHostKeyChecking=no \
                                -i "\${SSH_KEY}" \
                                /tmp/deploy.sh ec2-user@${ec2Host}:/tmp/deploy.sh

                            ssh -o StrictHostKeyChecking=no \
                                -i "\${SSH_KEY}" \
                                ec2-user@${ec2Host} 'bash /tmp/deploy.sh && rm /tmp/deploy.sh'
                        """

                        echo "App live at http://${ec2Host}:${APP_PORT}"
                    }
                }
            }
        }
    }

    post {
        always {
            sh """
                docker rmi ${FULL_IMAGE}   2>/dev/null || true
                docker rmi ${LATEST_IMAGE} 2>/dev/null || true
                docker logout ${REGISTRY}  2>/dev/null || true
            """
        }
        success { echo "Pipeline SUCCESS" }
        failure { echo "Pipeline FAILED — check stage logs above" }
    }
}