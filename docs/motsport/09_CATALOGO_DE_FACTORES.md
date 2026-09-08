# 09 · Catálogo de factores

> Todo lo que puede mover el resultado de un partido, ordenado, definido y con su fuente.
> Este catálogo **no vive en código**: vive en base de datos, versionado. Este documento es su especificación.

---

## 1. Cómo funciona el catálogo

Dos tablas, y todo lo demás se deriva de ellas:

```sql
catalogo_factores
  clave              -- 'viento_velocidad', 'dias_descanso', 'altitud_sede'
  familia            -- ambiente | disponibilidad | carga | forma | contexto | estilo | mercado
  deportes           -- a que deportes aplica; vacio = a todos
  nombre             -- nombre legible en espanol
  definicion         -- que mide exactamente
  unidad             -- km/h, dias, metros, porcentaje, indice
  fuente             -- de donde sale
  direccion_buena    -- si un valor alto es bueno, malo o depende
  version            -- se versiona; nunca se edita en su lugar
```

```sql
factores_partido
  tenant_id
  partido_id
  factor_clave
  equipo_id          -- nulo si el factor es del partido, no de un equipo
  valor
  fuente
  obtenido_ts
  confianza
```

**Por qué así:** el conocimiento del dominio cambia más rápido que el software. Si mañana descubrimos que la ráfaga importa más que la velocidad media del viento, eso debe ser una fila nueva y un peso ajustado, **no un despliegue**. Y si un umbral resulta estar mal —"viento adverso" son 22 km/h y no 25— eso es un `UPDATE`, no un *release*.

---

## 2. Familia · Ambiente

El clima es el factor contextual mejor documentado que existe, y el peor integrado en las herramientas actuales.

| Clave | Qué mide | Unidad | Fuente |
|---|---|---|---|
| `temperatura` | Temperatura del aire a la hora del partido | °C | Open-Meteo |
| `sensacion_termica` | Temperatura aparente | °C | Open-Meteo |
| `humedad_relativa` | Humedad | % | Open-Meteo |
| `indice_calor` | Combinación de temperatura y humedad | índice | Derivado |
| `viento_velocidad` | Velocidad media del viento | km/h | Open-Meteo |
| `viento_rafaga` | Ráfaga máxima | km/h | Open-Meteo |
| `precipitacion` | Lluvia acumulada en la ventana del partido | mm | Open-Meteo |
| `presion` | Presión atmosférica | hPa | Open-Meteo |
| `visibilidad` | Visibilidad | m | Open-Meteo |
| `altitud_sede` | Altitud del estadio sobre el nivel del mar | m | Catálogo de sedes |
| `techo` | Estadio techado, abierto o retráctil (y su estado) | categoría | Catálogo de sedes |
| `superficie` | Césped natural, híbrido o sintético | categoría | Catálogo de sedes |
| `dimensiones_cancha` | Largo × ancho | m | Catálogo de sedes |

### Lo que dice la evidencia

- **El viento es el factor climático que más pesa en fútbol americano.** Afecta la trayectoria del balón: degrada el juego aéreo y la precisión de los pateadores, y reduce los puntos por partido de **ambos** equipos.
- **Los extremos de temperatura reducen la anotación.** Los partidos por arriba de ~29 °C o por debajo de ~-4 °C muestran una caída cercana al 8 % en puntos anotados; entre -4 °C y 10 °C, alrededor del 5 %.
- **En fútbol, el óptimo de rendimiento físico está cerca de los 22 °C con menos de 60 % de humedad.** Por encima de eso, el calor y la humedad impiden la evaporación del sudor y el desempeño cae; alrededor de los 30 °C, la carrera de alta intensidad se desploma notoriamente **en los últimos 15 minutos** — que es justo cuando se deciden los partidos.
- **Los factores meteorológicos influyen sobre todo en las variables ofensivas**, que son las que separan ganar, empatar y perder.

Esto no se codifica como reglas: se convierte en **features del modelo predictivo** y en **señales visibles** en la pantalla de Radar y en el Centro de Partido.

---

## 3. Familia · Disponibilidad

| Clave | Qué mide | Unidad |
|---|---|---|
| `lesionados` | Jugadores no disponibles por lesión, con su peso en el once habitual | conteo ponderado |
| `suspendidos` | No disponibles por sanción | conteo |
| `convocatorias_internacionales` | Ausentes por selección | conteo |
| `alineacion_probable` | Once estimado, con nivel de certeza | lista + confianza |
| `alineacion_confirmada` | Once oficial, cuando se publica | lista |
| `minutos_acumulados` | Minutos por jugador en las últimas 3 y 6 semanas | minutos |
| `regreso_de_lesion` | Partidos desde la reincorporación | conteo |

**La pieza que más valor agrega no es la lista de lesionados: es su peso.** Que falten tres jugadores no dice nada; que falte el que juega el 92 % de los minutos, sí. Por eso `lesionados` es un conteo **ponderado** por participación habitual.

---

## 4. Familia · Carga y viaje

| Clave | Qué mide | Unidad |
|---|---|---|
| `dias_descanso` | Días desde el partido anterior | días |
| `diferencia_descanso` | Días de descanso propios menos los del rival | días |
| `partidos_7d` / `partidos_14d` | Congestión de calendario | conteo |
| `km_recorridos` | Distancia del viaje al partido | km |
| `husos_cruzados` | Diferencia horaria respecto a la sede habitual | horas |
| `back_to_back` | Partidos en días consecutivos (relevante en NBA) | booleano |
| `entre_semana` | Partido en día laboral | booleano |

La `diferencia_descanso` suele importar más que el descanso absoluto: lo que pesa es llegar peor que el rival, no llegar cansado.

---

## 5. Familia · Forma y fuerza

| Clave | Qué mide | Unidad |
|---|---|---|
| `rating_elo` | Rating tipo Elo, calibrado por deporte | puntos |
| `forma_reciente` | Rendimiento ponderado de los últimos N partidos, con más peso a los recientes | índice |
| `racha` | Resultados consecutivos del mismo signo | conteo con signo |
| `rendimiento_local` / `rendimiento_visitante` | Diferencia de desempeño según localía | índice |
| `nivel_competencia` | Ajuste por la dificultad de los rivales enfrentados | índice |

`nivel_competencia` es lo que evita la trampa más común del análisis: confundir una buena racha con un buen equipo cuando la racha se hizo contra rivales débiles.

---

## 6. Familia · Contexto

| Clave | Qué mide | Unidad |
|---|---|---|
| `importancia` | Peso del partido: liga regular, definición, descenso, clásico | categoría |
| `rivalidad` | Si es un clásico o derbi | booleano |
| `posicion_tabla` | Posición y distancia a los objetivos | posición + puntos |
| `entrenador_nuevo` | Partidos desde el cambio de entrenador | conteo |
| `arbitro` | Tarjetas y faltas por partido del árbitro designado | promedio |
| `asistencia_esperada` | Público estimado contra capacidad | % |

---

## 7. Familia · Estilo táctico

| Clave | Fútbol | Basquetbol | Fútbol americano |
|---|---|---|---|
| Ritmo | Posesiones por partido | **Pace** | Jugadas por partido |
| Control | Posesión % | — | Tiempo de posesión |
| Presión | **PPDA** (pases permitidos por acción defensiva) | Presión en balón | Tasa de presión al QB |
| Verticalidad | Pases progresivos, entradas al último tercio | Ritmo de transición | Yardas por intento aéreo |
| Riesgo | Altura de la línea defensiva | Tasa de triples | Tasa de jugadas explosivas |

---

## 8. Familia · Mercado

| Clave | Qué mide | Uso permitido |
|---|---|---|
| `cuota_consenso` | Cuota de mercado agregada | **Solo** como consenso externo para contrastar contra el modelo propio |
| `movimiento_cuota` | Cómo se movió la línea | Señal de información que el mercado tiene y nosotros no |

> ⛔ **Límite duro.** MotSport no integra casas de apuestas, no emite recomendaciones de apuesta y no calcula valor esperado sobre cuotas. Las cuotas entran únicamente como termómetro de consenso. La razón está en [`15_LEGAL.md`](15_LEGAL.md).
>
> Su valor real es de **diagnóstico interno**: si el modelo propio se desvía mucho del consenso de forma sistemática y pierde, el modelo está mal.

---

## 9. Métricas de rendimiento por deporte

Los factores de arriba son el contexto. Estas son las métricas del juego mismo.

### Fútbol

| Métrica | Qué mide |
|---|---|
| **xG** (goles esperados) | Calidad acumulada de las ocasiones |
| **xA** (asistencias esperadas) | Calidad de la creación |
| **xT** (amenaza esperada) | Valor que cada acción agrega a la probabilidad de gol |
| **PPDA** | Intensidad de la presión alta |
| Pases progresivos | Avance real con balón |
| Entradas al último tercio | Capacidad de llegada |
| Duelos ganados | Dominio individual |
| Recuperaciones en campo rival | Presión efectiva |
| xG concedido | Solidez defensiva más allá del marcador |

### Basquetbol

| Métrica | Qué mide |
|---|---|
| **Four Factors** (eFG%, TOV%, ORB%, FT rate) | Los cuatro determinantes del resultado |
| **Pace** | Posesiones por 48 minutos |
| **ORtg / DRtg / Net rating** | Puntos por 100 posesiones, a favor y en contra |
| **TS%** | Eficiencia de tiro real |
| **Usage** | Porcentaje de posesiones que termina el jugador |
| On/off y plus-minus ajustado | Impacto real en cancha |

### Fútbol americano

| Métrica | Qué mide |
|---|---|
| **EPA por jugada** | Puntos esperados agregados por jugada |
| **Success rate** | Porcentaje de jugadas que avanzan lo suficiente |
| Yardas por jugada | Eficiencia bruta |
| Conversión de terceras | Capacidad de sostener series |
| Eficiencia en zona roja | Convertir posición en puntos |
| Jugadas explosivas | Capacidad de romper el partido |
| Tasa de presión al QB | Dominio de la línea defensiva |

---

## 10. Cómo se agrega un factor nuevo

1. Se agrega la fila a `catalogo_factores` con su definición, unidad, fuente y dirección.
2. Se implementa su cálculo o su extracción en `apps/motor/`.
3. Si es candidato a entrar al modelo predictivo, se evalúa su aporte en el backtesting **antes** de incorporarlo. Un factor que no mejora la predicción no entra al modelo, aunque sea interesante: puede quedarse como información visible.
4. Se documenta aquí.

**Nunca se agrega un factor como constante en código.**

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
