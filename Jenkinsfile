// Pipeline de CI para Adopet (Flutter) - Jenkins sobre Windows
pipeline {
    agent any

    parameters {
        choice(
            name: 'ANDROID_BUILD_MODE',
            choices: ['debug', 'release'],
            description: 'Modo de compilacion del APK de Android.'
        )
        booleanParam(
            name: 'BUILD_WEB',
            defaultValue: true,
            description: 'Compilar tambien la version web.'
        )
        booleanParam(
            name: 'CLEAN_BUILD',
            defaultValue: false,
            description: 'Ejecutar "flutter clean" antes de compilar (mas lento).'
        )
    }

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '5'))
        disableConcurrentBuilds()
    }

    environment {
        FLUTTER_HOME     = 'C:\\src\\flutter'
        ANDROID_SDK_ROOT = 'C:\\Users\\Pablo\\AppData\\Local\\Android\\Sdk'
        ANDROID_HOME     = 'C:\\Users\\Pablo\\AppData\\Local\\Android\\Sdk'
        JAVA_HOME        = 'C:\\Program Files\\Microsoft\\jdk-21.0.13.21-hotspot'
        // Caches propias del servicio de Jenkins (corre como LocalSystem)
        PUB_CACHE        = 'C:\\ProgramData\\Jenkins\\caches\\pub-cache'
        GRADLE_USER_HOME = 'C:\\ProgramData\\Jenkins\\caches\\gradle'
        PATH             = "${FLUTTER_HOME}\\bin;${PUB_CACHE}\\bin;${JAVA_HOME}\\bin;C:\\Program Files\\Git\\cmd;${PATH}"
        // Evita que Flutter mande analitica desde el servidor de CI
        FLUTTER_SUPPRESS_ANALYTICS = 'true'
        CI               = 'true'
    }

    stages {

        stage('Entorno') {
            steps {
                bat '''@echo off
                    if not exist "%PUB_CACHE%"        mkdir "%PUB_CACHE%"
                    if not exist "%GRADLE_USER_HOME%" mkdir "%GRADLE_USER_HOME%"
                    if not exist "build\\reports"     mkdir "build\\reports"
                    echo ==== Versiones ====
                    flutter --version
                    dart --version
                    java -version
                    git --version
                '''
            }
        }

        stage('Limpieza') {
            when { expression { return params.CLEAN_BUILD } }
            steps {
                bat 'flutter clean'
            }
        }

        stage('Dependencias') {
            steps {
                bat 'flutter pub get'
            }
        }

        // Las etapas van en serie a proposito: sin un "agent" propio, las
        // ramas de un bloque "parallel" comparten el mismo workspace, y dos
        // comandos de Flutter a la vez se pisan en build/ y .dart_tool/.
        stage('Analisis estatico') {
            steps {
                // El proyecto tiene ~116 avisos "info" y 0 errores/warnings.
                // --no-fatal-infos deja pasar los info pero sigue fallando
                // ante errores y warnings reales.
                bat 'flutter analyze --no-fatal-infos'
            }
        }

        stage('Formato (aviso)') {
            steps {
                script {
                    def status = bat(
                        returnStatus: true,
                        script: 'dart format --output=none --set-exit-if-changed .'
                    )
                    if (status != 0) {
                        echo 'AVISO: hay archivos sin formatear. Ejecuta "dart format ." para corregirlo. No bloquea el build.'
                    } else {
                        echo 'Formato correcto.'
                    }
                }
            }
        }

        stage('Pruebas') {
            steps {
                script {
                    def status = bat(
                        returnStatus: true,
                        script: 'flutter test --coverage --reporter expanded --file-reporter json:build/reports/test-report.json'
                    )

                    // Reporte JUnit para que Jenkins muestre el detalle de las pruebas.
                    bat(returnStatus: true, script: 'dart pub global activate junitreport')
                    bat(returnStatus: true, script: 'dart pub global run junitreport:tojunit --input build/reports/test-report.json --output build/reports/junit.xml')

                    if (status != 0) {
                        error("Las pruebas unitarias fallaron (codigo ${status}).")
                    }
                }
            }
        }

        stage('APK Android') {
            steps {
                bat "flutter build apk --${params.ANDROID_BUILD_MODE}"
            }
        }

        stage('Web') {
            when { expression { return params.BUILD_WEB } }
            steps {
                bat 'flutter build web --release'
                // Compress-Archive evita depender del plugin pipeline-utility-steps
                bat 'powershell -NoProfile -Command "Compress-Archive -Path build/web/* -DestinationPath build/adopet-web.zip -Force"'
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'build/reports/junit.xml'

            archiveArtifacts artifacts: 'build/app/outputs/flutter-apk/*.apk',
                             allowEmptyArchive: true, fingerprint: true
            archiveArtifacts artifacts: 'build/adopet-web.zip',
                             allowEmptyArchive: true
            archiveArtifacts artifacts: 'build/reports/*, coverage/lcov.info',
                             allowEmptyArchive: true
        }
        success {
            echo "Build #${env.BUILD_NUMBER} correcto: APK (${params.ANDROID_BUILD_MODE}) y reportes archivados."
        }
        unstable {
            echo "Build #${env.BUILD_NUMBER} inestable: revisa el reporte de pruebas."
        }
        failure {
            echo "Build #${env.BUILD_NUMBER} fallido: revisa la consola de la etapa en rojo."
        }
    }
}
