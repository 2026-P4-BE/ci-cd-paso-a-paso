#!/bin/sh
# =============================================================================
# SOLO LECTURA: copia comentada de turnos-api/scripts/deploy.sh (el archivo real no se toca).
# El Jenkinsfile del paso 5 lo invoca así: sh scripts/deploy.sh <contenedor> <APP_ENV> <imagen> <puerto-host>
# Despliega una imagen como contenedor, verifica que quede sana y, si no, vuelve a la versión anterior (rollback).
# =============================================================================

# -e: aborta ante cualquier comando que falle. -u: aborta si se usa una variable no definida.
set -eu

# Los cuatro argumentos posicionales: nombre del contenedor, valor de APP_ENV, imagen a desplegar y puerto del host.
NAME="$1"; APP_ENV="$2"; IMAGE="$3"; HOST_PORT="$4"
# Red de Docker compartida con Jenkins: permite llegar al contenedor por nombre.
NETWORK="turnos-net"

# Recuerda qué imagen corre ahora con ese nombre, para poder volver a ella. Si no existe contenedor, queda vacío ("|| true").
PREVIOUS="$(docker inspect -f '{{.Config.Image}}' "$NAME" 2>/dev/null || true)"

# Interruptor de clase: BREAK_DEPLOY=true arranca la versión NUEVA con una URL de base de datos rota,
# así falla al arrancar (simula una mala configuración que llega a producción). El rollback no la recibe.
# El Jenkinsfile lo alimenta desde el parámetro BREAK_PRODUCTION.
FAULT=""
if [ "${BREAK_DEPLOY:-false}" = "true" ]; then
  FAULT="--env=SPRING_DATASOURCE_URL=jdbc:postgresql://nowhere/none"
  echo "BREAK_DEPLOY=true: injecting a bad configuration on purpose"
fi

# start <imagen> [flag extra de docker run]: reemplaza el contenedor por uno nuevo con esa imagen.
start() {
  # Elimina el contenedor actual (si existe) para liberar el nombre y el puerto.
  docker rm -f "$NAME" >/dev/null 2>&1 || true
  # Lo ejecuta en segundo plano, en la red compartida, publicando el puerto, con APP_ENV y 256 MB de memoria.
  # ${2:+"$2"} agrega el segundo argumento (la falla inyectada) solo si vino con valor.
  docker run -d --name "$NAME" --network "$NETWORK" -p "$HOST_PORT:8080" \
    -e APP_ENV="$APP_ENV" --memory 256m ${2:+"$2"} "$1" >/dev/null
}

# Health check desde dentro de la red de Docker (Jenkins llega al contenedor por nombre).
healthy() {
  # Hasta 30 intentos, 3 segundos entre cada uno.
  for i in $(seq 1 30); do
    # Si el contenedor ya se cayó, no tiene sentido seguir esperando: se informa "no sano" (return 1).
    [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" = "true" ] || return 1
    # Pregunta a /actuator/health; si dice "status":"UP" está sano (return 0).
    if curl -fs --max-time 3 "http://$NAME:8080/actuator/health" | grep -q '"status":"UP"'; then
      return 0
    fi
    sleep 3
  done
  # Se agotaron los intentos sin ver UP.
  return 1
}

# Descarga la imagen del registry (si no está ya en el host).
docker pull "$IMAGE"
echo "Deploying $IMAGE as $NAME (APP_ENV=$APP_ENV, port $HOST_PORT)"
# Despliega la versión nueva (con la falla inyectada si BREAK_DEPLOY=true).
start "$IMAGE" "$FAULT"

# Camino feliz: la nueva versión quedó sana, el script termina con éxito (exit 0).
if healthy; then
  echo "Health check OK for $NAME"
  exit 0
fi

# Camino de falla: la nueva versión no quedó sana.
echo "Health check FAILED for $NAME"
# Muestra las últimas causas del log del contenedor, para explicar por qué falló.
echo "Why (last causes in the container log):"
docker logs "$NAME" 2>&1 | grep -E 'Caused by|APPLICATION FAILED|Description:' | tail -3 | cut -c1-200 || true
# Rollback: si había una versión anterior, se vuelve a ella (sin la falla inyectada) y se vuelve a verificar.
if [ -n "$PREVIOUS" ]; then
  echo "Rolling back to $PREVIOUS"
  start "$PREVIOUS"
  healthy && echo "Rollback OK" || echo "Rollback is also unhealthy"
else
  # Primer despliegue, sin versión anterior: no hay a qué volver, se elimina el contenedor roto.
  docker rm -f "$NAME" >/dev/null 2>&1 || true
fi
# Sale con error para que Jenkins marque la etapa Deploy en rojo, incluso si el rollback anduvo bien:
# el despliegue pedido NO se concretó.
exit 1
