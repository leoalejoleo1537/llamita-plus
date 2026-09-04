# Las tareas automáticas — qué corre solo y cuándo

> Creadas el 2026-09-04. **Si algo aparece publicado y nadie lo escribió en el
> chat, salió de acá.**

## Por qué existen

Jhon trabaja en turnos y no puede mirar el chat mientras tanto. Estas rutinas
hacen que el proyecto avance durante sus turnos, y que a las 01:00 haya un
informe listo para leer camino al trabajo.

## Las cinco

| Qué | Cuándo (Chile) | Días | Sobre qué sesión |
|---|---|---|---|
| Construir · inicio de turno | 09:10 | martes, miércoles, sábado | **esta** |
| Construir · mitad de turno | 12:40 | martes, miércoles, sábado | **esta** |
| Construir · inicio de turno | 15:10 | jueves, viernes, domingo | **esta** |
| Construir · mitad de turno | 18:40 | jueves, viernes, domingo | **esta** |
| **El informe diario** | **01:05** | todos | **una nueva** |

**El lunes no corre ninguna**: es el descanso de Jhon y está disponible para
trabajar en el chat.

Los ids viven en el servidor; se listan con `list_triggers` y se apagan con
`update_trigger` (`enabled: false`) — **no hace falta borrarlas** para
pausarlas.

## Las dos decisiones que las explican

### Construir recuerda; auditar olvida

Las cuatro de construcción disparan **sobre la misma sesión**. Construir se
beneficia de recordar: esa sesión sabe que la maqueta de F3 está aprobada, que
se eligió la opción A, y por qué `cuenta_cobrar` se llama así. Una sesión nueva
cada turno volvería a preguntar lo ya contestado.

El informe dispara **sobre una sesión nueva**, y es lo contrario a propósito:
llegando sin memoria **no puede informar lo que cree que hizo**, sólo lo que el
`git log` y las pruebas digan. Un informe que se acuerda de su propio trabajo
es un informe que puede inventarlo.

⚠️ **Y hay un precio que no se puede esquivar:** una rutina que dispara sobre
una sesión existente **no puede mandar aviso al teléfono** — el servidor lo
rechaza. Por eso el informe, que es lo que Jhon tiene que recibir sí o sí, es
el único que abre sesión nueva.

### Las horas son UTC, y Chile se mueve

El cron se evalúa en **UTC**. Las horas de arriba apuntan a **UTC−3**, que es
Chile desde el **6 de septiembre de 2026**. Hasta esa fecha caen una hora
antes y después se acomodan solas.

Se eligieron **minutos raros** (`:10`, `:40`, `:05`) a propósito: todo el mundo
programa a las en punto y a la media.

## Cómo termina una tanda de construcción

**Batería en verde, commit y push a `master`** — o sea que se publica en
Vercel. Es la regla que ya rige para Lama: *un arreglo que Jhon no puede ver es
un arreglo que no está entregado*.

**Nunca se publica con una prueba en rojo.** La única roja conocida es
`estetica-no-rompio-nada`, deuda vieja de Stock, comprobada idéntica contra
`origin/master`.

⚠️ **Una tanda nunca se queda esperando una respuesta.** Jhon está trabajando.
Si aparece una decisión que es suya: se hace todo lo que no dependa de ella, se
publica, y **la pregunta se anota** para que entre en el informe de la noche.
Es el riesgo más concreto de todo esto — una sesión colgada en una pregunta
pierde el turno entero sin que nadie se entere.

## Los tres agentes

En `.claude/agents/`. **No corren solos**: se invocan cuando hacen falta.

| Agente | Cuándo conviene |
|---|---|
| `guardian-del-contexto` | antes de planificar algo grande, o al cerrar una etapa |
| `revisor-de-codigo` | antes de publicar una tanda |
| `vigia-de-seguridad` | una vez por semana, y antes de mostrarle el sistema a alguien |

Lo que los hace valer más que un revisor genérico es que **llevan escritas las
cicatrices de este proyecto**: el guardián conoce las cuatro veces que un
documento mintió, el revisor sabe que `create or replace` con parámetros nuevos
deja dos firmas conviviendo, y el vigía sabe cuáles decisiones de seguridad son
deliberadas — para no reportar lo mismo cada semana hasta que lo ignoren.

## Si hay que apagarlas

Decilo y se apagan en una línea. Y si una tanda hizo algo que no correspondía,
**está todo en `git log`**: se revierte el commit y listo.
