# 02 · Master Plan

> El documento de referencia del producto: qué es, por qué existe, hasta dónde llega cada fase y quién decide qué.

---

## 1. Identidad del producto

| Campo | Dato |
|---|---|
| **Nombre de trabajo** | **MotSport** — consistente con MotRest |
| **Nombres alternativos en evaluación** | MotScout · CANCHA · MOTRAE Arena |
| **Qué es** | Plataforma de análisis y control deportivo: la mesa de trabajo del analista |
| **Dueño** | MOTRAE (producto propio, no desarrollo para cliente) |
| **Etapa** | Fase 0 · Planeación · **uso interno** |
| **Deportes** | Fútbol, basquetbol y fútbol americano desde el diseño; ampliable sin migración de esquema |
| **Frase de una línea** | *Todo lo que rodea a un partido, en un solo lugar, y se le puede preguntar.* |

El nombre comercial se decide en Fase 0. Mientras no haya código publicado, cambiarlo cuesta una búsqueda y reemplazo.

---

## 2. El problema

Los datos deportivos son abundantes, mayormente públicos y **están rotos en pedazos**.

Nadie tiene el problema de "no hay datos". El problema es que viven en siete herramientas que no se hablan, con nombres distintos para lo mismo, sin forma de cruzarlos, y sin nadie que los ponga en contexto. Un cuerpo técnico que quiere decidir si conviene rotar el mediocampo el sábado necesita, al mismo tiempo:

- los minutos acumulados del jugador en las últimas tres semanas,
- los días de descanso propios contra los del rival,
- el pronóstico de calor y humedad en esa ciudad a esa hora,
- el historial contra ese entrenador,
- y la forma reciente del suplente.

Esas cinco respuestas viven hoy en cinco lugares distintos. La media jornada que se va en juntarlas es la media jornada que no se dedica a decidir.

---

## 3. La propuesta de valor

**Una sola pregunta, en español, con una sola respuesta que cite de dónde salió cada número.**

Tres capas:

1. **Almacenar** — una base propia y multideporte, con **procedencia obligatoria** por dato. Ningún número entra sin saber de dónde vino, cuándo y con qué confianza.
2. **Buscar** — ingesta programada de fuentes estructuradas, más búsqueda web en vivo para lo que ningún API tiene: una lesión de hace dos horas, una declaración, el estado del césped.
3. **Analizar** — métricas derivadas por deporte, comparación por percentiles, modelos predictivos propios, y un asistente de IA que responde en lenguaje natural **sin inventar un solo número**.

### Por qué esto es defendible

No es el dato: el dato lo tiene cualquiera que pague. Lo defendible son tres cosas que se construyen con el tiempo y no se compran:

- **El catálogo de factores contextuales** —clima, viaje, descanso, altitud, árbitro— cruzado con el rendimiento, que es justo lo que los proveedores de datos **no** entregan cruzado.
- **La capa de normalización multideporte**, que permite que la misma pregunta funcione en fútbol, en NBA y en NFL.
- **La calibración de los modelos propios**, que mejora con cada temporada acumulada y no se puede comprar hecha.

---

## 4. Por qué MOTRAE construye esto

Es la pregunta que va a hacer cualquiera que vea el catálogo de la empresa: ¿qué hace una compañía de optimización operativa metida en software deportivo?

La respuesta es que **es el mismo problema con otro vestido**. La tesis central de MOTRAE es que las iniciativas de inteligencia artificial fracasan cuando se resuelve la capa del modelo sin haber resuelto antes las de infraestructura, datos y orquestación. Un club preparando un partido tiene exactamente la patología que DELTA OPS diagnostica en una planta: información fragmentada entre sistemas que no se hablan, y decisiones tomadas con datos incompletos. Ingerir, normalizar, dar procedencia, orquestar y recién entonces poner inteligencia encima es la misma secuencia, aplicada a otro dominio.

Y hay una razón práctica: **MotSport es un producto que MOTRAE controla de punta a punta.** A diferencia de un proyecto de cliente, aquí la empresa decide el alcance, el ritmo y el momento de vender. Eso lo convierte en el mejor banco de pruebas para la arquitectura agéntica de la plataforma SaaS, sin arriesgar el compromiso con ningún cliente.

### La pregunta abierta

**Quién es exactamente «el equipo» que va a usar esto todos los días.** Toda la estrategia de este documento descansa en que el uso diario escriba el pliego de requisitos, y eso solo funciona si quien lo usa entiende de análisis deportivo. Si el usuario real termina siendo alguien de MOTRAE que no prepara partidos de verdad, el pliego que salga va a ser el de un aficionado con buenas herramientas, no el de un analista — y el producto que se construya no le va a servir a un cuerpo técnico.

**Esto se resuelve antes de arrancar la Fase 1**, junto con la decisión de qué deportes y ligas se siguen. Ver [`../../README.md`](../../README.md) § Estado actual.

---

## 5. Estrategia: interno primero

**MotSport arranca como herramienta de uso interno de MOTRAE.** Esa no es una etapa provisional que haya que apurar: es la estrategia de la empresa aplicada a su propio producto. MOTRAE no se presenta con pilotos teóricos —la columna digital que ofrece comercialmente es la misma que ya sostiene su operación—. **Demostrar primero, comercializar después.**

Las consecuencias prácticas son tres:

1. **El pliego de requisitos lo escribe el uso, no la imaginación.** Lo que el equipo abre todos los días se queda; lo que nadie abre en dos meses se corta.
2. **No se construye maquinaria de venta hasta que haya algo que valga la pena vender.** Ver la tabla de *costuras sí, fábrica no* en el [`README`](../../README.md#-en-qué-etapa-está).
3. **Cuando salga al mercado, sale con historial.** Meses de uso real, decisiones ya afinadas y modelos ya calibrados sobre temporadas completas.

---

## 6. Alcance por fase

| Fase | Uso | Duración | Qué entrega |
|---|---|---|---|
| **0 · Fundación** | interno | 2–3 sem | Repositorio y documentación · Esquema de datos · Deportes y ligas del equipo · Mockups navegables · Nombre comercial |
| **1 · Núcleo** | interno | 10–12 sem | Ingesta de fútbol y NBA · Acceso por invitación · Radar · Centro de Partido (previa) · Fichas de equipo y jugador · Comparador · Scouting · Clima · **Asistente IA v1** |
| **2 · Inteligencia** | interno | 8–10 sem | **Modelos predictivos con backtesting** · Alertas y seguimiento en vivo · Informes PDF · PWA y aplicaciones móviles · NFL y más ligas |
| **3 · Comercialización** | 🔓 venta | por definir | Los ocho puntos de [`16_DISTRIBUCION_Y_PRECIOS.md`](16_DISTRIBUCION_Y_PRECIOS.md) |
| **4 · Expansión** | venta | por definir | API para clientes · Datos propios del club (GPS) · Video, si el mercado lo justifica |

### Fuera de alcance, y por qué

| Qué | Por qué no |
|---|---|
| **Análisis de video** | Es prácticamente un segundo producto —ingesta, tagging, clips, almacenamiento pesado— y compite de frente con Hudl Sportscode, que lleva años de ventaja. Se evalúa en Fase 4 y solo si el mercado lo pide |
| **Funciones de apuestas** | Cambia el régimen legal, el posicionamiento y las reglas de las tiendas de aplicaciones. Ver [`15_LEGAL.md`](15_LEGAL.md) |
| **Todo lo que solo sirve para vender** | Facturación, planes, alta de clientes, tiendas. Es Fase 3 |

> ### Las dos reglas de oro
> **Si requiere video, no es Fase 1.**
> **Si solo sirve para vender, no es Fase 1.**

Todo lo que se corta por alcance no se pierde: se manda a [`17_VISION_FUTURA.md`](17_VISION_FUTURA.md).

---

## 7. Costos de operación

### Fases 0 a 2 (uso interno)

| Concepto | Costo mensual estimado |
|---|---|
| Fuentes de datos | **$0** (tiers gratuitos) |
| Supabase | $0 a ~$25 USD según el plan que haga falta |
| Contenedor del motor | ~$10–20 USD |
| API de Claude | **La partida real.** Techo puesto en **$80 USD/mes** |
| **Total con el techo puesto** | **~$125 USD/mes** en el peor caso |

El costo de IA es la única partida que puede sorprender, y por eso **tiene un tope duro configurado, no una intención de moderación**: `TOPE_DIARIO_IA_USD` y `TOPE_MENSUAL_IA_USD` en el entorno. Al llegar al tope, el asistente se apaga y lo dice; nunca degrada en silencio ni sigue gastando. La caché de prompt sobre el bloque estable y la medición por consulta están en el diseño desde el día uno, no como optimización posterior. Ver [`10_INTELIGENCIA_ARTIFICIAL.md`](10_INTELIGENCIA_ARTIFICIAL.md).

### Fase 3 (comercialización)

Se suma el proveedor de datos con derecho de redistribución (~€29–249/mes al arrancar con SportMonks), Open-Meteo de pago, y la infraestructura escalada. La estructura de costos y precios está en [`16_DISTRIBUCION_Y_PRECIOS.md`](16_DISTRIBUCION_Y_PRECIOS.md).

---

## 8. Riesgos

| # | Riesgo | Probabilidad | Impacto | Mitigación |
|---|---|---|---|---|
| 1 | **La licencia de datos frena la venta** | Media | Bloqueante (solo en Fase 3) | Capa de proveedores intercambiables desde el día uno; licencia documentada fuente por fuente en [`15_LEGAL.md`](15_LEGAL.md) |
| 2 | **El costo de IA se dispara** | Media | Alto | Caché de prompt, esfuerzo bajo en rutina, medición por consulta, presupuesto por usuario |
| 3 | **Datos sucios o con huecos** | Alta | Alto | Procedencia y confianza por fila; el asistente obligado a decir "no tengo ese dato" |
| 4 | **El límite de 100 consultas/día de la fuente principal** | Cierta | Medio | Ingesta incremental y caché agresivo desde el diseño, no como parche |
| 5 | **El alcance se estira hacia el video** | Media | Alto | Las dos reglas de oro, escritas en README y CLAUDE.md |
| 6 | **Se lee como producto de apuestas** | Media | Alto | Posicionamiento explícito, sin integración con casas, cuidado desde la ficha de tienda |
| 7 | **Los modelos predictivos no superan al consenso** | Media | Medio | Backtesting honesto desde el inicio; si no superan, se presentan como contexto y no como pronóstico |

---

## 9. Gobierno del proyecto

| Quién | Qué decide |
|---|---|
| **Gonzalo (CEO, MOTRAE)** | Alcance, prioridades, cuándo se pasa de fase, contratación de proveedores, cualquier acción sobre producción, y la decisión de comercializar |
| **Equipo de desarrollo** | Implementación dentro del alcance acordado, propuesta de ADR ante decisiones de arquitectura |

Reglas de gobierno:

- **Antes de un cambio grande, se propone un plan.** Se aprueba y luego se escribe.
- **Toda decisión de arquitectura queda en un ADR** en [`../adr/`](../adr/), con contexto, decisión y consecuencias.
- **Cambiar de fase es una decisión explícita de Gonzalo**, no una consecuencia de que se hayan terminado las tareas.
- **Nadie toca producción salvo Gonzalo.**

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
