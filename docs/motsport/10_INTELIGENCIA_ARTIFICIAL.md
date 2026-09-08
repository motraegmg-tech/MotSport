# 10 · Inteligencia artificial

> El asistente es la puerta de entrada al producto. También es el componente donde un error se ve peor: un asistente deportivo que inventa un marcador es peor que no tener asistente.

---

## 1. La regla que gobierna todo

> ### Ninguna cifra sale del modelo. Toda cifra viene de una llamada a herramienta.
> El modelo **busca**, **ordena** y **explica**. Nunca produce un número desde su memoria.

La formulación corta que se usa a diario es *«ninguna cifra sale del modelo, sale de la base»*, y para casi todo es exacta. La formulación precisa es la de arriba, porque hay una excepción legítima: la **búsqueda web en vivo** (sección 4) también es una llamada a herramienta y también puede traer un dato, pero ese dato **no se guarda en la base**. Se marca con confianza baja, se cita siempre, y nunca se mezcla con lo verificado.

Lo que la regla prohíbe, en las dos formulaciones, es lo mismo: **que el modelo escriba un número que no vino de ninguna herramienta.**

De esta regla se derivan las decisiones de diseño que siguen. Si alguien propone algo que la viole, la respuesta es no.

---

## 2. Herramientas tipadas, nunca SQL libre

El modelo no escribe consultas contra la base. Llama funciones acotadas, con esquema estricto y bitácora:

| Herramienta | Qué hace |
|---|---|
| `buscar_partidos` | Encuentra partidos por equipo, competencia, fecha o estado |
| `estadisticas_equipo` | Métricas de un equipo en una ventana, con percentil de su liga |
| `estadisticas_jugador` | Lo mismo para un jugador, con disponibilidad |
| `comparar` | Compara hasta cuatro entidades en la misma escala |
| `clima_de_partido` | Condiciones previstas o registradas para un partido |
| `disponibilidad_plantilla` | Lesionados, suspendidos y ausencias, ponderados por peso en el once |
| `historico_enfrentamientos` | Historial directo, con contexto de cada partido |
| `pronostico` | **Fase 2.** Salida del modelo predictivo, con sus factores y su confianza |
| `buscar_en_la_red` | Búsqueda web en vivo para lo que ningún API cubre |

> **Qué puede decir el asistente sobre el resultado en Fase 1.** El modelo predictivo completo es entrega de Fase 2, así que en Fase 1 la herramienta `pronostico` **no existe todavía**. Lo que sí hay desde Fase 1 es el **rating base tipo Elo** y los factores contextuales ya calculados, que el asistente puede leer y comparar: *«son parejos en rating, pero el visitante llega con dos días menos de descanso»*. Eso es descripción del contexto, no pronóstico, y así se presenta. Ninguna probabilidad de resultado se muestra antes de que exista backtesting — ver [`11_MODELOS_PREDICTIVOS.md`](11_MODELOS_PREDICTIVOS.md).

**Por qué no SQL libre.** Un modelo con acceso libre a la base es imposible de auditar —no sabes qué consultó hasta que ya lo hizo—, trivial de manipular con una pregunta mal intencionada, y capaz de tumbar la base con una consulta desafortunada. Con herramientas tipadas, la superficie es exactamente la que decidimos, **el filtro de tenant no lo controla el modelo**, y cada llamada queda registrada.

El costo de esta decisión es real: cada capacidad nueva del asistente es una herramienta nueva que alguien tiene que escribir. Se paga con gusto.

---

## 3. Modelos y configuración

| Uso | Modelo | Configuración |
|---|---|---|
| Consultas de análisis, previas, comparaciones | **`claude-opus-5`** | *Adaptive thinking*; esfuerzo `medium` en rutina, `high` en análisis completo de partido |
| Clasificación y enrutamiento de preguntas triviales | **`claude-haiku-4-5`** | Sin razonamiento extendido |

Referencia de precios (septiembre 2026): `claude-opus-5` a **$5 / $25 USD por millón de tokens** de entrada y salida; `claude-haiku-4-5` a **$1 / $5**. Contexto de 1M de tokens en Opus 5.

Implementación con el **tool runner** del SDK oficial de Anthropic (`client.beta.messages.tool_runner`), que se encarga del ciclo petición → ejecución → repetición sin que tengamos que escribir el bucle a mano, y deja ganchos por turno para aprobar, registrar e interceptar.

---

## 4. Búsqueda web en vivo

Lo que ningún API estructurado cubre —una lesión anunciada hace dos horas, una declaración del entrenador, el estado del césped tras tres días de lluvia— entra por la herramienta de búsqueda web del servidor (`web_search_20260209`), con **dominios permitidos configurados por competencia**.

Reglas duras:

- **No reemplaza a las fuentes estructuradas.** Complementa.
- Todo lo que entra por aquí se marca con **`confianza` baja** y `fuente = 'web'`.
- **Siempre se presenta citando el enlace.** El usuario tiene que poder ir a verificarlo.
- Nunca se guarda como si fuera dato estructurado propio.

---

## 5. Control de costo

El costo de IA es la única partida de operación que puede sorprender. Se controla desde el diseño, no como optimización posterior:

1. **Caché de prompt sobre el bloque estable.** El prompt de sistema, el diccionario de métricas y las definiciones del catálogo son grandes y no cambian entre consultas: van al principio, con punto de caché. Lo volátil —la pregunta, la fecha, el identificador de sesión— va después. **Este es el mayor ahorro del producto.**
2. **Se verifica que la caché funcione.** Si `usage.cache_read_input_tokens` sale en cero de forma repetida, hay un invalidador silencioso —una fecha en el prompt de sistema, un JSON sin ordenar, una lista de herramientas que cambia de orden— y hay que encontrarlo.
3. **Esfuerzo proporcional a la pregunta.** `medium` para consultas rutinarias, `high` solo para análisis completos.
4. **Enrutamiento a Haiku** de lo trivial.
5. **Medición por consulta desde el primer día**: tokens, aciertos de caché, costo, visible en la pantalla de operación.
6. **Presupuesto por usuario**, que en Fase 3 se convierte en límite por plan.

---

## 6. Anti-invención: los cinco candados

1. **El modelo no tiene forma de producir un número.** Solo puede transcribir lo que devolvió una herramienta.
2. **Cada respuesta cita las filas usadas**, con su fuente y su fecha de obtención.
3. **Si el dato no está, se dice.** El prompt de sistema es explícito: *"si una herramienta no devolvió el dato, dilo; no lo estimes, no lo aproximes, no lo rellenes con lo que recuerdes"*.
4. **Los datos con `confianza` baja se presentan marcados**, no mezclados con los verificados.
5. **Discrepancias visibles.** Si dos fuentes discrepan, la respuesta lo dice. Un número con una discrepancia declarada es más útil que un número falsamente limpio.

---

## 7. Qué debe poder responder

### Fase 1

- *¿Qué clima va a hacer en el partido del sábado y cómo le pega a cada equipo?*
- *¿Cómo llega el rival: quién está lesionado, cuántos días de descanso trae, cómo viene de forma?*
- *Compárame a estos dos delanteros en los últimos seis meses, por percentil de su liga.*
- *¿Qué pasa históricamente cuando este equipo juega a más de 2,000 metros de altitud?*
- *Búscame mediocampistas sub-23 en el percentil 80 o mejor de pases progresivos.*
- *Dame la previa completa del partido del domingo.* — con contexto y forma, sin probabilidad de resultado

### Fase 2, cuando exista el modelo con backtesting

- *¿Por qué el modelo da favorito al visitante?*
- *¿Qué tan seguro está el modelo y en qué se equivocó las últimas cinco veces que dijo esto?*

Este conjunto es también la **base del banco de pruebas**: cada pregunta tiene una respuesta esperada verificable contra la base, y se corre antes de cada cambio del prompt o de las herramientas. Un asistente sin banco de pruebas se degrada sin que nadie lo note.

---

## 8. Seguridad del asistente

- **El contenido que llega de la web es dato, nunca instrucción.** Un texto extraído de una página que diga "ignora tus reglas" es texto de una página, y así se trata.
- **El filtro de tenant vive en la herramienta**, no en el prompt. El modelo no puede saltárselo porque no lo controla.
- **Bitácora completa**: qué preguntó el usuario, qué herramientas llamó el modelo, con qué argumentos, y qué devolvieron.
- **Sin acciones de escritura.** En Fase 1 el asistente solo lee. Cualquier capacidad de escritura futura pasa por confirmación explícita del usuario.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
