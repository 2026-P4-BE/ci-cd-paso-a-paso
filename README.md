# CI/CD paso a paso: el protagonista es el archivo, no el comando

Material para dar la Unidad 5 mostrando pantalla. Cada paso es un archivo **completo y válido** que se copia sobre el del repositorio y agrega **una sola idea**, con cada línea comentada en español (el "machete"). La clase explica el archivo; el pipeline que corre es la prueba de que funciona.

> **Estado de verificación:** los archivos pasaron `actionlint` (GitHub Actions) y el validador declarativo de Jenkins, y los últimos pasos son equivalentes a los del repo (ver "Diferencias con los repos"). **Todavía no se ejecutó ningún paso de verdad** (ni en GitHub ni en Jenkins). Conviene correr cada paso una vez antes de la clase.

## Orden de la clase

| # | Bloque | Material | Idea que queda |
|---|--------|----------|----------------|
| 0 | YAML | [00-que-es-yaml.md](00-que-es-yaml.md) | La indentación es la estructura |
| 1 | GitHub Actions, 6 pasos | [github-actions/](github-actions/GUION.md) | Evento → workflow → job → step |
| 2 | Lo mismo en Jenkins, 5 pasos | [jenkins/](jenkins/GUION.md) | Pipeline como código, etapas |
| 3 | Comparar | [equivalencias.md](equivalencias.md) | Misma idea, distinto dueño del servidor |
| 4 | Estrategias de despliegue | `delivery-lab/RUNBOOK.md` | Rolling, Blue/Green, Canary, Feature Toggles |

## Aplicar un paso en GitHub Actions (`tienda-api`)

Se usa una rama `feature/demo-*` para no ensuciar `main`: el workflow corre en ramas `feature/**` y el `scripts/reset.sh` del repo reconoce y borra las `feature/demo-*`.

```bash
cd tienda-api
git switch main && git switch -c feature/demo-clase-paso-1
cp ../paso-a-paso/github-actions/01-minimo/ci.yml .github/workflows/ci.yml
git add .github/workflows/ci.yml
git commit -m "ci: class step 1 minimal workflow"
git push -u origin feature/demo-clase-paso-1
gh workflow run ci.yml --ref feature/demo-clase-paso-1   # ver nota
gh run watch                                         # elegir la ejecución en curso
```

- **Nota:** en este repo GitHub **no inicia** workflows por `push`/`pull_request` (causa desconocida); el disparo manual sí funciona. Decirlo así: *"el disparador normal es `on: push`, hoy lo disparo a mano con Run workflow; el workflow es el mismo"*. Botón: pestaña **Actions → CI → Run workflow**.
- Para el paso siguiente: copiar el nuevo `ci.yml` sobre el mismo archivo, commit, push y volver a ejecutar.
- Pasos 5 y 6 (`release.yml`) se disparan con un tag: `git tag -a v1.0.0 -m "[tienda-api demo] paso 5" && git push origin v1.0.0` (el prefijo `[tienda-api demo]` hace que `reset.sh` acepte borrarlo), y si no arranca solo, `gh workflow run release.yml --ref v1.0.0`. El `pom.xml` ya está en `1.0.0`.
- Volver a empezar: `scripts/reset.sh` de `tienda-api` (borra ramas, tags y releases de demos).

## Aplicar un paso en Jenkins (`turnos-api`)

Jenkins lee la rama `main` del repo local y lo consulta cada minuto, así que **el commit en `main` es el disparador**.

```bash
cd turnos-api
cp ../paso-a-paso/jenkins/01-minimo/Jenkinsfile Jenkinsfile
git add Jenkinsfile
git commit -m "ci: class step 1 minimal Jenkinsfile" -m "Class-Demo: step 1"
# esperar hasta 1 minuto (polling) o: scripts/jenkins.sh build
```

La línea `Class-Demo: step 1` (trailer del commit) es lo que permite que `scripts/demo.sh restore` y `scripts/reset.sh` reconozcan el commit como propio y lo deshagan; sin ella se niegan a resetear.

Abrir `http://localhost:8090/job/turnos-api/` (admin / admin) y mirar **Stage View**. En el paso 5 el build se frena en *Approval*: apretar **Deploy to production** en la interfaz.

## Plan B

Si algo falla en vivo: los repos completos (`tienda-api`, `turnos-api`) con sus `scripts/demo.sh`, sus `RUNBOOK.md` y los videos grabados en `ci-cd/videos/`. Este material no los reemplaza, los complementa.

## Qué hay en cada carpeta

| Ruta | Contenido |
|------|-----------|
| `github-actions/01..06` | `ci.yml` (pasos 1-4) y `release.yml` (pasos 5-6) acumulativos |
| `github-actions/03-quality-gates/pom-fragmento.xml` | Solo JaCoCo y PMD del `pom.xml`, para **leer** (no copiar) |
| `github-actions/04-docker/Dockerfile` | El Dockerfile multi-stage comentado, para **leer** |
| `jenkins/01..05` | `Jenkinsfile` acumulativos; `05-deploy/deploy.sh` comentado, para **leer** |
| `jenkins/jenkins-como-codigo/` | `Dockerfile`, `casc.yaml`, `docker-compose.yml` y `plugins.txt` comentados, de **solo lectura** |

## Diferencias con los repos

| Archivo | Diferencia funcional | Por qué |
|---------|----------------------|---------|
| `ci.yml` (paso 4) | Sin `concurrency` | Distrae; solo cancela ejecuciones viejas de la misma rama |
| `ci.yml` (paso 4) | Sin `timeout-minutes: 10` | Distrae del concepto de cada paso |
| `ci.yml` (paso 4) | Sin el step "Write job summary" | Es un adorno; no cambia el resultado |
| `release.yml` (paso 6) | Sin `concurrency` ni `timeout-minutes` | Idem |
| `Jenkinsfile` (paso 5) | Ninguna | Idéntico al del repo ignorando comentarios |

Todo lo que se conserva se comporta igual (las acciones usan las mismas versiones: `checkout@v7`, `setup-java@v6`, `upload-artifact@v7`, `docker/login-action@v4`; el PDF del curso muestra `@v4`).
