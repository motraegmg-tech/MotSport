# 07 · Modelo de datos

> 🟡 **Segunda pasada.** Las decisiones estructurales están tomadas y justificadas en [`03_ARQUITECTURA.md`](03_ARQUITECTURA.md); falta el esquema completo, tabla por tabla.

## Decisiones ya cerradas

| Decisión | Dónde se justifica |
|---|---|
| Núcleo común multideporte + métricas por catálogo, no por columnas | [`03_ARQUITECTURA.md`](03_ARQUITECTURA.md) · D-3 |
| Eventos con carga JSONB validada por deporte | D-4 |
| Procedencia obligatoria por fila (`fuente`, `obtenido_ts`, `confianza`) | D-5 |
| `tenant_id` con RLS en cada tabla desde la primera migración | D-2 |
| Ningún umbral como constante en código | D-9 |

## Núcleo común (borrador)

`deporte` · `competencia` · `temporada` · `equipo` · `jugador` · `sede` · `partido` · `plantilla` · `participacion` · `evento` · `catalogo_metricas` · `metricas` · `catalogo_factores` · `factores_partido`

La forma de `catalogo_factores` y `factores_partido` ya está especificada en [`09_CATALOGO_DE_FACTORES.md`](09_CATALOGO_DE_FACTORES.md).

## Pendiente de escribir

- Esquema completo con tipos, llaves e índices
- Políticas RLS por tabla
- Estrategia de vistas materializadas para percentiles (la consulta más caliente del producto)
- Reglas de identidad y deduplicación entre fuentes distintas — el mismo jugador con dos identificadores es el problema clásico de este dominio
- Resolución de conflictos por confianza en la capa de lectura
- Primera migración de Supabase

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
