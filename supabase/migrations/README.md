# supabase/migrations

El esquema, versionado.

**La primera migracion ya tiene dos requisitos escritos:** `tenant_id` con RLS activa en cada tabla, y las columnas de procedencia (`fuente`, `obtenido_ts`, `confianza`). Ver `docs/motsport/03_ARQUITECTURA.md` D-2 y D-5.

## Lo que hay

| Archivo | Que hace |
|---|---|
| `20260908000100_esquema_inicial.sql` | Las 40 tablas, 9 funciones, 18 triggers, 10 indices y 4 vistas de resolucion |
| `20260908000200_rls_lectura_aislada.sql` | 40 `ENABLE`, 40 `FORCE` y 40 politicas de lectura. Una por tabla, ninguna fuera |

La semilla de catalogos esta en `../seed.sql` y la aplica `supabase db reset` sola.

## ⚠️ Estado: escritas, NO aplicadas todavia

**Nadie las ha corrido contra un Postgres.** Se escribieron mientras Docker Desktop seguia sin arrancar en la maquina de desarrollo. Lo que si se comprobo:

| Comprobacion | Resultado |
|---|---|
| Orden de creacion | Derivado de las llaves foraneas, **no escrito a mano**. Sin ciclos y sin una sola referencia a tabla inexistente |
| Sintaxis con `sqlglot` (dialecto postgres) | 130 + 120 + 6 sentencias parseadas, cero errores |
| Balanceo | Parentesis pares, cuerpos `$$` pares, cero residuos de Markdown |

**Ojo con lo que ese `sqlglot` NO cubre.** No entiende `CREATE POLICY`, `ALTER TABLE … ROW LEVEL SECURITY`, `CREATE DOMAIN`, `CREATE EXTENSION` ni los cuerpos `plpgsql`: los trata como texto opaco y los deja pasar. Es decir, **la sintaxis validada de verdad es la de las tablas, los indices y las vistas** — justo donde esta el grueso del riesgo, pero no en todo el archivo. Y ninguna comprobacion estatica ve tipos, permisos ni si un `CHECK` es satisfacible.

Eso da confianza, no certeza. **La primera vez que corran es probable que falle algo**, y eso es normal: se arregla, se vuelve a correr y se quita este aviso.

```bash
corepack pnpm run base:levantar    # supabase start
corepack pnpm run base:reiniciar   # supabase db reset: aplica migraciones + seed
```

## De donde sale este SQL

De `docs/motsport/07_MODELO_DE_DATOS.md`, que sigue siendo **la fuente legible**. Este directorio es la misma definicion en orden aplicable.

El documento presenta las entidades (seccion 3) antes que los catalogos (seccion 4) porque asi se entiende mejor, pero las entidades referencian catalogos: **el orden de lectura no es un orden ejecutable.** El orden real se derivo de las propias llaves foraneas.

**Si cambias el esquema, cambia primero el documento y despues la migracion.** Al reves se pierde el porque, que es lo unico que no se puede reconstruir leyendo el SQL.

## La regla que no se negocia

**Toda politica de `INSERT` o `UPDATE` lleva `WITH CHECK (tenant_id = public.tenant_actual())`.** Hoy no hay ninguna politica de escritura y por eso no hace falta; la primera que se agregue, si. Plantilla y consulta de verificacion en `docs/motsport/07_MODELO_DE_DATOS.md` seccion 7.1.
