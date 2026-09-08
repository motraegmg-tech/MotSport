# Bienvenida al desarrollador · MotSport

Este documento es para la persona —o el agente— que va a tocar este código por primera vez. Se lee completo antes de escribir una línea. Toma diez minutos y ahorra semanas.

---

## 1. Qué estás por tocar

**MotSport** es la plataforma de análisis y control deportivo de MOTRAE. Concentra todo lo que rodea a un partido —datos históricos, forma, disponibilidad, clima, viaje, descanso— en una base propia multideporte, y le pone encima un asistente de IA al que se le pregunta en español.

**Lo más importante que tienes que entender antes que nada:** hoy esto es una **herramienta de uso interno** de MOTRAE. No se vende, no se distribuye, no se le da acceso a nadie fuera del equipo. Si una tarea que te llega suena a "preparar el cobro", "dar de alta clientes" o "publicar en tiendas", esa tarea es de **Fase 3** y no se construye hoy. Pregunta antes de construirla.

---

## 2. Qué leer y en qué orden

1. [`../README.md`](../README.md) — el contexto completo. No es opcional.
2. [`../CLAUDE.md`](../CLAUDE.md) — las reglas duras, en corto.
3. [`MOTRAE_EMPRESA.md`](MOTRAE_EMPRESA.md) — quién es la empresa que construye esto.
4. [`motsport/00_INDICE.md`](motsport/00_INDICE.md) — de ahí saltas al documento del tema que te toque.
5. [`motsport/15_LEGAL.md`](motsport/15_LEGAL.md) — **antes de tocar cualquier fuente de datos.**

---

## 3. Preparar la máquina

| Herramienta | Versión | Nota |
|---|---|---|
| Node | 24.x | Igual que MotRest |
| pnpm | 9.x vía Corepack | `corepack enable` — no instales pnpm por npm |
| Python | 3.12 | Para `apps/motor/` |
| uv o venv | — | Entorno virtual por proyecto, nunca global |
| Supabase CLI | última | Para migraciones y desarrollo local |
| Docker | — | El motor corre en contenedor |

Copia `.env.ejemplo` a `.env` y pide las llaves a Gonzalo. **Las llaves nunca viajan por chat ni por correo.**

---

## 4. El mapa del repositorio

| Carpeta | Qué vive ahí | Lenguaje |
|---|---|---|
| `apps/web/` | La aplicación que ve el usuario | SvelteKit 2 + Svelte 5 |
| `apps/movil/` | Empaquetado móvil de la misma aplicación | Capacitor 8 |
| `apps/motor/` | Ingesta, cálculo de métricas y modelos predictivos | Python 3.12 |
| `packages/dominio/` | Reglas de negocio puras, sin dependencias de framework | TypeScript |
| `packages/proveedores/` | Un conector por fuente de datos, detrás de una interfaz común | TypeScript |
| `packages/ui/` | Componentes compartidos | Svelte |
| `supabase/migrations/` | El esquema, versionado | SQL |
| `supabase/functions/` | Edge Functions | TypeScript (Deno) |
| `docs/` | Toda la documentación | Markdown |

**La frontera entre el motor y la plataforma es Postgres, y solo Postgres.** El motor de Python escribe a la base; la aplicación lee de la base. No hay llamadas directas entre ellos. Si te encuentras queriendo abrir un canal nuevo entre los dos, para y propón un ADR.

---

## 5. Cómo se trabaja

1. `git pull` sobre `main`.
2. `git checkout -b feature/lo-que-vas-a-hacer`.
3. Trabajas. Commits pequeños, en español, orientados al efecto.
4. `git add <rutas explícitas>` — **nunca** `git add .` ni `git add -A`.
5. Push, abres PR, se revisa, se hace merge a `main`.

Formato de commit — Conventional Commits con el asunto en español natural, describiendo **el efecto**, no el archivo tocado:

```
feat(ingesta): el clima del partido ya no depende de abrir el telefono
fix(asistente): respondia con datos de la temporada pasada sin avisarlo
docs(fuentes): queda escrito que StatsBomb no se puede usar al vender
refactor(dominio): el calculo de percentiles deja de asumir que es futbol
```

Ámbitos reales: `ingesta`, `datos`, `asistente`, `prediccion`, `web`, `movil`, `motor`, `fuentes`, `ui`, `release`.

---

## 6. Las reglas que no se negocian

1. **Todo en español.** Variables, funciones, commits, comentarios, documentos. Mezclar los dos idiomas en el mismo archivo hace que nadie encuentre nada.

2. **Los comentarios explican el porqué, no el qué.** Un párrafo largo justificando una decisión rara es bienvenido. `// incrementa i` no lo es.

3. **Ninguna cifra sale del modelo de IA.** El asistente busca en la base, ordena y explica. Si escribes código donde el modelo pueda producir un número que no vino de una fila, ese código está mal. Un asistente deportivo que alucina un marcador es peor que no tener asistente.

4. **Todo dato lleva procedencia.** `fuente`, `obtenido_ts`, `confianza`. Sin esas tres columnas, la fila no entra. Es lo que nos va a permitir cambiar de proveedor sin ensuciar el histórico.

5. **Nunca una consulta sin filtro de tenant.** Hoy el tenant es uno solo. Da igual: la RLS está activa y las consultas van filtradas. El día que haya diez tenants, no queremos auditar mil consultas.

6. **Ningún umbral es una constante en código.** Los factores, las métricas y sus umbrales viven en catálogos versionados en base de datos. Si estás por escribir `if (viento > 25)`, para: eso es un parámetro.

7. **Antes de agregar una fuente de datos, documenta su licencia** en [`motsport/08_FUENTES_DE_DATOS.md`](motsport/08_FUENTES_DE_DATOS.md) y verifica en [`motsport/15_LEGAL.md`](motsport/15_LEGAL.md) qué permite. Escribir el conector primero y preguntar después es cómo se construye un producto que no se puede vender.

8. **Secretos y llaves nunca al repositorio.** El `.gitignore` bloquea por extensión, pero el `.gitignore` es la segunda línea de defensa, no la primera.

9. **Nadie toca producción salvo Gonzalo.** Desplegar, publicar, rotar llaves.

10. **Dependencias nuevas se justifican antes de instalarse.** Una línea diciendo qué resuelve y por qué no lo resolvemos nosotros.

11. **Antes de un cambio grande, propón un plan.** Se aprueba y luego se escribe. No al revés.

---

## 7. Antes de abrir un PR

- [ ] Lint en verde
- [ ] Pruebas en verde, y pruebas nuevas para lo que agregaste
- [ ] `tsc --noEmit` / `svelte-check` sin errores
- [ ] Revisaste **tu propio diff, archivo por archivo**
- [ ] Ningún secreto, ninguna llave, ningún dato descargado en el diff
- [ ] Si tocaste una decisión de arquitectura, hay un ADR en `docs/adr/`

---

## 8. Dudas

Pregúntale a Gonzalo. Es más barato preguntar que reconstruir.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
