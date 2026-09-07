# ¿Cuánto mejoraría el proyecto darle a Llamita Plus acceso a la API de Fudo?

> Pregunta de Jhon, 2026-09-05: *"yo tengo las api de fudo y el permiso de
> usarlas… nos podríamos ahorrar horas de trabajo investigando o verificando
> cómo funciona Fudo"*.
>
> **La respuesta corta: sí, pero no para lo que estás pensando.** Y hay un
> corte que hay que hacer antes de decidir nada.

---

## El corte que decide todo: LEER no es ESCRIBIR

| | Qué pasa | Veredicto |
|---|---|---|
| **Leer** de Fudo | Llamita Plus se entera del catálogo, de las ventas, de las mesas abiertas | 🟢 **barato y sin riesgo** |
| **Escribir** en Fudo | Llamita Plus **cambia el POS que el café está usando ahora mismo** | 🔴 **no todavía** |

**Por qué la segunda es peligrosa hoy, y no es teórico:** Llamita Plus es el
banco de pruebas. Acá se crean productos de prueba, se abren y cierran mesas
veinte veces, se prueba el cobro. **La cuenta de Fudo es UNA SOLA** — la del
café de verdad. Un empuje de stock desde una prueba le cambiaría los números al
equipo en pleno turno, sin que nadie entienda por qué.

**Y eso es exactamente por qué los secretos de Fudo NO viajaron en la copia.**
No fue un olvido: el plan de separación lo dice con estas palabras — *"si no se
ponen esos secretos en el proyecto nuevo, la vía a Fudo queda muerta por
construcción"*. **Ese candado se puso a propósito y conviene entender qué
protege antes de sacarlo.**

---

## Dónde la API SÍ ahorra trabajo de verdad

### 1 · Desbloquea la Fase 4, que ya está esperando

Las **11 Edge Functions** están escritas y sin desplegar. Con ellas y los
secretos vuelven a andar el motor de descuento por ventas, el catálogo y el
ciclo automático. **Esto no es una idea nueva: es trabajo ya hecho que hoy está
apagado.** Es el mejor retorno por lejos.

### 2 · Las mesas abiertas — y esto arregla un problema real

Ya está **medido** (§10.1 del archivo madre): Fudo expone las mesas abiertas
con `filter[saleState]=in.(IN-COURSE)` y trae sus productos. Sirve para el
descuadre del conteo nocturno — el jefe cuenta 10 panes cuando el sistema dice
12 porque hay 2 en una mesa sin cerrar, "corrige" a 10, y al cerrar la mesa
queda en 8. **Leer las mesas abiertas hace que ese conteo cuadre solo.**

### 3 · Sembrar las mesas del salón, si Fudo las expone

Hoy Plaza tiene 12 mesas cargadas y en el local hay 20. Si la API entrega la
lista de mesas de Fudo, se cargan de una en vez de crearlas a mano.
⚠️ **No está comprobado que Fudo lo exponga** — el atlas no lo dice y no se
midió. Es una consulta de diez minutos con las llaves puestas, no una promesa.

### 4 · Datos para el tablero

Importes, medios de pago y propinas por venta. **Ojo:** lo que el motor ya
registra —qué se vendió y cuánto— **ya está en `fudo_movimientos`**, y para eso
la API no hace falta. Sirve para lo que el motor NO guarda.

---

## Dónde NO ahorra nada, y es la parte que hay que oír

**El atlas de Fudo NO se puede llenar con la API.** Las preguntas que quedan
abiertas ahí son de **comportamiento**, no de datos:

- *¿qué ve el cajero en un arqueo ciego?*
- *¿la precuenta impresa bloquea agregar productos?*
- *¿qué pasa si se olvidaron de abrir la caja?*

**Ninguna API contesta eso.** Una API entrega filas; el atlas describe
decisiones de diseño de un producto. Es la diferencia entre leer el inventario
de una cocina y saber cómo se cocina ahí.

Para eso, **NotebookLM sobre la documentación de Fudo funcionó y funcionó
bien** — las tres respuestas del bloque H son de las mejores del archivo. La
API no lo reemplaza, y creer que sí llevaría a mirar filas buscando una
respuesta que no está en ellas.

---

## La recomendación

**Sí, pero en dos etapas y con una regla dura en el medio.**

| Etapa | Qué | Cuándo |
|---|---|---|
| **1 · Leer** | Desplegar las Edge Functions de **lectura** y poner los secretos. Catálogo, ventas, mesas abiertas | **cuando quieras** — es la Fase 4, ya está esperando |
| **2 · Escribir** | Empujar stock, crear productos, encender y apagar en Fudo | **cuando Llamita Plus deje de ser el banco de pruebas** |

> ### 🔴 LA REGLA, si se avanza
>
> **Mientras Llamita Plus sea donde se prueba, las Edge Functions que
> ESCRIBEN en Fudo no se despliegan acá.** No alcanza con "tener cuidado": el
> día que alguien pruebe un reparto con datos inventados, esos números se van
> a Fudo y los ve el equipo en el mesón.
>
> El sistema ya tiene la pieza para apagarlo **sin tocar código**: los
> `fudo_bloqueos` de §0.65, desde Ajustes → Fudo. Pero un bloqueo que se
> apaga desde una pantalla **no es tan seguro como un secreto que no existe**.
> Lo más barato y lo más firme es no poner los secretos de escritura todavía.

**Y una advertencia de método**, que es la lección más cara de este proyecto:
tener la API no es lo mismo que saber cómo se comporta Fudo. Ya pasó una vez
—§7 daba por hecho que Fudo no instalaba nada en el computador del local, y la
respuesta estaba **en la pantalla que usa la gente**, no en razonar sobre el
síntoma—. **La API contesta "qué datos hay". El atlas contesta "cómo se
trabaja". Las dos hacen falta, y no se sustituyen.**
