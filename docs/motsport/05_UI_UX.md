# 05 · Interfaz y experiencia de uso

> Escrito **después** de los mockups, no antes. Las decisiones de aquí no son teoría: salieron de construir las ocho pantallas de Fase 1 y ver qué funcionaba. Los mockups navegables están en [`mockups/`](mockups/) y su guía en [`06_MOCKUPS.md`](06_MOCKUPS.md).

---

## 1. Los seis principios

1. **Densidad alta de datos.** El analista quiere ver mucho a la vez. No se esconde información detrás de tres clics para que se vea limpio. Una tabla de nueve métricas con sus percentiles es más útil que tres tarjetas grandes con tres números.

2. **Oscuro por defecto.** Se trabaja en salas de video. El tema claro existe y funciona —se prueba en cada mockup— pero no es el que se abre.

3. **Teclado primero.** `Ctrl+K` abre el asistente desde cualquier pantalla. `/` enfoca la búsqueda. Toda la navegación debe ser posible sin ratón.

4. **Todo exportable.** Cualquier tabla o gráfica se copia, se descarga o se manda a un informe. Un dato que no se puede sacar de la herramienta acaba copiado a mano en una hoja de cálculo, que es exactamente el problema que vinimos a resolver.

5. **Una pregunta por pantalla.** Si una vista intenta responder dos preguntas distintas, se parte en dos. El Radar responde *¿qué merece mi atención?*; el Centro de Partido responde *¿cómo llega este partido?*; la Ficha de Jugador responde *¿qué clase de jugador es este?*.

6. **El dato dice de dónde vino.** Fuente, fecha y confianza visibles junto a la cifra, no escondidas detrás del cursor.

---

## 2. Las cuatro reglas que salieron de construir los mockups

Estas no estaban en el plan original. Aparecieron al hacer las pantallas y ahora son obligatorias.

### 2.1 Ningún percentil se muestra sin su escala de referencia

Un «percentil 91» no significa nada sin saber contra quién. En el Comparador y en Scouting, los cinco parámetros que definen la comparación están **permanentemente a la vista**, nunca en un menú desplegable:

- Competencia · Temporada · Posición · Mínimo de minutos · Tamaño de la muestra

Cambiar cualquiera de los cinco cambia todos los números de la pantalla. Esconderlos sería invitar al error más caro del análisis deportivo: **comparar dos jugadores que no son comparables** y no darse cuenta.

Corolario: cuando la muestra es chica, se dice. Un jugador con 400 minutos tiene percentiles volátiles y la interfaz lo advierte en vez de presentarlos con la misma firmeza que los de uno con 1,800.

### 2.2 La interfaz interpreta, no solo muestra

Cada pantalla cierra con una **lectura en prosa**: qué significa este perfil, qué tienen en común estos cuatro jugadores, qué hay que mirar de este equipo. Un tablero que solo pinta números deja el trabajo a medias y obliga al usuario a hacer la parte difícil.

El mejor ejemplo está en Scouting: los cuatro resultados están todos por debajo del percentil 62 en duelos, y la pantalla dice que **eso no es un accidente de la muestra sino lo que produce el filtro**. Buscar élite creativa sub-23 devuelve, casi por definición, perfiles que no defienden.

Esa lectura la genera el asistente y sigue sus mismas reglas: cita las filas que usó y no inventa un número.

### 2.3 Las reglas del usuario se escriben como frases en español

En Alertas, una regla se construye como *«Avísame si **el viento** en **un partido de mis equipos** **supera** **25 km/h**»*, con cada hueco elegido del catálogo de factores. No como un formulario con campos `factor`, `operador` y `umbral`.

El usuario no debería tener que saber que existe un factor llamado `viento_velocidad`. Y **si un factor no tiene fuente configurada, no aparece como opción**: no se puede alertar sobre un dato que no existe.

### 2.4 Una alerta que se dispara todos los días deja de leerse

Si una regla supera diez disparos al mes, MotSport propone subirle el umbral en vez de seguir mandándola. La utilidad de una alerta es inversamente proporcional a su frecuencia, y una herramienta que educa al usuario a ignorarla está peor que una que no alerta.

---

## 3. Navegación

Nueve destinos en la barra superior, siempre visibles, sin menús anidados:

`Radar · Partido · Equipo · Jugador · Comparador · Scouting · Alertas · Consola IA`

**El asistente no es un destino más: es una capa.** Se abre con `Ctrl+K` desde cualquier pantalla, en panel lateral, sin perder el contexto de lo que se estaba viendo. La entrada de menú existe para descubrirlo la primera vez.

Jerarquía de rutas prevista:

```
/                          Radar
/partido/:id               Centro de Partido
/equipo/:id                Ficha de Equipo
/jugador/:id               Ficha de Jugador
/comparar?entidades=...    Comparador (el estado vive en la URL: es compartible)
/scouting?filtros=...      Scouting (idem)
/alertas                   Reglas y avisos
/operacion                 Panel de operación
```

**El estado del Comparador y de Scouting vive en la URL.** Una búsqueda de scouting es un artefacto de trabajo que se comparte con el cuerpo técnico pegando un enlace; si el estado vive solo en memoria, no se puede.

---

## 4. Estados

Un producto de datos vive en los estados que no son el feliz. Cada vista debe resolver seis:

| Estado | Qué muestra |
|---|---|
| **Cargando** | Esqueleto con la forma del contenido, no un giro indefinido |
| **Vacío** | Qué falta y qué hacer: *«esta competencia todavía no está en la ingesta»* |
| **Dato parcial** | Se muestra lo que hay **y se declara el hueco**: *«faltan 3 de 17 jornadas, los percentiles pueden moverse»* |
| **Dato en conflicto** | Las dos fuentes, con su confianza. Ver [`07_MODELO_DE_DATOS.md`](07_MODELO_DE_DATOS.md) § 6 |
| **Dato viejo** | La antigüedad visible: *«última actualización hace 31 h»* |
| **Error** | Qué pasó, en español, y qué se puede hacer. Nunca un código |

**El estado más importante es «dato parcial»**, porque es el más común y el más peligroso: un análisis sobre datos incompletos presentado como si fueran completos es peor que no tener análisis.

---

## 5. Sistema visual

Los tokens están definidos y son navegables en [`mockups/fundaciones/tokens.html`](mockups/fundaciones/tokens.html); la fuente única es [`mockups/estilos.css`](mockups/estilos.css).

- **Color**: verde MOTRAE `#57AD30` como acento dominante sobre base oscura `#14181A` / `#2D3A42`. Degradado `#F2853A → #E0392B` solo para acentos de energía, con moderación.
- **Semántica de datos**: bueno / alerta / malo / neutro. **Nunca solo por color** — siempre acompañado de texto o número, por daltonismo y por fotocopias en blanco y negro.
- **Confianza**: verde, naranja y morado para alta, media y baja. El morado es deliberado: la confianza baja no es «malo», es «de otra naturaleza».
- **Tipografía**: Space Grotesk para títulos y cifras, Inter para cuerpo. Las cifras siempre con `font-variant-numeric: tabular-nums` para que las columnas alineen.
- **Espaciado**: escala de 4, de 4 a 64 px.

---

## 6. Responsivo

Tres puntos de quiebre: escritorio (>1100 px), tablet (720–1100 px) y teléfono (<720 px).

En teléfono el orden de prioridad es: **señales primero, cifras después, tablas al final**. Un cuerpo técnico revisando el Radar desde el campo quiere ver «viento 34 km/h» sin desplazarse; la tabla de percentiles puede esperar a la laptop.

---

## 7. Accesibilidad

Compromiso mínimo, verificable en cada pantalla:

- Contraste **AA** en todo texto; AAA en el cuerpo cuando se pueda
- **Foco visible** en todo elemento interactivo
- Navegación completa por teclado, con orden de tabulación lógico
- Todo color con equivalente textual
- Tablas con encabezados correctos para lectores de pantalla
- Objetivos táctiles de al menos 44 px en móvil

---

## 8. Escritura

- **Español siempre**, incluidos los mensajes de error.
- **Segunda persona, tono directo.** *«Avísame si…»*, no *«El sistema notificará al usuario cuando…»*.
- **Sin jerga innecesaria, pero sin infantilizar.** El usuario sabe qué es un xG; no sabe —ni tiene por qué— qué es `catalogo_factores`.
- **Las cifras se acompañan de su unidad y su referencia.** «8.4 pases progresivos por 90 minutos, percentil 91 de su liga», no «8.4».
- **Los errores dicen qué hacer**, no qué falló.

---

## 9. Pendiente

- Especificación de componentes con sus variantes y estados (se hace al construir `packages/ui/`)
- Animación y transiciones: por ahora, la regla es que nada se mueve sin razón
- Modo de impresión para los informes de Fase 2

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
