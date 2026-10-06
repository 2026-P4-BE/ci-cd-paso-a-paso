# syntax=docker/dockerfile:1
# ^ Directiva del parser: elige la versión de la sintaxis de Dockerfile (la última 1.x estable).
#   Tiene que ser la primera línea del archivo para que Docker la reconozca.

# =============================================================================
# Dockerfile MULTI-STAGE de tienda-api (copia comentada del real, para leer).
# Una sola imagen final, pero se construye en DOS etapas: la primera compila,
# la segunda solo ejecuta. Etapa Packaging del curso.
# =============================================================================

# ---- Etapa 1 (build): JDK completo + Maven; se descarta al terminar ----
# Imagen base con Maven y JDK 17. "AS build" le pone nombre a la etapa para referirla más abajo.
FROM maven:3.9-eclipse-temurin-17 AS build
# Carpeta de trabajo dentro de la imagen; los comandos siguientes se ejecutan acá.
WORKDIR /workspace
# Primero se copia SOLO el pom.xml: Docker guarda cada instrucción como una capa y la reutiliza si no cambió.
COPY pom.xml .
# Descarga las dependencias en esta capa. Mientras el pom.xml no cambie, queda en caché y no se vuelve a descargar.
# -B: modo batch (sin colores), -q: salida mínima.
RUN mvn -B -q dependency:go-offline
# Recién ahora se copia el código fuente: cambiarlo no invalida la capa de dependencias de arriba.
COPY src ./src
# Los tests, la cobertura y PMD ya corrieron en el pipeline (./mvnw verify): la imagen solo empaqueta.
# -DskipTests omite los tests acá para no repetirlos. Genera el jar ejecutable en target/.
RUN mvn -B -q -DskipTests package

# ---- Etapa 2 (runtime): JRE liviano, usuario sin privilegios ----
# Imagen base final: solo JRE (para ejecutar, sin compilador ni Maven) sobre Alpine, una distribución mínima.
# Resultado: imagen mucho más chica y con menos superficie de ataque que la de la etapa 1.
FROM eclipse-temurin:17-jre-alpine
# Crea un grupo y un usuario de sistema (-S) llamados "app": el proceso no va a correr como root.
RUN addgroup -S app && adduser -S app -G app
# Carpeta de trabajo de la aplicación en la imagen final.
WORKDIR /app
# Copia el jar desde la etapa "build" (--from=build). El comodín evita escribir la versión en el nombre.
# Nada más de la etapa 1 llega a la imagen final: ni Maven, ni código fuente, ni dependencias descargadas.
COPY --from=build /workspace/target/tienda-api-*.jar app.jar
# A partir de acá el contenedor corre como el usuario "app" (mínimo privilegio).
USER app
# Documenta que la aplicación escucha en el 8080. No publica el puerto: eso lo hace "docker run -p".
EXPOSE 8080
# Docker consulta periódicamente la salud del contenedor y la muestra en "docker ps".
# --interval: cada cuánto chequea. --timeout: cuánto espera la respuesta.
# --start-period: gracia inicial mientras Spring Boot arranca (los fallos de ese período no cuentan).
# --retries: cuántos fallos seguidos hacen que el contenedor pase a "unhealthy".
HEALTHCHECK --interval=10s --timeout=3s --start-period=20s --retries=5 \
  CMD wget -qO- http://localhost:8080/actuator/health || exit 1
# Comando de arranque del contenedor, en forma exec (lista): java recibe las señales de parada directamente.
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
