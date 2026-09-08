# 11 · Modelos predictivos

> 🟡 **Segunda pasada.** Es entrega de Fase 2; se escribe completo antes de empezar a construirlo.

## Postura (decidida)

- Los modelos producen **probabilidades con explicación**, no pronósticos con aire de certeza.
- **Backtesting honesto o no se publica.** Se evalúa contra el consenso de mercado; si el modelo no lo supera de forma sostenida, se presenta como contexto y no como pronóstico. Decir eso es más valioso que fingir lo contrario, y es la única forma de que el equipo confíe en la herramienta.
- Se posiciona como insumo de decisión deportiva. **Nunca como recomendación de apuesta.** Ver [`15_LEGAL.md`](15_LEGAL.md).
- **Un factor que no mejora la predicción en el backtesting no entra al modelo**, por interesante que sea. Puede quedarse como información visible en la interfaz.

## Enfoque previsto

| Pieza | Enfoque candidato |
|---|---|
| Fuerza base | Rating tipo Elo, calibrado por deporte |
| Fútbol | Modelo de goles tipo Poisson con corrección de dependencia, alimentado con xG en vez de goles |
| Basquetbol | Modelo de margen sobre *pace* y ratings ofensivo/defensivo |
| Fútbol americano | Modelo sobre EPA y *success rate* |
| Ajuste contextual | Gradient boosting (LightGBM) sobre el catálogo de factores |
| Explicación | Contribución por factor, traducida a lenguaje natural por el asistente |

La separación en dos etapas —fuerza base y ajuste contextual— es deliberada: permite explicar el pronóstico en términos que un entrenador entiende («son parejos, pero el visitante llega con dos días menos de descanso y viento en contra para su juego aéreo») en vez de entregar un número opaco.

## Pendiente de escribir

- Lista de features derivada de [`09_CATALOGO_DE_FACTORES.md`](09_CATALOGO_DE_FACTORES.md)
- Protocolo de entrenamiento y **partición temporal, nunca aleatoria** — es una serie de tiempo, y partir al azar filtra el futuro al entrenamiento
- Métricas de calidad: Brier score, log-loss, curvas de calibración, comparación contra consenso
- Manejo de temporadas incompletas y de ligas con pocos datos
- Reentrenamiento: cada cuánto y con qué disparador
- Cómo se comunica la incertidumbre en la interfaz sin que se lea como certeza

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
