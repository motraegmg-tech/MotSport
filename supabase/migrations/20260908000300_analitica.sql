-- ─────────────────────────────────────────────────────────────
-- MotSport · Esquema analitica · 3 vistas materializadas
--
-- Fuente legible: docs/motsport/07_MODELO_DE_DATOS.md secciones 8.3 a 8.5
--
-- POR QUE ESTA MIGRACION LLEGA TARDE, Y QUE ENSEÑA:
-- al extraer el esquema del documento se clasificaron las secciones
-- 8.3 a 8.5 como "consultas de ejemplo" y se dejaron fuera. No lo son:
-- contienen el esquema analitica, tres vistas materializadas y siete
-- indices. El error no lo detectaron ni el orden topologico ni sqlglot
-- —ambos solo miran lo que se les da—, sino la primera pregunta real
-- que alguien le hizo a la base: "¿donde estan las materializadas?".
--
-- Cada vista lleva un UNIQUE INDEX a proposito: es el requisito de
-- Postgres para REFRESH MATERIALIZED VIEW CONCURRENTLY, que refresca
-- sin bloquear lecturas. Ojo: concurrente NO es incremental. Postgres
-- recalcula la vista completa; lo que evita es el bloqueo, no el
-- trabajo. Si el recalculo completo resulta caro con datos de verdad,
-- la salida es tabla de resumen mas ingesta incremental, no otra
-- opcion de REFRESH que no existe.
--
-- Se crean CON datos (sin WITH NO DATA en las que no lo traen del
-- documento) segun lo que diga cada definicion de abajo.
-- ─────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS analitica;
REVOKE ALL ON SCHEMA analitica FROM PUBLIC, anon, authenticated;

CREATE MATERIALIZED VIEW analitica.percentiles_jugador AS
WITH base AS (
  SELECT vm.tenant_id,
         vm.jugador_id,
         vm.competencia_id,
         vm.temporada_id,
         vm.posicion_id,
         vm.metrica_id,
         vm.valor,
         vm.minutos_muestra,
         vm.fuente,
         vm.obtenido_ts,
         vm.confianza,
         vm.hay_conflicto,
         cm.deporte_id,
         cm.direccion_favorable,
         umbral.valor_numero AS minutos_minimos
  FROM public.valores_metricas_resueltos AS vm
  JOIN public.catalogo_metricas AS cm
    ON cm.tenant_id = vm.tenant_id
   AND cm.metrica_id = vm.metrica_id
  JOIN LATERAL (
    SELECT vp.valor_numero
    FROM public.valores_parametros AS vp
    JOIN public.catalogo_parametros AS cp
      ON cp.tenant_id = vp.tenant_id
     AND cp.parametro_id = vp.parametro_id
    WHERE vp.tenant_id = vm.tenant_id
      AND cp.clave = 'minutos_minimos_percentil'
      AND vp.valor_numero IS NOT NULL
      AND (vp.deporte_id IS NULL OR vp.deporte_id = cm.deporte_id)
      AND (vp.competencia_id IS NULL OR vp.competencia_id = vm.competencia_id)
      AND (vp.temporada_id IS NULL OR vp.temporada_id = vm.temporada_id)
      AND (vp.posicion_id IS NULL OR vp.posicion_id = vm.posicion_id)
      AND (vp.metrica_id IS NULL OR vp.metrica_id = vm.metrica_id)
      AND vp.vigente_desde <= now()
      AND (vp.vigente_hasta IS NULL OR vp.vigente_hasta > now())
    ORDER BY
      (vp.metrica_id IS NOT NULL) DESC,
      (vp.posicion_id IS NOT NULL) DESC,
      (vp.temporada_id IS NOT NULL) DESC,
      (vp.competencia_id IS NOT NULL) DESC,
      (vp.deporte_id IS NOT NULL) DESC,
      vp.version DESC
    LIMIT 1
  ) AS umbral ON true
  WHERE vm.tipo_entidad = 'jugador'
    AND vm.ambito = 'temporada'
    AND vm.jornada_id IS NULL
), elegibles AS (
  SELECT *
  FROM base
  WHERE minutos_muestra >= minutos_minimos
)
SELECT e.*,
       round((100 * percent_rank() OVER (
         PARTITION BY e.tenant_id, e.competencia_id, e.temporada_id,
                      e.posicion_id, e.metrica_id
         ORDER BY e.valor
       ))::numeric, 2) AS percentil_bruto,
       CASE e.direccion_favorable
         WHEN 'alta' THEN round((100 * percent_rank() OVER (
           PARTITION BY e.tenant_id, e.competencia_id, e.temporada_id,
                        e.posicion_id, e.metrica_id
           ORDER BY e.valor
         ))::numeric, 2)
         WHEN 'baja' THEN round((100 * percent_rank() OVER (
           PARTITION BY e.tenant_id, e.competencia_id, e.temporada_id,
                        e.posicion_id, e.metrica_id
           ORDER BY e.valor DESC
         ))::numeric, 2)
         ELSE NULL
       END AS percentil_favorable,
       count(*) OVER (
         PARTITION BY e.tenant_id, e.competencia_id, e.temporada_id,
                      e.posicion_id, e.metrica_id
       ) AS tamano_poblacion,
       now() AS actualizado_ts
FROM elegibles AS e
WITH NO DATA;

CREATE UNIQUE INDEX idx_percentiles_jugador_unico
  ON analitica.percentiles_jugador
  (tenant_id, jugador_id, competencia_id, temporada_id, posicion_id, metrica_id);

CREATE INDEX idx_percentiles_jugador_busqueda_multiple
  ON analitica.percentiles_jugador
  (tenant_id, competencia_id, temporada_id, posicion_id, metrica_id,
   percentil_favorable, jugador_id)
  INCLUDE (valor, minutos_muestra, tamano_poblacion);

CREATE MATERIALIZED VIEW analitica.partidos_contexto AS
WITH factores AS (
  SELECT fr.tenant_id,
         fr.partido_id,
         jsonb_object_agg(
           cf.clave || COALESCE(':' || fr.equipo_id::text, ''),
           jsonb_build_object(
             'valor', fr.valor,
             'fuente', fr.fuente,
             'obtenido_ts', fr.obtenido_ts,
             'confianza', fr.confianza,
             'hay_conflicto', fr.hay_conflicto
           )
         ) AS factores
  FROM public.factores_partido_resueltos AS fr
  JOIN public.catalogo_factores AS cf
    ON cf.tenant_id = fr.tenant_id
   AND cf.factor_id = fr.factor_id
  GROUP BY fr.tenant_id, fr.partido_id
), participantes AS (
  SELECT pr.tenant_id,
         pr.partido_id,
         jsonb_agg(
           jsonb_build_object(
             'equipo_id', pr.equipo_id,
             'condicion', pr.condicion,
             'puntuacion', pr.puntuacion,
             'resultado', pr.resultado,
             'fuente', pr.fuente,
             'obtenido_ts', pr.obtenido_ts,
             'confianza', pr.confianza,
             'hay_conflicto', pr.hay_conflicto
           ) ORDER BY pr.condicion, pr.equipo_id
         ) AS participantes
  FROM public.participantes_partido_resueltos AS pr
  GROUP BY pr.tenant_id, pr.partido_id
)
SELECT vr.tenant_id,
       vr.partido_id,
       vr.deporte_id,
       vr.competencia_id,
       vr.temporada_id,
       vr.jornada_id,
       vr.sede_id,
       vr.inicio_programado,
       vr.estado,
       vr.neutral,
       vr.detalle_resultado,
       vr.fuente,
       vr.obtenido_ts,
       vr.confianza,
       vr.hay_conflicto,
       COALESCE(p.participantes, '[]'::jsonb) AS participantes,
       COALESCE(f.factores, '{}'::jsonb) AS factores,
       now() AS actualizado_ts
FROM public.versiones_partido_resueltas AS vr
LEFT JOIN participantes AS p
  ON p.tenant_id = vr.tenant_id
 AND p.partido_id = vr.partido_id
LEFT JOIN factores AS f
  ON f.tenant_id = vr.tenant_id
 AND f.partido_id = vr.partido_id
WITH NO DATA;

CREATE UNIQUE INDEX idx_partidos_contexto_unico
  ON analitica.partidos_contexto (tenant_id, partido_id);

CREATE INDEX idx_partidos_contexto_semana
  ON analitica.partidos_contexto
  (tenant_id, inicio_programado, competencia_id, estado);

CREATE INDEX idx_partidos_contexto_factores
  ON analitica.partidos_contexto USING gin (factores jsonb_path_ops);

CREATE MATERIALIZED VIEW analitica.historial_enfrentamientos AS
WITH pares AS (
  SELECT pr.tenant_id,
         pr.partido_id,
         (array_agg(DISTINCT pr.equipo_id ORDER BY pr.equipo_id))[1] AS equipo_a_id,
         (array_agg(DISTINCT pr.equipo_id ORDER BY pr.equipo_id))[2] AS equipo_b_id
  FROM public.participantes_partido_resueltos AS pr
  GROUP BY pr.tenant_id, pr.partido_id
  HAVING count(DISTINCT pr.equipo_id) = 2
)
SELECT pc.tenant_id,
       pares.equipo_a_id,
       pares.equipo_b_id,
       pc.partido_id,
       pc.competencia_id,
       pc.temporada_id,
       pc.inicio_programado,
       pc.detalle_resultado,
       pc.participantes,
       pc.factores,
       pc.fuente,
       pc.obtenido_ts,
       pc.confianza,
       pc.hay_conflicto,
       pc.actualizado_ts
FROM pares
JOIN analitica.partidos_contexto AS pc
  ON pc.tenant_id = pares.tenant_id
 AND pc.partido_id = pares.partido_id
WHERE pc.estado = 'finalizado'
WITH NO DATA;

CREATE UNIQUE INDEX idx_historial_enfrentamientos_unico
  ON analitica.historial_enfrentamientos (tenant_id, partido_id);

CREATE INDEX idx_historial_enfrentamientos_par
  ON analitica.historial_enfrentamientos
  (tenant_id, equipo_a_id, equipo_b_id, inicio_programado DESC);

