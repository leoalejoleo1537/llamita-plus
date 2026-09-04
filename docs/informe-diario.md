# El informe diario — qué dice y qué no

> Esto es la **receta** del informe de la 01:00, no el informe. Lo lee la
> sesión automática que lo escribe cada madrugada.
>
> Sale de la plantilla que Jhon armó con GPT el 2026-09-04, **recortada de 14
> secciones a 5**. Abajo está qué se sacó y por qué, porque el recorte es la
> parte que hay que defender.

---

## La regla que gobierna todo el informe

> **El informe dice sólo lo que CAMBIÓ y lo que BLOQUEA.**

Lo que no cambia ya vive en `CLAUDE.md`, `docs/LAMA.md` y `docs/atlas-fudo.md`.
Repetirlo cada mañana crea **una segunda copia que se desincroniza**, y ese es
el error más caro que este proyecto ya cometió cuatro veces: tres planes que
no coincidían, el *"C8 está a medias"* que siguió escrito días después de estar
hecho, cinco pruebas acusadas en falso, y §0.9 frenando trabajo legítimo.

Y hay una razón más simple: **un informe que repite lo mismo se deja de leer**,
y uno que no se lee es peor que no tenerlo, porque da sensación de control sin
darlo.

## La segunda regla: sólo lo que se puede probar

**Nada de lo que diga el informe sale de una impresión.** Cada afirmación se
apoya en algo que se corrió:

| Para decir… | Se corre… |
|---|---|
| qué se hizo | `git log --oneline --since` y `git show --stat` |
| si está sano | la batería entera, mirando **el número de casos** |
| qué falta | `docs/LAMA.md` (LA RUTA) y `README.md` (las fases) |
| qué espera a Jhon | `docs/sql-pendientes.md` |

⚠️ **Ningún porcentaje sin su cuenta a la vista.** La plantilla original ya lo
pedía y es la regla más fácil de violar sin querer. Un *"68 % completo"*
inventado hace tomar peores decisiones que no tener el número. Si no se puede
mostrar la fórmula, no va el número.

⚠️ **La sesión que lo escribe llega SIN MEMORIA, y es a propósito.** No puede
informar lo que cree que hizo: sólo lo que el repositorio dice que pasó.

---

## Las cinco secciones (todos los días)

### 1 · El semáforo — se lee en 30 segundos

Lo primero de la página, y tiene que alcanzar solo. Cinco líneas:

- **Cómo venimos** — 🟢 consolidado · 🟡 en construcción · 🟠 requiere atención · 🔴 crítico
- **Lo que avanzó desde ayer**, en una frase
- **Lo que bloquea hoy**, en una frase
- **La decisión que espera respuesta tuya** (o "ninguna")
- **Lo próximo**, en una frase

### 2 · Lo que cambió, con evidencia

Tabla: commit · qué hizo · qué prueba lo cubre.

Y los números que importan, comparados con ayer:
- casos de prueba (por archivo, y el total)
- pruebas en rojo — **cuáles y desde cuándo**
- si la batería no se pudo correr, **eso se dice**; no se asume verde

**Si no hubo cambios, se dice en una línea.** Un día sin avance es
información, no un hueco que llenar.

### 3 · Lo que bloquea — separado por a quién le toca

La sección más útil para leer camino al trabajo, porque **es la única sobre la
que Jhon puede actuar antes de llegar**.

| Le toca a Jhon | Le toca a Claude |
|---|---|
| pegar un SQL de `sql-pendientes.md` | construir lo que está desbloqueado |
| aprobar una maqueta | escribir la maqueta que falta |
| contestar una decisión | preparar las opciones |
| desplegar las Edge Functions | — |
| pasar preguntas del atlas por NotebookLM | — |

Cada fila dice **qué**, **por qué está frenado**, y **qué desbloquea**.

### 4 · Las tres cosas de mañana

> *"Si mañana sólo pudiéramos construir tres cosas, ¿cuáles elegirías?"*

**La mejor pregunta de la plantilla de GPT, conservada tal cual.** Obliga a
priorizar en vez de listar. Tres, con una línea de por qué cada una.

### 5 · Riesgos NUEVOS · *(antes del cierre)*

Sólo los nuevos. Los ya anotados se **cuentan** (*"7 riesgos abiertos, ver
`docs/LAMA.md`"*), no se repiten.

Por riesgo: qué puede pasar · qué tan grave · qué lo dispararía · qué lo evita.

Buena fuente: los casos límite que la plantilla de GPT lista bien —doble
cierre, pago parcial más descuento, anulación, concurrencia, sin conexión—.
Se revisan de a poco, no todos cada día.

### 6 · El cuadro de avance por área — **cierra el informe**

*(Pedido por Jhon el 2026-09-04.)* La tabla de cuánto llevamos y cuánto falta,
segmentada por área: inventario, bodega, mesas, comanda, cobro, configuración,
mostrador, impresión, arqueo, la conexión con Stock, y el producto
multi-cliente.

⚠️ **NO se recalcula ni se reinventa cada noche. Se LEE de
[`docs/avance-por-area.md`](avance-por-area.md), que es la fuente**, y se pinta
como tabla. Dos copias del mismo estado se desincronizan — es el mismo error
que este informe entero viene a evitar.

Si durante el día una etapa cambió de estado, **se actualiza primero el
documento fuente y después se pinta**. Nunca al revés.

⚠️ **Los porcentajes llevan su cuenta al lado** (`6 de 7`), siempre. Miden
piezas terminadas sobre piezas previstas, no código ni esfuerzo. Un número sin
su cuenta a la vista se lee como medido cuando es una impresión.

**No hay un "avance total del proyecto", y es a propósito:** un número único
mezcla terminar un botón con construir el arqueo de caja, y esconde justo lo
que hay que ver.

---

## Lo que pasa a semanal (los domingos)

Cambian de a poco. Diarias son ruido; una vez por semana se leen con atención.

- **El mapa de módulos** con su estado y madurez
- **Los árboles funcionales** por módulo (Mesas, Cobro, Caja…)
- **El benchmark contra Fudo** — qué hace él, qué hacemos nosotros, qué no
  vale la pena copiar
- **La salud arquitectónica** — base de datos, duplicación, deuda técnica
- **La experiencia de uso** — pasos, toques, fricciones
- **Las conexiones Plus ↔ Stock**

---

## Lo que se sacó del todo, y por qué

| Sección de la plantilla original | Por qué no va |
|---|---|
| **Porcentajes de avance** | Sin la fórmula a la vista, es un número inventado que se lee como medido |
| **El benchmark contra Fudo, diario** | Eso **es** `docs/atlas-fudo.md`, que ya es la fuente. Se cita, no se copia — dos copias se desincronizan |
| **Conexiones Plus ↔ Stock, diario** | Ya es una decisión tomada y fechada: va al final de la ruta. Reabrirla cada mañana **invita a adelantarla**, que es justo lo que la regla evita |
| **Evolución histórica** como sección | Los informes quedan versionados en `docs/informes/`. Una línea en el semáforo alcanza; el historial está ahí para quien quiera comparar |
| **El diagnóstico final** | Era el semáforo otra vez, al final. Se fusionó con la sección 1 |
| **Los ocho roles** ("actúa como arquitecto, PM, QA…") | No cambia lo que el informe encuentra, y ocupa espacio. Lo que importa es qué se revisa, no cómo se llame quien revisa |

---

## La forma

- Un solo archivo HTML que abra directo en el navegador, sin nada más.
- **Se lee en el teléfono**, de pie, camino al trabajo. Esa es la vara.
- La estética de la casa: la paleta del `:root` de `index.html`, tarjetas,
  esquinas redondeadas, **nada de rebordes**, líneas tenues.
- **Datos → tablas → conclusiones → texto**, en ese orden. Si algo se puede
  decir con un número o un color, no se dice con un párrafo.
- **La misma forma todos los días.** Un informe que cambia de estructura no se
  puede comparar con el de ayer.
- ⚠️ **Tres columnas como máximo por tabla.** A 390 px una cuarta columna
  aplasta a las otras tres hasta que no se leen. Medido, no supuesto: la tabla
  de riesgos empezó con cuatro y hubo que bajarla. Lo que sobra —la gravedad,
  el estado— va como **píldora dentro de la primera celda**.
- **Nada de scroll horizontal.** Si algo no entra en el ancho del teléfono, se
  reparte en dos tablas o se acorta el texto.

Vive en `docs/informes/AAAA-MM-DD.html`, y `docs/informes/index.html` lista
todos con su semáforo, el más nuevo arriba.
