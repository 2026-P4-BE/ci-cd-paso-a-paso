# Guion: Jenkins en 5 pasos

Es la misma idea que en GitHub Actions, con otro vocabulario: **etapa** (`stage`) en vez de job/step y **Jenkinsfile** en vez de workflow. Cómo aplicar un paso: [README](../README.md). Los números de línea son los de los archivos de esta carpeta.

**Antes de empezar:** Jenkins arriba en `http://localhost:8090` (admin / admin) y `turnos-api` en `main`, limpio. Cada paso es un commit en `main` con el trailer `Class-Demo: step N`; Jenkins lo detecta en **hasta 1 minuto** (polling) o se acelera con `scripts/jenkins.sh build`.

**Reparar un commit roto (pasos 2 a 4):** `scripts/demo.sh fix` crea un commit que lo revierte, porque el trailer lo marca como propio.

**Lo que hay que decir una vez:** el Jenkinsfile **no** define el disparador; lo define el job, y el job está definido por código en `casc.yaml` (`scm('* * * * *')`, cada minuto). Ver "Jenkins como código" más abajo.

---

## Paso 1: anatomía de un Jenkinsfile (`01-minimo/Jenkinsfile`)

**Antes de mostrar el archivo**
- Pipeline como código: el Jenkinsfile viaja en el repositorio junto con la aplicación.
- Sintaxis *declarativa*: bloques con una estructura fija, fácil de leer y de validar.
- Etapas 1 (Checkout) y 2 (Build) del curso.

**Señalar**

| Líneas | Qué decir |
|--------|-----------|
| 13 | `pipeline { }`: todo vive adentro |
| 15 | `agent any`: dónde corre (acá, el propio Jenkins) |
| 18-29 | `options`: hora en el log, tiempo máximo, un build a la vez, historial acotado |
| 32-35 | `environment`: variables disponibles en todas las etapas |
| 39-41 | `stages` → `stage('Checkout')`: cada etapa es una columna de Stage View |
| 46 | `checkout scm`: el mismo repo y commit del Jenkinsfile |
| 51-55 | `stage('Build')` y `sh`: comando de shell en el agente |

**Ejecutar:** aplicar el paso 1 y esperar el polling.
**Qué deben ver:** en la página del job, **Stage View** con 2 columnas verdes; en *Console Output*, cada línea con la hora.

**Pregunta:** *En GitHub teníamos `on: push`. ¿Dónde está el disparador acá?*
**Respuesta:** no está en el Jenkinsfile. Lo define el job (`triggers { scm('* * * * *') }` en `casc.yaml`): Jenkins consulta el repositorio cada minuto y construye si hay un commit nuevo.

**Romper:** en el Jenkinsfile, cambiar `stages {` (línea 39) por `stagess {`, commit y esperar. El build falla enseguida con `Undefined section "stagess"` (mensaje del validador de Jenkins) y **ninguna etapa corre** (`scripts/demo.sh fix` repara).

---

## Paso 2: tests, resultados y `post` (`02-tests/Jenkinsfile`)

**Antes de mostrar el archivo**
- Etapa Testing: *fail early*; un test rojo corta el pipeline.
- `post` = qué hacer **según cómo terminó** (siempre, solo si falló, solo si anduvo).
- Los resultados se publican en Jenkins, no solo quedan en el log.

**Señalar:** 61-65 (`Test` y `mvn -B test`); 66-72 (`post` de la etapa: `always { junit ... }`); 78-90 (`post` del pipeline: `always` archiva el jar, `failure` notifica).

**Ejecutar:** aplicar el paso 2 y esperar.
**Qué deben ver:** una columna *Test* verde; en el build, **Test Result** con la cantidad de tests; el jar en *Build Artifacts*.

**Pregunta:** *Si un test falla, ¿se llega a ejecutar `junit`?*
**Respuesta:** sí: está en `post { always }`, que corre pase lo que pase. Así el detalle de qué test falló queda publicado.

**Romper:** `src/test/java/ar/edu/utn/frc/turnos/service/AppointmentServiceTest.java`, línea 45 (test `createsAppointmentWhenSlotIsFree`): cambiar `isEqualTo("Dr. House")` por `isEqualTo("Dr. Who")` y hacer commit con `Class-Demo: step 2`. *Test* queda roja, no corre ninguna etapa posterior y la consola muestra `[SIMULATED NOTIFICATION] ... FAILED`.

---

## Paso 3: quality gates (`03-quality-gates/Jenkinsfile`)

**Antes de mostrar el archivo**
- Un quality gate **bloquea** el build: cobertura de líneas ≥ 80% (JaCoCo) y sin violaciones de PMD (análisis estático / SAST: mira el código sin ejecutarlo).
- Las reglas viven en el `pom.xml`; acá cada compuerta es **una etapa visible** (`jacoco:check@coverage-gate`, `pmd:check@static-analysis`).
- En GitHub, `mvn verify` hacía todo en un solo step; en Jenkins se separa para ver cuál falla.

**Señalar:** 75-86 (`Coverage Gate`, `recordCoverage`); 89-99 (`Static Analysis`, artefacto `pmd.xml`).

**Ejecutar:** aplicar el paso 3 y esperar.
**Qué deben ver:** dos columnas más; en el build, el reporte de cobertura (plugin Coverage) y `pmd.xml` entre los artefactos.

**Pregunta:** *Si bajo el umbral a 0%, ¿mejora el producto?*
**Respuesta:** no: el pipeline pasaría, pero la compuerta dejaría de proteger. "Una cobertura baja indica riesgo": el umbral es un acuerdo del equipo.

**Romper (PMD):** `src/main/java/ar/edu/utn/frc/turnos/service/AppointmentService.java`, después de la línea 35 (`public List<Appointment> findAll() {`) agregar `System.out.println("findAll called");`. *Static Analysis* queda roja (regla `SystemPrintln`). Para romper la cobertura en cambio: `scripts/demo.sh drop-coverage` agrega una clase sin tests.

---

## Paso 4: imagen Docker y registry (`04-docker/Jenkinsfile`)

**Antes de mostrar el archivo**
- Etapas Packaging y Release: la imagen es **el artefacto inmutable** que después se despliega.
- La etiqueta es `<versión del pom>-<número de build>-<commit>`: de cualquier imagen se llega a su build y a su commit.
- El registry es un contenedor local (`localhost:5001`), definido en `docker-compose.yml`.

**Señalar:** 36-39 (`REGISTRY`, `IMAGE_NAME`); 55-66 (el bloque `script` que arma `env.IMAGE`); 123-129 (`Package`: `docker build`); 132-137 (`Publish`: `docker push`).

**Ejecutar:** aplicar el paso 4 y esperar.
**Qué deben ver:** dos columnas más; en el log, `Image to build: localhost:5001/turnos-api:<versión>-<build>-<commit>`. Comprobar en el navegador `http://localhost:5001/v2/turnos-api/tags/list`.

**Pregunta:** *¿Por qué no se usa solo `latest` como etiqueta?*
**Respuesta:** `latest` se mueve en cada build y no dice qué hay adentro; con versión + build + commit, la imagen es rastreable y no se confunde con otra.

**Romper:** repetir el cambio del paso 2 (`AppointmentServiceTest.java:45`): el pipeline se corta en *Test* y **no se publica ninguna imagen nueva** en el registry (la lista de tags no cambia). Eso es "solo se publica si todo anterior pasó".

**Nota:** el `Dockerfile` de `turnos-api` es multi-stage como el de `tienda-api` (ver `github-actions/04-docker/Dockerfile`); cambia que fija memoria de la JVM y que su `HEALTHCHECK` busca `UP` con `grep`.

---

## Paso 5: deploy con aprobación y rollback (`05-deploy/Jenkinsfile` + `deploy.sh`)

**Antes de mostrar el archivo**
- Etapa Deploy en dos entornos: *staging* automático y *production* tras una **aprobación humana** (Continuous **Delivery**).
- El deploy hace health check y, si la versión nueva no queda sana, **vuelve a la anterior** (rollback). Abrir `deploy.sh` (copia comentada para leer).
- `BREAK_PRODUCTION` es un interruptor de clase para forzar esa falla.

**Señalar:** 34-40 (`parameters`); 148-156 (`Deploy Staging` y su smoke test); 159-168 (`Approval`: `timeout` + `input`); 171-180 (`Deploy Production` con `BREAK_DEPLOY`); 194-197 (`success`).

**Ejecutar:**
1. Aplicar el paso 5 y esperar. El **primer build con el bloque `parameters`** corre con los valores por defecto: Jenkins recién registra el parámetro ahí.
2. El build se detiene en *Approval*: apretar **Deploy to production** en Stage View o en la consola.
3. Para el rollback: lanzar un build con el parámetro (`scripts/jenkins.sh build break-prod`, o *Build with Parameters* marcando `BREAK_PRODUCTION`), esperar *Approval* y aprobar.

**Qué deben ver:** staging responde "staging" y producción queda arriba. Con `BREAK_PRODUCTION`, el log de *Deploy Production* muestra `Health check FAILED`, el motivo, `Rolling back to ...` y `Rollback OK`; la etapa queda roja pero **la versión anterior sigue sirviendo**.

**Pregunta:** *Si el rollback anduvo bien, ¿por qué la etapa queda roja?*
**Respuesta:** porque el despliegue que se pidió **no se concretó**; el rojo avisa que la versión nueva no está en producción aunque el servicio siga funcionando.

**Romper:** no hace falta tocar archivos: `BREAK_PRODUCTION` es el "romper". Si se quiere un rojo antes: en `Deploy Staging`, cambiar `grep -q staging` (línea 154) por `grep -q nada`; el smoke test falla y **no se llega a Approval**.

---

## Jenkins como código (`jenkins-como-codigo/`)

Solo lectura, para el momento "el servidor de CI también es código".

| Archivo | Qué mostrar |
|---------|-------------|
| `Dockerfile` | La imagen de Jenkins con versión fija, Maven, cliente Docker y plugins instalados al construir (sin clics) |
| `plugins.txt` | Los 8 plugins que importan; el archivo real (`turnos-api/jenkins/plugins.txt`) fija 77 |
| `casc.yaml` | Usuarios, URL y el job `turnos-api` con su disparador (`scm('* * * * *')`), todo en YAML |
| `docker-compose.yml` | Jenkins + registry, el socket de Docker y el repositorio montados |

**Pregunta:** *¿Qué pasa si se rompe el servidor Jenkins?*
**Respuesta:** se vuelve a levantar con `docker compose up` y queda igual: usuarios, job y plugins salen de archivos versionados. Distinto de un Jenkins configurado a mano con clics.

---

## Diferencias con `turnos-api`

El Jenkinsfile del paso 5 es **idéntico** al del repo ignorando comentarios y líneas en blanco (comprobado con `diff`). `deploy.sh` y los tres archivos de `jenkins-como-codigo/` también (ignorando comentarios). Las `options` completas aparecen desde el paso 1, no en el último.
