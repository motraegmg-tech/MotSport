# 04 · Módulos

> 🟡 **Segunda pasada.** El índice está cerrado; el documento de cada módulo se escribe cuando ese módulo entra en construcción.

Cada módulo tendrá su propio archivo con la misma estructura: **qué hace · qué NO hace · con qué habla · datos que toca · estado**.

| # | Módulo | Qué hace | Fase |
|---|---|---|---|
| 00 | **Plataforma transversal** | Autenticación, tenants, roles, auditoría, configuración | 1 |
| 01 | **Ingesta** | Conectores por proveedor, programación, reintentos, deduplicación, procedencia | 1 |
| 02 | **Núcleo de datos** | Modelo multideporte, catálogo de métricas, cálculo de derivadas | 1 |
| 03 | **Contexto de partido** | Clima, sede, viaje, descanso, árbitro, importancia | 1 |
| 04 | **Análisis y comparación** | Percentiles, radares, comparador, scouting | 1 |
| 05 | **Predicción** | Features, entrenamiento, backtesting, explicación | 2 |
| 06 | **Asistente IA** | Herramientas, orquestación, citas, presupuesto de consultas | 1 |
| 07 | **Alertas y en vivo** | Reglas del usuario, notificaciones, seguimiento | 2 |
| 08 | **Informes** | Generación de PDF de previa y de scouting | 2 |
| 09 | **Operación** | Salud de la ingesta, costos, errores; en Fase 3 crece hasta ser la Consola MOTRAE | 1 |

> **Regla de recorte:** un módulo que necesita conocer las tablas internas de otro está mal recortado. Los módulos se hablan por contrato, no por dentro.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
