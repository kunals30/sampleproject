pipeline {
  agent { label 'build' }

  options {
    timestamps()
  }

  environment {
    // Sonar
    SONAR_ORG = "kunals30"
    SONAR_PROJECT_KEY = "kunals30_sampleproject"

    // Image
    IMAGE_NAME = "sampleproject"
    IMAGE_TAG  = "build-${BUILD_NUMBER}"

    // Nexus
    NEXUS_REGISTRY = "65.1.128.203:8082"
    NEXUS_IMAGE = "${NEXUS_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"

    // AWS ECR
    AWS_REGION = "ap-south-1"
    AWS_ACCOUNT_ID = "319623177745"
    ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    ECR_IMAGE = "${ECR_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Setup Python Environment') {
      steps {
        sh '''
          python3 -m venv .venv
          . .venv/bin/activate
          pip install --upgrade pip setuptools wheel build
          pip install -e .
          pip install pytest pytest-cov
          mkdir -p reports
        '''
      }
    }

    stage('Unit Tests + Coverage') {
      steps {
        sh '''
          . .venv/bin/activate
          pytest --cov=src --cov-report=xml:coverage.xml \
                 --junitxml=reports/unit-tests.xml
        '''
      }
    }

    stage('Functional Tests') {
      steps {
        sh '''
          . .venv/bin/activate
          set +e
          pytest -m functional --junitxml=reports/functional-tests.xml
          rc=$?
          set -e
          if [ "$rc" -ne 0 ] && [ "$rc" -ne 5 ]; then
            exit "$rc"
          fi
        '''
      }
    }

    stage('SonarCloud Scan') {
      steps {
        withCredentials([
          string(credentialsId: 'sonarcloud-token', variable: 'SONAR_TOKEN')
        ]) {
          withEnv(["PATH+SONAR=${tool 'SonarScanner'}/bin"]) {
            sh '''
              . .venv/bin/activate
              sonar-scanner \
                -Dsonar.organization=${SONAR_ORG} \
                -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
                -Dsonar.host.url=https://sonarcloud.io \
                -Dsonar.sources=src \
                -Dsonar.tests=tests \
                -Dsonar.python.coverage.reportPaths=coverage.xml
            '''
          }
        }
      }
    }

    stage('Performance Tests') {
      steps {
        sh '''
          if [ -f tests/performance/load_test.js ]; then
            k6 run tests/performance/load_test.js \
              --summary-export=k6-summary.json
          else
            echo "No performance test found, skipping k6"
          fi
        '''
      }
    }

    stage('Build Python Wheel') {
      steps {
        sh '''
          . .venv/bin/activate
          python -m build
          ls -al dist || true
        '''
      }
    }

    stage('Docker Build') {
      steps {
        sh '''
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
        '''
      }
    }

    stage('Push Docker Image to Nexus') {
      steps {
        withCredentials([
          usernamePassword(
            credentialsId: 'nexus-docker-creds',
            usernameVariable: 'NEXUS_USER',
            passwordVariable: 'NEXUS_PASS'
          )
        ]) {
          sh '''
            echo "$NEXUS_PASS" | docker login ${NEXUS_REGISTRY} \
              -u "$NEXUS_USER" --password-stdin

            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${NEXUS_IMAGE}
            docker push ${NEXUS_IMAGE}
            docker logout ${NEXUS_REGISTRY}
          '''
        }
      }
    }

    stage('Push Docker Image to AWS ECR') {
      steps {
        sh '''
          aws ecr get-login-password --region ${AWS_REGION} \
            | docker login --username AWS --password-stdin ${ECR_REGISTRY}

          docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ECR_IMAGE}
          docker push ${ECR_IMAGE}
        '''
      }
    }
  }

  post {
    always {
      archiveArtifacts artifacts: 'dist/**,coverage.xml,k6-summary.json,reports/*.xml',
                       fingerprint: true,
                       allowEmptyArchive: true

      junit testResults: 'reports/*.xml',
            allowEmptyResults: true

      cleanWs()
    }
  }
}
