# 15 · Legal

> Este documento existe para responder una sola pregunta con precisión: **¿qué podemos hacer hoy con cada dato, y qué tendríamos que cambiar el día que cobremos por esto?**

**No es asesoría legal.** Es el trabajo de investigación que MOTRAE hizo en septiembre de 2026 para poder tomar decisiones de ingeniería informadas. Antes de firmar cualquier contrato o de emitir la primera factura, esto se revisa con abogado.

---

## 1. La distinción que ordena todo

Hay dos cosas separadas, y confundirlas es el error caro:

| | Qué es | Cómo nos afecta |
|---|---|---|
| **El hecho** | Que un partido terminó 2-1. Que hizo 34 °C. Que un jugador corrió 9.4 km | Un hecho no es de nadie. No hay derecho de autor sobre un marcador |
| **La base de datos y su presentación** | La compilación, la estructura, el texto editorial, y sobre todo **el contrato que aceptaste para acceder a ella** | Aquí sí hay derechos, y aquí sí se pierde un juicio |

Traducido: **nadie nos puede impedir saber que un partido terminó 2-1.** Lo que sí nos puede impedir es *tomar ese dato de su servidor* si aceptamos unos términos que lo prohíben. El riesgo real de este producto no es de derecho de autor: es **contractual**.

---

## 2. Estado actual — uso interno

**Hoy MotSport es una herramienta interna de MOTRAE, usada por Gonzalo y su equipo. No se distribuye, no se vende, no tiene usuarios externos.**

Bajo esa condición, las fuentes de la Fase 1 son correctas:

| Fuente | Qué permite hoy | ¿Sirve al comercializar? |
|---|---|---|
| **StatsBomb Open Data** | Uso libre para investigación y análisis, **con atribución** | ⛔ **No.** Prohíbe explícitamente el uso comercial |
| **Open-Meteo (gratuito)** | 10,000 consultas/día, **no comercial** | ⛔ **No** en el tier gratuito. ✅ Sí con el plan de pago, que incluye licencia comercial |
| **API-Football (gratuito)** | 100 consultas/día | 🟡 **Por verificar.** Hay planes de pago; hay que leer qué permiten exactamente respecto a mostrar el dato a un tercero que paga |
| **football-data.org** | Uso libre en competiciones abiertas | 🟡 Por verificar para uso comercial |
| **balldontlie** | Tier gratuito | 🟡 Por verificar |
| **Búsqueda web (Claude)** | Lectura de fuentes públicas, citando | ✅ Sí, siempre citando y sin almacenar el contenido ajeno como si fuera propio |

**Consecuencia práctica para quien programa hoy:** puedes usar todo lo de arriba sin problema. Lo único que se te pide es que **cada fila lleve su `fuente`**, para que el día de la migración se sepa exactamente qué hay que resembrar.

---

## 3. La compuerta de la Fase 3

**Antes del primer peso cobrado**, esto tiene que estar hecho. No es negociable ni aplazable: es la diferencia entre un producto y un problema.

1. **Contratar un proveedor con derecho de redistribución.** Recomendación: SportMonks (~€29–249/mes según catálogo). Alternativa si un cliente exige dato oficial de liga: Sportradar u Opta, con contrato anual enterprise.
2. **Sacar StatsBomb Open Data de todo lo que el usuario ve.** Puede seguir usándose para investigación interna y para calibrar modelos, pero ningún número servido a un cliente que paga puede venir de ahí.
3. **Migrar Open-Meteo al plan de pago**, que es lo que otorga la licencia comercial. Es una migración de plan, no de conector.
4. **Verificar y, si hace falta, sustituir** API-Football, football-data.org y balldontlie según lo que digan sus términos comerciales al momento.
5. **Leer con abogado la cláusula de reventa** del proveedor elegido. Sportradar, por ejemplo, otorga licencia amplia para usar y distribuir el contenido pero **prohíbe poner el servicio a disposición de terceros en modo *service bureau*** sin autorización. Un SaaS multi-cliente puede caer o no en esa definición según cómo esté redactado el contrato. Esta es la cláusula que hay que negociar, no el precio.
6. **Cumplir la atribución** que cada proveedor exija, en el lugar y con el formato que exija.

Esa lista vive también, con el resto de los requisitos de comercialización, en [`16_DISTRIBUCION_Y_PRECIOS.md`](16_DISTRIBUCION_Y_PRECIOS.md).

---

## 4. Lo que no hacemos, por decisión

**No hacemos scraping de sitios que lo prohíben.** Existen librerías conocidas y funcionales para extraer datos de FBref, Understat, Sofascore o WhoScored. Varios de esos sitios lo prohíben en sus términos. Aunque el hecho subyacente no sea propiedad de nadie, aceptar unos términos y violarlos es un problema contractual, y MOTRAE no construye un producto que quiere vender sobre esa base. Si una de esas fuentes se vuelve indispensable, se busca su origen licenciable.

**No integramos casas de apuestas ni emitimos recomendaciones de apuesta.** Las cuotas, si entran, entran únicamente como señal de consenso externo para contrastar contra el modelo propio. La razón es doble: posicionamiento —MotSport es una herramienta de preparación de partido y scouting, y ese es el mercado que queremos— y regulatoria: en el momento en que un producto recomienda apuestas, entra en un régimen legal completamente distinto en México y en las tiendas de aplicaciones. Ver [`16_DISTRIBUCION_Y_PRECIOS.md`](16_DISTRIBUCION_Y_PRECIOS.md).

---

## 5. Datos personales

Los datos de jugadores profesionales publicados por las ligas son información pública de figuras públicas en su actividad profesional. Aun así, cuando MotSport tenga usuarios externos (Fase 3) aplican dos cosas:

- **Los datos de nuestros usuarios** (nombre, correo, actividad en la plataforma) caen bajo la **Ley Federal de Protección de Datos Personales en Posesión de los Particulares**. Hace falta aviso de privacidad. Se reutiliza el esqueleto de `legal/` de MotRest.
- **Si un club sube datos propios de sus jugadores** —GPS, cargas, información médica (Fase 4)—, eso es información sensible de personas identificables y cambia el nivel de exigencia por completo: consentimiento, cifrado, retención, y contrato de encargado del tratamiento. **No se acepta ese tipo de dato sin resolver esto antes.**

---

## 6. Propiedad del producto

MotSport es desarrollo propio de **MOTRAE**. Código, modelos, esquema y documentación son propiedad de la empresa. Las dependencias de terceros son de código abierto con licencias permisivas; la política de dependencias está en [`12_STACK_TECNOLOGICO.md`](12_STACK_TECNOLOGICO.md).

---

## 7. Bitácora de revisión

| Fecha | Qué se revisó | Quién |
|---|---|---|
| Sep 2026 | Investigación inicial de licencias de fuentes de datos y redacción de este documento | MOTRAE |
| _pendiente_ | Revisión con abogado antes de Fase 3 | — |

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
