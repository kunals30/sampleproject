pipeline {
  agent { label 'build' }

  options {
    timestamps()
  }

  environment {
    SONAR_ORG = "kunals30"
    SONAR_PROJECT_KEY = "kunals30_sampleproject"

    // ===== Docker / Nexus (NEW) =====
    IMAGE_NAME = "sampleproject"
    IMAGE_TAG  = "build-${BUILD_NUMBER}"
    NEXUS_REGISTRY = "65.1.128.203:8082"
    NEXUS_IMAGE = "${NEXUS_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
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
        '''
      }
    }

    stage('Unit Tests + Coverage') {
      steps {
        sh '''
          . .venv/bin/activate
          pytest --cov=src --cov-report=xml --junitxml=unit-tests.xml
        '''
      }
    }

    stage('Functional Tests') {
      steps {
        sh '''
          . .venv/bin/activate
          pytest -m functional --junitxml=functional-tests.xml
        '''
      }
    }

    stage('Build Python Wheel') {
      steps {
        sh '''
          . .venv/bin/activate
          python -m build
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
          ls -al tests/performance || true
          test -f tests/performance/load_test.js
          k6 run ./tests/performance/load_test.js --summary-export=k6-summary.json
        '''
      }
    }

    // ===== Docker Build (NEW) =====
    stage('Docker Build') {
      agent { label 'docker' }
      steps {
        sh '''
          echo "Building Docker image ${IMAGE_NAME}:${IMAGE_TAG}"
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
        '''
      }
    }

    // ===== Push Docker Image to Nexus (NEW) =====
    stage('Push Docker Image to Nexus') {
      agent { label 'docker' }
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
  }

  post {
    always {
      archiveArtifacts artifacts: 'dist/*,coverage.xml,k6-summary.json', fingerprint: true
      junit 'unit-tests.xml'
      junit 'functional-tests.xml'
      cleanWs()
    }
  }
}

