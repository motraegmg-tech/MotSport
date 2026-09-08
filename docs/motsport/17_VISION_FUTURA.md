# 17 · Visión futura

> **Todo lo que excede el alcance vive aquí, no en el plan de trabajo.**
> Una idea escrita en este documento está a salvo: no se pierde y no se cuela. Cuando alguien proponga algo fuera de alcance, la respuesta correcta no es "no", es *"va al 17"*.

Nada de este documento está comprometido. Nada tiene fecha.

---

## Análisis de video

Ingesta de partidos grabados, etiquetado de jugadas con atajos de teclado, generación de clips y listas de reproducción, sincronización de los eventos de la base con el minuto del video.

**Por qué no está en el plan:** es prácticamente un segundo producto —almacenamiento pesado, transcodificación, un editor entero— y compite de frente con Hudl Sportscode, que lleva años de ventaja. Se evalúa en Fase 4 y solo si el mercado lo pide de forma insistente.

**El puente barato, si algún día se quiere:** no construir el reproductor, sino **sincronizar con el video que el club ya tiene**. Que al hacer clic en un evento de la base se abra su minuto en la herramienta que ya usan.

---

## Integración de datos propios del club

GPS y carga de entrenamiento (Catapult, WIMU), datos médicos, pruebas físicas, informes internos del cuerpo técnico.

**Por qué no está en el plan:** cambia el nivel de exigencia legal por completo. Datos médicos y biométricos de personas identificables exigen consentimiento, cifrado, política de retención y contrato de encargado del tratamiento. Ver [`15_LEGAL.md`](15_LEGAL.md).

**Cuando se haga**, es probablemente la función que más diferencia: cruzar la carga real del jugador con el contexto del próximo partido es exactamente lo que hoy no hace nadie.

---

## API para clientes

Que un club consuma los datos ya normalizados y las métricas derivadas desde sus propias herramientas.

**Depende por completo del contrato de datos**: redistribuir por API es un derecho distinto —y más caro— que mostrar en pantalla. Se negocia junto con el proveedor en Fase 3, o no se ofrece.

---

## Modelos por deporte más profundos

- Fútbol: modelo de posesión con valor esperado por acción (EPV) y simulación de alineaciones
- Basquetbol: modelo de lineups y ajuste por matchups
- Fútbol americano: modelo de series por *down* y situación

Se evalúan cuando haya varias temporadas acumuladas. Un modelo sofisticado sobre dos meses de datos es una ilusión.

---

## Informes generados automáticamente

Que la previa del rival se escriba sola cada semana y llegue por correo. La base técnica ya existe desde Fase 2 —el generador de PDF y el asistente—; lo que falta es la programación y la plantilla por club.

---

## Multideporte ampliado

Béisbol, tenis, voleibol, deportes de motor. **El modelo de datos está diseñado para que agregar un deporte sea insertar filas en el catálogo, no migrar el esquema** — así que esto es cuestión de conectores y de métricas, no de arquitectura.

---

## Otras ideas sin desarrollar

- Modo entrenador: convertir el análisis en una sesión de entrenamiento propuesta
- Comparador de mercado de fichajes con valor estimado
- Detección de patrones tácticos repetidos del rival
- Alertas por voz o por WhatsApp
- Modo público: fichas compartibles con la marca del club
- Histórico de decisiones: registrar qué se decidió y contrastarlo con el resultado

---

## Cómo se usa este documento

1. Alguien propone algo fuera de alcance.
2. Se escribe aquí, con dos líneas de por qué podría valer la pena y por qué no es ahora.
3. Al cerrar cada fase, se relee este documento completo y se decide si algo se gradúa al plan.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
