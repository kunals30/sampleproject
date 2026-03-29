pipeline {
  agent { label 'build' }

  options {
    timestamps()
    ansiColor('xterm')
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
    AWS_ACCOUNT_ID = "319623177745"   // ✅ looks already set
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
          set -euxo pipefail
          python3 -m venv .venv
          . .venv/bin/activate
          python -m pip install --upgrade pip setuptools wheel build
          # install app + deps
          pip install -e .
          # test deps
          pip install pytest pytest-cov
          # Ensure reports dir exists for JUnit
          mkdir -p reports
        '''
      }
    }

    stage('Unit Tests + Coverage') {
      steps {
        sh '''
          set -euxo pipefail
          . .venv/bin/activate
          # Always write junit xml into reports/
          pytest --cov=src --cov-report=xml:coverage.xml --junitxml=reports/unit-tests.xml
        '''
      }
    }

    stage('Functional Tests') {
      steps {
        sh '''
          set -euxo pipefail
          . .venv/bin/activate

          # Some projects don't have functional-marked tests.
          # pytest exits with code 5 when no tests are collected.
          # We allow 0 (success) and 5 (no tests), but fail on anything else.
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
          withEnv([
            "PATH+SONAR=${tool 'SonarScanner'}/bin"
          ]) {
            sh '''
              set -euxo pipefail
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
          set -euxo pipefail
          # Only run if file exists; otherwise skip gracefully
          if [ -f tests/performance/load_test.js ]; then
            k6 run tests/performance/load_test.js --summary-export=k6-summary.json
          else
            echo "No performance test file found at tests/performance/load_test.js - skipping k6"
          fi
        '''
      }
    }

    stage('Build Python Wheel') {
      steps {
        sh '''
          set -euxo pipefail
          . .venv/bin/activate
          python -m build
          ls -al dist || true
        '''
      }
    }

    stage('Docker Build') {
      steps {
        sh '''
          set -euxo pipefail
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
            set -euxo pipefail
            echo "$NEXUS_PASS" | docker login ${NEXUS_REGISTRY} -u "$NEXUS_USER" --password-stdin

            docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${NEXUS_IMAGE}
            docker push ${NEXUS_IMAGE}

            docker logout ${NEXUS_REGISTRY} || true
          '''
        }
      }
    }

    stage('Push Docker Image to AWS ECR') {
      steps {
        sh '''
          set -euxo pipefail
          echo "Logging in to AWS ECR"
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
      // Debug: show what junit files exist before publishing
      sh '''
        echo "=== JUnit report files in workspace ==="
        ls -al reports || true
        find reports -maxdepth 2 -type f -name "*.xml" -print || true
      '''

      // Archive artifacts safely even if some don't exist
      archiveArtifacts artifacts: 'dist/**,coverage.xml,k6-summary.json,reports/*.xml',
                       fingerprint: true,
                       allowEmptyArchive: true

      // Publish junit results safely (won't fail build if a report is missing)
      // JUnit plugin supports allowEmptyResults to prevent build failure on missing reports. 
      junit testResults: 'reports/*.xml', allowEmptyResults: true

      cleanWs()
    }
  }
}
