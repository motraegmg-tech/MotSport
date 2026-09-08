# 12 · Stack tecnológico

> Qué se usa, con qué versión, y **por qué esa y no otra**. Una tabla sin justificación no sirve: dentro de un año nadie va a recordar qué se descartó ni por qué.

---

## 1. La tabla

| Capa | Tecnología | Versión | Por qué |
|---|---|---|---|
| Web | **SvelteKit 2 + Svelte 5 + TypeScript** | Svelte 5.x · Vite 6 | Es lo que MOTRAE ya opera en producción con MotRest. Cero curva de aprendizaje y un solo dialecto en toda la empresa |
| Móvil | **Capacitor 8** + PWA instalable | 8.x | Mismo toolchain ya probado en `kds-android` y `motrest-android`. Una sola base de código para web, escritorio y teléfono |
| Backend | **Supabase** — Postgres 16, RLS, Auth, Realtime, Edge Functions | Postgres 16 | Ya es la nube de MotRest. Un solo proveedor que el equipo conoce, y RLS nativa, que es la costura multi-tenant del producto |
| Motor | **Python + FastAPI + pandas + LightGBM/scikit-learn** | Python 3.12 | El ecosistema del modelado deportivo es Python y no tiene equivalente real en TypeScript |
| IA | **Claude** vía SDK oficial de Anthropic | `claude-opus-5` · `claude-haiku-4-5` | Ver [`10_INTELIGENCIA_ARTIFICIAL.md`](10_INTELIGENCIA_ARTIFICIAL.md) |
| Gráficas | **ECharts** | 5.x | Ver § 3 |
| Monorepo | **pnpm workspaces** vía Corepack | pnpm 9.x · Node 24.x | Igual que MotRest |
| Pruebas | **vitest** + `svelte-check` + `tsc --noEmit`; **pytest** en el motor | — | Igual que MotRest |
| CI | **GitHub Actions**, acciones ancladas por hash de commit | — | Mismo estándar que el `ci.yml` de MotRest |

---

## 2. Por qué dos lenguajes

Es la primera pregunta que va a hacer cualquiera que llegue nuevo, y merece respuesta escrita.

**Porque reimplementar el modelado en TypeScript cuesta más que mantener una frontera limpia.** Un modelo de goles calibrado, un gradient boosting con validación temporal y una curva de calibración son cosas que en Python son una línea y en TypeScript son un proyecto. Y el costo de mantener dos lenguajes se paga una sola vez, con disciplina, mientras que el costo de reimplementar la estadística se paga en cada modelo nuevo.

**La frontera es Postgres y solo Postgres** ([`03_ARQUITECTURA.md`](03_ARQUITECTURA.md) · D-7). El motor escribe; la plataforma lee. No hay llamadas HTTP entre ellos, ni colas compartidas, ni archivos. Quien trabaja en la interfaz nunca tiene que entender LightGBM, y quien entrena modelos nunca tiene que abrir un `.svelte`.

Si alguien propone abrir otro canal entre los dos mundos, se para y se escribe un ADR.

---

## 3. Lo que se descartó, y por qué

| Descartado | A favor de | Razón |
|---|---|---|
| **React / Next.js** | SvelteKit | CLAVIS eligió Next.js, pero CLAVIS todavía no tiene código. MotRest sí, y está en Svelte 5 en producción. Se sigue lo que el equipo ya opera, no lo que otro documento planeó |
| **Tauri / app instalable** | SaaS en la nube | El caso de MotSport es el opuesto al de MotRest. Ahí el modo isla es el producto —un restaurante no puede dejar de vender—; aquí el dato viene de APIs externas y se consulta desde varios dispositivos. Ver D-1 |
| **Modelado en TypeScript** | Python | Ver § 2 |
| **D3** | ECharts | D3 es una caja de herramientas, no una librería de gráficas: cada visualización es un proyecto. ECharts trae hechas las que necesitamos —barras, líneas, radares, dispersión— con buen desempeño en tablas densas |
| **Chart.js** | ECharts | Se queda corto en radares y en interacción sobre muchos puntos, que es justo lo que hace el comparador |
| **Un ORM sobre Postgres** | SQL directo y vistas | El modelo se apoya en catálogos, JSONB y vistas materializadas. Un ORM encima estorbaría más de lo que ayuda |
| **Redis** | Postgres | Todavía no hay un problema de caché que Postgres no resuelva. Se agrega cuando exista, no antes |

---

## 4. Política de dependencias

1. **Toda dependencia nueva se justifica antes de instalarse.** Una línea diciendo qué resuelve y por qué no lo resolvemos nosotros. La conversación ocurre antes del `pnpm add`, no en la revisión del PR.
2. **Versiones fijadas**, no rangos abiertos. Un `^` es una actualización que nadie decidió.
3. **Acciones de terceros en CI ancladas por hash de commit**, nunca por etiqueta: una etiqueta se puede mover, un hash no.
4. **Auditoría de vulnerabilidades en verde antes de cada PR.**
5. **Preferir la biblioteca estándar y Postgres** antes que una dependencia nueva. Cada paquete es superficie de ataque y deuda de mantenimiento.
6. Las actualizaciones mayores se hacen **a propósito y solas**, en su propia rama, nunca mezcladas con una función nueva.

---

## 5. Pendiente

- Fijar versiones exactas y escribir `.nvmrc` y `pyproject.toml` al arrancar la Fase 1
- Decidir si el motor corre como servicio permanente o como trabajos programados — ver [`13_INFRAESTRUCTURA.md`](13_INFRAESTRUCTURA.md)
- Confirmar ECharts con una prueba real sobre la tabla de percentiles, que es la vista más densa del producto

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
