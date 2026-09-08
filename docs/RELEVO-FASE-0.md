# RELEVO · Fase 0 — MotSport

> **Para quien abra este repositorio sin haber estado en la conversación que lo creó** — otra máquina, otro IDE, otro agente, o tú mismo dentro de tres meses.
>
> Estado al **8 de septiembre de 2026** · 11 commits en `main` · 48 archivos · ~35,600 palabras de documentación · 10 mockups navegables.

---

## 1. Lo primero, en treinta segundos

**MotSport es la mesa de trabajo del analista deportivo**: concentra todo lo que rodea a un partido —histórico, forma, disponibilidad, clima, altitud, viaje, descanso— en una base propia multideporte, con un asistente de IA al que se le pregunta en español.

**Hoy es una herramienta de USO INTERNO de MOTRAE.** No se vende, no se distribuye. La venta es la Fase 3 y tiene su propia lista de ocho requisitos.

**No hay una sola línea de código de producto.** Eso es correcto y deliberado: la Fase 0 es documentación, esquema y mockups. `apps/`, `packages/` y `supabase/` tienen solo un README que dice qué va ahí.

### Orden de lectura para arrancar

1. [`../README.md`](../README.md) — el contexto completo
2. [`../CLAUDE.md`](../CLAUDE.md) — las reglas duras, en corto
3. [`motsport/00_INDICE.md`](motsport/00_INDICE.md) — índice de los 17 documentos
4. Este relevo — qué está hecho, qué falta y qué está bloqueado

---

## 2. Qué se hizo

### Documentación · 16 de 17 documentos

La suite completa está en [`motsport/`](motsport/), indexada en [`00_INDICE.md`](motsport/00_INDICE.md). Los que hay que leer si solo se leen tres: **02 (plan), 08 (fuentes) y 15 (legal)**.

**El único pendiente es [`11_MODELOS_PREDICTIVOS.md`](motsport/11_MODELOS_PREDICTIVOS.md)**, y está pendiente a propósito: es entrega de Fase 2 y no se puede especificar de verdad sin datos encima. Tiene escrita la postura y el enfoque candidato; falta el detalle, que se escribe cuando haya con qué medirlo.

### Esquema de datos · completo y auditado

[`07_MODELO_DE_DATOS.md`](motsport/07_MODELO_DE_DATOS.md), 2,544 líneas: **39 tablas** en español, con SQL, índices, políticas RLS, escala de confianza y algoritmo de resolución de conflictos.

Lo escribió **Codex** y lo auditó **Claude** de forma independiente (se intentó con Gemini, ver § 6). La auditoría está al final del propio documento, § 10.

### Mockups · las 10 pantallas

[`motsport/mockups/index.html`](motsport/mockups/index.html) — se abren con doble clic, sin instalar nada. HTML y CSS puros. **Verificados en navegador el 8 de septiembre**, en tema oscuro y claro.

### Repositorio

Sigue el patrón de MOTRAE: `README.md` y `CLAUDE.md` portátiles, `docs/MOTRAE_EMPRESA.md` importado con `@docs/MOTRAE_EMPRESA.md` (hash idéntico al canónico), `.gitignore` que bloquea secretos **por extensión** con el porqué comentado dentro.

**Prueba de portabilidad superada:** se le dio el repositorio a un lector sin ningún contexto previo y respondió correctamente qué es MOTRAE, qué es el producto y en qué etapa está, leyendo solo lo que hay dentro.

---

## 3. Las decisiones que ya están tomadas

No hace falta volver a discutirlas. Están todas justificadas en [`03_ARQUITECTURA.md`](motsport/03_ARQUITECTURA.md) (D-1 a D-9) y [`02_MASTER_PLAN.md`](motsport/02_MASTER_PLAN.md).

| Decisión | Dónde |
|---|---|
| Cliente eventual: equipos, entrenadores y analistas · SaaS en la nube | Plan § 1 |
| **Interno primero, venta después.** Costuras sí, fábrica no | README · Plan § 5 |
| Multideporte por catálogo, no por columnas: agregar un deporte es insertar filas | Arq. D-3 |
| `tenant_id` con RLS en cada tabla desde el día uno, aunque hoy haya un solo tenant | Arq. D-2 |
| Procedencia obligatoria por fila (`fuente`, `obtenido_ts`, `confianza`) | Arq. D-5 |
| **El asistente de IA no escribe SQL**: llama herramientas tipadas | Arq. D-6 |
| **Ninguna cifra sale del modelo.** Toda cifra viene de una llamada a herramienta | IA § 1 |
| Motor en Python, plataforma en TypeScript, **Postgres como única frontera** | Arq. D-7 |
| Ningún umbral es constante en código: va en catálogo versionado | Arq. D-9 |
| Fuera de alcance: video, apuestas, y todo lo que solo sirve para vender | Plan § 6 |

---

## 4. Lo que falta, en orden

### 4.1 Bloqueado — depende de Gonzalo

| # | Qué | Por qué bloquea |
|---|---|---|
| 1 | **Qué deportes y qué ligas sigue realmente el equipo** | Define la primera ingesta. Sin esto se construyen conectores que nadie va a abrir |
| 2 | **Quién es exactamente «el equipo» que va a usar esto a diario** | Toda la estrategia descansa en que el uso escriba el pliego de requisitos, y eso solo funciona si quien lo usa prepara partidos de verdad. Ver [`02_MASTER_PLAN.md`](motsport/02_MASTER_PLAN.md) § 4 |
| 3 | **Nombre comercial definitivo** | `MotSport` es nombre de trabajo. Cambiarlo hoy cuesta una búsqueda y reemplazo; con código publicado, no |
| 4 | **Crear el repositorio en GitHub** | Requiere `gh auth login`, que es interactivo. Ver § 5 |

### 4.2 Requisitos de máquina — antes de escribir código

| Herramienta | Estado el 8 sep 2026 |
|---|---|
| Node 24.x · pnpm 9 vía Corepack | ✅ instalado |
| **Python 3.12** | ⛔ **NO instalado.** Los `python.exe` de `WindowsApps` son *stubs* de Microsoft Store. Instalar desde python.org. **`apps/motor/` no arranca sin él** |
| **GitHub CLI (`gh`)** | ⛔ **NO instalado.** `winget install GitHub.cli` |
| Docker · Supabase CLI | Por verificar |

### 4.3 Primeras tareas de la Fase 1

En este orden:

1. **Medir el rendimiento del esquema.** Es lo único que la auditoría no pudo juzgar: si los índices sirven de verdad a la consulta de percentiles con millones de filas, y si las vistas materializadas se pueden refrescar de forma incremental. **No se juzga leyendo SQL, se mide con datos.**
2. **Aplicar los cuatro hallazgos de la auditoría** ([`07_MODELO_DE_DATOS.md`](motsport/07_MODELO_DE_DATOS.md) § 10) — ver § 4.4.
3. Escribir la primera migración de Supabase.
4. Escribir el primer conector, con su licencia documentada **antes** en [`08_FUENTES_DE_DATOS.md`](motsport/08_FUENTES_DE_DATOS.md).
5. Llenar a mano el catálogo de sedes y nombrar a su responsable.
6. Levantar `apps/web/` y el asistente v1.

### 4.4 Los cuatro hallazgos de la auditoría, pendientes de aplicar

Ninguno toca la estructura del núcleo. Detalle y SQL en [`07_MODELO_DE_DATOS.md`](motsport/07_MODELO_DE_DATOS.md) § 10.

| # | Sev. | Qué |
|---|---|---|
| 1 | GRAVE | `eventos.periodo` es texto libre sin catálogo. Un conector escribe `'1T'`, otro `'Q1'`, y la consulta que agrupe por periodo devuelve tres grupos donde debería haber uno |
| 2 | MENOR | No se distingue una victoria en penales de una normal. Sesga el rating y la forma reciente, que alimentan el modelo predictivo |
| 3 | MENOR hoy, **BLOQUEANTE** al haber escrituras | 39 `USING` y cero `WITH CHECK`. La primera política de escritura debe llevarlo o un `UPDATE` puede mover una fila a otro tenant |
| 4 | MENOR | Los catálogos son por tenant y no hay procedimiento de siembra. En Fase 3 el primer cliente abriría con la base vacía |

---

## 5. Cómo subir el repositorio a GitHub

El commit ya está hecho y el remoto ya está configurado. Falta crear el repositorio y empujar, y eso requiere autenticación interactiva:

```bash
winget install GitHub.cli          # si aun no esta
gh auth login                      # interactivo, una sola vez
cd "…/Software_de_Analisis_Deportivo"
gh repo create motraegmg-tech/MotSport --private --source=. --push
```

**Privado**, siguiendo el patrón de los demás repositorios de MOTRAE. Rama única `main`.

---

## 6. Cómo se trabajó, y qué aprendimos del entorno

### Se usaron tres modelos, a propósito

| Modelo | Hizo |
|---|---|
| **Claude** | Investigación, documentación, mockups, y la auditoría independiente del esquema |
| **Codex** | El esquema de datos completo — 39 tablas, RLS, índices |
| **Gemini** | Nada útil. Ver abajo |

La separación importa: **el esquema lo escribió un modelo y lo auditó otro distinto.** Ese es el motivo de que la auditoría encontrara cuatro cosas.

### Gemini: arreglado, pero limitado

Cuatro corridas murieron por *timeout* sin producir salida ni error, una de ellas de 50 minutos. Diagnóstico, saltándose el CLI y probando la API con `curl`:

- **El puente apuntaba a `gemini-2.5-flash`, un modelo que Google retiró** para cuentas nuevas. La API responde 404 y **el CLI se cuelga reintentando en silencio** en vez de fallar. **Ya está arreglado** en `~/.claude/scripts/gemini-bridge.mjs`: ahora fija el modelo explícitamente y responde en 6 segundos.
- **Los modelos Pro devuelven 429 incluso con un prompt de una palabra.** La cuota agotada es `GenerateRequestsPerDayPerProjectPerModel-FreeTier`: **el nivel gratuito de la llave no incluye Pro.** Requiere activar facturación.
- Con prompts medianos (12 KB) los tres modelos flash devolvieron **503 «alta demanda»**. Congestión del lado de Google.

**Conclusión práctica:** Gemini sirve para encargos cortos. No para auditar un archivo de miles de líneas.

### Truco de diagnóstico que vale la pena recordar

Cuando una CLI de un proveedor se cuelga sin decir nada, **saltarse la CLI y pegarle a la API con `curl`**. Un 404 dice modelo retirado, un 429 dice cuota, un 503 dice congestión y un 200 dice que el problema es de la CLI. Eso convirtió una hora de cuelgues en un diagnóstico de dos minutos.

### El heredoc de Bash se rompe con documentos largos

Escribir archivos Markdown grandes con `cat > archivo <<'EOF'` falló dos veces con `unexpected EOF`. Para documentos largos, usar la herramienta de escritura directa; `sed` y heredocs cortos sí funcionan bien.

---

## 7. Reglas que no se negocian

Están en [`../CLAUDE.md`](../CLAUDE.md) y [`BIENVENIDA-DESARROLLADOR.md`](BIENVENIDA-DESARROLLADOR.md). Las cuatro que más se olvidan:

1. **Todo en español**: variables, funciones, commits, comentarios, documentos.
2. **Nunca `git add .` ni `git add -A`** — lista explícita de rutas. Este repositorio va a tener llaves de API.
3. **Antes de agregar una fuente de datos, documentar su licencia** en [`08_FUENTES_DE_DATOS.md`](motsport/08_FUENTES_DE_DATOS.md) y verificarla contra [`15_LEGAL.md`](motsport/15_LEGAL.md). Escribir el conector primero es como se construye un producto que no se puede vender.
4. **Antes de un cambio grande, proponer un plan.** Se aprueba y luego se escribe.

---

## 8. Historial de commits

```
34fb20d  docs(seguridad): las 39 politicas RLS pasan, pero faltaba escribir la trampa que viene
15ce7f1  docs(datos): el esquema pasa la auditoria, con dos defectos que si valia la pena encontrar
8649b2a  feat(mockups): las diez pantallas estan hechas y verificadas en navegador
8cf664f  docs: falta Python en la maquina, y eso bloquea la Fase 1 desde el primer dia
d72991d  docs(modulos): cada modulo dice ahora que NO hace, que es lo que evita el desborde
ec05a77  docs(ui): la guia de interfaz se escribe despues de los mockups, no antes
54443ea  feat(mockups): las ocho pantallas del alcance de Fase 1 ya se pueden abrir
a001d19  feat(datos): el esquema deja de ser una lista de nombres de tablas
a7df800  docs: la documentacion se contradecia sola, y una lectura sin contexto lo destapo
acab854  docs: nace MotSport, y queda escrito que primero se usa y despues se vende
```

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026 · Xalapa, Veracruz · México*
