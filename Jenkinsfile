pipeline {
  agent { label 'build' }

  options {
    timestamps()
  }

  environment {
    SONAR_ORG = "kunals30"
    SONAR_PROJECT_KEY = "kunals30_sampleproject"
  }

  stages {

    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Setup Python venv & deps') {
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
          pytest --cov=src --cov-report=xml
        '''
      }
    }

    stage('SonarCloud Scan') {
      steps {
        withEnv(["SONAR_TOKEN=${credentials('sonarcloud-token')}"]) {
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

  post {
    always {
      archiveArtifacts artifacts: 'dist/*,coverage.xml', fingerprint: true
      cleanWs()
    }
  }
}

