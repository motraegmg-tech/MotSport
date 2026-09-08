-- ─────────────────────────────────────────────────────────────
-- MotSport · Esquema inicial · 40 tablas
--
-- Fuente de verdad legible: docs/motsport/07_MODELO_DE_DATOS.md
-- Este archivo es esa misma definicion, reordenada para que APLIQUE.
--
-- Por que cambia el orden respecto al documento: el documento
-- presenta las entidades (seccion 3) antes que los catalogos
-- (seccion 4) porque asi se entiende mejor, pero las entidades
-- referencian catalogos. El orden de aqui se derivo de las propias
-- llaves foraneas, no a mano.
--
-- Dos reglas que explican colocaciones que de otro modo extrañan:
--   · Las funciones plpgsql van arriba: Postgres no valida su cuerpo
--     al crearlas, asi que pueden nacer antes que sus tablas.
--   · prioridad_de_fuente y dato_dentro_de_vigencia van abajo: son
--     LANGUAGE sql, su cuerpo SI se valida al crearlas, y consultan
--     clases_dato y preferencias_fuente.
--
-- La RLS NO esta aqui: vive en 20260908000200_rls_lectura_aislada.sql
-- para poder auditarla de una sentada.
-- ─────────────────────────────────────────────────────────────

CREATE SCHEMA IF NOT EXISTS extensions;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE EXTENSION IF NOT EXISTS pg_jsonschema WITH SCHEMA extensions;

CREATE DOMAIN public.nivel_confianza AS smallint
  CHECK (VALUE IN (0, 25, 50, 75, 100));

CREATE OR REPLACE FUNCTION public.tenant_actual()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT NULLIF(
    COALESCE(
      auth.jwt() ->> 'tenant_id',
      auth.jwt() -> 'app_metadata' ->> 'tenant_id'
    ),
    ''
  )::uuid;
$$;

CREATE OR REPLACE FUNCTION public.validar_dimensiones_sede()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  esquema jsonb;
BEGIN
  SELECT d.esquema_dimensiones_sede
    INTO esquema
  FROM public.deportes AS d
  WHERE d.tenant_id = NEW.tenant_id
    AND d.deporte_id = NEW.deporte_id;

  IF esquema IS NULL
     OR NOT extensions.jsonschema_valid(esquema, NEW.dimensiones) THEN
    RAISE EXCEPTION 'Las dimensiones no cumplen el esquema del deporte';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validar_identificador_externo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  existe boolean;
BEGIN
  CASE NEW.tipo_entidad
    WHEN 'competencia' THEN
      SELECT EXISTS (
        SELECT 1 FROM public.competencias
        WHERE tenant_id = NEW.tenant_id
          AND competencia_id = NEW.entidad_id
      ) INTO existe;
    WHEN 'temporada' THEN
      SELECT EXISTS (
        SELECT 1 FROM public.temporadas
        WHERE tenant_id = NEW.tenant_id
          AND temporada_id = NEW.entidad_id
      ) INTO existe;
    WHEN 'sede' THEN
      SELECT EXISTS (
        SELECT 1 FROM public.sedes
        WHERE tenant_id = NEW.tenant_id
          AND sede_id = NEW.entidad_id
      ) INTO existe;
    WHEN 'equipo' THEN
      SELECT EXISTS (
        SELECT 1 FROM public.equipos
        WHERE tenant_id = NEW.tenant_id
          AND equipo_id = NEW.entidad_id
      ) INTO existe;
    WHEN 'jugador' THEN
      SELECT EXISTS (
        SELECT 1 FROM public.jugadores
        WHERE tenant_id = NEW.tenant_id
          AND jugador_id = NEW.entidad_id
      ) INTO existe;
    WHEN 'partido' THEN
      SELECT EXISTS (
        SELECT 1 FROM public.partidos
        WHERE tenant_id = NEW.tenant_id
          AND partido_id = NEW.entidad_id
      ) INTO existe;
  END CASE;

  IF NOT existe THEN
    RAISE EXCEPTION 'La entidad externa no existe dentro del tenant';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validar_evento_por_esquema()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  esquema jsonb;
BEGIN
  SELECT ee.esquema
    INTO esquema
  FROM public.esquemas_evento AS ee
  JOIN public.tipos_evento AS te
    ON te.tenant_id = ee.tenant_id
   AND te.tipo_evento_id = ee.tipo_evento_id
  JOIN public.partidos AS p
    ON p.tenant_id = NEW.tenant_id
   AND p.partido_id = NEW.partido_id
  WHERE ee.tenant_id = NEW.tenant_id
    AND ee.esquema_evento_id = NEW.esquema_evento_id
    AND ee.tipo_evento_id = NEW.tipo_evento_id
    AND te.deporte_id = NEW.deporte_id
    AND p.deporte_id = NEW.deporte_id
    AND ee.activo;

  IF esquema IS NULL THEN
    RAISE EXCEPTION 'No existe un esquema activo para el tipo y deporte del evento';
  END IF;

  IF NOT extensions.jsonschema_valid(esquema, NEW.carga) THEN
    RAISE EXCEPTION 'La carga del evento no cumple el esquema versionado';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validar_valor_metrica()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  deporte_metrica uuid;
  entidad_catalogo text;
  deporte_competencia uuid;
  competencia_temporada uuid;
  deporte_entidad uuid;
  deporte_posicion uuid;
  temporada_jornada uuid;
BEGIN
  SELECT cm.deporte_id, cm.tipo_entidad
    INTO deporte_metrica, entidad_catalogo
  FROM public.catalogo_metricas AS cm
  WHERE cm.tenant_id = NEW.tenant_id
    AND cm.metrica_id = NEW.metrica_id;

  SELECT c.deporte_id
    INTO deporte_competencia
  FROM public.competencias AS c
  WHERE c.tenant_id = NEW.tenant_id
    AND c.competencia_id = NEW.competencia_id;

  SELECT t.competencia_id
    INTO competencia_temporada
  FROM public.temporadas AS t
  WHERE t.tenant_id = NEW.tenant_id
    AND t.temporada_id = NEW.temporada_id;

  IF entidad_catalogo IS DISTINCT FROM NEW.tipo_entidad
     OR deporte_metrica IS DISTINCT FROM deporte_competencia
     OR competencia_temporada IS DISTINCT FROM NEW.competencia_id THEN
    RAISE EXCEPTION 'La métrica, entidad, competencia y temporada no son compatibles';
  END IF;

  IF NEW.tipo_entidad = 'jugador' THEN
    SELECT j.deporte_id INTO deporte_entidad
    FROM public.jugadores AS j
    WHERE j.tenant_id = NEW.tenant_id AND j.jugador_id = NEW.jugador_id;
  ELSIF NEW.tipo_entidad = 'equipo' THEN
    SELECT e.deporte_id INTO deporte_entidad
    FROM public.equipos AS e
    WHERE e.tenant_id = NEW.tenant_id AND e.equipo_id = NEW.equipo_id;
  ELSE
    SELECT p.deporte_id INTO deporte_entidad
    FROM public.partidos AS p
    WHERE p.tenant_id = NEW.tenant_id AND p.partido_id = NEW.partido_id;
  END IF;

  IF deporte_entidad IS DISTINCT FROM deporte_metrica THEN
    RAISE EXCEPTION 'La entidad no pertenece al deporte de la métrica';
  END IF;

  IF NEW.posicion_id IS NOT NULL THEN
    SELECT p.deporte_id INTO deporte_posicion
    FROM public.posiciones AS p
    WHERE p.tenant_id = NEW.tenant_id AND p.posicion_id = NEW.posicion_id;
    IF deporte_posicion IS DISTINCT FROM deporte_metrica THEN
      RAISE EXCEPTION 'La posición no pertenece al deporte de la métrica';
    END IF;
  END IF;

  IF NEW.jornada_id IS NOT NULL THEN
    SELECT j.temporada_id INTO temporada_jornada
    FROM public.jornadas AS j
    WHERE j.tenant_id = NEW.tenant_id AND j.jornada_id = NEW.jornada_id;
    IF temporada_jornada IS DISTINCT FROM NEW.temporada_id THEN
      RAISE EXCEPTION 'La jornada no pertenece a la temporada de la métrica';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.validar_factor_partido()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
DECLARE
  tipo_catalogo text;
  deportes_catalogo text[];
  deporte_partido text;
BEGIN
  SELECT cf.tipo_valor, cf.deportes, d.clave
    INTO tipo_catalogo, deportes_catalogo, deporte_partido
  FROM public.catalogo_factores AS cf
  JOIN public.partidos AS p
    ON p.tenant_id = NEW.tenant_id
   AND p.partido_id = NEW.partido_id
  JOIN public.deportes AS d
    ON d.tenant_id = p.tenant_id
   AND d.deporte_id = p.deporte_id
  WHERE cf.tenant_id = NEW.tenant_id
    AND cf.factor_id = NEW.factor_id;

  IF tipo_catalogo IS NULL THEN
    RAISE EXCEPTION 'No existe el factor o el partido dentro del tenant';
  END IF;
  IF cardinality(deportes_catalogo) > 0
     AND NOT deporte_partido = ANY (deportes_catalogo) THEN
    RAISE EXCEPTION 'El factor no aplica al deporte del partido';
  END IF;
  IF tipo_catalogo = 'numero'
     AND (jsonb_typeof(NEW.valor) <> 'number' OR NEW.valor_numero IS NULL) THEN
    RAISE EXCEPTION 'Un factor numérico requiere valor JSON numérico y valor_numero';
  END IF;
  IF tipo_catalogo = 'booleano' AND jsonb_typeof(NEW.valor) <> 'boolean' THEN
    RAISE EXCEPTION 'Un factor booleano requiere valor JSON booleano';
  END IF;
  IF tipo_catalogo = 'texto' AND jsonb_typeof(NEW.valor) <> 'string' THEN
    RAISE EXCEPTION 'Un factor de texto requiere valor JSON de texto';
  END IF;
  IF tipo_catalogo = 'objeto' AND jsonb_typeof(NEW.valor) <> 'object' THEN
    RAISE EXCEPTION 'Un factor de objeto requiere valor JSON de objeto';
  END IF;
  IF tipo_catalogo = 'arreglo' AND jsonb_typeof(NEW.valor) <> 'array' THEN
    RAISE EXCEPTION 'Un factor de arreglo requiere valor JSON de arreglo';
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.impedir_cambio_de_observacion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $$
BEGIN
  RAISE EXCEPTION 'Las observaciones son inmutables; inserte una nueva versión';
END;
$$;

CREATE TABLE public.inquilinos (
  tenant_id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
  clave text NOT NULL UNIQUE,
  nombre text NOT NULL,
  zona_horaria text NOT NULL DEFAULT 'America/Mexico_City',
  activo boolean NOT NULL DEFAULT true,
  creado_ts timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT inquilinos_clave_formato
    CHECK (clave ~ '^[a-z0-9_]+$')
);

COMMENT ON TABLE public.inquilinos IS
  'Fija la frontera de aislamiento sin adelantar funciones de venta.';

CREATE TABLE public.clases_dato (
  tenant_id uuid NOT NULL,
  clase_dato_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  clave text NOT NULL,
  nombre text NOT NULL,
  descripcion text NOT NULL,
  antiguedad_maxima interval,
  PRIMARY KEY (tenant_id, clase_dato_id),
  UNIQUE (tenant_id, clave),
  FOREIGN KEY (tenant_id)
    REFERENCES public.inquilinos (tenant_id),
  CONSTRAINT clases_dato_antiguedad_valida
    CHECK (antiguedad_maxima IS NULL OR antiguedad_maxima > interval '0 seconds')
);

COMMENT ON TABLE public.clases_dato IS
  'Permite que calendario, resultado o lesión tengan caducidades distintas.';

CREATE TABLE public.fuentes (
  tenant_id uuid NOT NULL,
  clave text NOT NULL,
  nombre text NOT NULL,
  clase text NOT NULL,
  url_base text,
  licencia text NOT NULL,
  permite_uso_comercial boolean NOT NULL,
  permite_redistribucion boolean NOT NULL,
  confianza_maxima public.nivel_confianza NOT NULL,
  activo boolean NOT NULL DEFAULT true,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  PRIMARY KEY (tenant_id, clave),
  FOREIGN KEY (tenant_id)
    REFERENCES public.inquilinos (tenant_id),
  CONSTRAINT fuentes_clave_formato CHECK (clave ~ '^[a-z0-9_]+$'),
  CONSTRAINT fuentes_clase_valida
    CHECK (clase IN (
      'oficial', 'proveedor_estructurado', 'repositorio_abierto',
      'busqueda_web', 'manual', 'derivada'
    )),
  CONSTRAINT fuentes_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde)
);

COMMENT ON TABLE public.fuentes IS
  'Hace sustituible cada proveedor y conserva las restricciones de licencia.';

CREATE TABLE public.niveles_confianza (
  tenant_id uuid NOT NULL,
  valor public.nivel_confianza NOT NULL,
  nombre text NOT NULL,
  significado text NOT NULL,
  elegible_resolucion boolean NOT NULL,
  PRIMARY KEY (tenant_id, valor),
  FOREIGN KEY (tenant_id)
    REFERENCES public.inquilinos (tenant_id)
);

COMMENT ON TABLE public.niveles_confianza IS
  'Evita que alta, media y baja dependan de la interpretación de cada conector.';

CREATE TABLE public.organizaciones (
  tenant_id uuid NOT NULL,
  organizacion_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  clave text NOT NULL,
  nombre text NOT NULL,
  activo boolean NOT NULL DEFAULT true,
  creado_ts timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, organizacion_id),
  UNIQUE (tenant_id, clave),
  FOREIGN KEY (tenant_id)
    REFERENCES public.inquilinos (tenant_id)
);

COMMENT ON TABLE public.organizaciones IS
  'Separa la propiedad de los datos de la identidad deportiva observada.';

CREATE TABLE public.catalogo_factores (
  tenant_id uuid NOT NULL,
  factor_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  clave text NOT NULL,
  familia text NOT NULL,
  deportes text[] NOT NULL DEFAULT ARRAY[]::text[],
  nombre text NOT NULL,
  definicion text NOT NULL,
  unidad text NOT NULL,
  tipo_valor text NOT NULL,
  fuente_predeterminada text,
  direccion_favorable text NOT NULL,
  version integer NOT NULL,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, factor_id),
  UNIQUE (tenant_id, clave, version),
  FOREIGN KEY (tenant_id, fuente_predeterminada)
    REFERENCES public.fuentes (tenant_id, clave),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT catalogo_factores_familia_valida
    CHECK (familia IN (
      'ambiente', 'disponibilidad', 'carga', 'forma',
      'contexto', 'estilo', 'mercado'
    )),
  CONSTRAINT catalogo_factores_tipo_valido
    CHECK (tipo_valor IN ('numero', 'booleano', 'texto', 'objeto', 'arreglo')),
  CONSTRAINT catalogo_factores_direccion_valida
    CHECK (direccion_favorable IN ('alta', 'baja', 'depende')),
  CONSTRAINT catalogo_factores_version_positiva CHECK (version > 0),
  CONSTRAINT catalogo_factores_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
  CONSTRAINT catalogo_factores_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.catalogo_factores IS
  'Permite ampliar el contexto sin desplegar una nueva columna o constante.';

CREATE TABLE public.catalogo_parametros (
  tenant_id uuid NOT NULL,
  parametro_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  clave text NOT NULL,
  nombre text NOT NULL,
  definicion text NOT NULL,
  tipo_valor text NOT NULL,
  unidad text NOT NULL,
  version integer NOT NULL,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  PRIMARY KEY (tenant_id, parametro_id),
  UNIQUE (tenant_id, clave, version),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT catalogo_parametros_tipo_valido
    CHECK (tipo_valor IN ('numero', 'booleano', 'texto', 'objeto')),
  CONSTRAINT catalogo_parametros_version_positiva CHECK (version > 0),
  CONSTRAINT catalogo_parametros_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde)
);

COMMENT ON TABLE public.catalogo_parametros IS
  'Evita que decisiones ajustables del dominio se conviertan en constantes.';

CREATE TABLE public.catalogo_superficies (
  tenant_id uuid NOT NULL,
  clave text NOT NULL,
  nombre text NOT NULL,
  descripcion text NOT NULL,
  activo boolean NOT NULL DEFAULT true,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  PRIMARY KEY (tenant_id, clave),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave)
);

COMMENT ON TABLE public.catalogo_superficies IS
  'Evita codificar como columnas las superficies propias de cada deporte.';

CREATE TABLE public.catalogo_techos (
  tenant_id uuid NOT NULL,
  clave text NOT NULL,
  nombre text NOT NULL,
  descripcion text NOT NULL,
  activo boolean NOT NULL DEFAULT true,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  PRIMARY KEY (tenant_id, clave),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave)
);

COMMENT ON TABLE public.catalogo_techos IS
  'Permite describir recintos nuevos sin cambiar el esquema.';

CREATE TABLE public.deportes (
  tenant_id uuid NOT NULL,
  deporte_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  clave text NOT NULL,
  nombre text NOT NULL,
  version integer NOT NULL,
  duracion_reglamentaria_segundos integer,
  periodos_reglamentarios smallint,
  esquema_dimensiones_sede jsonb NOT NULL,
  configuracion jsonb NOT NULL DEFAULT '{}'::jsonb,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, deporte_id),
  UNIQUE (tenant_id, clave, version),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT deportes_clave_formato CHECK (clave ~ '^[a-z0-9_]+$'),
  CONSTRAINT deportes_version_positiva CHECK (version > 0),
  CONSTRAINT deportes_duracion_positiva
    CHECK (
      duracion_reglamentaria_segundos IS NULL
      OR duracion_reglamentaria_segundos > 0
    ),
  CONSTRAINT deportes_periodos_positivos
    CHECK (periodos_reglamentarios IS NULL OR periodos_reglamentarios > 0),
  CONSTRAINT deportes_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
  CONSTRAINT deportes_esquema_dimensiones_objeto
    CHECK (jsonb_typeof(esquema_dimensiones_sede) = 'object'),
  CONSTRAINT deportes_configuracion_objeto
    CHECK (jsonb_typeof(configuracion) = 'object'),
  CONSTRAINT deportes_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.deportes IS
  'Convierte la incorporación de un deporte en carga de configuración.';

CREATE TABLE public.identificadores_externos (
  tenant_id uuid NOT NULL,
  identificador_externo_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  tipo_entidad text NOT NULL,
  entidad_id uuid NOT NULL,
  identificador text NOT NULL,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, identificador_externo_id),
  UNIQUE (tenant_id, fuente, tipo_entidad, identificador),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT identificadores_externos_tipo_valido
    CHECK (tipo_entidad IN (
      'competencia', 'temporada', 'sede', 'equipo', 'jugador', 'partido'
    )),
  CONSTRAINT identificadores_externos_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.identificadores_externos IS
  'Evita duplicados al cambiar o combinar proveedores.';

CREATE TRIGGER comprobar_identificador_externo
BEFORE INSERT OR UPDATE ON public.identificadores_externos
FOR EACH ROW EXECUTE FUNCTION public.validar_identificador_externo();

CREATE INDEX idx_identificadores_entidad
  ON public.identificadores_externos
  (tenant_id, tipo_entidad, entidad_id, fuente);

CREATE TABLE public.sedes (
  tenant_id uuid NOT NULL,
  sede_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  creado_ts timestamptz NOT NULL DEFAULT now(),
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, sede_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT sedes_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.sedes IS
  'Da una identidad estable al recinto mientras sus atributos conservan versiones.';

CREATE TABLE public.usuarios (
  tenant_id uuid NOT NULL,
  usuario_id uuid NOT NULL,
  organizacion_id uuid NOT NULL,
  nombre_visible text NOT NULL,
  activo boolean NOT NULL DEFAULT true,
  creado_ts timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, usuario_id),
  FOREIGN KEY (usuario_id)
    REFERENCES auth.users (id),
  FOREIGN KEY (tenant_id, organizacion_id)
    REFERENCES public.organizaciones (tenant_id, organizacion_id)
);

COMMENT ON TABLE public.usuarios IS
  'Vincula autenticación e aislamiento sin duplicar credenciales.';

CREATE TABLE public.catalogo_metricas (
  tenant_id uuid NOT NULL,
  metrica_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  deporte_id uuid NOT NULL,
  clave text NOT NULL,
  nombre text NOT NULL,
  definicion text NOT NULL,
  unidad text NOT NULL,
  formula text,
  tipo_entidad text NOT NULL,
  direccion_favorable text NOT NULL,
  agregacion text NOT NULL,
  version integer NOT NULL,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente_predeterminada text,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, metrica_id),
  UNIQUE (tenant_id, deporte_id, clave, version),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  FOREIGN KEY (tenant_id, fuente_predeterminada)
    REFERENCES public.fuentes (tenant_id, clave),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT catalogo_metricas_entidad_valida
    CHECK (tipo_entidad IN ('jugador', 'equipo', 'partido')),
  CONSTRAINT catalogo_metricas_direccion_valida
    CHECK (direccion_favorable IN ('alta', 'baja', 'depende')),
  CONSTRAINT catalogo_metricas_agregacion_valida
    CHECK (agregacion IN ('suma', 'promedio', 'tasa', 'ultimo', 'formula')),
  CONSTRAINT catalogo_metricas_version_positiva CHECK (version > 0),
  CONSTRAINT catalogo_metricas_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
  CONSTRAINT catalogo_metricas_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.catalogo_metricas IS
  'Evita que el vocabulario de un deporte determine las columnas del núcleo.';

CREATE TABLE public.catalogo_periodos (
  tenant_id uuid NOT NULL,
  deporte_id uuid NOT NULL,
  clave text NOT NULL,
  nombre text NOT NULL,
  orden smallint NOT NULL,
  -- Distingue el tiempo regular de prorroga y penales: solo lo reglamentario
  -- alimenta rating y forma reciente, igual que en participantes_partido.
  reglamentario boolean NOT NULL,
  activo boolean NOT NULL DEFAULT true,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  PRIMARY KEY (tenant_id, deporte_id, clave),
  UNIQUE (tenant_id, deporte_id, orden),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT catalogo_periodos_orden_positivo CHECK (orden > 0)
);

COMMENT ON TABLE public.catalogo_periodos IS
  'Impide que cada conector invente su propio vocabulario de periodos.';

COMMENT ON COLUMN public.catalogo_periodos.orden IS
  'Ordena cronologicamente dentro del deporte; permite agrupar sin conocer las claves.';

CREATE TABLE public.competencias (
  tenant_id uuid NOT NULL,
  competencia_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  deporte_id uuid NOT NULL,
  organizacion_id uuid,
  clave text NOT NULL,
  nombre text NOT NULL,
  pais_codigo char(2),
  nivel smallint,
  activo boolean NOT NULL DEFAULT true,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, competencia_id),
  UNIQUE (tenant_id, competencia_id, deporte_id),
  UNIQUE (tenant_id, deporte_id, clave),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  FOREIGN KEY (tenant_id, organizacion_id)
    REFERENCES public.organizaciones (tenant_id, organizacion_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT competencias_nivel_positivo
    CHECK (nivel IS NULL OR nivel > 0),
  CONSTRAINT competencias_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.competencias IS
  'Da contexto competitivo común a calendarios y comparaciones.';

CREATE TABLE public.equipos (
  tenant_id uuid NOT NULL,
  equipo_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  deporte_id uuid NOT NULL,
  organizacion_id uuid,
  creado_ts timestamptz NOT NULL DEFAULT now(),
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, equipo_id),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  FOREIGN KEY (tenant_id, organizacion_id)
    REFERENCES public.organizaciones (tenant_id, organizacion_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT equipos_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.equipos IS
  'Evita que un cambio de nombre o proveedor cambie la identidad histórica.';

CREATE TABLE public.jugadores (
  tenant_id uuid NOT NULL,
  jugador_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  deporte_id uuid NOT NULL,
  creado_ts timestamptz NOT NULL DEFAULT now(),
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, jugador_id),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT jugadores_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.jugadores IS
  'Mantiene una identidad canónica aun cuando las fuentes discrepan en el perfil.';

CREATE TABLE public.observaciones_sede (
  tenant_id uuid NOT NULL,
  observacion_sede_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  sede_id uuid NOT NULL,
  deporte_id uuid NOT NULL,
  nombre text NOT NULL,
  ciudad text NOT NULL,
  subdivision text,
  pais_codigo char(2) NOT NULL,
  latitud numeric(9,6) NOT NULL,
  longitud numeric(9,6) NOT NULL,
  zona_horaria text NOT NULL,
  altitud_m numeric(8,2),
  techo_clave text NOT NULL,
  superficie_clave text,
  dimensiones jsonb NOT NULL DEFAULT '{}'::jsonb,
  capacidad integer,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, observacion_sede_id),
  FOREIGN KEY (tenant_id, sede_id)
    REFERENCES public.sedes (tenant_id, sede_id),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  FOREIGN KEY (tenant_id, techo_clave)
    REFERENCES public.catalogo_techos (tenant_id, clave),
  FOREIGN KEY (tenant_id, superficie_clave)
    REFERENCES public.catalogo_superficies (tenant_id, clave),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT observaciones_sede_latitud_valida
    CHECK (latitud BETWEEN -90 AND 90),
  CONSTRAINT observaciones_sede_longitud_valida
    CHECK (longitud BETWEEN -180 AND 180),
  CONSTRAINT observaciones_sede_altitud_valida
    CHECK (altitud_m IS NULL OR altitud_m BETWEEN -500 AND 9000),
  CONSTRAINT observaciones_sede_capacidad_valida
    CHECK (capacidad IS NULL OR capacidad >= 0),
  CONSTRAINT observaciones_sede_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
  CONSTRAINT observaciones_sede_dimensiones_objeto
    CHECK (jsonb_typeof(dimensiones) = 'object'),
  CONSTRAINT observaciones_sede_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.observaciones_sede IS
  'Preserva por fuente las condiciones físicas que alteran el contexto del partido.';

CREATE TRIGGER comprobar_dimensiones_sede
BEFORE INSERT OR UPDATE OF deporte_id, dimensiones
ON public.observaciones_sede
FOR EACH ROW EXECUTE FUNCTION public.validar_dimensiones_sede();

CREATE TRIGGER preservar_observaciones_sede
BEFORE UPDATE OR DELETE ON public.observaciones_sede
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE TABLE public.posiciones (
  tenant_id uuid NOT NULL,
  posicion_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  deporte_id uuid NOT NULL,
  clave text NOT NULL,
  nombre text NOT NULL,
  grupo_comparacion text NOT NULL,
  version integer NOT NULL,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, posicion_id),
  UNIQUE (tenant_id, deporte_id, clave, version),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT posiciones_version_positiva CHECK (version > 0),
  CONSTRAINT posiciones_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
  CONSTRAINT posiciones_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.posiciones IS
  'Define grupos estadísticos coherentes para cada deporte.';

CREATE TABLE public.tipos_evento (
  tenant_id uuid NOT NULL,
  tipo_evento_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  deporte_id uuid NOT NULL,
  clave text NOT NULL,
  nombre text NOT NULL,
  version integer NOT NULL,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  PRIMARY KEY (tenant_id, tipo_evento_id),
  UNIQUE (tenant_id, deporte_id, clave, version),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT tipos_evento_version_positiva CHECK (version > 0),
  CONSTRAINT tipos_evento_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde)
);

COMMENT ON TABLE public.tipos_evento IS
  'Permite incorporar vocabulario de eventos sin crear tablas por deporte.';

CREATE TABLE public.accesos_equipo (
  tenant_id uuid NOT NULL,
  usuario_id uuid NOT NULL,
  equipo_id uuid NOT NULL,
  creado_ts timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, usuario_id, equipo_id),
  FOREIGN KEY (tenant_id, usuario_id)
    REFERENCES public.usuarios (tenant_id, usuario_id),
  FOREIGN KEY (tenant_id, equipo_id)
    REFERENCES public.equipos (tenant_id, equipo_id)
);

COMMENT ON TABLE public.accesos_equipo IS
  'Deja preparada la autorización por equipo sin construir roles comerciales.';

CREATE TABLE public.disponibilidades_jugador (
  tenant_id uuid NOT NULL,
  disponibilidad_jugador_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  jugador_id uuid NOT NULL,
  equipo_id uuid,
  tipo text NOT NULL,
  estado text NOT NULL,
  inicio date NOT NULL,
  fin_estimada date,
  fin_real date,
  detalle jsonb NOT NULL DEFAULT '{}'::jsonb,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, disponibilidad_jugador_id),
  FOREIGN KEY (tenant_id, jugador_id)
    REFERENCES public.jugadores (tenant_id, jugador_id),
  FOREIGN KEY (tenant_id, equipo_id)
    REFERENCES public.equipos (tenant_id, equipo_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT disponibilidades_jugador_tipo_valido
    CHECK (tipo IN (
      'lesion', 'sancion', 'seleccion', 'decision_tecnica', 'personal', 'otra'
    )),
  CONSTRAINT disponibilidades_jugador_estado_valido
    CHECK (estado IN ('disponible', 'duda', 'no_disponible', 'reintegrado')),
  CONSTRAINT disponibilidades_jugador_fechas_validas
    CHECK (
      (fin_estimada IS NULL OR fin_estimada >= inicio)
      AND (fin_real IS NULL OR fin_real >= inicio)
    ),
  CONSTRAINT disponibilidades_jugador_detalle_objeto
    CHECK (jsonb_typeof(detalle) = 'object'),
  CONSTRAINT disponibilidades_jugador_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.disponibilidades_jugador IS
  'Permite reconstruir qué se sabía sobre una ausencia en cada fecha.';

CREATE TRIGGER preservar_disponibilidades_jugador
BEFORE UPDATE OR DELETE ON public.disponibilidades_jugador
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE INDEX idx_disponibilidades_periodo
  ON public.disponibilidades_jugador
  (tenant_id, equipo_id, inicio, fin_estimada, estado);

CREATE TABLE public.esquemas_evento (
  tenant_id uuid NOT NULL,
  esquema_evento_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  tipo_evento_id uuid NOT NULL,
  version integer NOT NULL,
  esquema jsonb NOT NULL,
  activo boolean NOT NULL DEFAULT true,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  PRIMARY KEY (tenant_id, esquema_evento_id),
  UNIQUE (tenant_id, tipo_evento_id, version),
  FOREIGN KEY (tenant_id, tipo_evento_id)
    REFERENCES public.tipos_evento (tenant_id, tipo_evento_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT esquemas_evento_version_positiva CHECK (version > 0),
  CONSTRAINT esquemas_evento_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
  CONSTRAINT esquemas_evento_objeto CHECK (jsonb_typeof(esquema) = 'object')
);

COMMENT ON TABLE public.esquemas_evento IS
  'Valida cargas flexibles en la base y conserva la regla usada históricamente.';

CREATE TABLE public.perfiles_equipo (
  tenant_id uuid NOT NULL,
  perfil_equipo_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  equipo_id uuid NOT NULL,
  nombre text NOT NULL,
  nombre_corto text,
  abreviatura text,
  sede_id uuid,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, perfil_equipo_id),
  FOREIGN KEY (tenant_id, equipo_id)
    REFERENCES public.equipos (tenant_id, equipo_id),
  FOREIGN KEY (tenant_id, sede_id)
    REFERENCES public.sedes (tenant_id, sede_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT perfiles_equipo_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
  CONSTRAINT perfiles_equipo_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.perfiles_equipo IS
  'Conserva nombres y sedes históricos sin tratar el perfil actual como verdad eterna.';

CREATE TRIGGER preservar_perfiles_equipo
BEFORE UPDATE OR DELETE ON public.perfiles_equipo
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE TABLE public.perfiles_jugador (
  tenant_id uuid NOT NULL,
  perfil_jugador_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  jugador_id uuid NOT NULL,
  nombre text NOT NULL,
  fecha_nacimiento date,
  pais_codigo char(2),
  altura_cm numeric(5,2),
  peso_kg numeric(5,2),
  lateralidad text,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, perfil_jugador_id),
  FOREIGN KEY (tenant_id, jugador_id)
    REFERENCES public.jugadores (tenant_id, jugador_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT perfiles_jugador_altura_valida
    CHECK (altura_cm IS NULL OR altura_cm BETWEEN 50 AND 300),
  CONSTRAINT perfiles_jugador_peso_valido
    CHECK (peso_kg IS NULL OR peso_kg BETWEEN 10 AND 300),
  CONSTRAINT perfiles_jugador_lateralidad_valida
    CHECK (lateralidad IS NULL OR lateralidad IN ('derecha', 'izquierda', 'ambas')),
  CONSTRAINT perfiles_jugador_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
  CONSTRAINT perfiles_jugador_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.perfiles_jugador IS
  'Permite auditar discrepancias biométricas y cambios de nombre sin perder historia.';

CREATE TRIGGER preservar_perfiles_jugador
BEFORE UPDATE OR DELETE ON public.perfiles_jugador
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE TABLE public.posiciones_jugador (
  tenant_id uuid NOT NULL,
  posicion_jugador_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  jugador_id uuid NOT NULL,
  posicion_id uuid NOT NULL,
  es_principal boolean NOT NULL DEFAULT false,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, posicion_jugador_id),
  FOREIGN KEY (tenant_id, jugador_id)
    REFERENCES public.jugadores (tenant_id, jugador_id),
  FOREIGN KEY (tenant_id, posicion_id)
    REFERENCES public.posiciones (tenant_id, posicion_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT posiciones_jugador_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
  CONSTRAINT posiciones_jugador_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.posiciones_jugador IS
  'Permite comparar al jugador en la población posicional correcta para cada periodo.';

CREATE TRIGGER preservar_posiciones_jugador
BEFORE UPDATE OR DELETE ON public.posiciones_jugador
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE TABLE public.preferencias_fuente (
  tenant_id uuid NOT NULL,
  preferencia_fuente_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  clase_dato_id uuid NOT NULL,
  deporte_id uuid,
  competencia_id uuid,
  fuente text NOT NULL,
  prioridad integer NOT NULL,
  version integer NOT NULL,
  vigente_desde timestamptz NOT NULL,
  vigente_hasta timestamptz,
  PRIMARY KEY (tenant_id, preferencia_fuente_id),
  UNIQUE NULLS NOT DISTINCT (
    tenant_id, clase_dato_id, deporte_id, competencia_id,
    fuente, version
  ),
  FOREIGN KEY (tenant_id, clase_dato_id)
    REFERENCES public.clases_dato (tenant_id, clase_dato_id),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  FOREIGN KEY (tenant_id, competencia_id)
    REFERENCES public.competencias (tenant_id, competencia_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT preferencias_fuente_prioridad_positiva CHECK (prioridad > 0),
  CONSTRAINT preferencias_fuente_version_positiva CHECK (version > 0),
  CONSTRAINT preferencias_fuente_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta > vigente_desde),
  CONSTRAINT preferencias_fuente_alcance_valido
    CHECK (competencia_id IS NULL OR deporte_id IS NOT NULL)
);

COMMENT ON TABLE public.preferencias_fuente IS
  'Hace auditable y modificable el orden de desempate entre proveedores.';

CREATE TABLE public.temporadas (
  tenant_id uuid NOT NULL,
  temporada_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  competencia_id uuid NOT NULL,
  clave text NOT NULL,
  nombre text NOT NULL,
  inicio date NOT NULL,
  fin date NOT NULL,
  estado text NOT NULL,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, temporada_id),
  UNIQUE (tenant_id, temporada_id, competencia_id),
  UNIQUE (tenant_id, competencia_id, clave),
  FOREIGN KEY (tenant_id, competencia_id)
    REFERENCES public.competencias (tenant_id, competencia_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT temporadas_fechas_validas CHECK (fin >= inicio),
  CONSTRAINT temporadas_estado_valido
    CHECK (estado IN ('planificada', 'activa', 'cerrada')),
  CONSTRAINT temporadas_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.temporadas IS
  'Fija la ventana contra la que se agregan métricas y percentiles.';

CREATE TABLE public.inscripciones_equipo (
  tenant_id uuid NOT NULL,
  inscripcion_equipo_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  temporada_id uuid NOT NULL,
  equipo_id uuid NOT NULL,
  estado text NOT NULL DEFAULT 'activa',
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, inscripcion_equipo_id),
  FOREIGN KEY (tenant_id, temporada_id)
    REFERENCES public.temporadas (tenant_id, temporada_id),
  FOREIGN KEY (tenant_id, equipo_id)
    REFERENCES public.equipos (tenant_id, equipo_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT inscripciones_equipo_estado_valido
    CHECK (estado IN ('activa', 'retirada', 'descalificada')),
  CONSTRAINT inscripciones_equipo_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.inscripciones_equipo IS
  'Define la población competitiva real de cada temporada.';

CREATE TRIGGER preservar_inscripciones_equipo
BEFORE UPDATE OR DELETE ON public.inscripciones_equipo
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE TABLE public.jornadas (
  tenant_id uuid NOT NULL,
  jornada_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  temporada_id uuid NOT NULL,
  clave text NOT NULL,
  nombre text NOT NULL,
  orden integer NOT NULL,
  inicio timestamptz,
  fin timestamptz,
  tipo text NOT NULL DEFAULT 'regular',
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, jornada_id),
  UNIQUE (tenant_id, temporada_id, clave),
  UNIQUE (tenant_id, temporada_id, orden),
  FOREIGN KEY (tenant_id, temporada_id)
    REFERENCES public.temporadas (tenant_id, temporada_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT jornadas_orden_positivo CHECK (orden > 0),
  CONSTRAINT jornadas_fechas_validas
    CHECK (inicio IS NULL OR fin IS NULL OR fin >= inicio),
  CONSTRAINT jornadas_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.jornadas IS
  'Normaliza semana, fecha y ronda sin perder el vocabulario original.';

CREATE TABLE public.partidos (
  tenant_id uuid NOT NULL,
  partido_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  deporte_id uuid NOT NULL,
  competencia_id uuid NOT NULL,
  temporada_id uuid NOT NULL,
  creado_ts timestamptz NOT NULL DEFAULT now(),
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, partido_id),
  FOREIGN KEY (tenant_id, competencia_id, deporte_id)
    REFERENCES public.competencias (tenant_id, competencia_id, deporte_id),
  FOREIGN KEY (tenant_id, temporada_id, competencia_id)
    REFERENCES public.temporadas (tenant_id, temporada_id, competencia_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT partidos_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.partidos IS
  'Da una identidad estable al encuentro para cruzar observaciones de proveedores.';

CREATE TABLE public.plantillas (
  tenant_id uuid NOT NULL,
  plantilla_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  temporada_id uuid NOT NULL,
  equipo_id uuid NOT NULL,
  jugador_id uuid NOT NULL,
  dorsal text,
  vigente_desde date NOT NULL,
  vigente_hasta date,
  estado text NOT NULL DEFAULT 'activo',
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, plantilla_id),
  FOREIGN KEY (tenant_id, temporada_id)
    REFERENCES public.temporadas (tenant_id, temporada_id),
  FOREIGN KEY (tenant_id, equipo_id)
    REFERENCES public.equipos (tenant_id, equipo_id),
  FOREIGN KEY (tenant_id, jugador_id)
    REFERENCES public.jugadores (tenant_id, jugador_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT plantillas_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde),
  CONSTRAINT plantillas_estado_valido
    CHECK (estado IN ('activo', 'cedido', 'inactivo', 'baja')),
  CONSTRAINT plantillas_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.plantillas IS
  'Reconstruye quién pertenecía a cada equipo en cualquier fecha.';

CREATE TRIGGER preservar_plantillas
BEFORE UPDATE OR DELETE ON public.plantillas
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE TABLE public.valores_parametros (
  tenant_id uuid NOT NULL,
  valor_parametro_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  parametro_id uuid NOT NULL,
  deporte_id uuid,
  competencia_id uuid,
  temporada_id uuid,
  posicion_id uuid,
  metrica_id uuid,
  valor jsonb NOT NULL,
  valor_numero numeric,
  version integer NOT NULL,
  vigente_desde timestamptz NOT NULL,
  vigente_hasta timestamptz,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, valor_parametro_id),
  FOREIGN KEY (tenant_id, parametro_id)
    REFERENCES public.catalogo_parametros (tenant_id, parametro_id),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  FOREIGN KEY (tenant_id, competencia_id)
    REFERENCES public.competencias (tenant_id, competencia_id),
  FOREIGN KEY (tenant_id, temporada_id)
    REFERENCES public.temporadas (tenant_id, temporada_id),
  FOREIGN KEY (tenant_id, posicion_id)
    REFERENCES public.posiciones (tenant_id, posicion_id),
  FOREIGN KEY (tenant_id, metrica_id)
    REFERENCES public.catalogo_metricas (tenant_id, metrica_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT valores_parametros_version_positiva CHECK (version > 0),
  CONSTRAINT valores_parametros_vigencia_valida
    CHECK (vigente_hasta IS NULL OR vigente_hasta > vigente_desde),
  CONSTRAINT valores_parametros_alcance_valido CHECK (
    competencia_id IS NULL OR deporte_id IS NOT NULL
  ),
  CONSTRAINT valores_parametros_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.valores_parametros IS
  'Versiona el valor aplicable sin perder con qué regla se produjo un análisis.';

CREATE TABLE public.eventos (
  tenant_id uuid NOT NULL,
  evento_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  partido_id uuid NOT NULL,
  deporte_id uuid NOT NULL,
  tipo_evento_id uuid NOT NULL,
  esquema_evento_id uuid NOT NULL,
  equipo_id uuid,
  jugador_id uuid,
  secuencia integer NOT NULL,
  periodo_clave text,
  reloj_segundos numeric(10,3),
  ocurrido_ts timestamptz,
  carga jsonb NOT NULL,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, evento_id),
  UNIQUE (tenant_id, partido_id, fuente, secuencia, obtenido_ts),
  FOREIGN KEY (tenant_id, partido_id)
    REFERENCES public.partidos (tenant_id, partido_id),
  FOREIGN KEY (tenant_id, deporte_id)
    REFERENCES public.deportes (tenant_id, deporte_id),
  -- Compuesta con deporte_id: un evento de futbol no puede citar un periodo de NBA.
  FOREIGN KEY (tenant_id, deporte_id, periodo_clave)
    REFERENCES public.catalogo_periodos (tenant_id, deporte_id, clave),
  FOREIGN KEY (tenant_id, tipo_evento_id)
    REFERENCES public.tipos_evento (tenant_id, tipo_evento_id),
  FOREIGN KEY (tenant_id, esquema_evento_id)
    REFERENCES public.esquemas_evento (tenant_id, esquema_evento_id),
  FOREIGN KEY (tenant_id, equipo_id)
    REFERENCES public.equipos (tenant_id, equipo_id),
  FOREIGN KEY (tenant_id, jugador_id)
    REFERENCES public.jugadores (tenant_id, jugador_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT eventos_secuencia_positiva CHECK (secuencia > 0),
  CONSTRAINT eventos_reloj_valido
    CHECK (reloj_segundos IS NULL OR reloj_segundos >= 0),
  CONSTRAINT eventos_carga_objeto CHECK (jsonb_typeof(carga) = 'object'),
  CONSTRAINT eventos_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.eventos IS
  'Unifica sucesos heterogéneos sin convertir la forma de un deporte en la norma.';

CREATE TRIGGER comprobar_evento_por_esquema
BEFORE INSERT OR UPDATE OF carga, esquema_evento_id, tipo_evento_id, deporte_id
ON public.eventos
FOR EACH ROW EXECUTE FUNCTION public.validar_evento_por_esquema();

CREATE TRIGGER preservar_eventos
BEFORE UPDATE OR DELETE ON public.eventos
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE INDEX idx_eventos_partido_secuencia
  ON public.eventos (tenant_id, partido_id, secuencia);

CREATE INDEX idx_eventos_carga
  ON public.eventos USING gin (carga jsonb_path_ops);

CREATE TABLE public.factores_partido (
  tenant_id uuid NOT NULL,
  factor_partido_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  partido_id uuid NOT NULL,
  factor_id uuid NOT NULL,
  equipo_id uuid,
  valor jsonb NOT NULL,
  valor_numero numeric,
  calculado_ts timestamptz,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, factor_partido_id),
  FOREIGN KEY (tenant_id, partido_id)
    REFERENCES public.partidos (tenant_id, partido_id),
  FOREIGN KEY (tenant_id, factor_id)
    REFERENCES public.catalogo_factores (tenant_id, factor_id),
  FOREIGN KEY (tenant_id, equipo_id)
    REFERENCES public.equipos (tenant_id, equipo_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT factores_partido_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.factores_partido IS
  'Materializa contexto calculado y citable para cada partido y equipo.';

CREATE TRIGGER comprobar_factor_partido
BEFORE INSERT OR UPDATE OF partido_id, factor_id, valor, valor_numero
ON public.factores_partido
FOR EACH ROW EXECUTE FUNCTION public.validar_factor_partido();

CREATE TRIGGER preservar_factores_partido
BEFORE UPDATE OR DELETE ON public.factores_partido
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE INDEX idx_factores_partido_contexto
  ON public.factores_partido
  (tenant_id, partido_id, factor_id, equipo_id, confianza DESC, obtenido_ts DESC);

CREATE INDEX idx_factores_partido_valor_numero
  ON public.factores_partido
  (tenant_id, factor_id, valor_numero)
  WHERE valor_numero IS NOT NULL;

CREATE TABLE public.participaciones_jugador (
  tenant_id uuid NOT NULL,
  participacion_jugador_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  partido_id uuid NOT NULL,
  equipo_id uuid NOT NULL,
  jugador_id uuid NOT NULL,
  posicion_id uuid,
  titular boolean,
  segundos_jugados integer NOT NULL DEFAULT 0,
  entrada_segundo integer,
  salida_segundo integer,
  contexto jsonb NOT NULL DEFAULT '{}'::jsonb,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, participacion_jugador_id),
  FOREIGN KEY (tenant_id, partido_id)
    REFERENCES public.partidos (tenant_id, partido_id),
  FOREIGN KEY (tenant_id, equipo_id)
    REFERENCES public.equipos (tenant_id, equipo_id),
  FOREIGN KEY (tenant_id, jugador_id)
    REFERENCES public.jugadores (tenant_id, jugador_id),
  FOREIGN KEY (tenant_id, posicion_id)
    REFERENCES public.posiciones (tenant_id, posicion_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT participaciones_jugador_segundos_validos
    CHECK (
      segundos_jugados >= 0
      AND (entrada_segundo IS NULL OR entrada_segundo >= 0)
      AND (salida_segundo IS NULL OR salida_segundo >= 0)
      AND (
        entrada_segundo IS NULL OR salida_segundo IS NULL
        OR salida_segundo >= entrada_segundo
      )
    ),
  CONSTRAINT participaciones_jugador_contexto_objeto
    CHECK (jsonb_typeof(contexto) = 'object'),
  CONSTRAINT participaciones_jugador_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.participaciones_jugador IS
  'Da el denominador verificable de las comparaciones de rendimiento.';

CREATE TRIGGER preservar_participaciones_jugador
BEFORE UPDATE OR DELETE ON public.participaciones_jugador
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE TABLE public.participantes_partido (
  tenant_id uuid NOT NULL,
  participante_partido_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  partido_id uuid NOT NULL,
  equipo_id uuid NOT NULL,
  condicion text NOT NULL,
  puntuacion numeric(8,2),
  puntuacion_reglamentaria numeric(8,2),
  resultado text,
  resultado_reglamentario text,
  desenlace text,
  detalle_periodos jsonb NOT NULL DEFAULT '[]'::jsonb,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, participante_partido_id),
  FOREIGN KEY (tenant_id, partido_id)
    REFERENCES public.partidos (tenant_id, partido_id),
  FOREIGN KEY (tenant_id, equipo_id)
    REFERENCES public.equipos (tenant_id, equipo_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT participantes_partido_condicion_valida
    CHECK (condicion IN ('local', 'visitante', 'neutral')),
  CONSTRAINT participantes_partido_resultado_valido
    CHECK (resultado IS NULL OR resultado IN ('victoria', 'empate', 'derrota')),
  CONSTRAINT participantes_partido_resultado_reglamentario_valido
    CHECK (resultado_reglamentario IS NULL
           OR resultado_reglamentario IN ('victoria', 'empate', 'derrota')),
  CONSTRAINT participantes_partido_desenlace_valido
    CHECK (desenlace IS NULL
           OR desenlace IN ('reglamentario', 'prorroga', 'penales',
                            'muerte_subita', 'walkover')),
  -- Un empate reglamentario resuelto en penales no es un empate del encuentro:
  -- si el desenlace fue mas alla del tiempo regular, alguien avanzo.
  CONSTRAINT participantes_partido_desenlace_coherente
    CHECK (desenlace IS NULL
           OR desenlace = 'reglamentario'
           OR resultado IS NULL
           OR resultado <> 'empate'),
  CONSTRAINT participantes_partido_periodos_arreglo
    CHECK (jsonb_typeof(detalle_periodos) = 'array'),
  CONSTRAINT participantes_partido_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.participantes_partido IS
  'Modela localía y marcador sin columnas propias de un deporte.';

COMMENT ON COLUMN public.participantes_partido.resultado IS
  'Desenlace del encuentro: quien gano o avanzo, penales incluidos. Es lo que se muestra.';

COMMENT ON COLUMN public.participantes_partido.resultado_reglamentario IS
  'Resultado al terminar el tiempo regular. Es el que alimenta rating y forma reciente.';

COMMENT ON COLUMN public.participantes_partido.puntuacion_reglamentaria IS
  'Marcador al terminar el tiempo regular, sin penales. NULL si la fuente no lo separa.';

COMMENT ON COLUMN public.participantes_partido.desenlace IS
  'Como se decidio: reglamentario, prorroga, penales, muerte subita o walkover.';

CREATE TRIGGER preservar_participantes_partido
BEFORE UPDATE OR DELETE ON public.participantes_partido
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE INDEX idx_participantes_equipo_historial
  ON public.participantes_partido
  (tenant_id, equipo_id, partido_id, confianza DESC, obtenido_ts DESC);

CREATE TABLE public.valores_metricas (
  tenant_id uuid NOT NULL,
  valor_metrica_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  metrica_id uuid NOT NULL,
  tipo_entidad text NOT NULL,
  jugador_id uuid,
  equipo_id uuid,
  partido_id uuid,
  competencia_id uuid NOT NULL,
  temporada_id uuid NOT NULL,
  jornada_id uuid,
  posicion_id uuid,
  ambito text NOT NULL,
  clave_contexto text NOT NULL DEFAULT 'general',
  valor numeric NOT NULL,
  minutos_muestra numeric(10,2),
  tamano_muestra numeric(12,3),
  contexto jsonb NOT NULL DEFAULT '{}'::jsonb,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, valor_metrica_id),
  FOREIGN KEY (tenant_id, metrica_id)
    REFERENCES public.catalogo_metricas (tenant_id, metrica_id),
  FOREIGN KEY (tenant_id, jugador_id)
    REFERENCES public.jugadores (tenant_id, jugador_id),
  FOREIGN KEY (tenant_id, equipo_id)
    REFERENCES public.equipos (tenant_id, equipo_id),
  FOREIGN KEY (tenant_id, partido_id)
    REFERENCES public.partidos (tenant_id, partido_id),
  FOREIGN KEY (tenant_id, temporada_id, competencia_id)
    REFERENCES public.temporadas (tenant_id, temporada_id, competencia_id),
  FOREIGN KEY (tenant_id, jornada_id)
    REFERENCES public.jornadas (tenant_id, jornada_id),
  FOREIGN KEY (tenant_id, posicion_id)
    REFERENCES public.posiciones (tenant_id, posicion_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT valores_metricas_entidad_valida CHECK (
    (tipo_entidad = 'jugador' AND jugador_id IS NOT NULL AND equipo_id IS NULL AND partido_id IS NULL)
    OR (tipo_entidad = 'equipo' AND jugador_id IS NULL AND equipo_id IS NOT NULL AND partido_id IS NULL)
    OR (tipo_entidad = 'partido' AND jugador_id IS NULL AND equipo_id IS NULL AND partido_id IS NOT NULL)
  ),
  CONSTRAINT valores_metricas_ambito_valido
    CHECK (ambito IN ('partido', 'jornada', 'temporada', 'ventana')),
  CONSTRAINT valores_metricas_muestras_validas
    CHECK (
      (minutos_muestra IS NULL OR minutos_muestra >= 0)
      AND (tamano_muestra IS NULL OR tamano_muestra >= 0)
    ),
  CONSTRAINT valores_metricas_contexto_objeto
    CHECK (jsonb_typeof(contexto) = 'object'),
  CONSTRAINT valores_metricas_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.valores_metricas IS
  'Guarda cualquier métrica deportiva como dato y no como estructura.';

CREATE TRIGGER comprobar_valor_metrica
BEFORE INSERT OR UPDATE ON public.valores_metricas
FOR EACH ROW EXECUTE FUNCTION public.validar_valor_metrica();

CREATE TRIGGER preservar_valores_metricas
BEFORE UPDATE OR DELETE ON public.valores_metricas
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE INDEX idx_metricas_jugador_temporada
  ON public.valores_metricas
  (tenant_id, jugador_id, temporada_id, metrica_id, jornada_id, obtenido_ts DESC)
  WHERE tipo_entidad = 'jugador';

CREATE INDEX idx_metricas_poblacion_percentil
  ON public.valores_metricas
  (tenant_id, competencia_id, temporada_id, posicion_id, metrica_id,
   minutos_muestra, confianza DESC, obtenido_ts DESC)
  INCLUDE (jugador_id, valor, fuente)
  WHERE tipo_entidad = 'jugador' AND ambito = 'temporada';

CREATE TABLE public.versiones_partido (
  tenant_id uuid NOT NULL,
  version_partido_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  partido_id uuid NOT NULL,
  jornada_id uuid,
  sede_id uuid,
  inicio_programado timestamptz NOT NULL,
  estado text NOT NULL,
  neutral boolean NOT NULL DEFAULT false,
  asistencia integer,
  detalle_resultado jsonb NOT NULL DEFAULT '{}'::jsonb,
  fuente text NOT NULL,
  obtenido_ts timestamptz NOT NULL,
  confianza public.nivel_confianza NOT NULL,
  detalle_procedencia jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (tenant_id, version_partido_id),
  FOREIGN KEY (tenant_id, partido_id)
    REFERENCES public.partidos (tenant_id, partido_id),
  FOREIGN KEY (tenant_id, jornada_id)
    REFERENCES public.jornadas (tenant_id, jornada_id),
  FOREIGN KEY (tenant_id, sede_id)
    REFERENCES public.sedes (tenant_id, sede_id),
  FOREIGN KEY (tenant_id, fuente)
    REFERENCES public.fuentes (tenant_id, clave),
  CONSTRAINT versiones_partido_estado_valido
    CHECK (estado IN (
      'programado', 'aplazado', 'cancelado', 'en_curso',
      'suspendido', 'finalizado'
    )),
  CONSTRAINT versiones_partido_asistencia_valida
    CHECK (asistencia IS NULL OR asistencia >= 0),
  CONSTRAINT versiones_partido_resultado_objeto
    CHECK (jsonb_typeof(detalle_resultado) = 'object'),
  CONSTRAINT versiones_partido_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.versiones_partido IS
  'Conserva cambios de calendario y resultado para resolverlos en lectura.';

CREATE TRIGGER preservar_versiones_partido
BEFORE UPDATE OR DELETE ON public.versiones_partido
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();

CREATE INDEX idx_versiones_partido_semana
  ON public.versiones_partido
  (tenant_id, inicio_programado, partido_id, confianza DESC, obtenido_ts DESC);

CREATE OR REPLACE FUNCTION public.prioridad_de_fuente(
  p_tenant_id uuid,
  p_clase_dato text,
  p_deporte_id uuid,
  p_competencia_id uuid,
  p_fuente text,
  p_instante timestamptz
)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT COALESCE((
    SELECT pf.prioridad
    FROM public.preferencias_fuente AS pf
    JOIN public.clases_dato AS cd
      ON cd.tenant_id = pf.tenant_id
     AND cd.clase_dato_id = pf.clase_dato_id
    WHERE pf.tenant_id = p_tenant_id
      AND cd.clave = p_clase_dato
      AND pf.fuente = p_fuente
      AND (pf.deporte_id IS NULL OR pf.deporte_id = p_deporte_id)
      AND (pf.competencia_id IS NULL OR pf.competencia_id = p_competencia_id)
      AND pf.vigente_desde <= p_instante
      AND (pf.vigente_hasta IS NULL OR pf.vigente_hasta > p_instante)
    ORDER BY
      (pf.competencia_id IS NOT NULL) DESC,
      (pf.deporte_id IS NOT NULL) DESC,
      pf.version DESC
    LIMIT 1
  ), 2147483647);
$$;

CREATE OR REPLACE FUNCTION public.dato_dentro_de_vigencia(
  p_tenant_id uuid,
  p_clase_dato text,
  p_obtenido_ts timestamptz,
  p_instante timestamptz
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT COALESCE((
    SELECT cd.antiguedad_maxima IS NULL
           OR p_obtenido_ts >= p_instante - cd.antiguedad_maxima
    FROM public.clases_dato AS cd
    WHERE cd.tenant_id = p_tenant_id
      AND cd.clave = p_clase_dato
  ), true);
$$;

CREATE VIEW public.versiones_partido_resueltas
WITH (security_invoker = true)
AS
WITH ultima_por_fuente AS (
  SELECT vp.*,
         p.deporte_id,
         p.competencia_id,
         p.temporada_id,
         row_number() OVER (
           PARTITION BY vp.tenant_id, vp.partido_id, vp.fuente
           ORDER BY vp.obtenido_ts DESC, vp.version_partido_id ASC
         ) AS orden_fuente
  FROM public.versiones_partido AS vp
  JOIN public.partidos AS p
    ON p.tenant_id = vp.tenant_id
   AND p.partido_id = vp.partido_id
), elegibles AS (
  SELECT *
  FROM ultima_por_fuente
  WHERE orden_fuente = 1
    AND confianza > 0
    AND public.dato_dentro_de_vigencia(
      tenant_id, 'calendario_resultado', obtenido_ts, now()
    )
), ordenadas AS (
  SELECT u.*,
         row_number() OVER (
           PARTITION BY u.tenant_id, u.partido_id
           ORDER BY
             u.confianza DESC,
             public.prioridad_de_fuente(
               u.tenant_id, 'calendario_resultado', u.deporte_id,
               u.competencia_id, u.fuente, now()
             ) ASC,
             u.obtenido_ts DESC,
             u.fuente ASC,
             u.version_partido_id ASC
         ) AS orden_resolucion
  FROM elegibles AS u
)
SELECT o.*,
       EXISTS (
         SELECT 1
         FROM elegibles AS alternativa
         WHERE alternativa.tenant_id = o.tenant_id
           AND alternativa.partido_id = o.partido_id
           AND ROW(
             alternativa.inicio_programado,
             alternativa.estado,
             alternativa.sede_id,
             alternativa.detalle_resultado
           ) IS DISTINCT FROM ROW(
             o.inicio_programado,
             o.estado,
             o.sede_id,
             o.detalle_resultado
           )
       ) AS hay_conflicto
FROM ordenadas AS o
WHERE o.orden_resolucion = 1;

CREATE VIEW public.participantes_partido_resueltos
WITH (security_invoker = true)
AS
WITH candidatas AS (
  SELECT pp.*,
         p.deporte_id,
         p.competencia_id,
         row_number() OVER (
           PARTITION BY pp.tenant_id, pp.partido_id, pp.equipo_id, pp.fuente
           ORDER BY pp.obtenido_ts DESC, pp.participante_partido_id ASC
         ) AS orden_fuente
  FROM public.participantes_partido AS pp
  JOIN public.partidos AS p
    ON p.tenant_id = pp.tenant_id
   AND p.partido_id = pp.partido_id
), elegibles AS (
  SELECT *
  FROM candidatas
  WHERE orden_fuente = 1
    AND confianza > 0
    AND public.dato_dentro_de_vigencia(
      tenant_id, 'resultado', obtenido_ts, now()
    )
), ordenadas AS (
  SELECT c.*,
         row_number() OVER (
           PARTITION BY c.tenant_id, c.partido_id, c.equipo_id
           ORDER BY
             c.confianza DESC,
             public.prioridad_de_fuente(
               c.tenant_id, 'resultado', c.deporte_id,
               c.competencia_id, c.fuente, now()
             ) ASC,
             c.obtenido_ts DESC,
             c.fuente ASC,
             c.participante_partido_id ASC
         ) AS orden_resolucion
  FROM elegibles AS c
)
SELECT o.*,
       EXISTS (
         SELECT 1
         FROM elegibles AS alternativa
         WHERE alternativa.tenant_id = o.tenant_id
           AND alternativa.partido_id = o.partido_id
           AND alternativa.equipo_id = o.equipo_id
           AND ROW(
             alternativa.condicion,
             alternativa.puntuacion,
             alternativa.resultado,
             alternativa.detalle_periodos
           ) IS DISTINCT FROM ROW(
             o.condicion,
             o.puntuacion,
             o.resultado,
             o.detalle_periodos
           )
       ) AS hay_conflicto
FROM ordenadas AS o
WHERE o.orden_resolucion = 1;

CREATE VIEW public.factores_partido_resueltos
WITH (security_invoker = true)
AS
WITH candidatas AS (
  SELECT fp.*,
         p.deporte_id,
         p.competencia_id,
         row_number() OVER (
           PARTITION BY fp.tenant_id, fp.partido_id, fp.factor_id,
                        fp.equipo_id, fp.fuente
           ORDER BY fp.obtenido_ts DESC, fp.factor_partido_id ASC
         ) AS orden_fuente
  FROM public.factores_partido AS fp
  JOIN public.partidos AS p
    ON p.tenant_id = fp.tenant_id
   AND p.partido_id = fp.partido_id
), elegibles AS (
  SELECT *
  FROM candidatas
  WHERE orden_fuente = 1
    AND confianza > 0
    AND public.dato_dentro_de_vigencia(
      tenant_id, 'factor', obtenido_ts, now()
    )
), ordenadas AS (
  SELECT c.*,
         row_number() OVER (
           PARTITION BY c.tenant_id, c.partido_id, c.factor_id, c.equipo_id
           ORDER BY
             c.confianza DESC,
             public.prioridad_de_fuente(
               c.tenant_id, 'factor', c.deporte_id,
               c.competencia_id, c.fuente, now()
             ) ASC,
             c.obtenido_ts DESC,
             c.fuente ASC,
             c.factor_partido_id ASC
         ) AS orden_resolucion
  FROM elegibles AS c
)
SELECT o.*,
       EXISTS (
         SELECT 1
         FROM elegibles AS alternativa
         WHERE alternativa.tenant_id = o.tenant_id
           AND alternativa.partido_id = o.partido_id
           AND alternativa.factor_id = o.factor_id
           AND alternativa.equipo_id IS NOT DISTINCT FROM o.equipo_id
           AND alternativa.valor IS DISTINCT FROM o.valor
       ) AS hay_conflicto
FROM ordenadas AS o
WHERE o.orden_resolucion = 1;

CREATE VIEW public.valores_metricas_resueltos
WITH (security_invoker = true)
AS
WITH candidatas AS (
  SELECT vm.*,
         cm.deporte_id,
         row_number() OVER (
           PARTITION BY vm.tenant_id, vm.metrica_id, vm.tipo_entidad,
                        vm.jugador_id, vm.equipo_id, vm.partido_id,
                        vm.competencia_id, vm.temporada_id, vm.jornada_id,
                        vm.posicion_id, vm.ambito, vm.clave_contexto, vm.fuente
           ORDER BY vm.obtenido_ts DESC, vm.valor_metrica_id ASC
         ) AS orden_fuente
  FROM public.valores_metricas AS vm
  JOIN public.catalogo_metricas AS cm
    ON cm.tenant_id = vm.tenant_id
   AND cm.metrica_id = vm.metrica_id
), elegibles AS (
  SELECT *
  FROM candidatas
  WHERE orden_fuente = 1
    AND confianza > 0
    AND public.dato_dentro_de_vigencia(
      tenant_id, 'metrica', obtenido_ts, now()
    )
), ordenadas AS (
  SELECT c.*,
         row_number() OVER (
           PARTITION BY c.tenant_id, c.metrica_id, c.tipo_entidad,
                        c.jugador_id, c.equipo_id, c.partido_id,
                        c.competencia_id, c.temporada_id, c.jornada_id,
                        c.posicion_id, c.ambito, c.clave_contexto
           ORDER BY
             c.confianza DESC,
             public.prioridad_de_fuente(
               c.tenant_id, 'metrica', c.deporte_id,
               c.competencia_id, c.fuente, now()
             ) ASC,
             c.obtenido_ts DESC,
             c.fuente ASC,
             c.valor_metrica_id ASC
         ) AS orden_resolucion
  FROM elegibles AS c
)
SELECT o.*,
       EXISTS (
         SELECT 1
         FROM elegibles AS alternativa
         WHERE alternativa.tenant_id = o.tenant_id
           AND alternativa.metrica_id = o.metrica_id
           AND alternativa.tipo_entidad = o.tipo_entidad
           AND alternativa.jugador_id IS NOT DISTINCT FROM o.jugador_id
           AND alternativa.equipo_id IS NOT DISTINCT FROM o.equipo_id
           AND alternativa.partido_id IS NOT DISTINCT FROM o.partido_id
           AND alternativa.competencia_id = o.competencia_id
           AND alternativa.temporada_id = o.temporada_id
           AND alternativa.jornada_id IS NOT DISTINCT FROM o.jornada_id
           AND alternativa.posicion_id IS NOT DISTINCT FROM o.posicion_id
           AND alternativa.ambito = o.ambito
           AND alternativa.clave_contexto = o.clave_contexto
           AND alternativa.valor IS DISTINCT FROM o.valor
       ) AS hay_conflicto
FROM ordenadas AS o
WHERE o.orden_resolucion = 1;
