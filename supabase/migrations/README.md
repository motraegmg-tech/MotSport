# supabase/migrations

El esquema, versionado.

**La primera migracion ya tiene dos requisitos escritos:** `tenant_id` con RLS activa en cada tabla, y las columnas de procedencia (`fuente`, `obtenido_ts`, `confianza`). Ver `docs/motsport/03_ARQUITECTURA.md` D-2 y D-5.
