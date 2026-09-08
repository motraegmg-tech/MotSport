# 13 · Infraestructura

> 🟡 **Segunda pasada.** Se escribe al arrancar Fase 1, cuando haya algo que desplegar.

## Decidido

- **Supabase** como backend: Postgres 16, Auth, Realtime, Edge Functions.
- **El motor de Python corre en contenedor**, separado de la aplicación.
- **La única frontera entre motor y plataforma es Postgres.** Ningún otro canal.
- **CI en GitHub Actions**, con acciones ancladas por hash de commit.
- **Nadie toca producción salvo Gonzalo.**

## Pendiente de escribir

- Entornos: local, pruebas y producción, y cómo se separan sus datos
- Dónde corre el contenedor del motor y con qué programación
- Estrategia de respaldos **y prueba de restauración** — un respaldo que nunca se restauró no es un respaldo
- Secretos: dónde viven y cómo rotan
- Observabilidad: salud de la ingesta, costo de IA, errores
- Costos mensuales reales, una vez medidos

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
