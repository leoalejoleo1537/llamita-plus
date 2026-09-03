# Llamita Plus

> **Esta es la copia de trabajo de Jhon.** Salió de `inventario-mall-plaza`
> —la versión que usa Café del Desierto— el 2026-09-02, del commit `b4883c6`.
> Acá es donde sigue Llamita Lama y donde nace Llamita Plus.

---

## ⛔ ANTES DE DESPLEGAR ESTO EN NINGUNA PARTE, LEER

**Esta copia todavía apunta a la base de datos de Café del Desierto.**

En `index.html`, líneas **3024-3025**:

```js
const SUPABASE_URL = 'https://fqjdecjsbnicvyrxkxcu.supabase.co';
const SUPABASE_KEY = 'sb_publishable_...';
```

Ese es **el proyecto de ellos, en producción**. Si conectas este repositorio
a Vercel tal como está, tendrías **dos aplicaciones escribiendo en la misma
base de datos de producción** — y una de ellas es un banco de pruebas donde
se borran cosas para probar.

**No conectar a Vercel hasta haber cambiado esas dos líneas** por las del
proyecto Supabase nuevo. Es la Fase 3 del plan.

---

## Qué falta, y en qué orden

El plan completo está en **[`docs/plan-separacion.md`](docs/plan-separacion.md)**.
Resumido:

| Fase | Qué | Estado |
|---|---|---|
| 0 | La foto de lo entregado | ✅ hecha |
| 1 | Copiar el código a este repositorio | ✅ hecha |
| 2 | Proyecto Supabase nuevo, restaurado desde un respaldo | ⬜ **lo siguiente** |
| 3 | Cambiar `index.html:3024-3025` y marcar los `.sql` peligrosos | ⬜ |
| 4 | Desplegar las 11 Edge Functions en el proyecto nuevo | ⬜ |
| 5 | Vercel nuevo apuntando acá | ⬜ |
| 6 | Las comprobaciones que prueban que quedó separado | ⬜ |
| 7 | Reescribir §0.9, la política de divergencia, y "limpiar antes de vender" | ⬜ |

---

## La regla que no cambia

**El repositorio `inventario-mall-plaza` es de Café del Desierto y no se toca.**
Ni un commit, ni un push, ni un `.sql`. Está congelado. Lo que se construya de
ahora en adelante vive acá.

Si una sesión de Claude tiene los dos repositorios abiertos a la vez, el otro
va **solo de lectura**.

---

## Lo demás

Las reglas del proyecto siguen en [`CLAUDE.md`](CLAUDE.md). El área de ventas
tiene su propio archivo madre en [`docs/LAMA.md`](docs/LAMA.md).

⚠️ **Ojo con §0.9 de `CLAUDE.md`**, que dice *"no se toca Llamita Stock"*: esa
regla se escribió cuando Stock era la producción de Café del Desierto. **En
esta copia ya no aplica igual** — acá Stock sí se puede tocar, porque no es
producción de nadie. Reescribirla es parte de la Fase 7.
