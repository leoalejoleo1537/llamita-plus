# SEPARAR LLAMITA — el plan completo

> **Este documento va al repositorio nuevo (`llamita-plus`) apenas exista.**
> Mientras tanto, es lo que el chat que haga la separación tiene que leer entero
> antes de tocar nada.

---

## Contexto

Café del Desierto se queda con **Llamita Stock** tal como está hoy: es suyo y
queda congelado. Jhon se queda con **una copia**, y sobre esa copia sigue
Llamita Lama para formar **Llamita Plus**, su producto.

**El problema que esto resuelve:** hoy Lama está construida *dentro* de la app y
de la base de datos de Café del Desierto. Cada mesa de prueba escribe filas en
su base de producción. Se está construyendo un producto propio dentro de
infraestructura ajena.

**Fecha límite dura:** la "conexión final" —que cerrar una mesa descuente
inventario— **no puede ocurrir antes de esta separación**, porque ahí Lama
empezaría a mover el stock real de ellos.

**Decisión ya tomada (Jhon, 2026-09-02):** la copia se lleva **todo, con datos
reales** — productos, recetas, stock, ventas, historial. Es lo que permite
desarrollar Lama contra una carta y precios de verdad.

---

## LA PREGUNTA QUE IMPORTA: ¿puede romperse la app de Café del Desierto?

Jhon lo dijo así: *"lo veo como una cirugía donde si hacemos algo mal, Café del
Desierto amanece con el sistema dañado, a días de que me paguen."*

**No es una cirugía. Es una fotocopia.** Y conviene decir exactamente por qué,
porque la respuesta se puede verificar y no depende de tener cuidado:

**Solo existen cuatro caminos para dañar su sistema, y ninguno se recorre en
este trabajo:**

| # | Camino | ¿Quién puede? | ¿Se usa acá? |
|---|---|---|---|
| 1 | Empujar código a `inventario-mall-plaza` (despliega solo a su Vercel) | el chat, si tiene acceso | **NO** — el chat de la separación nunca tendrá ese repositorio |
| 2 | Correr SQL en su Supabase | solo Jhon, pegando a mano | **NO** — todo el SQL de este plan es para la base NUEVA |
| 3 | Cambiar sus Edge Functions | solo Jhon, pegando a mano | **NO** |
| 4 | Cambiar su Vercel | solo Jhon | **NO** |

**El camino 1 es el único real, y se cierra de raíz:** la copia del código la
empuja la sesión que YA tiene el repositorio original (la de Jhon con Claude), y
el chat que hace la separación **abre con acceso únicamente a `llamita-plus`**.
No es que le pidamos cuidado: **no puede tocar el original aunque se equivoque.**

**La única operación sobre el lado de ellos en todo el plan es LEER un
respaldo.** Leer no rompe nada.

**Y el peor caso posible, si todo sale mal:** la copia queda mal hecha y se
rehace. Café del Desierto no se entera.

---

## LA LISTA DE PELIGRO — verificada en el código, no supuesta

Cuatro cosas que, copiadas tal cual, **seguirían apuntando al sistema de ellos**.
No son riesgos de romperles algo: son riesgos de que **la copia se comporte como
si fuera la original**.

| # | Qué | Dónde vive | Qué pasaría si se olvida |
|---|---|---|---|
| 1 | URL y llave de Supabase | `index.html:3024-3025` | la copia escribiría en la base de ELLOS |
| 2 | **Los crons, con la URL escrita adentro** | dentro de la base (`cron.job`), **no en el repo** | la copia llamaría a las Edge Functions de ellos |
| 3 | Credenciales de Fudo | secretos del proyecto Supabase | escribiría en el Fudo de ellos |
| 4 | `.sql` viejos con la URL escrita | `sql/2026-07-cron-automatico-ventas.sql`, `2026-08-ciclo-fudo-automatico.sql`, `2026-08-ciclo-por-que-no-responde.sql`, `2026-08-probar-catalogo-fudo.sql` | si alguien los corre en la copia, reintroduce el #2 |

**El #2 es el que nadie ve venir.** Los crons no están en el repositorio: están
guardados *dentro* de la base de datos, con la URL completa del proyecto viejo
escrita en el texto del comando. Si el respaldo los arrastra, la copia empieza a
llamar sola a la casa de ellos. Hay una comprobación específica en la Fase 6.

**Dos cosas juegan a favor:**

- Las Edge Functions leen `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` **del
  entorno**, que Supabase inyecta solo en cada proyecto. Desplegadas en el
  proyecto nuevo apuntan solas a la base nueva. **No hay nada que editar.**
- Las credenciales de Fudo se leen como `FUDO_<SEDE>_APIKEY` / `_APISECRET`.
  **Si no se ponen esos secretos en el proyecto nuevo, la vía a Fudo queda
  muerta por construcción.** No hay que desactivar nada: basta con no ponerlos.

---

## LA VARA — los números de la base original, medidos el 2026-09-02

Contra estos se compara la copia en la Fase 6. Si no coinciden, el respaldo no
llegó completo.

| | |
|---|---|
| Tablas | **44** |
| Funciones | **76** ⚠️ *ver la nota* |
| Políticas | **60** |
| Crons | **5** |
| Productos | **1.434** |

Versión entregada a Café del Desierto: commit **`b4883c6`**, base
**`fqjdecjsbnicvyrxkxcu`**.

> ⚠️ **El 76 quedó en duda el 2026-09-05.** El `README.md` de la copia dice
> **45** funciones *"verificado contra el original"*, y la medición en la copia
> dio exactamente **44 · 45 · 60 · 1434** — o sea clava los otros tres números.
> **No se puede saber cuál de los dos documentos tiene razón sin consultar la
> base de ellos, y esa no se toca.**
>
> Por eso la comprobación (b) dejó de ser un conteo: ahora
> `sql/2026-09-plus-comprobacion-fase6.sql` pregunta **por las 33 funciones que
> la app llama de verdad**, una por una. Un conteo que no cuadra no dice cuál
> falta.

---

## LAS FASES

🔵 = lo hace Jhon · 🟢 = lo hace el chat de la separación · 🟠 = lo hace la sesión que tiene el repo original

### Fase 0 · La foto — HECHA ✅

- ✅ `docs/ENTREGA-CAFE-DEL-DESIERTO.md` publicado, marcando el commit `b4883c6`
- ✅ Los cinco números de la vara, medidos
- 🔵 **Falta:** el respaldo completo desde Supabase → Database → Backups

### Fase 1 · El repositorio nuevo

- 🔵 Crear en GitHub un repositorio **vacío y privado**: `llamita-plus`.
  Sin README, sin `.gitignore`, sin licencia — **completamente vacío**.
- 🟠 La copia con toda la historia la empuja la sesión que ya tiene el original.
- ⚠️ **No usar el "Fork" de GitHub.** Un fork mantiene el vínculo con el
  original y hace fácil empujar al lugar equivocado.
- ⚠️ **El chat de la separación abre con `llamita-plus` y NADA MÁS.** Esta es la
  guarda principal de todo el plan.

### Fase 2 · El proyecto Supabase nuevo

- 🔵 Crear un proyecto Supabase nuevo.
- 🔵 Restaurar ahí el respaldo de la Fase 0.
- 🔵 Anotar la **URL nueva** y la **llave publishable nueva** (Settings → API).
- ⚠️ **No poner todavía** los secretos `FUDO_*`. Se decide después, a propósito.

### Fase 3 · Cortar el cordón — ANTES de desplegar nada

Si se despliega primero y se corta después, hay una ventana en la que la copia
escribe en la base de ellos.

- 🟢 Cambiar `index.html:3024-3025` por la URL y la llave nuevas.
- 🟢 Marcar los cuatro `.sql` de la lista de peligro (#4) con
  **⛔ NO CORRER EN LA COPIA — contiene la URL del proyecto de Café del
  Desierto**, siguiendo el patrón de los dos archivos superados de la foto
  automática.
- 🔵 Correr la comprobación (a) de la Fase 6 **antes de seguir**.

### Fase 4 · Las Edge Functions

- 🔵 Desplegar las 11 funciones en el proyecto nuevo, pegando el código de
  `supabase/functions/*/index.ts`, una por una. **No hay que editarlas.**
- Las de Fudo van a fallar mientras no existan los secretos. **Eso es correcto y
  deseado** en esta etapa.

### Fase 5 · El despliegue

- 🔵 Proyecto nuevo en Vercel apuntando a `llamita-plus`, rama `master`.
- El Vercel de Café del Desierto **no se toca**.

### Fase 6 · La comprobación que prueba que quedó separado

**La fase más importante. "Creo que quedó separado" no es una respuesta.**

**a) Los crons no apuntan al proyecto viejo** — en la base **NUEVA**:

```sql
select jobname, left(command, 120) as empieza_asi
  from cron.job
 where command like '%fqjdecjsbnicvyrxkxcu%';
```

**Qué ver: CERO filas.** Si devuelve algo, borrarlos con
`select cron.unschedule('<jobname>');` y recrearlos con la URL nueva.

**b) La estructura llegó completa** — en la base **NUEVA**:

```sql
select
  (select count(*) from information_schema.tables where table_schema='public') as tablas,
  (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public') as funciones,
  (select count(*) from pg_policies where schemaname='public') as politicas,
  (select count(*) from cron.job) as crons,
  (select count(*) from public.productos) as productos;
```

**Qué ver:** ⚠️ **esta comprobación quedó reemplazada** — ver la nota de LA VARA.
El conteo de funciones no tiene una vara confiable, y el de crons no aplica
porque `pg_cron` no está instalada. La comprobación vigente es
`sql/2026-09-plus-comprobacion-fase6.sql`.

**c) La prueba de punta a punta, sin herramientas de desarrollador:** en la app
**nueva**, crear un producto con un nombre inconfundible (`ZZZ PRUEBA COPIA`).
Después mirarlo en el editor de tablas de Supabase:

- tiene que **aparecer** en el proyecto **nuevo**
- **no** puede aparecer en el proyecto **viejo**

Si aparece en los dos, o solo en el viejo, la Fase 3 quedó mal. **Parar.**

**d) Borrar el producto de prueba** de la base nueva.

### Fase 7 · Lo que queda escrito

- 🟢 **§0.9 cambia de significado en la copia.** Ahí Stock **sí se puede tocar**,
  porque ya no es producción de nadie. Reescribirla en el `CLAUDE.md` de la
  copia, o el chat de Lama va a seguir negándose a tocar lo que ahora debería
  poder.
- 🟢 **La política de divergencia.** El 2026-09-02 se arreglaron dos bugs reales
  en Stock (las metas que contaban otro producto, el cron de la foto que había
  retrocedido). Desde la separación, cada arreglo así hay que decidir si aplica
  a las dos versiones. Escribir la regla ahora, no cuando duela.
- 🟢 **Anotado y NO ejecutado: "limpiar antes de vender".** La copia se lleva
  datos de Café del Desierto, incluidos correos de personas en `app_permisos`.
  Sirve para desarrollar; **no puede viajar a otro cliente.** Requisito previo a
  la primera venta.
- 🟢 En el `CLAUDE.md` de la copia, una sección al principio que diga qué es
  esta copia, de dónde salió y qué la distingue del original.

---

## LO QUE NO SE HACE, EN NINGÚN CASO

- **No se toca nada de Café del Desierto** — ni repositorio, ni base, ni Vercel,
  ni crons, ni Edge Functions. La única operación de ese lado es leer el
  respaldo.
- **No se quita Lama de la versión de ellos.** Queda dormida y documentada: está
  escondida, no toca el inventario, y tocar un sistema congelado en producción
  para borrar código inerte es más riesgo que beneficio.
- **No se separa `index.html` en módulos.** Los niveles de producto (Stock solo
  / Plus / Pro) requieren un trabajo que hoy no existe: son 13.926 líneas en un
  archivo, unidas por convención de nombres. Es otro proyecto y va después.
- **No se corre ningún `.sql` "para reconstruir" la base.** Hay 128 archivos
  corridos a mano durante meses, algunos superados. §0.1.2 lo dice: *los
  archivos del repo NO son el estado de producción.* La copia sale del respaldo
  o no sale.

---

## SI ALGO NO CALZA — cuándo parar y preguntar

- El respaldo falla al restaurarse con errores que no se entienden.
- Alguna de las 33 funciones que la app llama dice `FALTA` en la comprobación de la Fase 6.
- La comprobación (c) muestra el producto de prueba en la base **vieja**.

En cualquiera de los tres: **parar, no improvisar, y avisar.** Ninguno de los
tres rompe nada de Café del Desierto — pero seguir adelante sin entenderlos sí
puede dejar una copia que se comporta como la original.
