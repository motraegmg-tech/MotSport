# 04 · Módulos

Cada módulo se describe con la misma ficha: **qué hace · qué NO hace · con qué habla · qué datos toca · fase**.

> **Regla de recorte:** un módulo que necesita conocer las tablas internas de otro está mal recortado. Los módulos se hablan por contrato, no por dentro.

---

## 00 · Plataforma transversal · Fase 1

**Qué hace.** Autenticación, tenants y organizaciones, roles, sesión, auditoría de accesos, configuración por tenant.

**Qué NO hace.** Alta de clientes, planes, facturación — eso es Fase 3, ver [`../16_DISTRIBUCION_Y_PRECIOS.md`](../16_DISTRIBUCION_Y_PRECIOS.md). En Fase 1 existe un solo tenant y el acceso es por invitación.

**Con qué habla.** Con todos. Es el que define el contexto de tenant que la RLS de Postgres usa en cada consulta.

**Datos.** `inquilinos`, `organizaciones`, `usuarios`, `accesos_equipo`.

---

## 01 · Ingesta · Fase 1

**Qué hace.** Un conector por fuente, todos detrás de la interfaz `ProveedorDeportivo`. Programación, reintentos, deduplicación, control del presupuesto de consultas y registro de procedencia en cada fila.

**Qué NO hace.** No normaliza métricas derivadas (eso es el 02) ni decide qué fuente gana un conflicto (eso se resuelve en lectura, ver [`../07_MODELO_DE_DATOS.md`](../07_MODELO_DE_DATOS.md) § 6). **Nunca sobreescribe el dato de otra fuente.**

**Con qué habla.** Fuentes externas por HTTP; escribe a Postgres. Nada más.

**Datos.** Escribe en todas las tablas de hechos con sus columnas de procedencia; lee `fuentes` y `preferencias_fuente`.

> **La restricción que define su diseño:** la fuente principal de Fase 1 da **100 consultas al día**. La ingesta es incremental y cachea agresivamente desde el primer día — no como parche, sino porque bajo esa restricción se escribe la ingesta correcta de todos modos.

**Antes de escribir un conector nuevo:** su licencia se documenta en [`../08_FUENTES_DE_DATOS.md`](../08_FUENTES_DE_DATOS.md) y se verifica contra [`../15_LEGAL.md`](../15_LEGAL.md).

---

## 02 · Núcleo de datos · Fase 1

**Qué hace.** El modelo multideporte, el catálogo de métricas y el cálculo de las derivadas: percentiles, ratings, agregados por ventana.

**Qué NO hace.** No consulta fuentes externas. No decide qué se muestra.

**Con qué habla.** Solo con Postgres.

**Datos.** `catalogo_metricas`, `valores_metricas`, vistas materializadas de percentiles.

> Agregar un deporte nuevo es **insertar filas en catálogos**, nunca una migración de esquema. Si alguna vez hace falta migrar para agregar un deporte, el modelo está mal y hay que abrir un ADR.

---

## 03 · Contexto de partido · Fase 1

**Qué hace.** Calcula y almacena todo lo que rodea al partido: clima de la sede a la hora del partido, altitud, superficie y techo, días de descanso, congestión de calendario, kilómetros de viaje, husos cruzados, árbitro, importancia.

**Qué NO hace.** No predice. Deja los factores calculados para que el 05 los use.

**Con qué habla.** Open-Meteo y el catálogo de sedes; escribe a Postgres.

**Datos.** `catalogo_factores`, `factores_partido`, `sedes`, `observaciones_sede`.

> **Este módulo es el corazón defendible del producto.** El dato crudo lo compra cualquiera; el contexto cruzado con el rendimiento es lo que los proveedores no entregan junto. Ver [`../01_INVESTIGACION_MERCADO.md`](../01_INVESTIGACION_MERCADO.md) § 3.

---

## 04 · Análisis y comparación · Fase 1

**Qué hace.** Percentiles contra una escala explícita, radares, comparador de hasta cuatro entidades, buscador de scouting por rangos de percentil, listas de seguimiento.

**Qué NO hace.** No calcula las métricas (eso es el 02). No predice.

**Con qué habla.** Lee de Postgres. Es el módulo más sensible al rendimiento: la consulta de percentiles es la más caliente del producto.

---

## 05 · Predicción · Fase 2

**Qué hace.** Construye features desde el catálogo de factores, entrena, hace backtesting con partición temporal y produce probabilidades **con la contribución de cada factor**.

**Qué NO hace.** **No emite recomendaciones de apuesta ni calcula valor esperado sobre cuotas.** Ver [`../15_LEGAL.md`](../15_LEGAL.md).

**Con qué habla.** Lee y escribe en Postgres. Vive en `apps/motor/` (Python).

> **En Fase 1 este módulo no existe**, y por eso el asistente no muestra ninguna probabilidad de resultado hasta la Fase 2. Un factor que no mejora la predicción en el backtesting no entra al modelo, por interesante que sea.

---

## 06 · Asistente IA · Fase 1

**Qué hace.** Traduce preguntas en español a llamadas de herramientas tipadas, orquesta el ciclo, arma la respuesta citando las filas usadas y lleva la cuenta del costo.

**Qué NO hace.** **No escribe SQL.** No inventa cifras. No escribe en la base: en Fase 1 solo lee.

**Con qué habla.** API de Claude, sus propias herramientas y la búsqueda web.

**Datos.** Lee a través de herramientas acotadas; escribe la bitácora de cada llamada.

> El filtro de tenant vive **en la herramienta**, no en el prompt: el modelo no puede saltárselo porque no lo controla. Detalle en [`../10_INTELIGENCIA_ARTIFICIAL.md`](../10_INTELIGENCIA_ARTIFICIAL.md).

---

## 07 · Alertas y en vivo · Fase 2

**Qué hace.** Evalúa las reglas del usuario contra el catálogo de factores, entrega los avisos por su canal y sigue el partido en vivo.

**Qué NO hace.** No define factores nuevos: solo se puede alertar sobre lo que ya está en el catálogo **y tiene fuente**.

**Con qué habla.** Supabase Realtime, notificaciones push, correo.

> Si una regla supera diez disparos al mes, el módulo propone subir el umbral. Una alerta que se dispara todos los días deja de leerse.

---

## 08 · Informes · Fase 2

**Qué hace.** Genera el PDF de previa de partido y el de scouting, con la marca correspondiente.

**Qué NO hace.** No calcula nada propio: compone lo que ya produjeron los módulos 03, 04 y 05.

---

## 09 · Operación · Fase 1 (mínimo) → Fase 3 (Consola MOTRAE)

**Qué hace.** Salud de la ingesta por fuente, consultas consumidas contra el presupuesto, costo de IA acumulado, últimos errores, cobertura y huecos por competencia.

**Qué NO hace.** En Fase 1, nada de tenants ni de planes: eso llega en Fase 3, cuando esta pantalla crece hasta ser la Consola MOTRAE.

> Tres cosas se miden desde el primer día o no existen: **salud de la ingesta, costo de IA y calidad del dato**.

---

## Mapa de dependencias

```
  01 Ingesta ──▶ Postgres ◀── 02 Nucleo ──▶ 04 Analisis ──▶ 06 Asistente
                    ▲                            ▲               │
                    │                            │               ▼
              03 Contexto ──▶ 05 Prediccion ─────┘         08 Informes
                    │                                             ▲
                    └──────────▶ 07 Alertas ──────────────────────┘

              00 Plataforma: envuelve a todos (tenant, roles, auditoria)
              09 Operacion: observa a todos, no depende de ninguno
```

**Todo pasa por Postgres.** Ningún módulo llama a otro directamente.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
