# supabase/migrations

El esquema, versionado.

**La primera migracion ya tiene dos requisitos escritos:** `tenant_id` con RLS activa en cada tabla, y las columnas de procedencia (`fuente`, `obtenido_ts`, `confianza`). Ver `docs/motsport/03_ARQUITECTURA.md` D-2 y D-5.

## Lo que hay

| Archivo | Que hace |
|---|---|
| `20260908000100_esquema_inicial.sql` | Las 40 tablas, 9 funciones, 18 triggers, 10 indices y 4 vistas de resolucion |
| `20260908000200_rls_lectura_aislada.sql` | 40 `ENABLE`, 40 `FORCE` y 40 politicas de lectura. Una por tabla, ninguna fuera |

La semilla de catalogos esta en `../seed.sql` y la aplica `supabase db reset` sola.

## ✅ Estado: aplicadas y verificadas · 8 de septiembre de 2026

**Aplicaron a la primera, sin un solo error**, contra `supabase/postgres:17.6.1.167` en local. Se esperaba que fallara algo y no fallo; el merito es del orden derivado de las llaves foraneas, no de la suerte.

Lo comprobado **contra la base**, no leyendo el SQL:

| Comprobacion | Resultado |
|---|---|
| Tablas creadas | **40** |
| RLS activa · RLS forzada | **40 · 40** — ninguna tabla fuera |
| Politicas | **40** de lectura |
| Funciones · triggers · indices propios · vistas | 9 · 18 · 10 · 4 |
| Llaves foraneas compuestas con `tenant_id` | **107 de 108** |
| Politicas de escritura sin `WITH CHECK` | **0** (la consulta del § 7.1 devuelve vacio) |
| Semilla | 1 inquilino · 7 fuentes · 3 deportes · 3 metricas · 3 factores · **15 periodos** |

**La FK 108 es legitima y no hay que "arreglarla":** `usuarios.usuario_id → auth.users(id)` apunta al esquema de autenticacion de Supabase, donde `tenant_id` no existe. La regla de llaves compuestas vale para el dominio; esta sale del dominio.

### El aislamiento se probo, ya no se deduce

La auditoria afirmaba que la RLS *falla cerrado* razonando sobre el SQL. Ahora esta medido:

| Quien consulta | Ve |
|---|---|
| `postgres` (dueño) | 3 deportes |
| `authenticated` **sin JWT** | **0 deportes, 0 fuentes, 0 inquilinos** |

Sin claim de tenant, `tenant_actual()` devuelve `NULL`, la comparacion evalua a `NULL` y la RLS lo trata como falso. **No hay fuga.**

```bash
corepack pnpm run base:levantar    # supabase start
corepack pnpm run base:reiniciar   # supabase db reset: aplica migraciones + seed
```

### Lo que sigue sin medirse

**El rendimiento.** Los indices se crearon, pero nadie ha comprobado que sirvan de verdad a la consulta de percentiles con millones de filas, ni si las vistas se pueden refrescar de forma incremental. Eso necesita datos sinteticos a escala, y es lo unico que la auditoria dejo abierto.

## De donde sale este SQL

De `docs/motsport/07_MODELO_DE_DATOS.md`, que sigue siendo **la fuente legible**. Este directorio es la misma definicion en orden aplicable.

El documento presenta las entidades (seccion 3) antes que los catalogos (seccion 4) porque asi se entiende mejor, pero las entidades referencian catalogos: **el orden de lectura no es un orden ejecutable.** El orden real se derivo de las propias llaves foraneas.

**Si cambias el esquema, cambia primero el documento y despues la migracion.** Al reves se pierde el porque, que es lo unico que no se puede reconstruir leyendo el SQL.

## La regla que no se negocia

**Toda politica de `INSERT` o `UPDATE` lleva `WITH CHECK (tenant_id = public.tenant_actual())`.** Hoy no hay ninguna politica de escritura y por eso no hace falta; la primera que se agregue, si. Plantilla y consulta de verificacion en `docs/motsport/07_MODELO_DE_DATOS.md` seccion 7.1.
