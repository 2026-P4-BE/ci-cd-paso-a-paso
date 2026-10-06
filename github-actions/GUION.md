# Guion: GitHub Actions en 6 pasos

Cada paso = un archivo para abrir en pantalla, copiarlo sobre el del repo y ejecutarlo. Cómo aplicarlo: [README](../README.md). Los números de línea son los de los archivos de esta carpeta.

**Antes de empezar:** repo `tienda-api` en `main`, limpio, y trabajar en una rama `feature/demo-clase-paso-N` (ver README). Recordar la limitación: GitHub no dispara por `push`; se usa **Run workflow** (o `gh workflow run ci.yml --ref <rama>`). Explicar igual `on: push` como el disparador normal.

**Cómo romper y reparar (vale para los pasos 2 a 4):** se hace un commit con el cambio, se empuja, se ejecuta y luego se repara con `git revert --no-edit HEAD && git push` (un commit nuevo, no se reescribe historia).

---

## Paso 1: el workflow mínimo (`01-minimo/ci.yml`)

**Antes de mostrar el archivo**
- Un workflow es un archivo YAML en `.github/workflows/`. Si hace falta, 5 minutos de [00-que-es-yaml.md](../00-que-es-yaml.md).
- Es el ejemplo del PDF casi igual: cambian el nombre del job, `@v7` en lugar de `@v4` y `./mvnw -B compile`.
- Pipeline = secuencia automática que arranca un evento. Etapas 1 (Checkout) y 2 (Build).

**Señalar**

| Líneas | Qué decir |
|--------|-----------|
| 13 | `name`: lo que se ve en la pestaña Actions |
| 16-28 | `on`: el disparador. `push` es el normal; `workflow_dispatch` es el botón manual |
| 33, 38 | Job y `runs-on`: una máquina nueva y vacía por ejecución |
| 42-45 | `uses` = acción reutilizable (checkout). Sin esto la máquina no tiene el código |
| 49-55 | `with` = parámetros; por qué `'17'` va entre comillas |
| 62 | `run` = comando de shell |

**Ejecutar:** aplicar el paso 1 y *Run workflow*.
**Qué deben ver:** el job "Build" con sus steps en verde; en el log de *Compile with Maven* aparece `BUILD SUCCESS`.

**Pregunta:** *Si el código ya está en GitHub, ¿para qué hace falta `checkout`?*
**Respuesta:** el runner es una máquina virtual vacía; `checkout` trae el código del commit exacto que disparó el workflow (trazabilidad).

**Romper:** en `.github/workflows/ci.yml` quitar 2 espacios de indentación a `uses: actions/setup-java@v6` (línea 49), commit y push. GitHub debería marcar el workflow como inválido e indicar la línea (no se probó: verificarlo una vez). Reparar con `git revert`.

---

## Paso 2: tests y reportes (`02-tests/ci.yml`)

**Antes de mostrar el archivo**
- Etapa Testing: *fail early*. Si un test falla, todo lo demás se corta y el desarrollador se entera enseguida.
- Los reportes se necesitan **justo cuando falla**: por eso `if: always()`.
- Un artefacto es un archivo que la ejecución deja para descargar.

**Señalar:** línea 61 (`./mvnw -B test` reemplaza al compile); 66 (`if: always()`); 64-78 (`upload-artifact`, `path`, `name` con `run_attempt`).

**Ejecutar:** aplicar el paso 2 y *Run workflow*.
**Qué deben ver:** en *Run tests*, líneas `Tests run: N, Failures: 0`. Al pie de la ejecución, sección **Artifacts**: `reports-<n>-1`.

**Pregunta:** *Si borro `if: always()` y un test falla, ¿qué pasa con el artefacto?*
**Respuesta:** el step de subida se saltea porque uno anterior falló: no queda ningún reporte, justo cuando más hacía falta.

**Romper:** `src/test/java/ar/edu/utn/frc/tienda/product/ProductServiceTest.java`, línea 61 (test `createSavesNewProduct`): cambiar `isEqualTo(5)` por `isEqualTo(6)`. *Run tests* queda rojo, *Upload test reports* igual se ejecuta y el artefacto trae el reporte con el test fallido.

---

## Paso 3: quality gates (`03-quality-gates/ci.yml` + `pom-fragmento.xml`)

**Antes de mostrar el archivo**
- Un quality gate es una regla que **bloquea** el build: aquí, cobertura de líneas ≥ 80% y cero violaciones de PMD.
- Las reglas **no están en el workflow**: viven en `pom.xml`. El workflow solo ejecuta `./mvnw -B verify`. Abrir `pom-fragmento.xml` (es un extracto para leer).
- "Una cobertura alta no garantiza calidad, pero una cobertura baja indica riesgo."

**Señalar:** línea 59 (`cache: maven`); 66-67 (`verify`); 74-88 (más rutas en el artefacto). En `pom-fragmento.xml`: el bloque `check` de JaCoCo (`minimum`) y `failOnViolation` de PMD.

**Ejecutar:** aplicar el paso 3 y *Run workflow*; si se puede, ejecutar **dos veces**.
**Qué deben ver:** en el artefacto, las carpetas `site/jacoco` y `pmd.xml`. En el log de *Set up Temurin 17 with Maven cache* se informa si el caché se guardó o se restauró (la 2da ejecución debería restaurarlo).

**Pregunta:** *Con 100% de cobertura, ¿el código es bueno?*
**Respuesta:** no necesariamente: mide qué líneas se ejecutaron, no si los tests verifican lo correcto. Por eso es una compuerta mínima, no una garantía.

**Romper (PMD):** `src/main/java/ar/edu/utn/frc/tienda/product/ProductService.java`, después de la línea 15 (`public List<Product> findAll() {`) agregar `System.out.println("findAll called");`. Los tests pasan, pero `verify` falla en PMD (regla `SystemPrintln` del `config/pmd-ruleset.xml`).

---

## Paso 4: segundo job con `needs` e imagen Docker (`04-docker/ci.yml` + `Dockerfile`)

**Antes de mostrar el archivo**
- Jobs vs steps: los **steps** corren en orden dentro de una máquina; los **jobs** son máquinas distintas, en paralelo salvo que se use `needs`.
- Etapa Packaging: la imagen es el artefacto que se despliega; "lo que se prueba es exactamente lo que se desplegará".
- Se agrega `permissions: contents: read` (mínimo privilegio); se profundiza en el paso 5.

**Señalar:** 34-36 (`permissions`); 97-101 (`package` y `needs: build-test`); 105-106 (otro checkout: máquina nueva); 115 (`docker build`, etiqueta = SHA corto); 123-128 (arranca el contenedor y consulta `/actuator/health`). Abrir `Dockerfile`: dos `FROM` = multi-stage (la etapa de build se descarta; la final solo tiene el JRE y corre sin ser root).

**Ejecutar:** aplicar el paso 4 y *Run workflow*.
**Qué deben ver:** el grafo con dos cajas unidas por una flecha, `build-test → package`; en el log, `Health check passed after N attempt(s)`.

**Pregunta:** *¿Por qué `package` vuelve a hacer checkout?*
**Respuesta:** cada job arranca en una máquina nueva y vacía; no hereda nada del anterior.

**Romper:** repetir el cambio del paso 2 (`ProductServiceTest.java:61`, `5` → `6`). `build-test` queda rojo y `package` aparece **omitido** (skipped): eso es `needs`. Reparar con `git revert`.

**Nota:** el `Dockerfile` comentado es una copia para leer; el repo ya tiene el real, equivalente.

---

## Paso 5: release por tag (`05-release/release.yml`)

**Antes de mostrar el archivo**
- Etapa Release: solo se publica si todo lo anterior pasó, y con una **versión** (SemVer: `MAJOR.MINOR.PATCH`, `v1.0.0`).
- El **tag de git es el disparador**: crear el tag es la decisión humana de "esta versión sale".
- Cero credenciales en el repo: `GITHUB_TOKEN` lo crea GitHub para cada ejecución y vence al terminar.

**Señalar:** 23 (`tags: ['v*.*.*']`); 27-29 y 41-45 (`permissions` del workflow y del job: el del job reemplaza, no suma); 66-90 (el step `meta`: el tag y el `pom.xml` deben coincidir); 114-122 (login a GHCR con `secrets.GITHUB_TOKEN`); 142-145 (`gh release create`).

**Ejecutar:** en la rama con el archivo ya commiteado, `git tag -a v1.0.0 -m "[tienda-api demo] paso 5" && git push origin v1.0.0` (el `pom.xml` ya está en 1.0.0; el prefijo del mensaje es lo que deja a `reset.sh` borrarlo). Si no arranca solo: `gh workflow run release.yml --ref v1.0.0`.
**Qué deben ver:** job verde; en el repo, un **Release** `v1.0.0` con el jar adjunto y en **Packages** la imagen `ghcr.io/daronarg/tienda-api` con las etiquetas `1.0.0` y `latest`.

**Pregunta:** *¿Dónde está la contraseña con la que se sube la imagen a GHCR?*
**Respuesta:** en ningún lado: `secrets.GITHUB_TOKEN` se genera en cada ejecución. No hay credenciales guardadas en el repositorio.

**Romper:** crear un tag que no coincide con el `pom.xml`: `git tag -a v1.0.1 -m "[tienda-api demo] tag erróneo" && git push origin v1.0.1` (o `gh workflow run release.yml --ref v1.0.1`). Falla en *Check that the Git tag matches the pom.xml version* con la anotación "Tag/version mismatch", **antes** de publicar nada. Reparar: `git push origin --delete v1.0.1 && git tag -d v1.0.1`.

---

## Paso 6: deploy con entornos (`06-deploy/release.yml`)

**Antes de mostrar el archivo**
- Etapa Deploy y entornos: *staging* y *production*. Un `environment` es una configuración del repositorio (Settings > Environments) con reglas propias.
- **Continuous Delivery:** el artefacto siempre está listo y una persona decide producción. **Continuous Deployment:** sin esa persona.
- El deploy es **simulado**: el contenedor corre dentro del runner para demostrar que la imagen publicada funciona.

**Señalar:** 48-52 (`outputs`: cómo un job le pasa datos a otro); 158-166 (`deploy-staging`, `needs`, `environment: staging`); 185 (se **descarga** la imagen, no se recompila: artefacto inmutable); 226 (`needs` con lista); 228-235 (comentario y `environment: production`).

**Ejecutar:** si ya se hizo el paso 5, hay que borrar el tag y el Release de `v1.0.0` (`scripts/reset.sh` de `tienda-api`) y repetir con este archivo: `git tag -a v1.0.0 -m "[tienda-api demo] paso 6" && git push origin v1.0.0` (o `gh workflow run release.yml --ref v1.0.0`).
**Qué deben ver:** `release` verde, `deploy-staging` corre solo y `deploy-production` queda **Waiting** con el botón *Review deployments*. Aprobar: producción corre.

**Pregunta:** *¿Qué cambio convierte esto en Continuous Deployment?*
**Respuesta:** el freno no está en el archivo sino en el entorno: quitar *Required reviewers* de `production` en Settings > Environments (el archivo no cambia). En el archivo, la alternativa es borrar el bloque `environment` de `deploy-production`, a costa de perder el registro de despliegues del entorno.

**Romper:** en `deploy-staging`, línea 204, cambiar `${VERSION}` por `9.9.9` dentro del `grep`. Staging falla y `deploy-production` **ni se ofrece** (no queda esperando aprobación), porque `needs` exige staging verde.

---

## Diferencias con `tienda-api` (para decirlo si preguntan)

Los pasos 4 y 6 son equivalentes a los workflows verificados del repo, salvo: sin `concurrency`, sin `timeout-minutes` y, en `ci.yml`, sin el step "Write job summary". Verificado comparando los YAML ya interpretados, sin comentarios.
