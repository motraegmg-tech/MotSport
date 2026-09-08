-- ─────────────────────────────────────────────────────────────
-- MotSport · Aislamiento entre inquilinos (RLS)
--
-- 40 tablas · 40 ENABLE · 40 FORCE · 40 politicas de lectura.
-- Ninguna tabla queda fuera, catalogos incluidos.
--
-- Solo hay politicas de SELECT. 'authenticated' NO puede escribir
-- nada, y eso es deliberado: escribe el rol de servicio de la
-- ingesta, que evita RLS por diseño y cuya credencial nunca llega
-- al cliente.
--
-- Si el JWT no trae el claim de tenant, tenant_actual() devuelve
-- NULL, la comparacion evalua a NULL y la RLS lo trata como falso:
-- no se ve ninguna fila. Falla cerrado, que es lo correcto.
--
-- ⚠️  LA PROXIMA MIGRACION QUE AGREGUE ESCRITURA DEBE LLEVAR
--     WITH CHECK (tenant_id = public.tenant_actual()), SIN EXCEPCION.
--     Un USING sin WITH CHECK en un UPDATE permite mover una fila a
--     otro tenant. En un INSERT, USING ni siquiera se evalua: la
--     politica no restringe absolutamente nada.
--     Plantilla y consulta de verificacion en
--     docs/motsport/07_MODELO_DE_DATOS.md seccion 7.1
-- ─────────────────────────────────────────────────────────────

ALTER TABLE public.inquilinos ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.inquilinos FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_inquilinos ON public.inquilinos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.clases_dato ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.clases_dato FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_clases_dato ON public.clases_dato
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.fuentes ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.fuentes FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_fuentes ON public.fuentes
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.niveles_confianza ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.niveles_confianza FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_niveles_confianza ON public.niveles_confianza
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.organizaciones ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.organizaciones FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_organizaciones ON public.organizaciones
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_factores ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.catalogo_factores FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_catalogo_factores ON public.catalogo_factores
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_parametros ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.catalogo_parametros FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_catalogo_parametros ON public.catalogo_parametros
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_superficies ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.catalogo_superficies FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_catalogo_superficies ON public.catalogo_superficies
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_techos ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.catalogo_techos FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_catalogo_techos ON public.catalogo_techos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.deportes ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.deportes FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_deportes ON public.deportes
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.identificadores_externos ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.identificadores_externos FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_identificadores_externos ON public.identificadores_externos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.sedes ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.sedes FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_sedes ON public.sedes
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.usuarios ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.usuarios FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_usuarios ON public.usuarios
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_metricas ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.catalogo_metricas FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_catalogo_metricas ON public.catalogo_metricas
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.catalogo_periodos ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.catalogo_periodos FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_catalogo_periodos ON public.catalogo_periodos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.competencias ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.competencias FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_competencias ON public.competencias
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.equipos ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.equipos FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_equipos ON public.equipos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.jugadores ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.jugadores FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_jugadores ON public.jugadores
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.observaciones_sede ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.observaciones_sede FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_observaciones_sede ON public.observaciones_sede
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.posiciones ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.posiciones FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_posiciones ON public.posiciones
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.tipos_evento ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.tipos_evento FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_tipos_evento ON public.tipos_evento
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.accesos_equipo ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.accesos_equipo FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_accesos_equipo ON public.accesos_equipo
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.disponibilidades_jugador ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.disponibilidades_jugador FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_disponibilidades_jugador ON public.disponibilidades_jugador
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.esquemas_evento ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.esquemas_evento FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_esquemas_evento ON public.esquemas_evento
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.perfiles_equipo ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.perfiles_equipo FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_perfiles_equipo ON public.perfiles_equipo
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.perfiles_jugador ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.perfiles_jugador FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_perfiles_jugador ON public.perfiles_jugador
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.posiciones_jugador ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.posiciones_jugador FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_posiciones_jugador ON public.posiciones_jugador
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.preferencias_fuente ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.preferencias_fuente FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_preferencias_fuente ON public.preferencias_fuente
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.temporadas ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.temporadas FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_temporadas ON public.temporadas
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.inscripciones_equipo ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.inscripciones_equipo FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_inscripciones_equipo ON public.inscripciones_equipo
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.jornadas ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.jornadas FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_jornadas ON public.jornadas
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.partidos ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.partidos FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_partidos ON public.partidos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.plantillas ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.plantillas FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_plantillas ON public.plantillas
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.valores_parametros ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.valores_parametros FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_valores_parametros ON public.valores_parametros
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.eventos ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.eventos FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_eventos ON public.eventos
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.factores_partido ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.factores_partido FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_factores_partido ON public.factores_partido
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.participaciones_jugador ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.participaciones_jugador FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_participaciones_jugador ON public.participaciones_jugador
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.participantes_partido ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.participantes_partido FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_participantes_partido ON public.participantes_partido
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.valores_metricas ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.valores_metricas FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_valores_metricas ON public.valores_metricas
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());

ALTER TABLE public.versiones_partido ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.versiones_partido FORCE ROW LEVEL SECURITY;

CREATE POLICY lectura_aislada_versiones_partido ON public.versiones_partido
  FOR SELECT TO authenticated USING (tenant_id = public.tenant_actual());
