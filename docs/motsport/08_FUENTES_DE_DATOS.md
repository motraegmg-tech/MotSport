# 08 · Fuentes de datos

> **Regla de oro de este documento:** antes de escribir un conector nuevo, su fuente se documenta aquí —con su licencia— y se verifica contra [`15_LEGAL.md`](15_LEGAL.md). Escribir el conector primero y preguntar después es como se construye un producto que no se puede vender.

Datos recabados en **septiembre de 2026**. Precios y condiciones cambian: **verificar contra la página oficial antes de contratar o de tomar una decisión de dinero.**

---

## 1. La arquitectura que hace esto reversible

Ninguna parte de la aplicación conoce a un proveedor por su nombre. Todos entran por la misma puerta:

```
                          ┌─────────────────────────────┐
   API-Football  ────────▶│                             │
   football-data.org ────▶│   interfaz                  │
   balldontlie   ────────▶│   ProveedorDeportivo        │──▶  normalizacion  ──▶  Postgres
   StatsBomb     ────────▶│                             │      + procedencia
   (futuro: SportMonks)──▶│  listarPartidos()           │
                          │  obtenerPartido()           │
                          │  plantilla()                │
                          │  eventos()                  │
                          └─────────────────────────────┘
```

La interfaz vive en `packages/proveedores/`. Cambiar de una fuente gratuita a una licenciada debe ser **escribir una implementación nueva y cambiar una variable de entorno**, no reescribir la aplicación. Ese es todo el propósito de la capa.

Y por eso **cada fila lleva `fuente`, `obtenido_ts` y `confianza`**: cuando llegue el proveedor de pago, el histórico viejo no se tira ni se ensucia — se sabe exactamente qué vino de dónde y cuándo, y se puede resembrar por encima.

---

## 2. Fuentes en uso — Fases 0 a 2 (uso interno)

Todas son gratuitas y **legales para uso interno no comercial**. Ninguna de ellas sobrevive al momento de vender sin revisarse.

### Fútbol

| Fuente | Cobertura | Límite | Licencia | Uso previsto |
|---|---|---|---|---|
| **API-Football** (api-sports.io) | ~1,236 ligas en el tier gratuito | **100 consultas/día** | Tier gratuito. Verificar condiciones de uso comercial antes de Fase 3 | Calendario, resultados, tablas, plantillas, lesiones. **Fuente principal de Fase 1** |
| **football-data.org** | 12 competiciones (top 5 europeas + Champions) | Generoso para hobby | Gratuito | Respaldo y contraste de calendario/resultados |
| **StatsBomb Open Data** | Competiciones selectas, evento a evento, con freeze-frames de posición en cada tiro | Sin límite (archivos en GitHub) | ⛔ **Prohíbe uso comercial.** Requiere atribución | Métricas avanzadas de fútbol (xG, xA, xT) y calibración de modelos. **Puede servirse al equipo mientras el uso sea interno; se retira antes del primer cobro** |
| **Club Elo** | Ratings históricos de clubes | — | Verificar | Rating base para el modelo de fuerza |

> ⚠️ El límite de **100 consultas al día** de API-Football es la restricción real de la Fase 1. Obliga a diseñar la ingesta como **incremental y con caché agresivo desde el primer día** —lo cual, de todos modos, es como debe estar hecha—. No se resuelve pagando: se resuelve no pidiendo lo que ya tenemos.

### Basquetbol

| Fuente | Cobertura | Licencia | Uso previsto |
|---|---|---|---|
| **balldontlie** | NBA, NFL, MLB, EPL, NHL — equipos, jugadores, partidos, estadísticas, tablas, lesiones | Tier gratuito para NBA; verificar condiciones comerciales | **Fuente principal de NBA en Fase 1.** Buen tooling y SDKs |

### Fútbol americano

| Fuente | Cobertura | Licencia | Uso previsto |
|---|---|---|---|
| **balldontlie** (NFL) | Equipos, jugadores, partidos, estadísticas | Verificar | Base de NFL en Fase 2 |
| **nflverse / nflfastR** | Jugada a jugada con EPA calculado | 🟡 **Por verificar antes de usar** — es un proyecto abierto, pero hay que leer su licencia y el origen de sus datos | EPA, success rate, análisis por jugada |

### Clima

| Fuente | Qué da | Límite | Licencia |
|---|---|---|---|
| **Open-Meteo** | Pronóstico e histórico: temperatura, humedad, viento y ráfaga, precipitación, presión | 10,000 consultas/día en el tier gratuito | ⛔ **Tier gratuito = solo uso no comercial.** El plan de pago incluye licencia comercial |

Open-Meteo es la elección correcta para Fase 1: no pide llave, tiene histórico —que es lo que hace falta para entrenar modelos con clima— y su versión de pago existe y es asequible, así que la migración de Fase 3 ya está resuelta antes de necesitarla.

### Búsqueda web en vivo

Lo que ningún API cubre —una lesión anunciada hace dos horas, una declaración del entrenador, el estado del césped— entra por la **herramienta de búsqueda web de Claude**, con dominios permitidos por competencia. Esto **no reemplaza** a las fuentes estructuradas: complementa, se marca con `confianza` baja y **siempre se presenta citando el origen**. Ver [`10_INTELIGENCIA_ARTIFICIAL.md`](10_INTELIGENCIA_ARTIFICIAL.md).

### Factores del catálogo que todavía NO tienen fuente

[`09_CATALOGO_DE_FACTORES.md`](09_CATALOGO_DE_FACTORES.md) define el catálogo completo de lo que puede mover un partido. Varias familias **no tienen proveedor asignado** en las Fases 1 y 2, y conviene decirlo antes de que alguien las dé por hechas:

| Factores | Estado | Cómo se resuelve |
|---|---|---|
| `altitud_sede`, `techo`, `superficie`, `dimensiones_cancha` | **Sin API** | **Tabla propia de sedes, llenada a mano por MOTRAE.** Son unas decenas de estadios por competencia, cambian casi nunca, y la altitud sale de las coordenadas. Es trabajo de una tarde y vale la pena: la altitud es uno de los factores con más peso real |
| `km_recorridos`, `husos_cruzados` | **Derivados** | Se calculan de las coordenadas de las dos sedes; no necesitan proveedor |
| `arbitro` (tarjetas y faltas por partido) | **Parcial** | API-Football publica designación arbitral en algunas competencias. Donde no, el factor queda vacío y se declara |
| `asistencia_esperada` | **Sin fuente confiable** | Se pospone. Un factor sin dato es un factor que no entra al modelo |
| `cuota_consenso`, `movimiento_cuota` (familia mercado) | **Fase 3** | El único proveedor de cuotas contemplado es SportMonks, que llega con la comercialización. **Hasta entonces la familia mercado está vacía**, y el modelo no la usa |

**Regla:** un factor sin fuente se queda en el catálogo con su definición escrita, pero **no entra al modelo predictivo ni se muestra como si existiera**. La interfaz dice que no hay dato; no lo estima.

### Lo que NO vamos a hacer

**Scraping de sitios que lo prohíben en sus términos.** Existen librerías conocidas para extraer de FBref, Understat, Sofascore o WhoScored, y técnicamente funcionan. Varios de esos sitios lo prohíben explícitamente. Los datos en sí —hechos como un marcador— no son propiedad de nadie, pero los términos de servicio son un contrato aparte, y un producto que MOTRAE quiere vender no se construye sobre una violación de términos. **Si alguna de esas fuentes se vuelve necesaria, se busca su origen licenciable, no su scraper.**

---

## 3. Fuentes candidatas — Fase 3 (comercialización)

Cuando MotSport pase a venderse, hace falta un proveedor que otorgue **derecho de redistribución**: el derecho a mostrarle esos datos a un cliente que nos paga.

| Proveedor | Cobertura | Precio (sep 2026) | Notas |
|---|---|---|---|
| **SportMonks** | 2,200+ ligas de fútbol, odds de 145+ casas, histórico | **€29** Starter · **€99** Growth · **€249** Pro · Enterprise a medida | **La opción recomendada para arrancar la venta.** Precio público, condiciones claras, sin contrato anual mínimo |
| **Sportradar** | 80+ deportes, datos oficiales de ligas, verificados para mercados regulados | Custom, típicamente **€1,300–4,990+/mes** con contrato anual y compromiso mínimo | Solo si el cliente exige dato oficial. Su licencia permite usar y distribuir el contenido, pero **prohíbe revender el servicio a terceros** (*service bureau*) sin autorización — leer con abogado |
| **Stats Perform / Opta** | Estándar de la industria en fútbol | Enterprise | Mismo perfil que Sportradar |
| **SportsDataIO** | NFL profundo, proyecciones, DFS | Enterprise | La opción fuerte si el fútbol americano se vuelve central |
| **Open-Meteo (plan de pago)** | Igual que el gratuito, con licencia comercial | Standard 1M consultas/mes · Professional 5M · Enterprise 50M+ | Migración directa, sin cambiar el conector |

**Recomendación:** empezar la Fase 3 con **SportMonks Growth o Pro + Open-Meteo Standard**. Es el punto donde el costo de datos sigue siendo de tres cifras al mes y ya es legal cobrar.

---

## 4. Cómo se agrega una fuente nueva

1. Se documenta aquí: cobertura, límites, precio, **licencia y qué permite exactamente**.
2. Se verifica contra [`15_LEGAL.md`](15_LEGAL.md) y se registra ahí si cambia el panorama de la Fase 3.
3. Se implementa la interfaz `ProveedorDeportivo` en `packages/proveedores/`.
4. Se mapea al modelo de datos con su `fuente` propia. **Nunca se sobreescribe el dato de otra fuente**: se guarda y se resuelve el conflicto en la capa de lectura, por `confianza`.
5. Se agrega a la pantalla de operación para poder ver su salud y su consumo.

---

## 5. Conflictos entre fuentes

Dos fuentes van a discrepar. Es normal y hay que decidirlo de antemano, no en caliente:

- **Nunca se borra el dato perdedor.** Se guardan ambos con su `fuente` y su `confianza`.
- El orden de preferencia por tipo de dato vive en **catálogo, en base de datos**, no en código.
- Cuando dos fuentes discrepan en algo que el usuario está viendo, **la interfaz lo dice**. Un número con una discrepancia declarada es más útil que un número falsamente limpio.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
