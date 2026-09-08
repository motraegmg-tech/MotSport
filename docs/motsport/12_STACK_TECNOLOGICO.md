# 12 · Stack tecnológico

> 🟡 **Segunda pasada.** La tabla está decidida; faltan versiones exactas y la justificación escrita de las piezas todavía abiertas.

## La tabla

| Capa | Tecnología | Por qué |
|---|---|---|
| Web | **SvelteKit 2 + Svelte 5 + TypeScript + Vite** | Es lo que MOTRAE ya opera en producción con MotRest; cero curva de aprendizaje |
| Móvil | **Capacitor 8** sobre la misma aplicación, más PWA instalable | Mismo toolchain probado en `kds-android` y `motrest-android` |
| Backend | **Supabase**: Postgres 16 con RLS, Auth, Realtime, Edge Functions | Ya es la nube de MotRest; un solo proveedor que el equipo conoce |
| Motor | **Python 3.12 + FastAPI + pandas + LightGBM/scikit-learn** | El ecosistema del modelado deportivo es Python y no tiene equivalente real en TypeScript |
| IA | **Claude `claude-opus-5`** vía SDK oficial de Anthropic | Ver [`10_INTELIGENCIA_ARTIFICIAL.md`](10_INTELIGENCIA_ARTIFICIAL.md) |
| Gráficas | **ECharts** (propuesta) | Densidad de datos alta y buen desempeño |
| Monorepo | **pnpm workspaces** vía Corepack | Igual que MotRest |
| CI | **GitHub Actions**, acciones ancladas por hash de commit | Mismo estándar que el `ci.yml` de MotRest |

## Por qué dos lenguajes

Es la pregunta que va a hacer cualquiera que llegue nuevo. La respuesta está en [`03_ARQUITECTURA.md`](03_ARQUITECTURA.md) · D-7: reimplementar un modelo de goles calibrado o un gradient boosting en TypeScript cuesta más que mantener un segundo lenguaje con una frontera bien definida. **La frontera es Postgres y solo Postgres**, y quien trabaja en la interfaz nunca tiene que entender LightGBM.

## Política de dependencias (decidida)

- **Toda dependencia nueva se justifica antes de instalarse**: una línea diciendo qué resuelve y por qué no lo resolvemos nosotros.
- Versiones **fijadas**, no rangos abiertos.
- Acciones de terceros en CI **ancladas por hash de commit**, nunca por etiqueta: una etiqueta se puede mover, un hash no.
- Auditoría de vulnerabilidades en verde antes de cada PR.

## Pendiente de escribir

- Versiones exactas y archivo `.nvmrc`
- Justificación escrita de ECharts contra sus alternativas
- Decisión sobre si el motor corre como servicio permanente o como trabajos programados

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
