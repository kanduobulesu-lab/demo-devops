pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                checkout scm    
            }
        }
        stage('Install Dependencies') {
            steps {
                echo "Installing Node.js dependencies..."
                bat 'npm install'
            }
        }
        stage('Build') {
            steps {
                echo "Building the project..."
                // Create build folder if not exists
                bat 'if not exist build mkdir build'
                // Copy public folder
                bat 'xcopy public build /E /I /Y'
                // Copy build.js
                bat 'copy build.js build\\'
                echo "Build completed!"     
            }
        }
        stage('Archive Artifacts') {
            steps {
                echo "Archiving build artifacts..."
                archiveArtifacts artifacts: '**/build/**', allowEmptyArchive: true  
            }  
        }      
    }
}