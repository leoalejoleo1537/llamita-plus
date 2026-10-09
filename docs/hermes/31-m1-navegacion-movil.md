# M1 — Navegación móvil sin riel fijo

Fecha: 2026-10-09. Repositorio: `leoalejoleo1537/llamita-plus`. Fase de interfaz M1 de la propuesta 30. No se conectó Supabase ni se modificaron datos.

## Estado anterior y cambio

El CSS reservaba 88 px para `.tabs` bajo 1080 px, incluso en teléfonos de 375–390 px. El panel contenía tanto las pestañas principales como Ajustes, Historial, Cambiar sede y Apariencia. M1 mantiene ese mismo DOM y los mismos handlers, pero bajo 720 px lo desplaza fuera de pantalla y lo abre como menú temporal con fondo, cierre por botón, clic fuera y Escape. El contenido recupera todo el ancho.

Una barra inferior contextual ofrece accesos rápidos derivados de las pestañas existentes. En Local 1: Mesas (solo con `puede_lama`), Inventario, Reparto, Mermas y Más. En Bodega: Inventario, Recibir, Enviar, Mermas y Más. Si el modo demostración oculta un módulo, tampoco aparece abajo. Más abre el menú completo, que conserva Recetas, Arqueo, Movimientos, Historial, Ajustes si hay permiso, Cambiar sede, Apariencia y cierre de sesión. La barra delega el clic en la pestaña original; no hay nuevas rutas de negocio. `inert` impide tabular por el panel cerrado, y el botón comunica `aria-expanded`.

La cabecera móvil coloca menú, sede/módulo y acción existente en una fila compacta. La barra respeta `safe-area-inset-bottom`; se retiró la prohibición de zoom del viewport. En escritorio (1280 px probado) se mantiene el riel fijo y no aparece la barra inferior.

## Archivos y límites

- `index.html`: HTML de menú/barra, interacción y sincronización con sede, permiso, vista activa y modo demostración; sin cambios en acciones comerciales.
- `themes.css`: reglas exclusivas bajo 720 px y estados de foco; escritorio intacto.
- `pruebas/movil-navegacion.mjs`: navegador con Supabase completamente simulado, sin red de datos.
- Documentación Hermes: cola, bitácora, canal e informe.

No se modificaron SQL, Edge Functions, Auth, ledger, productos, stock, lotes, transferencias, Fudo, Lama comercial ni Bodega operativa. No se accedió a Café del Desierto / Llamita Stock.

## Verificación

`npm test` pasó (suite estática y pruebas sin navegador). Con Chromium real sobre servidor local y datos simulados pasó `pruebas/movil-navegacion.mjs`: ancho libre a 390 px, cinco accesos, menú y Escape/foco, delegación de ruta, retiro de Mesas al quitar permiso, filtro de demostración, enlaces propios de Bodega, riel intacto a 1280 px y cero excepciones JavaScript. Se inspeccionó una captura a 390 px. `git diff --check` pasó.

Las pruebas de navegador heredadas no son evidencia de regresión M1: `inventario-areas.mjs` tiene una expectativa incompatible con sus propios saldos simulados (exige que todas las áreas muestren cero pese a asignar saldo a Barra y Cafetería) y luego espera una fila de Bodega que su fixture no entrega; `lama-ancho.mjs` no logra activar su pestaña con el mock de permisos anterior a S1. Ambas requieren actualizar fixtures en una fase de pruebas, sin alterar la aplicación para hacerlas pasar. La suite `npm test` sin `CHROME_PATH` las omite explícitamente.

## Riesgos y siguiente punto

M1 no redistribuye el interior de Mesas. La captura sintética muestra aún el aviso de caja estrecho y el plano angosto/vacío: es M2, prioridad siguiente. M3 cubrirá Inventario y formularios; M4 hará revisión transversal de módulos y dispositivos reales. Debe comprobarse en Safari iPhone y Chrome Android antes de dar por terminada la remodelación completa. B3.2a.3 y B3.2b siguen pendientes; no se activan desde esta fase.
