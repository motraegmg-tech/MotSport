-- ─────────────────────────────────────────────────────────────
-- MotSport · Semilla de catalogos · desarrollo local
--
-- Solo catalogos. Aqui NO entran partidos, equipos ni jugadores:
-- esos llegan por ingesta, con su procedencia.
--
-- Los ejemplos de eventos de docs/motsport/07_MODELO_DE_DATOS.md
-- seccion 5.5 quedaron fuera a proposito: referencian partidos,
-- equipos y jugadores que nadie inserta, y aplicarlos reventaria
-- por llave foranea. Sirven para leer, no para sembrar.
--
-- El inquilino se crea aqui y no esta en el documento porque el
-- documento describe el esquema, no la operacion. Todo lo demas
-- cuelga de este tenant_id.
-- ─────────────────────────────────────────────────────────────

INSERT INTO public.inquilinos (tenant_id, clave, nombre, zona_horaria)
VALUES (
  '00000000-0000-0000-0000-000000000001',
  'motrae',
  'MOTRAE',
  'America/Mexico_City'
)
ON CONFLICT (tenant_id) DO NOTHING;

INSERT INTO public.fuentes (
  tenant_id, clave, nombre, clase, url_base, licencia,
  permite_uso_comercial, permite_redistribucion,
  confianza_maxima, vigente_desde
) VALUES
  ('00000000-0000-0000-0000-000000000001', 'motrae_manual',
   'Captura revisada por MOTRAE', 'manual', NULL, 'Dato interno',
   false, false, 75, DATE '2026-09-01'),
  ('00000000-0000-0000-0000-000000000001', 'motrae_derivada',
   'Cálculo reproducible de MOTRAE', 'derivada', NULL, 'Dato interno',
   false, false, 75, DATE '2026-09-01'),
  ('00000000-0000-0000-0000-000000000001', 'api_football',
   'API-Football', 'proveedor_estructurado', 'https://www.api-football.com/',
   'Nivel gratuito; revisar antes de Fase 3', false, false, 75, DATE '2026-09-01'),
  ('00000000-0000-0000-0000-000000000001', 'statsbomb_abierto',
   'StatsBomb Open Data', 'repositorio_abierto',
   'https://github.com/statsbomb/open-data',
   'Uso no comercial con atribución', false, false, 75, DATE '2026-09-01'),
  ('00000000-0000-0000-0000-000000000001', 'balldontlie',
   'balldontlie', 'proveedor_estructurado', 'https://www.balldontlie.io/',
   'Nivel gratuito; revisar antes de Fase 3', false, false, 75, DATE '2026-09-01'),
  ('00000000-0000-0000-0000-000000000001', 'nflverse',
   'nflverse', 'repositorio_abierto', 'https://nflverse.nflverse.com/',
   'Licencia y origen pendientes de verificar antes de usar',
   false, false, 50, DATE '2026-09-01'),
  ('00000000-0000-0000-0000-000000000001', 'open_meteo',
   'Open-Meteo', 'proveedor_estructurado', 'https://open-meteo.com/',
   'Nivel gratuito solo para uso no comercial', false, false, 75, DATE '2026-09-01');

INSERT INTO public.deportes (
  tenant_id, deporte_id, clave, nombre, version,
  duracion_reglamentaria_segundos, periodos_reglamentarios,
  esquema_dimensiones_sede, configuracion,
  vigente_desde, fuente, obtenido_ts, confianza
) VALUES
  ('00000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000001',
   'futbol', 'Fútbol', 1, 5400, 2,
   '{"type":"object","required":["largo_m","ancho_m"],"properties":{"largo_m":{"type":"number"},"ancho_m":{"type":"number"}},"additionalProperties":false}',
   '{"reloj":"ascendente","admite_empate":true}',
   DATE '2026-09-01', 'motrae_manual', TIMESTAMPTZ '2026-09-01 12:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000002',
   'basquetbol', 'Basquetbol', 1, 2880, 4,
   '{"type":"object","required":["largo_m","ancho_m"],"properties":{"largo_m":{"type":"number"},"ancho_m":{"type":"number"}},"additionalProperties":false}',
   '{"reloj":"descendente","admite_empate":false,"duracion_periodo_segundos":720}',
   DATE '2026-09-01', 'motrae_manual', TIMESTAMPTZ '2026-09-01 12:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000003',
   'futbol_americano', 'Fútbol americano', 1, 3600, 4,
   '{"type":"object","required":["largo_yardas","ancho_yardas"],"properties":{"largo_yardas":{"type":"number"},"ancho_yardas":{"type":"number"}},"additionalProperties":false}',
   '{"reloj":"descendente","admite_empate":true,"intentos_por_serie":4}',
   DATE '2026-09-01', 'motrae_manual', TIMESTAMPTZ '2026-09-01 12:00:00+00', 75);

INSERT INTO public.catalogo_metricas (
  tenant_id, metrica_id, deporte_id, clave, nombre, definicion, unidad,
  formula, tipo_entidad, direccion_favorable, agregacion, version,
  vigente_desde, fuente_predeterminada, fuente, obtenido_ts, confianza
) VALUES
  ('00000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000001',
   '10000000-0000-0000-0000-000000000001',
   'xg', 'Goles esperados', 'Calidad acumulada de las ocasiones', 'goles',
   'Suma de probabilidades de gol de los tiros', 'jugador', 'alta', 'suma', 1,
   DATE '2026-09-01', 'statsbomb_abierto', 'motrae_manual',
   TIMESTAMPTZ '2026-09-01 12:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000002',
   '10000000-0000-0000-0000-000000000002',
   'ritmo_48', 'Ritmo por 48 minutos', 'Posesiones estimadas por 48 minutos',
   'posesiones', 'Normalización de posesiones a 48 minutos',
   'equipo', 'depende', 'formula', 1,
   DATE '2026-09-01', 'balldontlie', 'motrae_manual',
   TIMESTAMPTZ '2026-09-01 12:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001',
   '20000000-0000-0000-0000-000000000003',
   '10000000-0000-0000-0000-000000000003',
   'epa_por_jugada', 'Puntos esperados agregados por jugada',
   'Cambio medio de puntos esperados provocado por una jugada',
   'puntos por jugada', 'Promedio de EPA de las jugadas válidas',
   'jugador', 'alta', 'promedio', 1,
   DATE '2026-09-01', 'nflverse', 'motrae_manual',
   TIMESTAMPTZ '2026-09-01 12:00:00+00', 50);

INSERT INTO public.catalogo_factores (
  tenant_id, factor_id, clave, familia, deportes, nombre, definicion,
  unidad, tipo_valor, fuente_predeterminada, direccion_favorable,
  version, vigente_desde, fuente, obtenido_ts, confianza
) VALUES
  ('00000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000001',
   'viento_velocidad', 'ambiente', ARRAY[]::text[], 'Velocidad del viento',
   'Velocidad media prevista durante el partido', 'km/h', 'numero',
   'open_meteo', 'depende', 1, DATE '2026-09-01', 'motrae_manual',
   TIMESTAMPTZ '2026-09-01 12:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000002',
   'partidos_dias_consecutivos', 'carga', ARRAY['basquetbol'], 'Partidos consecutivos',
   'Indica si el equipo jugó el día anterior', 'booleano', 'booleano',
   'motrae_derivada', 'baja', 1, DATE '2026-09-01', 'motrae_manual',
   TIMESTAMPTZ '2026-09-01 12:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001',
   '30000000-0000-0000-0000-000000000003',
   'altitud_sede', 'ambiente', ARRAY[]::text[], 'Altitud de la sede',
   'Elevación del recinto sobre el nivel medio del mar', 'm', 'numero',
   'motrae_manual', 'depende', 1, DATE '2026-09-01', 'motrae_manual',
   TIMESTAMPTZ '2026-09-01 12:00:00+00', 75);

INSERT INTO public.catalogo_periodos (
  tenant_id, deporte_id, clave, nombre, orden, reglamentario,
  fuente, obtenido_ts, confianza
) VALUES
  -- Futbol
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'primer_tiempo',  'Primer tiempo',        1, true,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'segundo_tiempo', 'Segundo tiempo',       2, true,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'prorroga_1',     'Prórroga · primer tiempo',  3, false,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'prorroga_2',     'Prórroga · segundo tiempo', 4, false,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001',
   'penales',        'Tanda de penales',     5, false,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),

  -- NBA
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002',
   'cuarto_1', 'Primer cuarto',  1, true,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002',
   'cuarto_2', 'Segundo cuarto', 2, true,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002',
   'cuarto_3', 'Tercer cuarto',  3, true,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002',
   'cuarto_4', 'Cuarto cuarto',  4, true,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000002',
   'prorroga_1', 'Prórroga 1',   5, false,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),

  -- NFL
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003',
   'cuarto_1', 'Primer cuarto',  1, true,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003',
   'cuarto_2', 'Segundo cuarto', 2, true,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003',
   'cuarto_3', 'Tercer cuarto',  3, true,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003',
   'cuarto_4', 'Cuarto cuarto',  4, true,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75),
  ('00000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003',
   'prorroga_1', 'Tiempo extra', 5, false,
   'motrae_manual', TIMESTAMPTZ '2026-09-08 00:00:00+00', 75);
