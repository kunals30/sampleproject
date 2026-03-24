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
      steps { checkout scm }
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
