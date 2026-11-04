# CI de Adopet en Jenkins

Configuración de integración continua para el proyecto Flutter **Adopet**, sobre
el Jenkins que corre en esta máquina (`http://localhost:8080`).

## Archivos

| Archivo | Para qué sirve |
| --- | --- |
| `../../Jenkinsfile` | Pipeline declarativo: dependencias, análisis, formato, pruebas, APK y web. |
| `job-config.xml` | Definición del job de Jenkins (plantilla; el script sustituye repo y rama). |
| `setup-jenkins.ps1` | Instala plugins, crea/actualiza el job y lanza el primer build. |
| `install-plugins-offline.py` | Instala plugins escribiendo en `JENKINS_HOME`, sin pasar por la UI. Para reparar una instalación de plugins a medias. |

## Reparación de la instalación de plugins (ya aplicada)

El asistente inicial de Jenkins no terminó de bajar sus plugins: dejó 24
archivos `*.jpi.tmp` de **0 bytes** en `C:\ProgramData\Jenkins\.jenkins\plugins\`.
El efecto visible era este error en *Manage Jenkins*:

```
Pipeline: Declarative Extension Points API — Falta el plugin: pipeline-stage-step
Pipeline: Declarative              — Falta el plugin: pipeline-stage-step
```

Sin `pipeline-stage-step` el plugin **Pipeline: Declarative** no carga, y sin él
un `Jenkinsfile` declarativo no compila: el pipeline no habría arrancado nunca.

`install-plugins-offline.py` ya instaló los 8 plugins que faltaban, verificando
el sha256 de cada descarga (`git`, `git-client`, `gson-api`,
`mina-sshd-api-common`, `mina-sshd-api-core`, `pipeline-graph-view`,
`pipeline-stage-step`, `workflow-aggregator`).

Los archivos `.jpi.tmp` vacíos y restantes pertenecen a `SYSTEM`, así que hay que
borrarlos desde una consola **como administrador** (son basura, no se cargan,
pero ensucian la vista de plugins):

```powershell
Remove-Item 'C:\ProgramData\Jenkins\.jenkins\plugins\*.jpi.tmp' -Force
Restart-Service jenkins
```

El reinicio es obligatorio: Jenkins solo activa los `.jpi` nuevos al arrancar.

## Puesta en marcha

1. **Genera un API token** en Jenkins:
   `http://localhost:8080/me/security/` → *API Token* → *Add new Token* → *Generate*.

2. **Ejecuta el script** desde PowerShell (no requiere administrador):

   ```powershell
   cd C:\Users\Pablo\Documents\8-sem\Adopet\ci\jenkins
   .\setup-jenkins.ps1 -JenkinsUser jenkins -JenkinsToken <TU_TOKEN>
   ```

   El script instala los plugins que faltan (con sus dependencias), reinicia
   Jenkins solo si hace falta, crea el job `Adopet-CI` y espera el resultado del
   primer build.

Para usar el repositorio local en vez de GitHub:

```powershell
.\setup-jenkins.ps1 -JenkinsUser jenkins -JenkinsToken <TU_TOKEN> -RepoUrl 'C:/Users/Pablo/Documents/8-sem/Adopet'
```

> Con cualquiera de las dos opciones, el `Jenkinsfile` tiene que estar
> **commiteado** en la rama que el job vigila (`main`), porque Jenkins hace
> checkout del commit, no del directorio de trabajo.

## Qué hace el pipeline

| Etapa | Comando | Falla el build? |
| --- | --- | --- |
| Entorno | crea cachés e imprime versiones | sí |
| Limpieza | `flutter clean` (solo con `CLEAN_BUILD`) | sí |
| Dependencias | `flutter pub get` | sí |
| Análisis estático | `flutter analyze --no-fatal-infos` | sí, ante errores y *warnings* |
| Formato | `dart format --set-exit-if-changed` | no, solo avisa |
| Pruebas | `flutter test --coverage` + reporte JUnit | sí |
| APK Android | `flutter build apk --debug\|--release` | sí |
| Web | `flutter build web --release` + zip | sí |

Las etapas corren **en serie** a propósito. En un pipeline declarativo, las
ramas de un bloque `parallel` que no declaran su propio `agent` comparten el
mismo workspace, y dos comandos de Flutter simultáneos se pisan en `build/` y
`.dart_tool/`. Paralelizar aquí requeriría agentes separados.

### Parámetros del job

- `ANDROID_BUILD_MODE` — `debug` (por defecto) o `release`.
- `BUILD_WEB` — compilar también la versión web (activado).
- `CLEAN_BUILD` — `flutter clean` antes de compilar (desactivado; es más lento).

Los parámetros los declara el `Jenkinsfile`, así que aparecen en la interfaz
**después del primer build**.

### Artefactos que archiva

- `build/app/outputs/flutter-apk/*.apk`
- `build/adopet-web.zip`
- `build/reports/*` (JSON y JUnit XML de las pruebas)
- `coverage/lcov.info`

## Decisiones de configuración

- **`--no-fatal-infos` en el análisis.** El proyecto tiene ~116 avisos de nivel
  `info` (sobre todo `withOpacity` deprecado) y 0 errores o *warnings*. Sin esa
  bandera, `flutter analyze` devuelve código 1 y el build quedaría siempre rojo.
  Cuando limpies esos avisos, quita la bandera para volverlos bloqueantes.

- **El formato no bloquea.** `dart format` cambiaría 54 de 55 archivos. La etapa
  avisa en consola sin tumbar el build. Si ejecutas `dart format .` y commiteas
  el resultado, puedes convertirla en una etapa bloqueante.

- **Variables de entorno explícitas en el `Jenkinsfile`.** El servicio de Jenkins
  corre como `LocalSystem`, que no hereda el `PATH` ni el `ANDROID_HOME` de tu
  usuario. Por eso el pipeline fija `FLUTTER_HOME`, `ANDROID_SDK_ROOT`,
  `JAVA_HOME` y añade Flutter y Git al `PATH`.

- **Cachés propias del CI.** `PUB_CACHE` y `GRADLE_USER_HOME` apuntan a
  `C:\ProgramData\Jenkins\caches\`, para que el servicio tenga un directorio
  donde escribir y no compita con tus cachés de usuario. El **primer build es
  lento** (descarga paquetes de pub y Gradle); los siguientes reutilizan la caché.

- **Trigger:** `SCMTrigger` cada 15 minutos (`H/15 * * * *`). Si prefieres
  webhooks de GitHub, hacen falta un Jenkins accesible desde internet (o un túnel)
  y el plugin `github`.

- **`Compress-Archive` en vez del step `zip`.** Así el pipeline no depende del
  plugin `pipeline-utility-steps`.

## Verificado en esta máquina

- Jenkins 2.580.2, servicio corriendo como `LocalSystem`, `JENKINS_HOME` en
  `C:\ProgramData\Jenkins\.jenkins`.
- Flutter 3.47.8 (Dart 3.13.7) en `C:\src\flutter`, JDK 21, Android SDK 37.0.0
  con todas las licencias aceptadas.
- `flutter test` → 3 pruebas en verde; conversión a JUnit XML con `junitreport`
  funcionando.
- `flutter build apk --debug` → `app-debug.apk` generado correctamente.

## Problemas frecuentes

**`flutter` no se reconoce como comando** — el servicio no ve tu `PATH`.
Comprueba que `FLUTTER_HOME` en el `Jenkinsfile` apunte a tu instalación real
(`where.exe flutter`).

**El build no encuentra el Android SDK** — ajusta `ANDROID_SDK_ROOT` en el
`Jenkinsfile`; el SDK está en el perfil de tu usuario, no en una ruta global.

**El reporte de pruebas sale vacío** — el pipeline instala `junitreport` con
`dart pub global activate` en cada build; si la máquina está sin red, ese paso
falla en silencio y no se genera `build/reports/junit.xml`. Las pruebas siguen
corriendo y el build sigue siendo válido.

**APK en modo `release`** — `android/app/build.gradle.kts` solo configura firma
si existe la variable `ADOPET_KEYSTORE_PATH`. Sin ella, el `release` queda sin
firmar. Para firmarlo, define en el job (o en las credenciales de Jenkins)
`ADOPET_KEYSTORE_PATH`, `ADOPET_KEYSTORE_PASSWORD`, `ADOPET_KEY_ALIAS` y
`ADOPET_KEY_PASSWORD`.
