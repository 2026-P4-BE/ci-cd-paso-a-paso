# =============================================================================
# SOLO LECTURA: copia comentada de turnos-api/jenkins/Dockerfile (el archivo real no se toca).
# Idea: el servidor de CI también es código. Esta receta construye el Jenkins de la
# clase y siempre queda igual: sin instalar nada a mano ni hacer clic en la interfaz.
# =============================================================================

# Imagen base de Jenkins con versión fija (LTS 2.541.3 sobre JDK 17).
# El tag "lts-jdk17" se mueve cada pocas semanas: fijarlo evita que el servidor cambie sin avisar.
FROM jenkins/jenkins:2.541.3-lts-jdk17

# Las instalaciones siguientes necesitan permisos de administrador dentro de la imagen.
USER root

# Instala Maven, que el pipeline usa para compilar y probar.
# --no-install-recommends evita paquetes opcionales; borrar /var/lib/apt/lists deja la capa más chica.
# Es el paquete de Debian: su versión depende de la imagen base fijada arriba.
RUN apt-get update \
    && apt-get install -y --no-install-recommends maven \
    && rm -rf /var/lib/apt/lists/*

# ARG: parámetro de construcción con valor por defecto; fija la versión del cliente de Docker.
ARG DOCKER_VERSION=27.4.0
# Instala SOLO el cliente de Docker (binario estático). El demonio que ejecuta los contenedores
# es el del host: se alcanza por el socket montado en docker-compose.yml.
# uname -m detecta la arquitectura (x86_64, aarch64); curl descarga el .tgz y tar extrae únicamente docker/docker.
# "docker --version" al final verifica en el build que el binario funciona.
RUN ARCH="$(uname -m)" \
    && curl -fsSL "https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VERSION}.tgz" \
       | tar -xz --strip-components=1 -C /usr/local/bin docker/docker \
    && docker --version

# El repositorio se monta desde el host con otro propietario: sin esto, git falla
# con "detected dubious ownership in repository". Se marca cualquier directorio como seguro.
RUN git config --system --add safe.directory '*'

# Los plugins se fijan por nombre y versión en plugins.txt y se instalan al construir la imagen (sin clics en la interfaz).
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
# jenkins-plugin-cli instala cada plugin de la lista, con sus versiones exactas.
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

# Configuration as Code: copia la configuración de Jenkins (usuarios, job, URL) escrita en YAML.
COPY casc.yaml /usr/share/jenkins/casc.yaml
# CASC_JENKINS_CONFIG le indica al plugin Configuration as Code dónde está ese archivo; lo aplica al arrancar.
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/casc.yaml
