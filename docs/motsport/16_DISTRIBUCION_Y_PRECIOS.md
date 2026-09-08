# 16 · Distribución y precios — La lista de Fase 3

> **Este documento se escribe hoy aunque se ejecute dentro de un año.** No es planeación adelantada por gusto: es lo que evita construir hoy algo que haya que tirar después.

MotSport es hoy una herramienta de uso interno de MOTRAE. Este documento describe **todo lo que tiene que pasar para que deje de serlo** y pueda venderse.

---

## 1. El principio: costuras sí, fábrica no

| Se construye desde la Fase 0 (las costuras) | Se construye hasta la Fase 3 (la fábrica) |
|---|---|
| `tenant_id` en cada tabla con RLS activa | Alta de organizaciones, invitaciones, roles por club |
| Capa de proveedores de datos intercambiables | Contratos con proveedores de pago |
| Procedencia obligatoria por dato | Planes, límites, facturación, cobro recurrente |
| Métricas por catálogo versionado | Portal de suscripción y tiendas de aplicaciones |
| Medición de costo de IA por consulta | Presupuestos por plan y facturación del consumo |
| Documentación portátil y ADR | Términos de servicio, EULA, contrato de suscripción |

**El criterio para decidir de qué lado va cada cosa:** ¿cuánto cuesta meterla después? Si meterla después obliga a reescribir el sistema, va en las costuras. Si conectarla después cuesta semanas y nada más, es fábrica y espera.

`tenant_id` es el ejemplo canónico: hoy cuesta una columna y una política por tabla; en un año obliga a auditar cada consulta del sistema con la certeza de que una se escapa y filtra datos entre clientes. Una pasarela de cobro, en cambio, se conecta en dos semanas el día que haga falta.

---

## 2. Los ocho puntos

### 1. Licencia de datos con derecho de redistribución 🔴 BLOQUEANTE

**Sin esto no se cobra un peso.** Las fuentes actuales son legales para uso interno y varias dejan de serlo en el momento en que hay un cliente pagando.

- Contratar un proveedor con derecho de redistribución. **Recomendación: SportMonks** (~€29–249/mes según catálogo), por precio público y sin contrato anual mínimo. Alternativa si un cliente exige dato oficial de liga: Sportradar u Opta, en contrato anual enterprise (~€1,300–4,990+/mes).
- **Sacar StatsBomb Open Data de todo lo que el usuario ve.** Puede seguir usándose para investigación y calibración interna.
- **Migrar Open-Meteo al plan de pago**, que es lo que otorga la licencia comercial. Es cambio de plan, no de conector.
- Verificar API-Football, football-data.org y balldontlie contra sus términos comerciales vigentes.
- **Negociar la cláusula de reventa**, no el precio. Es la que decide si un SaaS multi-cliente cabe en el contrato.

Detalle completo en [`15_LEGAL.md`](15_LEGAL.md).

### 2. Activar el multi-tenant

La costura ya está puesta. Lo que falta es la maquinaria encima:

- **Sembrar los catálogos del tenant nuevo.** Deportes, métricas, factores y fuentes son **por tenant**: un cliente recién dado de alta abre con la base vacía si nadie los copia del tenant plantilla. Lo detectó la auditoría del esquema — ver [`07_MODELO_DE_DATOS.md`](07_MODELO_DE_DATOS.md) § 10, hallazgo 4.

- Alta y administración de organizaciones
- Invitaciones y gestión de usuarios por organización
- Roles: administrador del club, cuerpo técnico, analista, solo lectura
- Aislamiento verificado con pruebas de penetración entre tenants

### 3. Facturación y planes

- Definición de planes y qué límite mueve cada uno: consultas de IA, ligas incluidas, usuarios, informes
- Cobro recurrente
- **Facturación fiscal mexicana (CFDI)** — se reutiliza lo aprendido en MotRest
- Manejo de impagos: aviso, gracia, suspensión. La misma máquina de estados de MotRest, que ya está probada en producción

### 4. Consola MOTRAE

La pantalla de operación de Fase 1 crece hasta ser la consola interna de administración:

- Tenants activos, plan y estado de cada uno
- Consumo de API de datos por cliente
- **Costo de IA por cliente** — indispensable para saber si un plan es rentable
- Salud de la ingesta y alertas de operación

### 5. Marco legal

Se reutiliza el esqueleto de `legal/` de MotRest, adaptado:

- Términos de servicio
- Aviso de privacidad (LFPDPPP)
- EULA
- Contrato de suscripción
- Política de retención y borrado
- **Deslinde explícito de apuestas**, redactado por abogado

### 6. Publicación en tiendas

- App Store y Google Play, empaquetado con Capacitor
- **Cuidado del posicionamiento desde la ficha de la tienda.** Un producto con predicciones deportivas puede caer en la categoría de apuestas si la ficha se redacta mal, y eso cambia las reglas de revisión, las restricciones por país y la edad mínima. La ficha habla de *preparación de partido, scouting y análisis de rendimiento*
- Cumplimiento de las políticas de privacidad de ambas tiendas

### 7. Soporte y actualización

- Canal de soporte con tiempos de respuesta comprometidos
- Ciclo de versiones y notas de cambio
- Respaldos con compromiso de recuperación
- Documentación para el usuario final, que hoy no existe porque el usuario somos nosotros

### 8. Precios

**Hipótesis de trabajo, no compromiso.** Se validan con al menos **tres entrevistas a clubes reales** antes de fijarse:

| Plan | Perfil | Precio hipotético | Incluye |
|---|---|---|---|
| **Analista** | Individual | ~$49 USD/mes | 1 usuario, ligas seleccionadas, consultas de IA limitadas |
| **Club** | Equipo o academia | ~$299–899 USD/mes | Usuarios múltiples, todas las ligas del plan, informes, alertas |
| **Federación** | Multi-equipo | A medida | Varios equipos, integraciones, soporte dedicado |

> ⚠️ **Estos precios no tienen sustento todavía.** Las herramientas establecidas del sector —Wyscout, StatsBomb, Sportscode— no publican precio de forma confiable: se vende por configuración de club y por contrato anual, y las cifras que circulan en comparativas públicas no son verificables. **Sin saber qué paga hoy un club real, cualquier precio nuestro es un número inventado.**
>
> Por eso las tres entrevistas no son una formalidad: son el requisito para poder fijar precio. Lo que hay que sacar de ellas es (1) qué herramientas paga hoy y cuánto, (2) cuántas horas por semana se le van en preparar un partido, y (3) qué tendría que hacer MotSport para justificar cambiar. **Hasta tener esas tres respuestas, la tabla de arriba es una hipótesis de trabajo y nada más.**

El hueco que MotSport busca no es competir en precio con Hudl: es dar el contexto integrado —clima, viaje, descanso, disponibilidad, todo cruzado— que ninguna de ellas entrega junto.

---

## 3. Qué NO se toca al pasar a Fase 3

Estas decisiones se toman hoy y sobreviven a la comercialización sin cambios:

- El modelo de datos multideporte por catálogo
- La arquitectura de proveedores intercambiables
- La procedencia por dato
- El diseño del asistente con herramientas tipadas y sin SQL libre
- El aislamiento por RLS

**Si algo de esta lista hubiera que rehacerlo en Fase 3, es que se diseñó mal hoy.**

---

## 4. Criterio para decidir cuándo pasar a Fase 3

No es una fecha. Es una condición, y la decide Gonzalo:

1. El equipo usa MotSport **todas las semanas** y dejaría de trabajar bien sin él.
2. Los modelos predictivos tienen **al menos una temporada completa de backtesting** honesto.
3. Existe al menos **un club real que lo pidió** después de verlo funcionando.

Antes de eso, comercializar es adelantar el trabajo caro sin haber validado que hay algo que vender.

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
