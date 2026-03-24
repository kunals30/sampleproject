pipeline {
  agent { label 'build' }

  options {
    timestamps()
  }

  environment {
    SONAR_ORG = "kunals30"
    SONAR_PROJECT_KEY = "kunals30_sampleproject"

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
          ls -al dist
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
  }

  post {
    always {
      archiveArtifacts artifacts: 'dist/*,coverage.xml', fingerprint: true
      junit 'unit-tests.xml'
      junit 'functional-tests.xml'
      cleanWs()
    }
  }
}
