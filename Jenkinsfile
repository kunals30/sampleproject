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
    withCredentials([
      string(credentialsId: 'sonarcloud-token', variable: 'SONAR_TOKEN')
    ]) {
      withEnv([
        "PATH+SONAR=${tool 'SonarScanner'}/bin"
      ]) {
        sh '''
          . .venv/bin/activate
          sonar-scanner \
            -Dsonar.organization=kunals30 \
            -Dsonar.projectKey=kunals30_sampleproject \
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

