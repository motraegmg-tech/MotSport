# CLAUDE.md — MotSport · Plataforma de análisis y control deportivo

**Lee primero [`README.md`](README.md): es el contexto completo del proyecto.**
**Si retomas trabajo, lee [`docs/RELEVO-FASE-0.md`](docs/RELEVO-FASE-0.md): qué está hecho, qué falta y qué está bloqueado.**
Índice maestro de documentación: [`docs/motsport/00_INDICE.md`](docs/motsport/00_INDICE.md)

## Lo esencial para no equivocarse

- Producto **propio de MOTRAE**, no de un cliente. CEO de MOTRAE: **Gonzalo** — empieza tus respuestas llamándolo por su nombre.
- MotSport es la **mesa de trabajo del analista deportivo**: almacena, busca, compara y explica todo lo que rodea a un partido.
- ⚠️ **Hoy es una herramienta de USO INTERNO** — la usan Gonzalo y su equipo. **No se distribuye, no se vende, no se le da acceso a nadie fuera del equipo.** La venta es la Fase 3 y tiene su propia lista de requisitos en [`docs/motsport/16_DISTRIBUCION_Y_PRECIOS.md`](docs/motsport/16_DISTRIBUCION_Y_PRECIOS.md).
- **Costuras sí, fábrica no.** Se construyen hoy las costuras que costaría carísimo abrir después (`tenant_id` con RLS, proveedores intercambiables, procedencia por dato). **No** se construye maquinaria de venta: sin planes, sin facturación, sin alta de clientes.
- **No es** una plataforma de video (fuera de Fase 1 y 2). **No es** un producto de apuestas: se posiciona como preparación de partido y scouting.
- Cliente eventual (Fase 3): **equipos, entrenadores y analistas**. SaaS en la nube, multi-dispositivo.
- **Ninguna cifra sale del modelo de IA. Sale de la base.** El asistente busca, ordena y explica; jamás inventa un número. Toda respuesta cita las filas y su fecha.
- **Todo dato lleva procedencia** (`fuente`, `obtenido_ts`, `confianza`). Sin eso no entra a la base.
- **Todo umbral y toda métrica es un parámetro versionado en base de datos**, nunca una constante en código.
- **Las fuentes gratuitas son legales mientras el uso sea interno**, y solo mientras lo sea. StatsBomb Open Data y el tier gratuito de Open-Meteo prohíben el uso comercial. Antes del primer cobro hay que sustituirlas — ver [`docs/motsport/15_LEGAL.md`](docs/motsport/15_LEGAL.md). Si vas a agregar una fuente nueva, documenta su licencia en [`08_FUENTES_DE_DATOS.md`](docs/motsport/08_FUENTES_DE_DATOS.md) **antes** de escribir el conector.
- Multi-tenant con RLS de Postgres desde el día uno, aunque hoy el tenant sea uno solo. Nunca una consulta sin filtro de tenant.
- Stack: SvelteKit 2 + Svelte 5 · Capacitor 8 · Supabase (Postgres 16, RLS, Realtime) · motor Python (FastAPI + LightGBM) · Claude `claude-opus-5`. Justificación en [`docs/motsport/12_STACK_TECNOLOGICO.md`](docs/motsport/12_STACK_TECNOLOGICO.md).
- **Estado: planeación (Fase 0) · uso interno**

## Marca (aplicar en todo artefacto visual)

- Verde MOTRAE `#57AD30` acento dominante sobre base oscura `#14181A` / `#2D3A42`; degradado `#F2853A → #E0392B` con moderación.
- Space Grotesk (títulos) + Inter (cuerpo). Español, tono profesional.

## Convenciones

- **Todo en español**: variables, funciones, commits, comentarios, documentos. Mezclar idiomas en el mismo archivo hace que nadie encuentre nada.
- Los comentarios explican **el porqué**, no el qué.
- Antes de cambios grandes, **propón un plan**.
- Ramas `feature/…` `fix/…` `docs/…`. Nunca commitear directo a `main`. **Nunca `git add -A` ni `git add .`** — lista explícita de rutas.
- Secretos y llaves de API: **nunca** al repo. Variables de entorno.
- Entregables finales en `entregables/` y copia a Drive.

## Documentos de referencia

- [`docs/RELEVO-FASE-0.md`](docs/RELEVO-FASE-0.md) — **empieza aquí si retomas**: avance, pendientes, bloqueos y cómo subir el repo a GitHub
- [`docs/motsport/00_INDICE.md`](docs/motsport/00_INDICE.md) — índice maestro de los 17 documentos
- [`docs/motsport/08_FUENTES_DE_DATOS.md`](docs/motsport/08_FUENTES_DE_DATOS.md) — proveedores, costos y licencias
- [`docs/motsport/09_CATALOGO_DE_FACTORES.md`](docs/motsport/09_CATALOGO_DE_FACTORES.md) — todo lo que afecta un partido
- [`docs/motsport/10_INTELIGENCIA_ARTIFICIAL.md`](docs/motsport/10_INTELIGENCIA_ARTIFICIAL.md) — el asistente y sus reglas
- [`docs/BIENVENIDA-DESARROLLADOR.md`](docs/BIENVENIDA-DESARROLLADOR.md) — cómo se trabaja aquí

## Contexto de la empresa (MOTRAE)

Este producto lo desarrolla **MOTRAE**. El contexto completo de la empresa se importa automáticamente:

@docs/MOTRAE_EMPRESA.md
