# 07 · Modelo de datos

> Especificación de Fase 0 para Postgres 16 en Supabase. Este documento define el esquema lógico y físico; no es una migración ejecutable del repositorio.

---

## 1. Principios del modelo

1. **Aislamiento desde el origen (D-2).** Todas las tablas tienen `tenant_id`; las llaves foráneas incluyen el tenant y RLS aplica el aislamiento aunque hoy solo exista MOTRAE. La jerarquía queda preparada como `inquilino → organización → equipo → usuario`, sin construir todavía altas comerciales, planes ni facturación.
2. **Multideporte por filas (D-3).** Fútbol, basquetbol y fútbol americano comparten entidades, partidos, participantes, eventos y valores. Una métrica es una fila de `catalogo_metricas` y su medición es una fila de `valores_metricas`; nunca se agrega como columna. Incorporar otro deporte consiste en insertar catálogos, tipos y esquemas, no en migrar tablas.
3. **Un solo flujo de eventos (D-4).** `eventos` contiene el tipo y la `carga` JSONB. Cada fila apunta al esquema versionado de su deporte y un disparador la valida antes de aceptar el dato.
4. **Procedencia innegociable (D-5).** Toda tabla que recibe o deriva datos externos exige `fuente`, `obtenido_ts` y `confianza`. Las observaciones son históricas e insertables: una fuente nunca actualiza ni elimina la versión de otra.
5. **Conocimiento versionado (D-9).** Definiciones de métricas, factores, umbrales, pesos, esquemas de evento y preferencias de fuente tienen versión y vigencia. Afinar un umbral produce una fila nueva, no un despliegue.
6. **Identidad no equivale a observación.** `jugadores`, `equipos`, `sedes` y `partidos` dan una identidad canónica interna. Sus perfiles, versiones e identificadores externos conservan lo que dijo cada proveedor. Las vistas resuelven la observación preferida sin destruir las demás.
7. **Toda cifra citable.** Cada valor servido al producto conserva la fila ganadora, sus alternativas, la fuente y la fecha de obtención. El asistente puede explicar de dónde salió un número y declarar una discrepancia.

Los bloques están ordenados para explicar el dominio. Al convertir esta especificación en migraciones se crean primero las extensiones y los catálogos de la sección 4, después el núcleo de la sección 3, y al final RLS, índices y vistas.

---

## 2. Diagrama de relaciones del núcleo

```text
inquilinos ── organizaciones ── usuarios
     │                │              │
     │                └──── equipos ─┴── accesos_equipo
     │                         │
     ├── deportes ── competencias ── temporadas ── jornadas
     │      │               │             │
     │      ├── posiciones  │             │
     │      ├── tipos_evento ── esquemas_evento
     │      ├── catalogo_metricas ── valores_metricas
     │      └── catalogo_factores ── factores_partido
     │
     ├── jugadores ── perfiles_jugador ── plantillas ── equipos
     │        │                                 │
     │        └── participaciones_jugador ── partidos
     │                                           │
     ├── sedes ── observaciones_sede ────────────┤
     │                                           │
     └── partidos ── versiones_partido           ├── eventos
              └──── participantes_partido ───────┘

fuentes ── preferencias_fuente ── clases_dato
    └──── fuente + obtenido_ts + confianza en cada observación externa
```

Las relaciones siempre incluyen `tenant_id`. El diagrama omite esas columnas y las tablas de parámetros e identificadores externos para conservar legibilidad.

---

## 3. Núcleo común, tabla por tabla

### 3.1 Tipos y función de contexto

La escala admite únicamente cinco valores; el dominio impide que aparezcan porcentajes inventados entre niveles evaluables.

```sql
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
```

### 3.2 `inquilinos`

Existe para fijar la frontera de aislamiento que sería costosa de incorporar después; no contiene maquinaria comercial.

```sql
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
```

### 3.3 `organizaciones`

Existe para conservar la jerarquía D-2 entre el tenant y los equipos sin asumir que tenant y club serán siempre lo mismo.

```sql
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
```

### 3.4 `usuarios`

Existe para vincular Supabase Auth con el tenant y la organización que determinan su contexto de trabajo.

```sql
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
```

### 3.5 `competencias`

Existe para reunir ligas, copas y torneos de cualquier deporte bajo la misma estructura.

```sql
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
```

### 3.6 `temporadas`

Existe porque la etiqueta y las fechas de una temporada cambian entre deportes, pero su función analítica es la misma.

```sql
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
```

### 3.7 `jornadas`

Existe para ordenar una serie temporal sin imponer que todos los deportes llamen igual a sus semanas, fechas o rondas.

```sql
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
```

### 3.8 `sedes` y `observaciones_sede`

`sedes` conserva una identidad física estable. `observaciones_sede` contiene altitud, techo, superficie y dimensiones por fuente y versión. Esta separación permite discrepar sobre una dimensión sin duplicar partidos ni sobrescribir otra fuente.

```sql
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

CREATE TRIGGER comprobar_dimensiones_sede
BEFORE INSERT OR UPDATE OF deporte_id, dimensiones
ON public.observaciones_sede
FOR EACH ROW EXECUTE FUNCTION public.validar_dimensiones_sede();
```

Las dimensiones usan claves españolas definidas por el esquema del deporte. Ejemplos: fútbol `{"largo_m": 105, "ancho_m": 68}`, NBA `{"largo_m": 28.65, "ancho_m": 15.24}` y NFL `{"largo_yardas": 120, "ancho_yardas": 53.333}`.

El llenado es explícito: MOTRAE crea la identidad; transcribe nombre, techo, superficie, capacidad y dimensiones desde la ficha oficial del recinto, equipo o liga; registra cada URL y fecha en `detalle_procedencia`; obtiene coordenadas de la dirección oficial; y calcula la altitud desde esas coordenadas con una fuente de elevación registrada. Una segunda persona compara la captura con el origen. Si falta un atributo se deja nulo: no se estima. Una remodelación o una fuente discrepante genera otra observación con nueva vigencia. La sección 6 fija la confianza de cada paso.

### 3.9 `equipos`, `perfiles_equipo` y `accesos_equipo`

`equipos` da identidad; los perfiles preservan nombres y sede declarados por cada fuente; los accesos completan la costura organización-equipo-usuario de D-2.

```sql
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
```

### 3.10 `jugadores`, `perfiles_jugador` y `posiciones_jugador`

Estas tablas separan a la persona de sus atributos variables y de las posiciones que ocupa por periodo.

```sql
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
```

### 3.11 `inscripciones_equipo` y `plantillas`

La primera fija qué equipos disputaron una temporada; la segunda registra el vínculo temporal jugador-equipo y evita asumir plantillas permanentes.

```sql
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
```

### 3.12 `partidos`, `versiones_partido` y `participantes_partido`

`partidos` es la identidad conciliada. Calendario, estado, sede, marcador y participantes son observaciones que solo admiten anexos por fuente; así un cambio de horario o marcador no borra lo recibido antes.

```sql
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

CREATE TABLE public.participantes_partido (
  tenant_id uuid NOT NULL,
  participante_partido_id uuid NOT NULL DEFAULT extensions.gen_random_uuid(),
  partido_id uuid NOT NULL,
  equipo_id uuid NOT NULL,
  condicion text NOT NULL,
  puntuacion numeric(8,2),
  resultado text,
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
  CONSTRAINT participantes_partido_periodos_arreglo
    CHECK (jsonb_typeof(detalle_periodos) = 'array'),
  CONSTRAINT participantes_partido_procedencia_objeto
    CHECK (jsonb_typeof(detalle_procedencia) = 'object')
);

COMMENT ON TABLE public.participantes_partido IS
  'Modela localía y marcador sin columnas propias de un deporte.';
```

### 3.13 `participaciones_jugador`

Existe para explicar minutos, titularidad y posición realmente ejercida en un partido; alimenta los mínimos de muestra y las métricas por 90, 48 minutos o jugada.

```sql
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
```

### 3.14 `disponibilidades_jugador`

Existe para historizar lesiones, sanciones y ausencias como intervalos observados, sin convertir cada causa en columna.

```sql
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
```

### 3.15 `identificadores_externos`

Existe para conciliar el mismo objeto entre proveedores sin usar sus identificadores como llave interna.

```sql
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

CREATE TRIGGER comprobar_identificador_externo
BEFORE INSERT OR UPDATE ON public.identificadores_externos
FOR EACH ROW EXECUTE FUNCTION public.validar_identificador_externo();
```

### 3.16 `eventos`

Existe como flujo único de sucesos para todos los deportes; el esquema versionado conserva flexibilidad sin aceptar JSON arbitrario.

```sql
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
  periodo text,
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

CREATE TRIGGER comprobar_evento_por_esquema
BEFORE INSERT OR UPDATE OF carga, esquema_evento_id, tipo_evento_id, deporte_id
ON public.eventos
FOR EACH ROW EXECUTE FUNCTION public.validar_evento_por_esquema();
```

---

## 4. Catálogos

### 4.1 `fuentes`

Existe como registro operativo y legal de proveedores; una clave estable desacopla los datos de una implementación concreta.

```sql
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
```

### 4.2 `niveles_confianza`

Existe para que la interfaz y los procesos compartan el mismo significado de la escala cerrada.

```sql
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
```

### 4.3 `deportes`

Existe para que las diferencias deportivas sean configuración: reglas de periodo, dimensiones y vocabulario entran como filas versionadas.

```sql
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
```

### 4.4 `catalogo_techos` y `catalogo_superficies`

Existen para agregar una categoría física sin modificar un `CHECK` ni desplegar código.

```sql
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
```

### 4.5 `posiciones`

Existe para definir poblaciones comparables por deporte sin columnas ni enumeraciones rígidas.

```sql
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
```

### 4.6 `clases_dato` y `preferencias_fuente`

`clases_dato` identifica el hecho que se resuelve; `preferencias_fuente` guarda el desempate versionado por alcance. Ninguna prioridad queda en código.

```sql
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
```

### 4.7 `catalogo_metricas` y `valores_metricas`

El catálogo define una métrica versionada. La tabla de valores guarda una medición por entidad y ámbito. Las columnas son dimensiones comunes de consulta; ninguna representa una métrica concreta.

```sql
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

CREATE TRIGGER comprobar_valor_metrica
BEFORE INSERT OR UPDATE ON public.valores_metricas
FOR EACH ROW EXECUTE FUNCTION public.validar_valor_metrica();
```

### 4.8 `catalogo_factores` y `factores_partido`

Conservan la forma definida en `09_CATALOGO_DE_FACTORES.md`: clave, familia, deportes aplicables, definición, unidad, fuente, dirección y versión; las observaciones pueden pertenecer al partido completo o a uno de sus equipos.

```sql
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
```

`valor_numero` se exige además de `valor` cuando `tipo_valor = 'numero'`; permite rangos e índices sin convertir JSONB en cada consulta. Un disparador valida tipo y deporte aplicable:

```sql
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

CREATE TRIGGER comprobar_factor_partido
BEFORE INSERT OR UPDATE OF partido_id, factor_id, valor, valor_numero
ON public.factores_partido
FOR EACH ROW EXECUTE FUNCTION public.validar_factor_partido();
```

### 4.9 `catalogo_parametros` y `valores_parametros`

Existen para sacar del código mínimos de minutos, ventanas, umbrales y pesos. Cada valor declara alcance, vigencia y versión.

```sql
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
```

### 4.10 `tipos_evento` y `esquemas_evento`

Existen para que cada deporte describa sus eventos y cargas como datos versionados.

```sql
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
```

Las claves `type`, `properties`, `required` y `additionalProperties` que aparezcan dentro de `esquema` pertenecen al estándar JSON Schema; no son nombres del dominio MotSport.

---

## 5. Datos por deporte

Los tres deportes usan las mismas tablas. Solo cambian filas de catálogo, valores de configuración, tipos de evento y esquemas. Los UUID siguientes son deterministas únicamente para que los ejemplos sean reproducibles.

### 5.1 Fuentes y deportes iniciales

```sql
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
```

### 5.2 Ejemplos de métricas

```sql
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
```

No existe `xg`, `ritmo_48` ni `epa_por_jugada` como columna. Una cuarta disciplina agrega sus filas a `deportes`, `posiciones`, `catalogo_metricas`, `tipos_evento` y `esquemas_evento`.

### 5.3 Ejemplos de factores

```sql
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
```

### 5.4 Ejemplos de eventos

Las propiedades son diferentes, pero las tres filas entrarían en `eventos` y serían validadas contra esquemas distintos:

```sql
-- Fútbol: tiro.
INSERT INTO public.eventos (
  tenant_id, partido_id, deporte_id, tipo_evento_id, esquema_evento_id,
  equipo_id, jugador_id, secuencia, periodo, reloj_segundos, carga,
  fuente, obtenido_ts, confianza
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000001',
  '10000000-0000-0000-0000-000000000001',
  '50000000-0000-0000-0000-000000000001',
  '51000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000001',
  '70000000-0000-0000-0000-000000000001',
  83, 'segundo_tiempo', 4120,
  '{"x": 91.4, "y": 36.2, "xg": 0.18, "resultado": "atajado"}',
  'statsbomb_abierto', TIMESTAMPTZ '2026-09-06 21:04:00+00', 75
);

-- NBA: posesión.
INSERT INTO public.eventos (
  tenant_id, partido_id, deporte_id, tipo_evento_id, esquema_evento_id,
  equipo_id, jugador_id, secuencia, periodo, reloj_segundos, carga,
  fuente, obtenido_ts, confianza
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000002',
  '50000000-0000-0000-0000-000000000002',
  '51000000-0000-0000-0000-000000000002',
  '60000000-0000-0000-0000-000000000002',
  '70000000-0000-0000-0000-000000000002',
  146, 'cuarto_3', 318,
  '{"puntos": 3, "duracion_segundos": 17.2, "resultado": "triple_anotado"}',
  'balldontlie', TIMESTAMPTZ '2026-09-06 21:04:00+00', 75
);

-- NFL: jugada.
INSERT INTO public.eventos (
  tenant_id, partido_id, deporte_id, tipo_evento_id, esquema_evento_id,
  equipo_id, jugador_id, secuencia, periodo, reloj_segundos, carga,
  fuente, obtenido_ts, confianza
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  '40000000-0000-0000-0000-000000000003',
  '10000000-0000-0000-0000-000000000003',
  '50000000-0000-0000-0000-000000000003',
  '51000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000003',
  '70000000-0000-0000-0000-000000000003',
  57, 'cuarto_2', 104,
  '{"intento": 3, "yardas_por_avanzar": 7, "yardas_ganadas": 12, "epa": 1.34, "resultado": "pase_completo"}',
  'nflverse', TIMESTAMPTZ '2026-09-06 21:04:00+00', 50
);
```

Los UUID de partido, equipo, jugador, tipo y esquema presuponen las filas de identidad y catálogo correspondientes. Son ejemplos de forma, no datos semilla de producción.

---

## 6. Procedencia y confianza

### 6.1 Escala operable

La columna `confianza` no es una probabilidad. Es una clasificación ordinal cerrada que describe fuerza de procedencia y posibilidad de auditoría.

| Valor | Nombre | Criterio exacto de asignación | Puede ganar |
|---:|---|---|---|
| 100 | Confirmada | Dato leído directamente de una fuente primaria oficial que publica ese hecho: liga, equipo, recinto, parte oficial o marcador oficial; sin transcripción manual. | Sí |
| 75 | Verificada | Proveedor estructurado con origen identificable; captura manual de fuente primaria revisada por dos personas; o cálculo determinista cuyos insumos tienen mínimo 100. | Sí |
| 50 | Corroborada | Dos fuentes secundarias independientes coinciden tras normalización; o cálculo determinista cuyo insumo de menor confianza es 75. | Sí |
| 25 | Indicativa | Una sola fuente secundaria o búsqueda web identificada; dato no estructurado aún no corroborado. Toda búsqueda web en vivo inicia aquí. | Sí, solo si no hay una candidata superior |
| 0 | No verificable | No hay origen reproducible, la fuente retractó el dato o una validación lo invalidó. Se conserva para auditoría pero nunca se elige. | No |

Reglas de asignación, en este orden:

1. El conector determina el nivel por la tabla anterior y guarda la evidencia en `detalle_procedencia` —identificador externo, URL o ruta, método y versión del cálculo—.
2. El valor final es el menor entre el nivel calculado y `fuentes.confianza_maxima`; un conector nunca puede elevarse por sí mismo.
3. Para derivados: `confianza = máximo(0, mínimo(confianza de insumos) - 25)`. Excepción única: si todos los insumos son 100 y el cálculo está versionado y es exactamente reproducible, el resultado es 75, nunca 100.
4. Una captura manual de documento oficial solo llega a 75 después de revisión por una segunda persona; sin revisión queda en 50.
5. Dos fuentes no se consideran independientes si consumen el mismo origen. La dependencia se registra en `detalle_procedencia` y no aumenta el nivel.
6. La frescura no cambia el nivel: se evalúa por `obtenido_ts`, vigencia y `clases_dato.antiguedad_maxima` durante la resolución.

### 6.2 Inmutabilidad y granularidad

- Una nueva respuesta de la misma fuente se inserta con otro `obtenido_ts`; no se usa una inserción con actualización destructiva.
- El hecho comparable se define por su llave natural: por ejemplo, partido + factor + equipo; o jugador + métrica + competencia + temporada + jornada + posición + contexto.
- `detalle_procedencia` contiene como mínimo `identificador_origen`, `metodo`, `version_metodo` cuando aplique y `origenes_insumo` para derivados.
- Corregir una conciliación cambia la lectura o agrega una observación; no modifica la evidencia histórica.

Las tablas de observación rechazan actualización y borrado en la base; una corrección se anexa como otra fila. Las tablas de identidad y catálogo no usan este disparador porque requieren conciliación o cierre de vigencias controlado.

```sql
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

CREATE TRIGGER preservar_observaciones_sede
BEFORE UPDATE OR DELETE ON public.observaciones_sede
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_perfiles_equipo
BEFORE UPDATE OR DELETE ON public.perfiles_equipo
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_perfiles_jugador
BEFORE UPDATE OR DELETE ON public.perfiles_jugador
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_posiciones_jugador
BEFORE UPDATE OR DELETE ON public.posiciones_jugador
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_inscripciones_equipo
BEFORE UPDATE OR DELETE ON public.inscripciones_equipo
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_plantillas
BEFORE UPDATE OR DELETE ON public.plantillas
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_versiones_partido
BEFORE UPDATE OR DELETE ON public.versiones_partido
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_participantes_partido
BEFORE UPDATE OR DELETE ON public.participantes_partido
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_participaciones_jugador
BEFORE UPDATE OR DELETE ON public.participaciones_jugador
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_disponibilidades_jugador
BEFORE UPDATE OR DELETE ON public.disponibilidades_jugador
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_eventos
BEFORE UPDATE OR DELETE ON public.eventos
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_valores_metricas
BEFORE UPDATE OR DELETE ON public.valores_metricas
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
CREATE TRIGGER preservar_factores_partido
BEFORE UPDATE OR DELETE ON public.factores_partido
FOR EACH ROW EXECUTE FUNCTION public.impedir_cambio_de_observacion();
```

### 6.3 Algoritmo de resolución de conflictos

Para cada hecho y fecha de consulta:

1. Agrupar observaciones por la llave natural del hecho.
2. Dentro de cada fuente conservar como candidata su observación más reciente cuya vigencia cubra la fecha consultada. Las anteriores siguen almacenadas.
3. Excluir confianza 0 y observaciones vencidas según `clases_dato.antiguedad_maxima`. Para hechos históricos inmutables, la antigüedad es nula y no caducan.
4. Buscar preferencia vigente con el alcance más específico: competencia, después deporte, después global. Si una fuente no tiene fila recibe prioridad 2,147,483,647.
5. Ordenar por: `confianza DESC`, `prioridad ASC`, `obtenido_ts DESC`, `fuente ASC` y UUID de observación `ASC`. La primera fila es el valor resuelto. No se promedian marcadores, fechas, métricas ni factores discrepantes.
6. Marcar `hay_conflicto = true` si dos candidatas elegibles contienen valores normalizados distintos, incluso si la ganadora es clara. La respuesta conserva las filas alternativas para mostrarlas y citarlas.

La confianza manda; la preferencia desempata fuentes del mismo nivel; la recencia desempata a igual confianza y prioridad. El orden final por texto y UUID hace reproducible el resultado incluso en empates completos.

La prioridad vive en catálogo y no en código:

```sql
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
```

---

## 7. RLS

RLS se activa y fuerza en **cada tabla**, incluidos catálogos. Las políticas de Fase 1 dan lectura a miembros autenticados solo dentro del tenant del JWT. El motor de ingesta usa el rol de servicio de Supabase, que evita RLS por diseño; no se entrega esa credencial al cliente. Las escrituras manuales se harán mediante funciones acotadas cuando se implemente la aplicación, no abriendo escritura general a `authenticated`.

```sql
ALTER TABLE public.inquilinos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inquilinos FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_inquilinos ON public.inquilinos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.organizaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.organizaciones FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_organizaciones ON public.organizaciones
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.usuarios FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_usuarios ON public.usuarios
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.fuentes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fuentes FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_fuentes ON public.fuentes
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.niveles_confianza ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.niveles_confianza FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_niveles_confianza ON public.niveles_confianza
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.deportes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.deportes FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_deportes ON public.deportes
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_techos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogo_techos FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_catalogo_techos ON public.catalogo_techos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_superficies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogo_superficies FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_catalogo_superficies ON public.catalogo_superficies
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.competencias ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.competencias FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_competencias ON public.competencias
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.temporadas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.temporadas FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_temporadas ON public.temporadas
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.jornadas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jornadas FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_jornadas ON public.jornadas
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.sedes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sedes FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_sedes ON public.sedes
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.observaciones_sede ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.observaciones_sede FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_observaciones_sede ON public.observaciones_sede
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.equipos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipos FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_equipos ON public.equipos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.perfiles_equipo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_equipo FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_perfiles_equipo ON public.perfiles_equipo
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.accesos_equipo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accesos_equipo FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_accesos_equipo ON public.accesos_equipo
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.jugadores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.jugadores FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_jugadores ON public.jugadores
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.perfiles_jugador ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.perfiles_jugador FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_perfiles_jugador ON public.perfiles_jugador
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.posiciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posiciones FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_posiciones ON public.posiciones
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.posiciones_jugador ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.posiciones_jugador FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_posiciones_jugador ON public.posiciones_jugador
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.inscripciones_equipo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.inscripciones_equipo FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_inscripciones_equipo ON public.inscripciones_equipo
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.plantillas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.plantillas FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_plantillas ON public.plantillas
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.partidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partidos FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_partidos ON public.partidos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.versiones_partido ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.versiones_partido FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_versiones_partido ON public.versiones_partido
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.participantes_partido ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participantes_partido FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_participantes_partido ON public.participantes_partido
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.participaciones_jugador ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.participaciones_jugador FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_participaciones_jugador ON public.participaciones_jugador
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.disponibilidades_jugador ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disponibilidades_jugador FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_disponibilidades_jugador ON public.disponibilidades_jugador
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.identificadores_externos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.identificadores_externos FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_identificadores_externos ON public.identificadores_externos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.clases_dato ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clases_dato FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_clases_dato ON public.clases_dato
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.preferencias_fuente ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.preferencias_fuente FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_preferencias_fuente ON public.preferencias_fuente
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_metricas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogo_metricas FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_catalogo_metricas ON public.catalogo_metricas
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.valores_metricas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.valores_metricas FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_valores_metricas ON public.valores_metricas
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_factores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogo_factores FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_catalogo_factores ON public.catalogo_factores
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.factores_partido ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.factores_partido FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_factores_partido ON public.factores_partido
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_parametros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.catalogo_parametros FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_catalogo_parametros ON public.catalogo_parametros
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.valores_parametros ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.valores_parametros FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_valores_parametros ON public.valores_parametros
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.tipos_evento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipos_evento FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_tipos_evento ON public.tipos_evento
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.esquemas_evento ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.esquemas_evento FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_esquemas_evento ON public.esquemas_evento
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.eventos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.eventos FORCE ROW LEVEL SECURITY;
CREATE POLICY lectura_aislada_eventos ON public.eventos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());
```

No se concede acceso directo a las vistas materializadas de `analitica`; las funciones tipadas de la aplicación siempre reciben y comprueban el tenant efectivo.

---

## 8. Índices y vistas materializadas

### 8.1 Índices base

Los índices empiezan con `tenant_id` para que el aislamiento también reduzca el espacio de búsqueda.

```sql
CREATE INDEX idx_versiones_partido_semana
  ON public.versiones_partido
  (tenant_id, inicio_programado, partido_id, confianza DESC, obtenido_ts DESC);

CREATE INDEX idx_participantes_equipo_historial
  ON public.participantes_partido
  (tenant_id, equipo_id, partido_id, confianza DESC, obtenido_ts DESC);

CREATE INDEX idx_factores_partido_contexto
  ON public.factores_partido
  (tenant_id, partido_id, factor_id, equipo_id, confianza DESC, obtenido_ts DESC);

CREATE INDEX idx_factores_partido_valor_numero
  ON public.factores_partido
  (tenant_id, factor_id, valor_numero)
  WHERE valor_numero IS NOT NULL;

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

CREATE INDEX idx_eventos_partido_secuencia
  ON public.eventos (tenant_id, partido_id, secuencia);

CREATE INDEX idx_eventos_carga
  ON public.eventos USING gin (carga jsonb_path_ops);

CREATE INDEX idx_identificadores_entidad
  ON public.identificadores_externos
  (tenant_id, tipo_entidad, entidad_id, fuente);

CREATE INDEX idx_disponibilidades_periodo
  ON public.disponibilidades_jugador
  (tenant_id, equipo_id, inicio, fin_estimada, estado);
```

### 8.2 Vistas de resolución

Las vistas aplican el algoritmo de la sección 6. Se escriben completas las cuatro rutas que alimentan las consultas calientes; los perfiles de jugador, equipo y sede se resuelven con el mismo orden desde sus funciones tipadas.

```sql
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
```

### 8.3 Percentil de jugador: consulta más caliente

La vista materializada parte de métricas de ámbito temporada ya agregadas, toma el umbral versionado `minutos_minimos_percentil` con el alcance más específico y calcula percentil dentro de tenant, liga, temporada, posición y métrica. `percentil_favorable` siempre deja 100 como mejor cuando la dirección es alta o baja; queda nulo cuando depende del contexto.

```sql
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
```

El primer índice permite `REFRESH MATERIALIZED VIEW CONCURRENTLY`. El segundo permite filtrar varias métricas por rango, agrupar por jugador y exigir `count(distinct metrica_id) = número de filtros`, sin recalcular ventanas.

### 8.4 Partidos de la semana con contexto

```sql
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
```

La pantalla semanal filtra por rango de `inicio_programado`; no calcula clima, descanso o viaje durante la lectura.

### 8.5 Historial directo con contexto

```sql
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
```

Ordenar el par de UUID hace que A contra B y B contra A usen la misma entrada de índice. El JSON conserva condiciones, marcador y contexto de cada encuentro.

### 8.6 Serie temporal y búsqueda multivariable

- **Serie temporal:** `idx_metricas_jugador_temporada` sirve jugador + temporada + métrica y devuelve jornadas en orden; la vista resuelta evita duplicados por fuente.
- **Búsqueda por varios percentiles:** `idx_percentiles_jugador_busqueda_multiple` resuelve cada rango; una intersección por `jugador_id` conserva solo quienes cumplen todos.
- **Actualización:** percentiles se refrescan después del cálculo de agregados de temporada; contexto semanal después de cada corrida de factores; historial después de contexto. Todos usan `REFRESH MATERIALIZED VIEW CONCURRENTLY` tras su primera carga.
- **Exposición:** las vistas materializadas permanecen en `analitica` sin permisos para el cliente. Las herramientas tipadas consultan con `tenant_id = tenant_actual()` y devuelven fuente, fecha, confianza y conflicto junto al valor.

---

## 9. Preguntas abiertas

1. **Competiciones iniciales.** Gonzalo debe decidir qué ligas y temporadas sigue realmente el equipo; el esquema no cambia, pero sí la carga semilla y el orden de conectores.
2. **Mínimos de muestra.** El área de análisis debe aprobar los valores iniciales de `minutos_minimos_percentil` por deporte, competencia y grupo de posición, y decidir si en NBA/NFL se expresa además como porcentaje de oportunidades disponibles.
3. **Matriz inicial de fuentes.** El responsable de datos debe aprobar las primeras prioridades por clase y competencia, en particular API-Football contra football-data.org y balldontlie contra fuentes oficiales. El algoritmo ya está cerrado; faltan los valores de catálogo.
4. **Gobierno de sedes.** Debe nombrarse responsable y periodicidad de revisión del catálogo manual, especialmente después de remodelaciones, cambios de superficie o uso de techo retráctil.
5. **Recencia operativa.** Producto y análisis deben fijar `antiguedad_maxima` por clase —lesiones, alineaciones, clima, calendario y resultados— según la frecuencia real de ingesta de Fase 1.

Estas preguntas cambian filas y operación, no la estructura del esquema.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
