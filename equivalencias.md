# GitHub Actions ↔ Jenkins: la misma idea, dos vocabularios

Los dos hacen lo mismo: un **evento** dispara un **pipeline** definido en un **archivo versionado** que ejecuta **etapas** en una máquina limpia. Lo que cambia es quién mantiene el servidor y cómo se escribe el archivo.

## Tabla de equivalencias

| Concepto | GitHub Actions (`tienda-api`) | Jenkins (`turnos-api`) |
|----------|-------------------------------|------------------------|
| Archivo de configuración | `.github/workflows/ci.yml` (YAML) | `Jenkinsfile` en la raíz (Groovy declarativo) |
| Disparador | `on:` dentro del archivo (`push`, `pull_request`, tag, manual) | Lo define el **job**, no el archivo: acá, polling cada minuto en `casc.yaml` |
| Dónde corre | `runs-on: ubuntu-latest`: VM nueva por job, la destruye GitHub | `agent any`: el propio Jenkins (2 executors); no se destruye |
| Unidad grande | `job` (máquina propia; entre jobs, `needs`) | `stage` (todas en el mismo agente y workspace) |
| Unidad chica | `step` (`uses:` acción o `run:` comando) | step dentro de `steps { }` (`sh`, `junit`, `input`...) |
| Código reutilizable | Acciones (`actions/checkout@v7`) | Plugins (`junit`, `coverage`) y librerías compartidas |
| Variables | `env:` en workflow, job o step | `environment { }` en pipeline o etapa |
| Artefactos | `actions/upload-artifact` | `archiveArtifacts` |
| Resultados de tests | Artefacto con los reportes | `junit` publica Test Result con tendencia |
| Secretos | `secrets.GITHUB_TOKEN`, secrets del repo o del entorno | Credentials de Jenkins (en el material no se usan; el registry local no pide login) |
| Aprobación manual | `environment` con *Required reviewers* (se configura en Settings, no en el archivo) | `input` dentro del Jenkinsfile |
| Entornos | `environment: staging` / `production` | Etapas (`Deploy Staging`, `Deploy Production`); sin objeto "entorno" propio |
| Tiempo máximo | `timeout-minutes` | `options { timeout(...) }` |
| Evitar solapes | `concurrency:` | `disableConcurrentBuilds()` |
| Condición | `if: always()` | `post { always { ... } }` |
| Quién mantiene el servidor | GitHub | Nosotros (imagen, plugins, actualizaciones, disco) |
| El servidor como código | No aplica: lo da GitHub | `Dockerfile` + `casc.yaml` + `docker-compose.yml` |
| Costo | Incluido en el plan (límites por minutos en repos privados) | Lo que cueste la máquina y su mantenimiento |

## Mismo pipeline, lado a lado

| Etapa del curso | GitHub Actions | Jenkins |
|-----------------|----------------|---------|
| 1. Checkout | `actions/checkout@v7` | `checkout scm` |
| 2. Build | `./mvnw -B compile` | `mvn -B clean package -DskipTests` |
| 3. Testing | `./mvnw -B test` | `mvn -B test` + `junit` |
| 3. Cobertura | `./mvnw -B verify` (JaCoCo en el `pom.xml`) | `jacoco:check@coverage-gate` en su propia etapa |
| 4. Análisis estático | PMD dentro de `verify` | `pmd:check@static-analysis` en su propia etapa |
| 5. Packaging | job `package` con `docker build` | etapa `Package` con `docker build` |
| 6. Release | `release.yml` por tag `v*.*.*`, imagen en GHCR, GitHub Release | etapa `Publish`, imagen en el registry local |
| 7. Deploy | `deploy-staging` y `deploy-production` | `Deploy Staging`, `Approval`, `Deploy Production` |

## Cuándo elegir cada uno

| Elegir **GitHub Actions** si... | Elegir **Jenkins** si... |
|---------------------------------|--------------------------|
| El código ya está en GitHub y se quiere arrancar hoy | Hay que correr dentro de una red propia o con hardware propio |
| No se quiere administrar un servidor | Se necesita control total (versiones, plugins, agentes) |
| El equipo es chico o el proyecto es abierto | La organización ya lo opera o integra muchos sistemas distintos |
| Se valora un ecosistema de acciones listo para usar | Se aceptan los costos de mantenerlo (seguridad, actualizaciones) |

**Para cerrar la comparación:** el concepto es el mismo; lo que cambia es *dónde vive el disparador*, *quién es dueño del servidor* y *dónde se configura la aprobación manual* (en el archivo en Jenkins, en el entorno del repositorio en GitHub).
