# Fuentes y trazabilidad

## Objetivo

Este Context Pack sintetiza el proyecto; no reemplaza sus fuentes primarias. La tabla indica qu� consultar para comprobar o actualizar cada tema.

## Fuentes principales

| Tema | Fuente recomendada |
|---|---|
| Separaci�n del proyecto | `README.md` |
| Identidad visual y decisiones de Dar�o | `docs/DECISIONES-ESTETICA.md`, `identity-modules.css`, `area-selection.css`, `area-workspace.css`, `themes.css`, `manifest.json` |
| Definici�n general hist�rica | `docs/notion/01-que-es-llamita.md` |
| Objetivo de inventario por �reas | `docs/hermes/00-mapa-objetivo-inventario-areas.md` |
| Cola y estado de trabajo | `docs/hermes/03-cola-de-trabajo-codex.md` |
| Contrato de inventario | `docs/hermes/07-contrato-comun-inventario.md` |
| Contrato stock/repartos/Lama | `docs/hermes/36-contrato-operativo-stock-repartos-lama.md` |
| Plan del Panel, cat�logo y Fudo | `docs/hermes/37-p0-panel-productos-catalogo-recetas-fudo-reinicio.md` |
| Validaci�n P4 | `docs/hermes/38-validacion-e2e-reforzada-p4.md` |
| Circuito Mocachino actual | `docs/hermes/38-circuito-mocachino-e2e.md` |
| C�digo visible actual | `index.html`, `panel-productos.js`, `panel-productos-venta.js` y m�dulos CSS vigentes |
| Modelo instalado | Migraciones en `supabase/migrations/` y definici�n remota cuando la tarea sea t�cnica |

## Jerarqu�a ante contradicciones

1. C�digo y migraciones instaladas.
2. Prueba/resultados m�s recientes.
3. Decisi�n actual del propietario.
4. Context Pack.
5. Plan o bit�cora hist�rica.

Un documento hist�rico puede describir correctamente su momento y estar obsoleto hoy.

## M�todo usado para construir el paquete

- Se sincroniz� el repositorio con `origin/master`.
- Se revis� la documentaci�n de producto, contratos, resultados recientes y lineamientos visuales.
- Se inspeccionaron nombres de m�dulos y flujos presentes en el c�digo actual.
- Se clasific� cada afirmaci�n como implementada, aprobada, propuesta o legacy.
- No se consult� ni modific� Caf� del Desierto / Llamita Stock.
- No se modificaron base de datos, producci�n ni datos operativos.

## Mantenimiento recomendado

Actualizar este paquete cuando ocurra alguno de estos eventos:

- Se complete P5, P6 o P7A.
- Cambie el nombre o identidad de marca.
- Se modifique el modelo maestro/representaci�n.
- Se active un origen POS real.
- Se cierre un piloto con evidencia publicable.
- Se reemplace de forma sustancial la experiencia del Panel o Mesas.

Al actualizar, cambiar primero los documentos especializados y despu�s revisar `01-CONTEXTO-UNIVERSAL-IA.md` y `context-manifest.json`.

## Fecha y corte

- Fecha de generaci�n: 2026-10-27.
- Rama: `master`.
- Commit de referencia: `f8d4ad4`.
- Alcance: Llamita Plus.


