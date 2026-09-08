# MotSport — Plataforma de análisis y control deportivo

> La mesa de trabajo del analista: almacena, busca, compara y **explica** todo lo que rodea a un partido de cualquier deporte.
> **Estado:** Planeación · Fase 0 · **uso interno** · Septiembre 2026

---

> ### 🤖 Para Claude / agentes de IA — léeme primero
>
> **Orden de lectura:**
> 1. Este `README.md` — qué es el producto, en qué etapa está y cómo se trabaja aquí.
> 2. [`CLAUDE.md`](CLAUDE.md) — las reglas que no se negocian, en corto.
> 3. [`docs/motsport/00_INDICE.md`](docs/motsport/00_INDICE.md) — índice maestro; de ahí saltas al documento del tema que te toque.
> 4. [`docs/MOTRAE_EMPRESA.md`](docs/MOTRAE_EMPRESA.md) — quién es la empresa que construye esto.
>
> **Dos cosas antes de escribir una línea:**
> - Empieza SIEMPRE las respuestas llamando al CEO por su nombre: **Gonzalo**.
> - ⚠️ **Este producto todavía no se vende ni se distribuye.** Es una herramienta interna de MOTRAE. Si una tarea suena a "preparar el cobro", "dar de alta clientes" o "publicar en tiendas", eso es **Fase 3** y no se construye hoy. Ver [🔒 En qué etapa está](#-en-qué-etapa-está).

---

## 🎯 Qué es

Preparar un partido hoy significa abrir siete pestañas. Los datos históricos en un sitio, la tabla en otro, el parte de lesionados en la cuenta del club, el clima en una app del teléfono, las notas del último enfrentamiento en un cuaderno. La información existe casi toda y es casi toda pública; lo que no existe es **un solo lugar donde esté junta y se pueda interrogar**.

**MotSport es ese lugar.** Concentra todo lo que rodea a un partido —resultados históricos, forma reciente, métricas avanzadas, disponibilidad de plantilla, clima, altitud, viaje, días de descanso, árbitro, contexto de la competencia— en una base propia y multideporte, y encima le pone un asistente de inteligencia artificial al que se le pregunta en español, como se le preguntaría a un analista que se sabe todos los números de memoria.

Cubre **fútbol, basquetbol y fútbol americano** desde el diseño, no como parches: el modelo de datos está construido para que agregar un deporte nuevo no obligue a rehacer la base. Y corre en varios dispositivos: navegador, aplicación instalable en la computadora y aplicación en el teléfono, con la misma información sincronizada.

---

## 🔒 En qué etapa está

**Hoy MotSport es una herramienta de uso interno.** La usan Gonzalo y su equipo. No se vende, no se distribuye, no se le da acceso a nadie fuera del equipo.

Eso no es una limitación temporal que haya que apurar: es **la estrategia de MOTRAE aplicada a nuestro propio producto**. La empresa no se presenta con un piloto teórico —la columna digital que ofrece comercialmente es la misma que ya sostiene su operación—. MotSport sigue esa misma secuencia: **demostrar primero, comercializar después**. Cuando llegue el momento de venderlo, va a llegar al mercado con meses de uso real encima y con las decisiones ya afinadas por el uso diario, no por suposiciones.

### La regla que hace barato el cambio de etapa: costuras sí, fábrica no

Construir "para uso interno" no significa construir descuidado. Significa distinguir dos cosas:

| Se construye HOY (las costuras) | NO se construye hoy (la fábrica) |
|---|---|
| `tenant_id` en cada tabla, con RLS de Postgres activo — aunque exista un solo tenant | Alta de organizaciones, invitaciones, roles por club |
| Capa de proveedores de datos intercambiables detrás de una interfaz común | Contratos con proveedores de pago |
| Procedencia obligatoria por dato (`fuente`, `obtenido_ts`, `confianza`) | Planes, límites por plan, facturación, cobro recurrente |
| Métricas por catálogo versionado, no por columnas fijas | Portal de suscripción, publicación en App Store y Play Store |
| Documentación portátil y decisiones registradas | Términos de servicio, EULA, contrato de suscripción |

La lógica es simple: **meter `tenant_id` hoy no cuesta casi nada; meterlo después obliga a reescribir cada consulta del sistema.** Una pasarela de cobro, en cambio, se conecta en dos semanas el día que haga falta. Se paga por adelantado solo lo que es caro de retrofitear.

La lista completa de lo que falta para poder vender está escrita **desde ahora**, aunque se ejecute dentro de un año, en [`docs/motsport/16_DISTRIBUCION_Y_PRECIOS.md`](docs/motsport/16_DISTRIBUCION_Y_PRECIOS.md). Se escribe hoy precisamente para no construir hoy algo que haya que tirar.

---

## 🏢 Quién lo hace

**MOTRAE** es una compañía **AI-first** fundada en 2026 en Xalapa, Veracruz, México, que transforma las operaciones y los sistemas productivos de las empresas mediante ingeniería estratégica, optimización inteligente e innovación funcional. Su slogan: *Innovation already in motion*.

Opera sobre **dos motores que se retroalimentan**:

1. **DELTA OPS** — consultoría y optimización empresarial con una metodología propietaria de 7 pilares, que entrega reducciones de costos operativos del 10–30 % bajo un único contrato con responsabilidad sobre el resultado, y que genera datos reales de campo.
2. **Plataforma SaaS** — un sistema operativo empresarial de arquitectura agéntica que esos datos alimentan, validan y refinan.

Su diferencia es que no compite en una sola capa: entrega diagnóstico, instalación, operación y mejora continua como un solo producto, y cobra por resultado, no por horas. **Una sola empresa, un solo contrato, un solo responsable del resultado.**

MotSport es un **producto propio de MOTRAE**, no un desarrollo para un cliente. Se suma a la línea de productos que ya incluye **MotRest** (ERP restaurantero, en producción) y **CLAVIS** (cumplimiento de licitaciones de obra pública).

El contexto completo de la empresa —misión, visión, valores, modelo de negocio, marca y glosario— está en [`docs/MOTRAE_EMPRESA.md`](docs/MOTRAE_EMPRESA.md), que este repositorio trae consigo para ser portátil.

---

## 👥 Para quién

**Hoy:** Gonzalo y el equipo de MOTRAE.

**Mañana (Fase 3),** el producto apunta a este mercado:

| Perfil | Su dolor |
|---|---|
| **Equipos y clubes** | Pagan tres herramientas distintas y ninguna les responde una pregunta directa; los datos no se cruzan entre sí |
| **Cuerpo técnico** | Preparar la previa de un rival se lleva media jornada de copiar y pegar que debería llevarse veinte minutos |
| **Analistas de rendimiento** | Tienen los números pero no el tiempo de contextualizarlos: clima, viaje, descanso y disponibilidad viven fuera de la hoja de cálculo |
| **Academias y fuerzas básicas** | No pueden pagar Hudl ni Wyscout, y se quedan sin ninguna herramienta seria |

---

## ❗ El problema

> Los datos deportivos son abundantes, públicos y están rotos en pedazos.

Nadie tiene el problema de "no hay datos". El problema es que están en siete lugares que no se hablan, con nombres distintos para lo mismo, sin forma de cruzarlos y sin nadie que los ponga en contexto. Un cuerpo técnico que quiere saber si conviene rotar al mediocampo el sábado necesita, al mismo tiempo: los minutos acumulados del jugador, los días de descanso respecto al rival, el pronóstico de calor y humedad en esa ciudad, el historial contra ese entrenador y la forma reciente del suplente. Esas cinco respuestas viven hoy en cinco herramientas.

**MotSport existe para que esa sea una sola pregunta, hecha en español, con una sola respuesta que cite de dónde salió cada número.**

---

## ✅ Alcance / ⛔ Fuera de alcance

### Dentro (Fases 0 a 2)

- Base de datos propia multideporte con procedencia por dato
- Ingesta programada de fuentes abiertas + búsqueda web en vivo
- Métricas derivadas por deporte y comparación por percentiles
- Asistente de IA con herramientas tipadas sobre la base
- Modelos predictivos propios, con backtesting y explicación
- Alertas, seguimiento en vivo e informes en PDF
- Web, PWA instalable y aplicaciones móviles para el equipo

### Fuera

- **Análisis de video** (ingesta de partidos, tagging de jugadas, clips). Es prácticamente un segundo producto y compite de frente con Hudl Sportscode. Decisión comercial de Fase 4.
- **Cualquier función de apuestas**: no hay integración con casas, no hay recomendaciones de apuesta, no hay cálculo de valor esperado sobre cuotas. Las cuotas se usan únicamente como señal de consenso externo para contrastar el modelo propio.
- **Todo lo que solo sirve para vender**: facturación, planes, alta de clientes, tiendas de aplicaciones. Eso es Fase 3.

> ### Las dos reglas de oro
> **Si requiere video, no es Fase 1.**
> **Si solo sirve para vender, no es Fase 1.**

---

## 🧭 Decisiones clave

1. **Interno primero, venta después.** Se construye para usarlo, no para demostrarlo. El uso diario del equipo es el mejor pliego de requisitos que existe y evita construir funciones que nadie pidió.
2. **SaaS en la nube, no aplicación instalada con licencia.** A diferencia de MotRest —que es LAN-first porque un restaurante no puede dejar de vender si se cae el internet—, aquí el dato vive naturalmente en la nube: viene de APIs externas, se actualiza solo y se consulta desde varios dispositivos. Una base local por dispositivo sería trabajo extra para un problema que no tenemos.
3. **Multideporte por catálogo, no por columnas.** El error clásico es hacer un esquema de fútbol y después intentar meterle basquetbol. Las métricas viven en un catálogo versionado en base de datos; agregar un deporte no requiere migración de esquema.
4. **El asistente de IA no escribe SQL.** Llama funciones acotadas y auditables. Un modelo con acceso libre a la base es imposible de auditar y trivial de romper con una pregunta mal intencionada.
5. **Ninguna cifra sale del modelo.** El asistente busca, ordena y explica; jamás inventa un número. Toda respuesta cita las filas que usó y su fecha de obtención. Un asistente deportivo que alucina un marcador es peor que no tener asistente.
6. **Fuentes gratuitas con la puerta legal documentada.** Mientras el uso sea interno son legalmente correctas. La lista de qué hay que sustituir para vender está escrita desde hoy, fuente por fuente.
7. **Motor en Python, plataforma en TypeScript, Postgres como frontera.** Los modelos deportivos viven en el ecosistema de Python; forzarlos a TypeScript cuesta más de lo que ahorra. El motor solo escribe a Postgres: esa es toda la superficie de contacto entre los dos mundos.

---

## 🖥️ La interfaz

Principios: **densidad alta de datos** (el analista quiere ver mucho a la vez), **oscuro por defecto** (se trabaja en salas de video), **teclado primero** (`Ctrl+K` abre el asistente desde cualquier pantalla), **todo exportable**, y una regla dura: *una pregunta por pantalla*.

| # | Pantalla | Qué resuelve |
|---|---|---|
| 1 | **Radar** (inicio) | Los partidos que importan hoy y esta semana, con señales automáticas: "viento de 34 km/h", "3 días menos de descanso que el rival", "duda el central titular" |
| 2 | **Centro de Partido** ★ | La vista estrella. Tres estados: **previa** (condiciones, alineaciones probables, forma, historial, pronóstico con su porqué) → **en vivo** → **informe post-partido** |
| 3 | **Ficha de Equipo** | Perfil táctico, tendencias, calendario con carga acumulada, fortalezas y debilidades por percentil |
| 4 | **Ficha de Jugador** | Radar de percentiles, evolución temporal, disponibilidad, jugadores similares |
| 5 | **Comparador** | Hasta cuatro equipos o jugadores lado a lado, misma escala, misma temporada |
| 6 | **Scouting** | Buscador por métricas con filtros de percentil, búsquedas guardadas y listas de seguimiento |
| 7 | **Consola IA** | Panel lateral siempre disponible. Pregunta en español → respuesta con tabla, gráfica y **cita de las filas usadas** |
| 8 | **Informes** | Genera informe de previa o de scouting en PDF |
| 9 | **Alertas** | Reglas del usuario: "avísame si el viento supera 25 km/h en el partido del sábado", "si X no entrena" |
| 10 | **Panel de operación** | Salud de la ingesta, costo de IA acumulado, últimos errores. En Fase 1 es una pantalla mínima para el equipo; en Fase 3 crece hasta ser la Consola MOTRAE |

Los mockups navegables viven en [`docs/motsport/mockups/`](docs/motsport/mockups/) y los principios completos en [`05_UI_UX.md`](docs/motsport/05_UI_UX.md).

---

## 🌦️ Qué afecta un partido

Este es el corazón del producto: el catálogo de todo lo que puede mover un resultado. Se modela como **catálogo versionado en base de datos**, nunca como constantes en código, para poder agregar un factor sin tocar el programa.

| Familia | Factores |
|---|---|
| **Ambiente** | Temperatura, sensación térmica, humedad, viento (velocidad y ráfaga), precipitación, presión, visibilidad, altitud del estadio, techo abierto o cerrado, tipo de césped, dimensiones de cancha |
| **Disponibilidad** | Lesionados, suspendidos, convocatorias internacionales, alineación probable contra confirmada, minutos acumulados, regreso de lesión |
| **Carga y viaje** | Días de descanso, partidos en los últimos 7 y 14 días, kilómetros recorridos, husos horarios cruzados, back-to-back, partido entre semana |
| **Forma y fuerza** | Rating tipo Elo por deporte, forma reciente ponderada, racha, rendimiento como local y como visitante, diferencia de nivel de competencia |
| **Contexto** | Importancia del partido, rivalidad, posición en tabla, entrenador nuevo, árbitro (tarjetas y faltas por partido), asistencia esperada |
| **Estilo táctico** | Posesión, ritmo, presión alta, verticalidad, tiros por posesión, altura de la línea defensiva |
| **Mercado** | Cuotas de casas como señal de consenso externo, **solo** para contrastar contra el modelo propio; nunca como fuente de verdad |

El catálogo completo, con definición, unidad y fuente de cada factor, está en [`09_CATALOGO_DE_FACTORES.md`](docs/motsport/09_CATALOGO_DE_FACTORES.md).

---

## 🤖 El asistente de IA

> **Regla no negociable: ninguna cifra sale del modelo. Sale de la base. El modelo la busca, la ordena y la explica.**

Preguntas que debe poder responder en Fase 1:

- *¿Qué clima va a hacer en el partido del sábado y cómo le pega a cada equipo?*
- *¿Cómo llega el rival: quién está lesionado, cuántos días de descanso trae, cómo viene de forma?*
- *Compárame a estos dos delanteros en los últimos seis meses, por percentil de su liga.*
- *¿Qué pasa históricamente cuando este equipo juega a más de 2,000 metros de altitud?*
- *Búscame mediocampistas sub-23 en el percentil 80 o mejor de pases progresivos.*
- *Dame la previa completa del partido del domingo.*

Cómo funciona:

- **Modelo:** Claude `claude-opus-5`, con *adaptive thinking* y esfuerzo bajo o medio para consultas rutinarias, alto para análisis de partido completo. `claude-haiku-4-5` para clasificar y enrutar preguntas triviales.
- **Herramientas tipadas, no SQL libre:** `buscar_partidos`, `estadisticas_equipo`, `estadisticas_jugador`, `comparar`, `clima_de_partido`, `disponibilidad_plantilla`, `pronostico`, `historico_enfrentamientos`.
- **Búsqueda web en vivo** para lo que ningún API cubre: lesiones de última hora, declaraciones, estado del campo.
- **Caché de prompt** sobre el prompt de sistema y el diccionario de métricas — es el mayor ahorro de costo del producto.
- **Toda respuesta cita su origen.** Si un dato no está, el asistente lo dice; no lo rellena.

Detalle completo en [`10_INTELIGENCIA_ARTIFICIAL.md`](docs/motsport/10_INTELIGENCIA_ARTIFICIAL.md).

---

## 🧩 Módulos

| # | Módulo | Qué hace |
|---|---|---|
| 00 | **Plataforma transversal** | Autenticación, tenants, roles, auditoría, configuración |
| 01 | **Ingesta** | Conectores por proveedor, programación, reintentos, deduplicación, procedencia |
| 02 | **Núcleo de datos** | Modelo multideporte, catálogo de métricas, cálculo de derivadas |
| 03 | **Contexto de partido** | Clima, sede, viaje, descanso, árbitro, importancia |
| 04 | **Análisis y comparación** | Percentiles, radares, comparador, scouting |
| 05 | **Predicción** | Features, entrenamiento, backtesting, explicación del pronóstico |
| 06 | **Asistente IA** | Herramientas, orquestación, citas, presupuesto de consultas |
| 07 | **Alertas y en vivo** | Reglas del usuario, notificaciones, seguimiento de partido |
| 08 | **Informes** | Generación de PDF de previa y de scouting |
| 09 | **Operación** | Salud de ingesta, costos, errores; en Fase 3 se convierte en Consola MOTRAE |

---

## 🧱 Stack técnico

| Capa | Tecnología | Por qué |
|---|---|---|
| Web | **SvelteKit 2 + Svelte 5 + TypeScript + Vite** | Es lo que MOTRAE ya opera en producción con MotRest; cero curva de aprendizaje |
| Móvil | **Capacitor 8** sobre la misma aplicación, más PWA instalable | Mismo toolchain ya probado en `kds-android` y `motrest-android` |
| Backend | **Supabase**: Postgres 16 con **RLS multi-tenant**, Auth, Realtime, Edge Functions | Ya es la nube de MotRest; un solo proveedor que el equipo conoce |
| Motor | **Python 3.12 + FastAPI + pandas + LightGBM/scikit-learn**, en contenedor | Los modelos deportivos viven en Python. Frontera limpia: **el motor solo escribe a Postgres** |
| IA | **Claude `claude-opus-5`** vía SDK oficial, con tool runner, búsqueda web y caché de prompt | — |
| Datos deportivos | Interfaz `ProveedorDeportivo` con implementaciones intercambiables | Permite arrancar con fuentes abiertas y migrar a licencia pagada sin tocar la aplicación |
| Clima | Open-Meteo (tier gratuito, uso interno) | Sustituible por licencia comercial en Fase 3 |
| Gráficas | ECharts | Densidad de datos alta y buen desempeño |
| CI | GitHub Actions, acciones ancladas por hash de commit | Mismo estándar que `ci.yml` de MotRest |

Justificaciones y política de dependencias en [`12_STACK_TECNOLOGICO.md`](docs/motsport/12_STACK_TECNOLOGICO.md).

---

## 🗺️ Roadmap

| Fase | Uso | Duración | Entrega |
|---|---|---|---|
| **Fase 0 — Fundación** | interno | 2–3 sem | Repositorio, documentación, esquema de datos, deportes y ligas del equipo, mockups navegables |
| **Fase 1 — Núcleo** | interno | 10–12 sem | Ingesta fútbol + NBA con fuentes abiertas · Acceso por invitación · Radar · Centro de Partido (previa) · Fichas de equipo y jugador · Comparador · Scouting · Clima · **Asistente IA v1** |
| **Fase 2 — Inteligencia** | interno | 8–10 sem | **Modelos predictivos con backtesting** · Alertas y en vivo · Informes PDF · PWA y móviles para el equipo · NFL y más ligas |
| **Fase 3 — Comercialización** | 🔓 venta | por definir | Licencia de datos con redistribución · Activar multi-tenant · Facturación y planes · Consola MOTRAE · Marco legal · Tiendas · Soporte · Precios |
| **Fase 4 — Expansión** | venta | por definir | API para clientes · Datos propios del club (GPS/Catapult) · Video (decisión comercial) |

**Las fases 0 a 2 no producen nada vendible, y está bien.** Producen una herramienta que el equipo usa todos los días, que es la única forma honesta de saber qué merece venderse.

La lista detallada de los ocho puntos de la Fase 3 está en [`16_DISTRIBUCION_Y_PRECIOS.md`](docs/motsport/16_DISTRIBUCION_Y_PRECIOS.md).

---

## ⚠️ Riesgos abiertos

| Riesgo | Impacto | Cómo se controla |
|---|---|---|
| **Licencia de datos** | Bloqueante, **pero solo al comercializar**. StatsBomb Open Data y el tier gratuito de Open-Meteo prohíben el uso comercial | Capa de proveedores intercambiables desde el día uno; licencia por fuente documentada en [`15_LEGAL.md`](docs/motsport/15_LEGAL.md); sustitución antes del primer cobro |
| **Costo de IA por consulta** | Alto si se descuida | Caché de prompt sobre el bloque estable, esfuerzo bajo en consultas rutinarias, medición por consulta desde el primer día |
| **Calidad y huecos del dato** | Un análisis sobre datos sucios es peor que ningún análisis | Procedencia obligatoria por fila, nivel de confianza, y el asistente obligado a decir "no tengo ese dato" |
| **Posicionamiento** | Un producto de predicción puede leerse como herramienta de apuestas | Se posiciona como preparación de partido y scouting; sin integración con casas, sin recomendaciones de apuesta; cuidado desde la ficha de tienda en Fase 3 |
| **Alcance que se estira** | El video y la venta son imanes de esfuerzo | Las dos reglas de oro, escritas en este README y en `CLAUDE.md` |

---

## 📁 Estructura del repositorio

```
MotSport/
├─ README.md                             ← este archivo: el contexto completo
├─ CLAUDE.md                             ← carga automática en Claude Code
├─ .gitignore                            ← secretos bloqueados por EXTENSIÓN
├─ docs/
│  ├─ MOTRAE_EMPRESA.md                  ← contexto de empresa (copia del canónico)
│  ├─ BIENVENIDA-DESARROLLADOR.md        ← onboarding y reglas que no se negocian
│  ├─ motsport/                          ← la suite de documentación del producto
│  │  ├─ 00_INDICE.md                    ← empieza por aquí
│  │  ├─ 01…17_*.md                      ← mercado, plan, arquitectura, datos, IA, legal…
│  │  ├─ 04_modulos/                     ← un documento por módulo
│  │  └─ mockups/                        ← tokens, componentes y pantallas navegables
│  └─ adr/                               ← una decisión de arquitectura por archivo
├─ apps/
│  ├─ web/                               ← SvelteKit 2
│  ├─ movil/                             ← Capacitor 8
│  └─ motor/                             ← Python: ingesta, métricas y modelos
├─ packages/
│  ├─ dominio/                           ← reglas de negocio, isomórfico
│  ├─ proveedores/                       ← conectores por fuente de datos
│  └─ ui/                                ← componentes compartidos
├─ supabase/
│  ├─ migrations/                        ← esquema versionado
│  └─ functions/                         ← Edge Functions
└─ entregables/                          ← versionado por entrega
```

---

## 🚦 Estado actual

**Hecho**
- Investigación de mercado, proveedores de datos y licencias
- Decisiones de producto: cliente, distribución, alcance de Fase 1, política de datos
- Repositorio, `README.md`, `CLAUDE.md` y suite de documentación
- Mockups navegables: fundaciones y **las diez pantallas**, verificadas en navegador en tema claro y oscuro — [`docs/motsport/mockups/index.html`](docs/motsport/mockups/index.html)
- Esquema de datos completo: 39 tablas con RLS, escala de confianza y resolución de conflictos

**Pendiente de MOTRAE**
- Esquema de datos detallado y primeras migraciones
- Nombrar responsable y periodicidad del catálogo manual de sedes
- Conector de la primera fuente

**Pendiente de decisión de Gonzalo** — las tres se resuelven antes de arrancar la Fase 1
- **Qué deportes y qué ligas sigue realmente el equipo** — define la primera ingesta y evita construir conectores que nadie va a abrir
- **Quién es exactamente «el equipo» que va a usar esto a diario** — toda la estrategia descansa en que el uso escriba el pliego de requisitos, y eso solo funciona si quien lo usa prepara partidos de verdad. Ver [`02_MASTER_PLAN.md`](docs/motsport/02_MASTER_PLAN.md) § 4
- Nombre comercial definitivo (`MotSport` es el nombre de trabajo)

---

## 🛠️ Cómo trabajar en este repo

- **Todo en español**: variables, funciones, commits, comentarios, documentos.
- Los comentarios explican **el porqué**, no el qué.
- Una rama por cambio: `feature/…`, `fix/…`, `docs/…`. **Nunca commitear directo a `main`.**
- **Nunca `git add -A` ni `git add .`** — se commitea por lista explícita de rutas.
- Commits estilo Conventional con el asunto en español natural, orientado al efecto: `feat(ingesta): el clima del partido ya no depende de abrir el teléfono`.
- Secretos y llaves de API **nunca** al repositorio: variables de entorno.
- Antes de un cambio grande, **propón un plan**.
- Entregables finales en `entregables/` y copia a Drive.

Detalle completo en [`docs/BIENVENIDA-DESARROLLADOR.md`](docs/BIENVENIDA-DESARROLLADOR.md).

---

## 🎨 Identidad visual

- **Verde MOTRAE `#57AD30`** como acento dominante, sobre base oscura `#14181A` / `#2D3A42`.
- Degradado `#F2853A → #E0392B` con moderación, solo para acentos de energía.
- Neutros claros `#E8F3E1` y `#F7F8F6`.
- **Space Grotesk** para títulos, **Inter** para cuerpo.
- Tono: moderno, profesional, con energía y movimiento. Español siempre.

---

## 📄 Documentos

| Documento | Qué contiene |
|---|---|
| [`docs/motsport/00_INDICE.md`](docs/motsport/00_INDICE.md) | Índice maestro de la suite |
| [`docs/motsport/02_MASTER_PLAN.md`](docs/motsport/02_MASTER_PLAN.md) | Identidad, propuesta de valor, alcance, riesgos, gobierno |
| [`docs/motsport/03_ARQUITECTURA.md`](docs/motsport/03_ARQUITECTURA.md) | Vista general y decisiones con justificación |
| [`docs/motsport/08_FUENTES_DE_DATOS.md`](docs/motsport/08_FUENTES_DE_DATOS.md) | Proveedores, cobertura, costo y licencia |
| [`docs/motsport/09_CATALOGO_DE_FACTORES.md`](docs/motsport/09_CATALOGO_DE_FACTORES.md) | Todo lo que afecta un partido |
| [`docs/motsport/15_LEGAL.md`](docs/motsport/15_LEGAL.md) | Qué permite cada fuente hoy y qué hay que sustituir para vender |
| [`docs/MOTRAE_EMPRESA.md`](docs/MOTRAE_EMPRESA.md) | Contexto completo de la empresa |

---

## ☎️ Contacto

**MOTRAE** · Xalapa, Veracruz · México
motrae.gmg@gmail.com · 228 353 6911 · www.motrae.com

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026 · Xalapa, Veracruz · México*
