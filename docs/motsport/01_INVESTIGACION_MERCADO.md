# 01 · Investigación de mercado

> Quién ya juega en esta cancha, qué hace cada uno y **cuál es el hueco que MotSport ocupa**.
> Investigación de septiembre de 2026. Precios y posicionamientos cambian; verificar antes de usarlos en un argumento comercial.

---

## 1. El mapa

El sector está partido en cuatro grupos que casi no compiten entre sí. Entender esa partición es entender dónde cabe MotSport.

| Grupo | Quiénes | Qué venden |
|---|---|---|
| **Video y análisis de rendimiento** | Hudl (Sportscode, Wyscout, InStat), Veo, Pixellot | Grabar, etiquetar, cortar y compartir video |
| **Datos de evento y tracking** | Stats Perform (Opta), StatsBomb, Second Spectrum, Sportradar, Genius Sports | El dato crudo, vendido a clubes, medios y casas de apuestas |
| **Carga física y prevención** | Catapult, Zone7 | GPS, carga de entrenamiento, riesgo de lesión |
| **Herramientas de análisis propias** | Hojas de cálculo, R, Python, tableros caseros | Lo que el analista se construye porque nadie se lo vende junto |

---

## 2. Los que hay que conocer

### Hudl — el gigante consolidado

Absorbió **Wyscout** e **InStat**, y en 2025 los fusionó en un solo producto. Hoy Hudl es el estándar de facto en tres frentes:

- **Wyscout** — el estándar global de scouting en fútbol. Video de cientos de ligas, con datos de evento al lado, filtros, listas y clips de scouting. Flujo *video-first*.
- **Sportscode** — análisis de rendimiento profesional: etiquetado de video con scripting, integración con GPS (WIMU) para responder preguntas sobre demanda física.
- Un club profesional típico usa **Sportscode para rendimiento + Wyscout para scouting**.

**Qué no resuelve:** el contexto que rodea al partido. Clima, viaje, descanso, altitud y disponibilidad ponderada no están cruzados con el rendimiento en ninguno de sus productos. Y nada de eso se pregunta en lenguaje natural.

### StatsBomb (hoy parte de Hudl)

Profundidad a nivel de evento con calidad de investigación: cada acción del campo, con coordenadas y con *freeze frames* de las posiciones de todos los jugadores en el momento del tiro. Es la base sobre la que se construyen los modelos serios de xG y xT.

Publica un subconjunto como **Open Data**, gratuito, con atribución y **prohibido para uso comercial** — que es exactamente el rol que le damos en MotSport: calibrar modelos, nunca servir al cliente. Ver [`15_LEGAL.md`](15_LEGAL.md).

### Second Spectrum, Catapult, Zone7

Tracking óptico, carga física y predicción de riesgo de lesión. Juegan en una capa distinta —el cuerpo del atleta, no el contexto del partido— y son complementarios, no competencia. En Fase 4, integrar datos de GPS del club es una extensión natural.

### Sportradar, Genius Sports, Opta

Proveedores de dato oficial a escala industrial. Su cliente principal es el mercado regulado de apuestas y los medios. Para MotSport son **proveedores potenciales**, no competidores.

### Lo que el analista se construye solo

El competidor más real y el menos visible. Una hoja de cálculo con datos pegados a mano, un cuaderno de R, un tablero casero. Gana en que está hecho exactamente a la medida; pierde en que se rompe con cada temporada, no se comparte y consume media jornada por partido.

---

## 3. El hueco

Los datos deportivos son abundantes y mayormente públicos. **Lo que nadie vende junto es el contexto cruzado con el rendimiento, interrogable en lenguaje natural.**

Concretamente, hoy no existe una herramienta que responda de una sola vez:

> *"¿Conviene rotar el mediocampo el sábado?"*
> — considerando minutos acumulados, diferencia de descanso contra el rival, calor y humedad previstos en esa ciudad a esa hora, historial contra ese entrenador y forma del suplente.

Esas cinco piezas viven hoy en cinco herramientas. Ninguna de las cuatro categorías del mapa las junta.

### Los tres pilares del hueco

1. **Contexto integrado.** El catálogo de factores —ambiente, disponibilidad ponderada, carga y viaje, forma, árbitro— cruzado con rendimiento. Es justo lo que los proveedores de datos **no** entregan cruzado, porque su producto es el dato, no el análisis.
2. **Multideporte de verdad.** Wyscout es de fútbol. Los productos de NBA son de NBA. Un cuerpo técnico o un analista que trabaja en más de un deporte cambia de herramienta y de vocabulario. MotSport usa el mismo modelo y la misma pregunta en los tres.
3. **Interrogable en español.** No es un chatbot encima de un tablero: es un asistente con acceso tipado a la base, que responde con números que cita. Ninguna de las herramientas del mapa lo tiene resuelto.

---

## 4. Dónde MotSport **no** compite

Decirlo explícitamente evita que el alcance se estire:

- **No compite en video.** Sportscode lleva años de ventaja y es un producto entero. Ver la regla de oro en [`02_MASTER_PLAN.md`](02_MASTER_PLAN.md).
- **No compite en tracking óptico ni en GPS.** Es otra capa; en Fase 4 se integra, no se replica.
- **No compite en venta de dato crudo.** Somos consumidores de esos proveedores, no su alternativa.
- **No compite en apuestas.** Decisión de posicionamiento y de riesgo legal. Ver [`15_LEGAL.md`](15_LEGAL.md).

---

## 5. Segmento desatendido

El grupo con el dolor más claro y sin oferta razonable: **academias, fuerzas básicas y clubes medianos**. No pueden pagar el escalón de club de Hudl, y por debajo de eso no hay nada serio: caen de vuelta a la hoja de cálculo.

Es un segmento que MotSport puede atender bien porque su costo marginal por cliente es bajo —el dato ya está ingerido, lo que se suma es consulta de IA—, y es el mejor candidato para las primeras entrevistas de validación de precio en Fase 3.

---

## 6. Fuentes

- Hudl — [Wyscout](https://www.hudl.com/en_gb/products/wyscout) · [Sportscode](https://www.hudl.com/products/sportscode) · [productos](https://www.hudl.com/products)
- [StatsBomb Open Data](https://github.com/statsbomb/open-data)
- [SportMonks — comparativa de APIs de fútbol](https://www.sportmonks.com/football-api/alternatives/)
- [LSports — cuánto cuestan los datos deportivos en 2026](https://www.lsports.eu/blog/sports-data-cost/)
- [Highlightly — mejores APIs de NBA / NFL](https://highlightly.net/blogs/best-nba-apis-in-2026)

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
