# ADR-01 · Las herramientas de desarrollo se versionan en el repositorio, no en la máquina

**Estado:** aceptado · **Fecha:** 2026-09-08 · **Decide:** Gonzalo (MOTRAE)

## Contexto

Al arrancar la Fase 1 hizo falta instalar el entorno en la máquina de desarrollo, y dos cosas salieron mal de forma reveladora:

1. **El Supabase CLI no existe como paquete de winget.** El intento de `winget install Supabase.CLI` falló sin dejar nada instalado. La vía que Supabase documenta para Windows es Scoop, que instala una versión global cuya identidad no queda registrada en ninguna parte.
2. **`python.exe` respondía en la terminal sin haber un Python instalado.** Windows coloca *stubs* de Microsoft Store en `WindowsApps` que se anuncian en el `PATH` y no ejecutan nada. Una comprobación ingenua —«¿responde `python`? entonces está instalado»— da un falso positivo.

A eso se sumó un tercer tropiezo de diagnóstico: **el Bash de Git no hereda todo el `PATH` de Windows** y reportaba como ausentes herramientas que sí estaban instaladas.

El patrón común es que **el estado de la máquina no es observable ni reproducible**. Si la versión de una herramienta vive solo en una computadora, nadie puede decir con qué se construyó el proyecto, y la siguiente máquina —o la de un colaborador, o CI— corre otra distinta sin que nadie se entere.

Restricción adicional: `corepack enable` escribe en `C:\Program Files\nodejs` y **requiere administrador**, que no siempre se tiene.

## Decisión

**Toda herramienta cuya versión afecte el resultado del build se declara en el repositorio.**

| Herramienta | Cómo se fija | Dónde vive |
|---|---|---|
| **Supabase CLI 2.117.0** | `devDependency` de npm | `package.json` + `pnpm-lock.yaml` |
| **pnpm 9.15.9** | campo `packageManager`, ejecutado con `corepack pnpm` | `package.json` |
| **Node 24.16.0** | `engines` y `.nvmrc` | `package.json` · `.nvmrc` |
| **Python 3.12** | gestionado con `uv` | `.python-version` |

Consecuencias operativas:

- **El Supabase CLI se invoca como `corepack pnpm exec supabase …`**, o por los scripts `base:*` del `package.json`. No se instala global.
- **Se usa `corepack pnpm <comando>` en vez de `pnpm <comando>`.** Evita `corepack enable`, que pide administrador, y usa exactamente la versión declarada en `packageManager`.
- **Python se instala y se ejecuta con `uv`**, no con el instalador de python.org. `uv` coloca el intérprete en `%APPDATA%\uv\python`, fuera del alcance de los *stubs* de `WindowsApps`, y no necesita administrador.

Y una regla de método, que es lo que costó descubrir:

> **En Windows, que un comando responda no prueba que esté instalado.** Se verifica con `Get-Command <nombre>` en **PowerShell** —no en el Bash de Git— y, ante la duda, comprobando el binario en disco.

## Consecuencias

**Lo que gana el proyecto.** Cualquier máquina que clone el repositorio obtiene las mismas versiones sin leer un instructivo. El `pnpm-lock.yaml` deja escrito con qué CLI se generó cada migración, que es información de auditoría real cuando algo se comporta distinto entre dos entornos. Y el día que haya CI, la configuración ya está declarada.

**Lo que pierde.** Invocar el CLI es más largo: `corepack pnpm exec supabase` en lugar de `supabase`. Se mitiga con los scripts `base:*`, pero la incomodidad existe y hay que asumirla. Además, quien llegue con el CLI ya instalado global tendrá dos versiones en la máquina y debe recordar que **manda la del repositorio**.

**Lo que queda fuera de esta decisión.** Docker Desktop y GitHub CLI **sí** se instalan de forma global con winget: son infraestructura de la máquina, no dependencias del build, y ninguna de las dos cambia el resultado de compilar o migrar.

**Deuda que esto abre.** `apps/motor/` todavía no tiene `pyproject.toml`; hoy solo está fijada la versión del intérprete. Las dependencias de Python —FastAPI, pandas, LightGBM— se fijan cuando el motor tenga su primera línea de código, y hasta entonces la reproducibilidad del lado Python está a medias.
