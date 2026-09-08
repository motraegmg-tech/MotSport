# 03 · Arquitectura

> Cómo está armado MotSport y, sobre todo, **por qué** está armado así. Cada decisión de esta página tiene su justificación al lado; si alguna deja de tener sentido, se abre un ADR y se cambia.

---

## 1. Vista general

```
   FUENTES                 MOTOR (Python)              PLATAFORMA (TypeScript)          CLIENTES
┌──────────────┐      ┌────────────────────┐      ┌────────────────────────┐      ┌──────────────┐
│ API deportes │─────▶│ Ingesta programada │      │ SvelteKit 2 (web)      │◀────▶│ Navegador    │
│ Clima        │─────▶│ Normalizacion      │      │ Supabase               │      │ PWA instalab.│
│ Busqueda web │─────▶│ Metricas derivadas │─────▶│   Postgres 16 + RLS    │      │ iOS / Android│
└──────────────┘      │ Modelos predictivos│      │   Auth · Realtime      │      │  (Capacitor) │
                      └────────────────────┘      │   Edge Functions       │      └──────────────┘
                               │                  │ Asistente IA (Claude)  │
                               └───── Postgres ───┴────────────────────────┘
                                  la unica frontera entre los dos mundos
```

**Dos mundos, una frontera.** El motor de Python escribe a Postgres. La plataforma lee de Postgres. No hay ningún otro canal entre ellos: ni llamadas HTTP directas, ni colas compartidas, ni archivos. Si aparece la necesidad de abrir otro canal, se para y se propone un ADR.

Por qué importa tanto: es lo que permite que las dos mitades evolucionen, se prueben y se desplieguen por separado, y que quien trabaja en la interfaz nunca tenga que entender LightGBM.

---

## 2. Decisiones de arquitectura y su justificación

### D-1 · SaaS en la nube, no aplicación instalada con licencia

**Decisión.** MotSport vive en la nube y se consume desde navegador, PWA y móvil. No hay base local canónica por dispositivo.

**Por qué.** MotRest es LAN-first porque un restaurante **no puede dejar de vender** si se cae el internet: ahí el modo isla es el producto. Aquí el caso es el opuesto. El dato viene de APIs externas, se actualiza solo, y el mismo analista lo consulta desde la laptop, la tablet y el teléfono. Una base local canónica por dispositivo sería resolver un problema que no tenemos, a cambio de sincronización, conflictos y arbitraje que sí tendríamos.

**Consecuencia.** Sin conexión, MotSport muestra lo último cacheado y lo dice. No pretende operar offline.

---

### D-2 · Multi-tenant desde el día uno, aunque el tenant sea uno solo

**Decisión.** `tenant_id` en cada tabla, con **Row Level Security de Postgres activa**, desde la primera migración. Jerarquía `tenant → organización → equipo → usuario`.

**Por qué.** Es la costura más cara de retrofitear que existe. Meter `tenant_id` hoy cuesta una columna y una política por tabla. Meterlo dentro de un año obliga a auditar y reescribir **cada consulta del sistema**, con la certeza de que una se va a escapar y va a filtrar datos entre clientes. En cambio, la maquinaria que se apoya encima —alta de organizaciones, invitaciones, roles por club— sí se construye después, porque conectarla cuesta semanas, no meses.

Esto es la aplicación literal de la regla **costuras sí, fábrica no**.

**Consecuencia.** En Fase 1 existe un único tenant (MOTRAE) y el acceso es por invitación. Ninguna consulta se escribe sin filtro de tenant, aunque hoy sea redundante.

---

### D-3 · Métricas por catálogo, no por columnas

**Decisión.** Las métricas no son columnas de una tabla de fútbol. Viven en un catálogo:

- `catalogo_metricas` — `clave`, `deporte`, `nombre`, `unidad`, `formula`, `direccion_buena`, `fuente`, `version`
- `metricas` — `tenant_id`, `entidad` (equipo/jugador/partido), `entidad_id`, `metrica_clave`, `valor`, `contexto`

**Por qué.** El error clásico del software deportivo es nacer con un esquema de fútbol y después intentar meterle basquetbol. Los xG no existen en la NBA; el *pace* no existe en el fútbol; el EPA solo existe en el fútbol americano. Con columnas fijas, cada deporte nuevo es una migración y una rama de código. Con catálogo, **agregar un deporte es insertar filas**.

**Consecuencia.** Se pierde algo de tipado fuerte en la base y hay que compensarlo con validación en `packages/dominio/` y con vistas materializadas para las consultas calientes. Es un precio que vale la pena.

---

### D-4 · Eventos con carga JSONB validada por deporte

**Decisión.** Tabla `eventos` con `tipo` y una carga `JSONB` validada contra un esquema por deporte.

**Por qué.** Un tiro de fútbol, una posesión de NBA y una jugada de NFL no comparten forma. Forzarlos a una tabla común los mutila; darles una tabla a cada uno multiplica el código de lectura. JSONB con validación en la frontera da lo mejor de ambos, y Postgres lo indexa bien.

---

### D-5 · Procedencia obligatoria por fila

**Decisión.** Toda fila lleva `fuente`, `obtenido_ts` y `confianza`. Sin las tres, no entra.

**Por qué.** Tres razones, y las tres son importantes:

1. **Migración de proveedor.** El día que se pase de fuentes gratuitas a una licenciada (Fase 3), hay que saber exactamente qué resembrar. Sin `fuente`, hay que tirar la base entera.
2. **Conflictos.** Dos fuentes van a discrepar. Se guardan ambas y se resuelve en lectura por confianza; **nunca se sobreescribe** el dato de otra fuente.
3. **El asistente.** No puede citar de dónde salió un número si el número no sabe de dónde salió.

---

### D-6 · El asistente de IA no escribe SQL

**Decisión.** El modelo llama **funciones tipadas y acotadas**, no consultas libres contra la base.

**Por qué.** Un modelo con acceso libre a SQL es imposible de auditar —no sabes qué consulta hizo hasta que la hizo—, trivial de romper con una pregunta mal intencionada, y capaz de generar una consulta que tumbe la base sin querer. Con herramientas tipadas, la superficie es exactamente la que decidimos, cada llamada queda en bitácora, y el filtro de tenant es imposible de saltar porque no lo controla el modelo.

**Consecuencia.** Cada capacidad nueva del asistente es una herramienta nueva que alguien tiene que escribir. Es más trabajo y es correcto. Detalle en [`10_INTELIGENCIA_ARTIFICIAL.md`](10_INTELIGENCIA_ARTIFICIAL.md).

---

### D-7 · Motor en Python, plataforma en TypeScript

**Decisión.** Ingesta, cálculo de métricas derivadas y modelos predictivos en Python. Aplicación, autenticación y asistente en TypeScript. Postgres como única frontera.

**Por qué.** El ecosistema del modelado deportivo —pandas, scikit-learn, LightGBM, statsmodels— es Python, y no tiene equivalente real en TypeScript. Reimplementar un Dixon-Coles o un gradient boosting calibrado en TS costaría más que mantener un segundo lenguaje con una frontera bien definida.

**Consecuencia.** Dos lenguajes en el repositorio. Se paga con disciplina: la frontera es Postgres y solo Postgres, y `packages/dominio/` no duplica lógica que viva en el motor.

---

### D-8 · Ingesta incremental y con caché desde el diseño

**Decisión.** La ingesta pide solo lo que cambió, cachea agresivamente y respeta un presupuesto de consultas por fuente.

**Por qué.** La fuente principal de Fase 1 da **100 consultas al día**. Eso no se resuelve pagando más adelante: se resuelve no pidiendo lo que ya se tiene. Y una ingesta bien hecha bajo esa restricción sigue siendo la ingesta correcta cuando el límite desaparezca.

---

### D-9 · Ningún umbral es una constante en código

**Decisión.** Factores, métricas, umbrales y pesos viven en catálogos versionados en base de datos.

**Por qué.** Es la misma regla de ingeniería que rige CLAVIS, por la misma razón: lo que cambia con el conocimiento del dominio no puede requerir un despliegue para cambiar. Si el umbral de "viento adverso" resulta ser 22 km/h y no 25, eso es una fila, no un *release*.

---

## 3. Seguridad, en resumen

- **Aislamiento por RLS de Postgres**, no por filtros en la aplicación.
- **Secretos en variables de entorno**, nunca en el repositorio. El `.gitignore` bloquea por extensión como segunda línea.
- **El asistente no ejecuta SQL** (ver D-6): esa es la mitad de la superficie de ataque de un producto así, y está cerrada por diseño.
- **Bitácora de cada llamada a herramienta** del asistente: qué preguntó, qué herramientas usó, qué devolvieron.
- Detalle completo en [`14_SEGURIDAD.md`](14_SEGURIDAD.md).

---

## 4. Observabilidad

Desde Fase 1, tres cosas se miden o no existen:

1. **Salud de la ingesta** — última corrida por fuente, filas nuevas, errores, consultas consumidas contra el presupuesto.
2. **Costo de IA** — tokens de entrada y salida, aciertos de caché (`cache_read_input_tokens`), costo por consulta y por usuario.
3. **Calidad del dato** — cobertura por competencia, huecos detectados, discrepancias entre fuentes.

Todo eso se ve en la pantalla de operación, que en Fase 3 crece hasta ser la Consola MOTRAE.

---

## 5. Lo que todavía no está decidido

Se decide en Fase 0 o al inicio de Fase 1, y cada una llevará su ADR:

- Motor de gráficas definitivo (ECharts es la propuesta).
- Si el motor corre como servicio permanente o como trabajos programados.
- Estrategia de vistas materializadas para percentiles.
- Nombre comercial del producto.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
