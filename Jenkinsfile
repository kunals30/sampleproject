pipeline {
  agent { label 'build' }

  options { timestamps() }

  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Setup venv + deps') {
      steps {
        sh '''
          python3 -m venv .venv
          . .venv/bin/activate
          pip install --upgrade pip setuptools wheel build
          pip install -e .
          pip install pytest
        '''
      }
    }

    stage('Build wheel') {
      steps {
        sh '''
          . .venv/bin/activate
          python -m build
          ls -al dist/
        '''
      }
    }

    stage('Unit tests') {
      steps {
        sh '''
          . .venv/bin/activate
          pytest -q
        '''
      }
    }
  }

  post {
    success {
      archiveArtifacts artifacts: 'dist/*', fingerprint: true
    }
    always {
      cleanWs()
    }
  }
}
