# Llamita Plus

> **Esta es la copia de trabajo de Jhon.** Salió de `inventario-mall-plaza`
> —la versión que usa Café del Desierto— el 2026-09-02, del commit `b4883c6`.
> Acá es donde sigue Llamita Lama y donde nace Llamita Plus.

---

## ✅ La copia ya está separada

Al 2026-09-02, esta copia **apunta a su propia base de datos** y no tiene
ninguna conexión con el sistema de Café del Desierto.

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
| 4 | Desplegar las 11 Edge Functions en el proyecto nuevo | ⬜ **lo siguiente** |
| 5 | Vercel nuevo apuntando acá | ⬜ |
| 6 | Las comprobaciones finales | ⬜ |
| 7 | Reescribir §0.9, la política de divergencia, "limpiar antes de vender" | ⬜ |

**Además de la Fase 4, quedaron cuatro cosas que a propósito no viajaron en el
respaldo** y hay que rehacer en el proyecto nuevo cuando toque:

- Los **crons** (`foto-inventario`, `limpieza-diaria`, `ciclo-fudo`).
- Marcar las tablas para **tiempo real** (`supabase_realtime`).
- La **cuenta de acceso** — los usuarios viven en otro esquema que no se copió.
- Los **secretos de Fudo**. Mientras no existan, la vía a Fudo está muerta por
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

⚠️ **Ojo con §0.9 de `CLAUDE.md`**, que dice *"no se toca Llamita Stock"*: esa
regla se escribió cuando Stock era la producción de Café del Desierto. **En esta
copia ya no aplica igual** — acá Stock sí se puede tocar, porque no es
producción de nadie. Reescribirla es parte de la Fase 7.
