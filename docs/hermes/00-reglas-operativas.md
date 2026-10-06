# Reglas operativas de Hermes y Codex

## 1. Límites de seguridad

- Trabajar únicamente en el repositorio `leoalejoleo1537/llamita-plus`.
- No consultar, modificar, migrar, desplegar ni borrar nada de Café del Desierto / Llamita Stock.
- No asumir que una tabla, columna, ruta, permiso o integración existe: verificar primero en código, documentación y, cuando corresponda, la base autorizada de Llamita Plus.
- No inventar credenciales ni pedir que se copien secretos al chat.
- No borrar datos ni cambiar datos existentes como parte de una refactorización sin autorización explícita.
- Las pruebas con datos sintéticos solo pueden ejecutarse en Llamita Plus y deben quedar identificadas y reversibles.

## 2. Regla de fases

- Una ejecución de Codex trabaja en una sola fase activa.
- Si la tarea pide primero análisis o plan, no se implementa código.
- Si aparece una decisión arquitectónica no resuelta, Codex se detiene y la registra en `05-decisiones-pendientes.md`.
- No combinar en una misma ejecución modelo de datos, UI, migraciones y automatizaciones salvo que la fase lo autorice expresamente.

## 3. Antes de modificar

Codex debe:

1. Leer este archivo y `README.md`, `CLAUDE.md` y los documentos relevantes de `docs/`.
2. Confirmar la rama y el estado del repositorio.
3. Inspeccionar las rutas, componentes, consultas y tablas realmente implicadas.
4. Identificar riesgos de compatibilidad, datos históricos, sedes y despliegue.
5. Explicar qué archivos tocará y qué no tocará.

## 4. Cambios y datos

- Preferir cambios aditivos y migraciones reversibles.
- No reemplazar `rubro`, `tipo` u otros campos históricos para simular una arquitectura nueva si se puede añadir una capa explícita.
- Mantener compatibilidad con el comportamiento actual hasta que exista una fase de migración aprobada.
- Las integraciones Fudo/POS deben permanecer aisladas y no se amplían durante una fase que no lo indique.

## 5. Pruebas y publicación

- Ejecutar las pruebas disponibles y las comprobaciones manuales relevantes.
- Registrar comandos, resultado y limitaciones en la bitácora.
- Cada push debe incluir un resumen de archivos, comportamiento y riesgos pendientes.
- El objetivo de publicación directa es `master` de Llamita Plus, pero solo para la fase expresamente autorizada.
- Si la verificación falla, no presentar la fase como terminada.

## 6. Comunicación

Cuando una tarea está incompleta, Codex debe dejar:

- estado: `completada`, `bloqueada` o `requiere decisión`;
- archivos revisados o modificados;
- pruebas ejecutadas;
- riesgos o preguntas concretas;
- siguiente paso recomendado.

La cola de trabajo es la autorización vigente; una conversación antigua o un supuesto no reemplaza su contenido.