# Llamita Plus

> **Esta es la copia de trabajo de Jhon.** Salió de `inventario-mall-plaza`
> —la versión que usa Café del Desierto— el 2026-09-02, del commit `b4883c6`.
> Acá es donde sigue Llamita Lama y donde nace Llamita Plus.

---

## La copia está separada — y falta la comprobación que lo prueba

Al 2026-09-02, esta copia **apunta a su propia base de datos** y no tiene
ninguna conexión con el sistema de Café del Desierto.

⚠️ **Dicho con precisión:** todo lo comprobado apunta a que sí — el código no
nombra su proyecto por ninguna parte, y la app corre contra la base nueva. Pero
**la prueba de punta a punta de la Fase 6 todavía no se corrió**, y hasta que se
corra lo honesto es decir *"todo indica que quedó separado"*. Está lista para
pegar en [`docs/sql-pendientes.md`](docs/sql-pendientes.md).

| | |
|---|---|
| **Base de datos** | proyecto Supabase `iuryhsjucblmebdogewa` (`llamita-plus`) |
| **Copiado de la base** | 44 tablas · 45 funciones · 60 políticas · 1.434 productos — **verificado contra el original** |
| **Código** | 339 commits, toda la historia del proyecto |

**No queda un solo rastro del proyecto de ellos en el código.** Se comprobó
buscando su identificador y su llave en `index.html` y en los 128 archivos de
`sql/`: cero resultados.

---

## Qué falta, y en qué orden

El plan completo está en **[`docs/plan-separacion.md`](docs/plan-separacion.md)**.

| Fase | Qué | Estado |
|---|---|---|
| 0 | La foto de lo entregado | ✅ |
| 1 | Copiar el código a este repositorio | ✅ |
| 2 | Proyecto Supabase nuevo, restaurado desde el respaldo | ✅ |
| 3 | Cortar el cordón: credenciales nuevas, `.sql` marcados | ✅ |
| 4 | Desplegar las 11 Edge Functions en el proyecto nuevo | ⬜ **lo único que falta de verdad** · lo pega Jhon |
| 5 | Vercel nuevo apuntando acá | ✅ **2026-09-02** · Jhon abre la app desde el teléfono |
| 6 | Las comprobaciones finales | 🟡 **a medias** — ver abajo |
| 7 | Reescribir §0.9, la política de divergencia, "limpiar antes de vender" | ✅ **2026-09-04** · están en `CLAUDE.md` |

> ⚠️ **Corregido el 2026-09-05.** Las fases 5 y 7 decían ⬜ **estando hechas**,
> y la 6 no distinguía lo comprobado de lo que falta. Un tablero que manda a
> rehacer trabajo terminado es el error más caro de este proyecto, así que se
> arregla apenas se ve.

### Qué falta de la Fase 6, exactamente

| Comprobación | Estado |
|---|---|
| **El código no nombra el proyecto de ellos** | ✅ cero resultados en `index.html` y en los 128 `.sql` |
| **La app corre contra la base nueva** | ✅ Jhon entra, ve sus datos, y el `.sql` del tiempo real hizo efecto |
| **(a) Ningún cron apunta al proyecto viejo** | ⬜ los crons no viajaron en el respaldo, así que hay poco que apuntar — igual **hay que mirarlo**, no suponerlo |
| **(b) Los números de la estructura** — 44 · 76 · 60 · 5 · 1434 | ⬜ sin correr |
| **(c) El producto `ZZZ PRUEBA COPIA`** — que aparezca acá y **no** allá | ⬜ **es la prueba que de verdad prueba**, y no está hecha |

⚠️ **La (c) es la que importa** y las otras dos no la reemplazan. Mientras no
esté, lo honesto es decir *"todo indica que quedó separado"*, no *"está
comprobado"*.

**Además de la Fase 4, quedaron cuatro cosas que a propósito no viajaron en el
respaldo** y hay que rehacer en el proyecto nuevo cuando toque:

- Los **crons** (`foto-inventario`, `limpieza-diaria`, `ciclo-fudo`). ⬜
  Dependen de la Fase 4: sin las Edge Functions desplegadas no hay a qué llamar.
- Marcar las tablas para **tiempo real** (`supabase_realtime`). ✅ **hecho el
  2026-09-04** — las seis que la app escucha; `mesas` y `comandas` quedan
  apagadas a propósito, porque nadie las escucha.
- La **cuenta de acceso** — los usuarios viven en otro esquema que no se copió.
  ✅ Jhon entra con sus dos cuentas.
- Los **secretos de Fudo**. ⬜ Mientras no existan, la vía a Fudo está muerta por
  construcción, y eso es deliberado.

---

## La regla que no cambia

**El repositorio `inventario-mall-plaza` es de Café del Desierto y no se toca.**
Ni un commit, ni un push, ni un `.sql`. Está congelado. Lo que se construya de
ahora en adelante vive acá.

Si una sesión de Claude tiene los dos repositorios abiertos a la vez, el otro va
**solo de lectura**.

---

## Lo demás

Las reglas del proyecto siguen en [`CLAUDE.md`](CLAUDE.md). El área de ventas
tiene su propio archivo madre en [`docs/LAMA.md`](docs/LAMA.md).

✅ **§0.9 de `CLAUDE.md` ya está reescrita** (2026-09-04). Decía *"no se toca
Llamita Stock"* —correcto cuando Stock era la producción de Café del Desierto— y
ahora dice lo que corresponde acá: **Stock sí se puede tocar**, porque no es
producción de nadie. Lo que sobrevive de la regla vieja está escrito ahí mismo:
un cambio que nadie pidió sigue siendo un riesgo que nadie aceptó, y las reglas
que protegen los datos no se relajan ni un poco.
