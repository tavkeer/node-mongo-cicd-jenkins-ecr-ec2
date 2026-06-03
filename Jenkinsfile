pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        AWS_ACCOUNT_ID = '494003776090'
        ECR_REPOSITORY = 'devops-node-mongo-base'
        IMAGE_TAG = "${BUILD_NUMBER}"
        IMAGE_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}"

        PROD_APP_DIR = '/home/ubuntu/devops-node-mongo-base'
        SSH_TARGET = 'ubuntu@13.206.223.80'

        APP_PORT = '3000'
        MONGO_URI = 'mongodb://mongo:27017/devopsapp'
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t $ECR_REPOSITORY:$IMAGE_TAG .
                    docker tag $ECR_REPOSITORY:$IMAGE_TAG $IMAGE_URI:$IMAGE_TAG
                    docker tag $ECR_REPOSITORY:$IMAGE_TAG $IMAGE_URI:latest
                '''
            }
        }

        stage('Login to Amazon ECR') {
            steps {
                sh '''
                    aws ecr get-login-password --region $AWS_REGION | \
                    docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    docker push $IMAGE_URI:$IMAGE_TAG
                    docker push $IMAGE_URI:latest
                '''
            }
        }

        stage('Deploy with Docker Compose') {
            steps {
                sshagent(credentials: ['production-server-ssh']) {
                    sh '''
                        ssh -o StrictHostKeyChecking=no $SSH_TARGET "
                            set -e
                            mkdir -p $PROD_APP_DIR
                        "

                        scp -o StrictHostKeyChecking=no docker-compose.yml $SSH_TARGET:$PROD_APP_DIR/docker-compose.yml

                        ssh -o StrictHostKeyChecking=no $SSH_TARGET "
                            set -e
                            cd $PROD_APP_DIR

                            cat > .env <<EOF
                            IMAGE_URI=$IMAGE_URI
                            IMAGE_TAG=$IMAGE_TAG
                            APP_PORT=$APP_PORT
                            MONGO_URI=$MONGO_URI
                            EOF

                            aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
                            docker compose pull
                            docker compose up -d
                        "
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline completed successfully. Deployed image tag: ${IMAGE_TAG}"
        }
        failure {
            echo "Pipeline failed. Check Jenkins console output for details."
        }
    }
}
