# 14 · Seguridad

> 🟡 **Segunda pasada.** Los principios están fijados desde la arquitectura; falta el detalle operativo.

## Decidido

1. **Aislamiento por RLS de Postgres**, no por filtros en la aplicación. Desde la primera migración, aunque hoy exista un solo tenant.
2. **El asistente de IA no ejecuta SQL.** Llama herramientas tipadas. Eso cierra por diseño la mitad de la superficie de ataque de un producto así. Ver [`10_INTELIGENCIA_ARTIFICIAL.md`](10_INTELIGENCIA_ARTIFICIAL.md).
3. **El filtro de tenant vive en la herramienta, no en el prompt.** El modelo no puede saltárselo porque no lo controla.
4. **El contenido traído de la web es dato, nunca instrucción.** Un texto de una página que diga «ignora tus reglas» es texto de una página, y así se trata.
5. **Secretos en variables de entorno**, nunca en el repositorio. El `.gitignore` bloquea por extensión como segunda línea de defensa, no como primera.
6. **Bitácora de cada llamada a herramienta** del asistente: qué se preguntó, qué se llamó, con qué argumentos, qué devolvió.
7. **El asistente no escribe.** En Fase 1 solo lee. Cualquier capacidad de escritura futura pasa por confirmación explícita del usuario.

## Pendiente de escribir

- Matriz de roles y permisos
- Política de contraseñas y segundo factor
- Auditoría: qué se registra, cuánto se retiene, quién lo consulta
- **Pruebas de aislamiento entre tenants** — obligatorias antes de Fase 3
- Plan de respuesta ante incidentes
- Rotación de llaves de API

---

*MOTRAE · Innovation already in motion · Confidencial · Uso interno · Septiembre 2026*
