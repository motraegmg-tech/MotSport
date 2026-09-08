# 06 · Mockups

> Las fundaciones y las diez pantallas están hechas. Verificadas en navegador, en tema oscuro y claro, el 8 de septiembre de 2026.

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
| [`mockups/pantallas/ficha-equipo.html`](mockups/pantallas/ficha-equipo.html) | Pantalla 3 · Ficha de Equipo | ✅ |
| [`mockups/pantallas/ficha-jugador.html`](mockups/pantallas/ficha-jugador.html) | Pantalla 4 · Ficha de Jugador | ✅ |
| [`mockups/pantallas/comparador.html`](mockups/pantallas/comparador.html) | Pantalla 5 · Comparador | ✅ |
| [`mockups/pantallas/scouting.html`](mockups/pantallas/scouting.html) | Pantalla 6 · Scouting | ✅ |
| [`mockups/pantallas/consola-ia.html`](mockups/pantallas/consola-ia.html) | Pantalla 7 · Consola IA | ✅ |
| [`mockups/pantallas/informes.html`](mockups/pantallas/informes.html) | Pantalla 8 · Informes (entrega de Fase 2) | ✅ |
| [`mockups/pantallas/alertas.html`](mockups/pantallas/alertas.html) | Pantalla 9 · Alertas | ✅ |
| [`mockups/pantallas/operacion.html`](mockups/pantallas/operacion.html) | Pantalla 10 · Panel de operación | ✅ |

**Las diez pantallas están hechas.** Con esto termina la Fase 0 de diseño.

## Seis decisiones que estos mockups ya fijan

1. **La señal es la unidad de valor del Radar.** «Viento 34 km/h», «3 días menos de descanso», «duda el central titular»: un hecho del contexto en cuatro palabras. No es opinión ni pronóstico — es un dato que amerita mirarse.
2. **Todo dato lleva su sello de procedencia visible**, con un punto de color según la confianza. No escondido detrás del cursor: a la vista, junto a la cifra.
3. **En la Consola IA, las herramientas que llamó el asistente quedan visibles** arriba de cada respuesta, y cada cifra cita su fuente y su fecha. El tercer intercambio del mockup es a propósito uno donde **el asistente dice que no tiene el dato** — ese es el comportamiento que hay que construir, no el que hay que evitar.
4. **Ningún percentil se muestra sin su escala de referencia.** En el Comparador y en Scouting, los cinco parámetros que definen la comparación —competencia, temporada, posición, mínimo de minutos y tamaño de muestra— están permanentemente a la vista, porque cambiar cualquiera cambia todos los números de la pantalla.
5. **Las reglas de alerta se escriben como frases en español**, no como formularios de campos. El usuario no debería tener que saber que existe un factor llamado `viento_velocidad`.
6. **La interfaz interpreta, no solo muestra.** Cada pantalla cierra con una lectura en prosa —qué significa este perfil, qué tienen en común estos cuatro jugadores, qué hay que mirar de este equipo—. Un tablero que solo pinta números deja el trabajo a medias.

## Qué fase muestran los mockups

**Muestran el producto completo, no el recorte de Fase 1.** Es deliberado: sirven para juzgar hacia dónde va MotSport, no para especificar la primera entrega. Dos diferencias concretas a tener presentes:

- **Las probabilidades de resultado son de Fase 2.** El Radar y el Centro de Partido muestran un pronóstico porque así se ve el producto terminado; en Fase 1 no se muestra ninguna probabilidad, porque el modelo con backtesting es entrega de Fase 2. Ver [`10_INTELIGENCIA_ARTIFICIAL.md`](10_INTELIGENCIA_ARTIFICIAL.md) § 3 y [`11_MODELOS_PREDICTIVOS.md`](11_MODELOS_PREDICTIVOS.md).
- **Las fuentes citadas cambian en Fase 3.** El mockup de la Consola IA cita `statsbomb` junto a una respuesta al usuario. Eso es correcto mientras el uso sea interno, y **deja de serlo el día que se cobre**: ver [`15_LEGAL.md`](15_LEGAL.md).

## Reglas de los mockups

- **HTML y CSS puros**, sin framework. Se abren con doble clic, sin instalar nada.
- **Con datos falsos pero realistas.** Un mockup lleno de texto de relleno no permite juzgar densidad ni longitudes reales, que es justo lo que hay que juzgar en un producto de datos.
- **Se construyeron primero las cuatro críticas** —Radar, Centro de Partido, Ficha de Jugador y Consola IA—, porque si esas cuatro funcionan, el producto funciona. Las otras seis salieron después y más rápido, apoyadas en los mismos componentes.
- Deben verse correctos en tema claro y oscuro, y en pantalla de teléfono.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
