# Si el primer cliente es Café del Desierto

> Pregunta de Jhon, 2026-09-04: *"posiblemente el primer cliente de Llamita
> Plus sea Café del Desierto… al momento de desplegar debemos pasar todo el
> inventario con su control de stock más reciente, también los usuarios con sus
> contraseñas y demás. ¿Va a ser muy difícil? ¿Se puede lograr?"*

## La respuesta corta

**Sí se puede, y es mucho más fácil de lo que parece — pero al revés de como
lo estás imaginando.**

Vos lo estás pensando como una **mudanza**: sacar todo de su casa y meterlo en
la casa nueva. Los productos, el stock, los usuarios, las contraseñas.

**No hay que mudar nada.** Lo que se mueve es **la llave de la puerta**: la app
nueva se apunta a la base que ellos ya tienen.

## Las dos direcciones posibles

| | **A · traerlos a la base de Plus** | **B · apuntar el código de Plus a la base de ELLOS** |
|---|---|---|
| El inventario y el stock | hay que copiarlo, y queda viejo desde el segundo uno | **ya está, y es el de hoy** |
| Los usuarios y sus contraseñas | hay que migrarlos entre proyectos. Es la parte más delicada de todo | **ya existen. Cero trabajo** |
| Las 11 Edge Functions | hay que desplegarlas | **ya están desplegadas y andando** |
| Los 3 crons | hay que recrearlos | **ya corren** |
| Los secretos de Fudo | hay que ponerlos | **ya están** |
| El tiempo real | hay que encenderlo | **ya encendido** |
| Las tablas de Lama | ya están | **ya están** (ver abajo) |

**B gana por goleada, y no es una opinión: es que en la columna A hay siete
trabajos y en la B hay cero.**

## Por qué la base de ellos ya sirve, y esto es lo que sorprende

**Llamita Lama se construyó ADENTRO de la base de ellos.** Ésa fue la razón de
ser de la separación: cada mesa de prueba escribía filas en su base de
producción, y por eso hubo que sacar una copia.

O sea que su base **ya tiene todo Lama**: `mesas`, `cuentas`, `cuenta_items`,
`comandas`, `cuenta_pagos`, `cuenta_propinas`, `lama_medios_pago`,
`lama_motivos_descuento`, `lama_motivos_anulacion`. Todo, con sus funciones.

**Y comprobado hoy, no supuesto:** desde la separación se escribieron dos
`.sql` nuevos y **ninguno crea estructura** — uno sólo mira y el otro enciende
el tiempo real. Su base sigue siendo **compatible con el código de hoy**.

## Lo que de verdad bloquea, y son dos líneas

```
index.html:3194   const SUPABASE_URL = 'https://iuryhsjucblmebdogewa.supabase.co';
index.html:3195   const SUPABASE_KEY = 'sb_publishable_...';
```

**La dirección de la base está escrita a mano dentro del código.** Un código,
una base. Para que existan dos clientes, eso tiene que salir de ahí.

No es difícil —es la pieza más chica de todo esto— pero **es la que convierte
"mi app" en "un producto"**, y hoy no está hecha. Formas de resolverlo hay
varias (un archivo de configuración por despliegue, o que la app mire desde qué
dirección la abrieron); se elige cuando toque, con maqueta como todo lo demás.

## El reloj, y por eso conviene saberlo ahora

**Hoy es el día más barato que va a tener esta mudanza, y se encarece sola.**

Cada `.sql` que Lama corra de acá en adelante —el arqueo va a necesitar
tablas nuevas, seguro— abre un hueco entre su base y la de Plus. No es grave y
no es motivo para apurarse: **es motivo para llevar la lista desde el día
uno.** `docs/sql-pendientes.md` ya es esa lista; lo único que hay que agregar
es una columna que diga *"esto también hay que correrlo en la base del
cliente"*.

## Lo que NO haría

**Migrar los usuarios entre proyectos.** Las contraseñas viven encriptadas en
un esquema que el respaldo normal ni siquiera copia —por eso las cuentas no
viajaron a esta copia— y moverlas es la parte más frágil de la opción A. Con
la opción B **no hay nada que migrar**: sus cuentas ya están donde tienen que
estar.

## La pregunta que sí importa, y no es técnica

Nada de lo de arriba contesta lo único que decide la fecha:

> **¿Cuándo Llamita Lama está lo bastante terminada como para que un café deje
> de usar Fudo?**

Hoy le falta: el **arqueo de caja** (bloqueado hasta que se contesten tres
preguntas del atlas), el **mostrador** —vender sin mesa, que en un café es la
mitad de las ventas— y el **puente de impresión**, que necesita una visita al
local. Sin esos tres, Lama no reemplaza a Fudo: convive con él.

**Ese es el camino crítico, no la migración.** La mudanza es de días; terminar
Lama es de semanas.

## Y una advertencia que hay que decir ahora

El día que Café del Desierto use Llamita Plus, **Lama deja de ser "algo que no
usa nadie"**. Todo lo que hoy permite construir rápido —publicar apenas las
pruebas están en verde, abrir y cerrar mesas veinte veces para probar— se
termina en ese momento para ese despliegue.

No es un problema: es un cambio de etapa. Pero conviene que la fecha en que
pasa sea **una decisión**, no una consecuencia de haber apurado un despliegue.
