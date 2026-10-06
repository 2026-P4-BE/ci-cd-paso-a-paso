# YAML en 5 minutos

YAML es texto donde **la indentación es la estructura**. GitHub Actions, Docker Compose y la configuración de Jenkins como código (`casc.yaml`) lo usan. Si se entiende este archivo de 15 líneas, se entienden todos.

## El ejemplo: un fragmento del paso 1

```yaml
name: CI                          # (1) clave: valor
on:                               # (2) clave con contenido anidado
  push:
    branches: [main, develop]     # (3) lista en una línea
jobs:
  build-test:
    runs-on: ubuntu-latest
    steps:                        # (4) lista con guiones
      - name: Checkout
        uses: actions/checkout@v7
      - name: Set up Temurin 17
        uses: actions/setup-java@v6
        with:                     # (5) mapa dentro de un elemento de la lista
          java-version: '17'      # (6) texto entre comillas
```

## Las 6 reglas

| # | Regla | Dónde se ve arriba |
|---|-------|--------------------|
| 1 | `clave: valor`, con **un espacio** después de los dos puntos | `name: CI` |
| 2 | Lo que está más indentado **pertenece** a la clave de arriba (se usan 2 espacios) | `push:` está dentro de `on:` |
| 3 | `[a, b]` es una lista escrita en una línea | `branches: [main, develop]` |
| 4 | Un `-` abre un elemento de lista; lo que sigue alineado con el texto del guion es del mismo elemento | cada step empieza con `- name:` |
| 5 | Los mapas se pueden anidar sin límite | `with:` dentro del step |
| 6 | Los comentarios empiezan con `#` y llegan hasta el final de la línea | todo el material de la clase |

## Los errores clásicos (probados con un parser real)

| Error | Ejemplo | Qué pasa |
|-------|---------|----------|
| Tabulador en vez de espacios | `⇥build-test:` | El archivo no se puede leer. YAML **prohíbe** tabuladores para indentar |
| Indentación inconsistente | `uses:` con 2 espacios menos que `name:` en el mismo step | Error de estructura: ya no es parte del mismo elemento |
| Dos puntos dentro de un valor | `run: echo a: b` | Error: "mapping values are not allowed here". Se resuelve con comillas |
| Valor que empieza con `*` | `path: *.jar` | Error: YAML cree que `*` es un alias. Hay que escribir `'*.jar'` |
| Números que no son texto | `java-version: 17.0` | Se lee como número (17.0). Por eso en el material va `'17'` |
| `on`, `yes`, `no`, `off` | `on:` | Algunos parsers YAML 1.1 los convierten en `true`/`false`. GitHub entiende `on:` como disparador sin problema; el cuidado es con otras herramientas (por ejemplo, un script en Python lee la clave `on` como `True`) y con valores como `no` |

**Regla práctica:** ante la duda, comillas. Y si un archivo "no anda", primero revisar indentación.

## Anatomía de un workflow de GitHub Actions

```
EVENTO            push · pull_request · tag · botón "Run workflow"
   │
   ▼
WORKFLOW          .github/workflows/ci.yml            (name, on)
   │
   ▼
JOB               build-test, package                 (runs-on: máquina nueva y vacía)
   │              varios jobs = en paralelo, salvo que se use needs
   ▼
STEP              checkout · setup-java · ./mvnw      (corren en orden, uno por uno)
   │
   ▼
ACCIÓN o COMANDO  uses: actions/checkout@v7   |   run: ./mvnw -B test
```

| Nivel | Pregunta que responde | Clave en el YAML |
|-------|-----------------------|------------------|
| Evento | ¿Cuándo arranca? | `on:` |
| Workflow | ¿Cómo se llama el conjunto? | `name:` |
| Job | ¿En qué máquina y qué grupo de pasos? | `jobs.<id>.runs-on` |
| Step | ¿Qué hace, en qué orden? | `steps:` |
| Acción / comando | ¿Reutilizo algo hecho o escribo el comando? | `uses:` / `run:` |

## Para preguntar a la clase

*Si en el step "Set up Temurin 17" muevo `uses:` dos espacios a la izquierda, ¿qué pasa?*
**Respuesta:** el archivo deja de ser válido: `uses:` ya no queda dentro del elemento de lista iniciado por `- name:`. La estructura **es** la indentación.

## Siguiente

[github-actions/GUION.md](github-actions/GUION.md), paso 1.
