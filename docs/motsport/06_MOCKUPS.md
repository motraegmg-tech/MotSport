# 06 · Mockups

> Las fundaciones y las cuatro pantallas críticas están hechas. Faltan las seis pantallas restantes, que son variaciones sobre los mismos componentes.

**Empieza por [`mockups/index.html`](mockups/index.html)** — desde ahí se navega todo.

## Qué hay

| Archivo | Contenido | Estado |
|---|---|---|
| [`mockups/index.html`](mockups/index.html) | Índice navegable de todos los mockups | ✅ |
| [`mockups/estilos.css`](mockups/estilos.css) | Tokens y componentes compartidos por todas las páginas | ✅ |
| [`mockups/fundaciones/tokens.html`](mockups/fundaciones/tokens.html) | Color, tipografía, espaciado, semántica de datos, niveles de confianza | ✅ |
| [`mockups/fundaciones/componentes.html`](mockups/fundaciones/componentes.html) | Señales, sellos de procedencia, percentiles, tarjetas de partido, dato en conflicto, estados | ✅ |
| [`mockups/pantallas/radar.html`](mockups/pantallas/radar.html) | Pantalla 1 · Radar | ✅ |
| [`mockups/pantallas/centro-partido.html`](mockups/pantallas/centro-partido.html) | Pantalla 2 · Centro de Partido (estado «previa») | ✅ |
| [`mockups/pantallas/ficha-jugador.html`](mockups/pantallas/ficha-jugador.html) | Pantalla 4 · Ficha de Jugador | ✅ |
| [`mockups/pantallas/consola-ia.html`](mockups/pantallas/consola-ia.html) | Pantalla 7 · Consola IA | ✅ |
| Pantallas 3, 5, 6, 8, 9 y 10 | Equipo, Comparador, Scouting, Informes, Alertas, Operación | 🟡 pendiente |

## Tres decisiones que estos mockups ya fijan

1. **La señal es la unidad de valor del Radar.** «Viento 34 km/h», «3 días menos de descanso», «duda el central titular»: un hecho del contexto en cuatro palabras. No es opinión ni pronóstico — es un dato que amerita mirarse.
2. **Todo dato lleva su sello de procedencia visible**, con un punto de color según la confianza. No escondido detrás del cursor: a la vista, junto a la cifra.
3. **En la Consola IA, las herramientas que llamó el asistente quedan visibles** arriba de cada respuesta, y cada cifra cita su fuente y su fecha. El tercer intercambio del mockup es a propósito uno donde **el asistente dice que no tiene el dato** — ese es el comportamiento que hay que construir, no el que hay que evitar.

## Reglas de los mockups

- **HTML y CSS puros**, sin framework. Se abren con doble clic, sin instalar nada.
- **Con datos falsos pero realistas.** Un mockup lleno de texto de relleno no permite juzgar densidad ni longitudes reales, que es justo lo que hay que juzgar en un producto de datos.
- **Las cuatro críticas primero.** Si Radar, Centro de Partido, Ficha de Jugador y Consola IA funcionan, el producto funciona.
- Deben verse correctos en tema claro y oscuro, y en pantalla de teléfono.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
