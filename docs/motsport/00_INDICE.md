# 00 · Índice maestro — Documentación de MotSport

> Suite oficial de documentación del producto. Un tema por documento.
> **Estado del producto:** Planeación · Fase 0 · **uso interno** · Septiembre 2026

Antes de entrar aquí, lee [`../../README.md`](../../README.md). Este índice es para saltar al documento del tema que te toque, no para entender el producto desde cero.

---

## La suite

| # | Documento | Qué contiene | Estado |
|---|---|---|---|
| 01 | [`01_INVESTIGACION_MERCADO.md`](01_INVESTIGACION_MERCADO.md) | Hudl, Wyscout, StatsBomb, Second Spectrum, Catapult. Qué hace cada uno, qué cuesta y cuál es el hueco que ocupamos | ✅ escrito |
| 02 | [`02_MASTER_PLAN.md`](02_MASTER_PLAN.md) | Identidad del producto, problema y oportunidad, propuesta de valor, alcance por fase, riesgos, gobierno del proyecto | ✅ escrito |
| 03 | [`03_ARQUITECTURA.md`](03_ARQUITECTURA.md) | Vista general, decisiones de arquitectura con su justificación, fronteras entre componentes | ✅ escrito |
| 04 | [`04_modulos/`](04_modulos/) | Un documento por módulo: qué hace, qué no hace, con qué habla | 🟡 índice escrito, detalle en segunda pasada |
| 05 | [`05_UI_UX.md`](05_UI_UX.md) | Principios de interfaz, navegación, estados, densidad, accesibilidad | 🟡 segunda pasada |
| 06 | [`06_MOCKUPS.md`](06_MOCKUPS.md) | Guía de los mockups navegables en [`mockups/`](mockups/) — fundaciones y las 4 pantallas críticas ya están hechas | ✅ escrito |
| 07 | [`07_MODELO_DE_DATOS.md`](07_MODELO_DE_DATOS.md) | Núcleo multideporte, catálogo de métricas, eventos, procedencia, multi-tenant | 🟡 segunda pasada |
| 08 | [`08_FUENTES_DE_DATOS.md`](08_FUENTES_DE_DATOS.md) | ★ Proveedor por proveedor: cobertura, costo, límites, **licencia** y plan de migración | ✅ escrito |
| 09 | [`09_CATALOGO_DE_FACTORES.md`](09_CATALOGO_DE_FACTORES.md) | ★ Todo lo que afecta un partido, por familia y por deporte, con definición y fuente | ✅ escrito |
| 10 | [`10_INTELIGENCIA_ARTIFICIAL.md`](10_INTELIGENCIA_ARTIFICIAL.md) | El asistente: modelo, herramientas, reglas anti-invención, costo por consulta | ✅ escrito |
| 11 | [`11_MODELOS_PREDICTIVOS.md`](11_MODELOS_PREDICTIVOS.md) | Features, entrenamiento, backtesting, métricas de calidad, explicación del pronóstico | 🟡 segunda pasada |
| 12 | [`12_STACK_TECNOLOGICO.md`](12_STACK_TECNOLOGICO.md) | Tabla de stack, justificaciones, política de versiones y dependencias | 🟡 segunda pasada |
| 13 | [`13_INFRAESTRUCTURA.md`](13_INFRAESTRUCTURA.md) | Supabase, contenedor del motor, CI/CD, respaldos, entornos | 🟡 segunda pasada |
| 14 | [`14_SEGURIDAD.md`](14_SEGURIDAD.md) | RLS, roles, manejo de secretos, auditoría, superficie de ataque del asistente | 🟡 segunda pasada |
| 15 | [`15_LEGAL.md`](15_LEGAL.md) | ★ Qué permite cada fuente **hoy** y qué hay que sustituir para poder vender | ✅ escrito |
| 16 | [`16_DISTRIBUCION_Y_PRECIOS.md`](16_DISTRIBUCION_Y_PRECIOS.md) | ★ La lista de Fase 3: los ocho puntos que convierten esto en producto vendible | ✅ escrito |
| 17 | [`17_VISION_FUTURA.md`](17_VISION_FUTURA.md) | Todo lo que excede el alcance vive aquí, no en el plan de trabajo | ✅ escrito |

**★** = documento crítico. Si solo vas a leer tres, lee el 02, el 08 y el 15.

---

## Decisiones de arquitectura

Las decisiones puntuales, una por archivo, viven en [`../adr/`](../adr/). Todavía no hay ninguna: se abren cuando empiece el código en Fase 1. Formato:

```
# ADR-NN · <título en lenguaje natural>
**Estado:** aceptado · **Fecha:** … · **Decide:** Gonzalo (MOTRAE)
## Contexto
## Decisión
## Consecuencias
```

---

## Cómo se mantiene esta suite

- Un documento cubre **un tema**. Si un documento empieza a hablar de dos cosas, se parte.
- Lo que excede el alcance no se borra: se manda a [`17_VISION_FUTURA.md`](17_VISION_FUTURA.md). Así no se pierde la idea y no se cuela al plan de trabajo.
- Cuando una decisión cambie, se actualiza el documento **y** se abre un ADR explicando por qué cambió. El documento dice qué es hoy; el ADR dice por qué dejó de ser lo de ayer.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
