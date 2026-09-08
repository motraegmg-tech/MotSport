# 13 · Infraestructura

> Dónde corre cada cosa, cómo se despliega y cómo se recupera. Lo que todavía no está decidido está marcado como tal.

---

## 1. Vista general

```
   NUBE                                          MAQUINA DE DESARROLLO
┌────────────────────────────┐                ┌────────────────────────────┐
│ Supabase                   │                │ pnpm dev  -> apps/web      │
│  Postgres 16 (RLS)         │◀──────────────▶│ supabase start (local)     │
│  Auth · Realtime           │                │ docker    -> apps/motor    │
│  Edge Functions            │                └────────────────────────────┘
└────────────────────────────┘
            ▲
            │ (escribe)
┌────────────────────────────┐                ┌────────────────────────────┐
│ Contenedor del motor       │                │ GitHub Actions             │
│  Python 3.12 · FastAPI     │                │  lint · pruebas · esquema  │
│  ingesta + metricas +      │                │  acciones ancladas por hash│
│  modelos                   │                └────────────────────────────┘
└────────────────────────────┘
```

**Postgres es la única frontera** entre el motor y la plataforma.

---

## 2. Entornos

| Entorno | Para qué | Datos |
|---|---|---|
| **Local** | Desarrollo diario. Supabase local + motor en Docker | Semilla ficticia, nunca datos reales |
| **Pruebas** | Verificar migraciones e ingesta antes de producción | Copia reducida y anonimizada |
| **Producción** | El que usa el equipo | Reales |

**Nadie toca producción salvo Gonzalo.** Desplegar, migrar el esquema, rotar llaves y publicar son suyos.

---

## 3. Requisitos de la máquina de desarrollo

Verificado en la máquina de MOTRAE el **8 de septiembre de 2026**:

| Herramienta | Versión | Estado |
|---|---|---|
| Node | 24.x | ✅ instalado (`C:\Program Files\nodejs\node.exe`) |
| pnpm | 9.x vía Corepack | ✅ (`corepack enable`) |
| **Python** | **3.12** | ⛔ **NO instalado.** Lo que hay en `WindowsApps\python.exe` son *stubs* de Microsoft Store que solo abren la tienda |
| Docker | — | Por verificar |
| Supabase CLI | última | Por verificar |
| Git | — | ✅ |
| GitHub CLI (`gh`) | — | ⛔ **NO instalado** |

> ### ⚠️ Dos huecos que hay que cerrar antes de arrancar la Fase 1
>
> 1. **Instalar Python 3.12 de verdad**, desde python.org y no desde la Microsoft Store. `apps/motor/` —ingesta, métricas derivadas y modelos— no arranca sin él. Es la dependencia más importante que hoy falta.
> 2. **Instalar GitHub CLI** (`winget install GitHub.cli`) para poder crear y administrar el repositorio desde la terminal.
>
> Ninguno de los dos bloquea la Fase 0, que es documentación y mockups. Los dos bloquean la Fase 1 desde el primer día.

---

## 4. El motor

Corre en contenedor, separado de la aplicación. **Decisión pendiente:** si vive como servicio permanente con un programador interno, o como trabajos programados que arrancan, hacen su corrida y mueren.

| | Servicio permanente | Trabajos programados |
|---|---|---|
| A favor | Estado en memoria entre corridas, respuesta inmediata para reentrenar | Más barato, más simple, se cae y no pasa nada |
| En contra | Paga por estar despierto sin trabajo | Arranque en frío en cada corrida |

**Inclinación actual:** trabajos programados. La ingesta de Fase 1 corre pocas veces al día y está limitada por el presupuesto de consultas de la fuente, no por la latencia. Se decide con un ADR al arrancar la Fase 1.

---

## 5. Despliegue

- **Migraciones de esquema** con Supabase CLI, versionadas en `supabase/migrations/`. **Se aplican desde cero en CI** para garantizar que la secuencia completa funciona, no solo el último paso.
- **La aplicación web** se despliega desde `main`, después de CI en verde.
- **El motor** se publica como imagen de contenedor etiquetada por versión.
- **Nada se despliega desde una máquina local.**

---

## 6. Respaldos

- Respaldo diario de Postgres, con retención de 30 días.
- **Una restauración de prueba al mes, en el entorno de pruebas.** Un respaldo que nunca se restauró no es un respaldo: es un archivo del que nadie sabe nada.
- El catálogo de sedes, que se llena a mano, se respalda aparte: es el único dato del sistema que no se puede volver a descargar.

---

## 7. Secretos

- Viven en variables de entorno; la plantilla es [`../../.env.ejemplo`](../../.env.ejemplo).
- En producción, en el gestor de secretos de Supabase y del proveedor del contenedor.
- **Nunca en el repositorio.** El `.gitignore` bloquea por extensión como segunda línea de defensa, no como primera.
- Rotación: al menos anual, e inmediata ante cualquier sospecha.

---

## 8. Observabilidad

Tres cosas se miden desde el primer día o no existen:

| Qué | Por qué |
|---|---|
| **Salud de la ingesta** | Última corrida por fuente, filas nuevas, errores, consultas consumidas contra el presupuesto |
| **Costo de IA** | Tokens, aciertos de caché (`cache_read_input_tokens`), costo por consulta y por usuario, contra los topes de `.env` |
| **Calidad del dato** | Cobertura por competencia, huecos detectados, discrepancias entre fuentes |

Todo se ve en la pantalla de operación (módulo 09), que en Fase 3 crece hasta ser la Consola MOTRAE.

---

## 9. Costos

Ver [`02_MASTER_PLAN.md`](02_MASTER_PLAN.md) § 7. Con los topes puestos, el peor caso de las Fases 0 a 2 es de unos **$125 USD al mes**.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
