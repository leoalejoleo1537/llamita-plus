# La impresora — todo lo que sabemos

> **Documento de referencia.** Junta en un solo lugar la investigación sobre
> cómo imprimir comandas desde Llamita: lo medido en el local, cómo lo resuelve
> Fudo, y el diseño que quedó decidido.
>
> Última actualización: **2026-09-07**.
>
> ⚠️ **Lo trajo Jhon al chat el 2026-09-07 para frenar un error mío**, y lo
> frenó a tiempo. Ver *"La corrección del 7 de septiembre"* al final: el plan
> que yo había escrito pedía **instalar Node.js** en el computador del café.
> Estaba mal.

---

## Resumen: lo que ya está cerrado

| Pregunta | Respuesta | Cómo se supo |
|---|---|---|
| ¿Qué impresora es? | **Xprinter XP-N160II**, térmica de 80 mm | la vio Jhon |
| ¿Cómo está conectada? | **USB** al computador del local. No hay cable de red | miró los cables: solo corriente y PC |
| ¿Qué idioma habla? | **ESC/POS**, el estándar de la industria | es el que el propio Fudo exige |
| ¿Está configurada? | **Sí, funcionando.** No hay que instalarla ni buscarle IP | funciona con Fudo hoy |
| ¿Su identidad USB? | **vendorId `0x1FC9` · productId `0x2016`**, se presenta como `Printer-80` | medido en el local, 2026-09-01 |
| ¿El navegador puede hablarle directo? | **NO.** Las dos vías están cerradas | medido, ver abajo |
| ¿Hace falta un programa en el computador? | **Sí, es obligatorio** | conclusión de la medición |

---

## LO MEDIDO EN EL LOCAL — 2026-09-01

Hasta esa fecha era razonamiento. Esto es la prueba, hecha con
`impresora-prueba.html` en el Chrome del computador del local.

### Vía 1 · USB directo (WebUSB)

| Paso | Resultado |
|---|---|
| ¿El navegador VE la impresora? | **Sí.** `Printer-80`, fabricante `Printer` |
| ¿Puede abrirla? | **NO.** `SecurityError — Access denied` al hacer `open()` |

**Falló ANTES de intentar imprimir**, al abrir el dispositivo. No es un problema
de nuestro código: es Windows negándose a compartirla.

### Vía 2 · Puerto serie (Web Serial)

| Paso | Resultado |
|---|---|
| ¿Aparece la impresora como puerto COM? | **NO.** Ningún puerto de la máquina es la impresora |
| ¿Se probó? | Sí — se abrieron puertos, se escribió, y **el papel no se movió** |

**Se probó con el envío más pequeño posible** —despertar y avanzar papel, diez
bytes, sin texto ni corte— justamente para que un resultado en blanco no
admitiera dos lecturas. Si el rollo no se mueve, no le estamos hablando.

### Conclusión

**Las dos puertas del navegador están cerradas, y con datos.** El puente es
obligatorio. Y averiguarlo costó un rato en el local, no dos meses de puente a
medio hacer.

---

## ⚠️ LA CORRECCIÓN QUE DECIDE EL DISEÑO

Al medirlo, la conclusión natural fue: *"Fudo no ha terminado de soltar la
impresora"*. **No es eso**, y la diferencia importa:

- **Windows toma la impresora con su driver al instalarla, y se queda con
  ella.** No es un préstamo temporal.
- **Fudo no se apodera del aparato:** le pide a Windows que imprima. Por eso su
  programa convive con el driver en vez de pelearlo.
- **Cerrar Fudo no libera nada.** No hay nada que esperar.

**Y acá está la salida, que es lo contrario de lo que uno intenta primero:** si
Windows no comparte la impresora pero sí imprime cuando se lo piden, el puente
**no tiene que quitarle el aparato — tiene que pedírselo**. Se le mandan los
bytes ESC/POS crudos a la cola de impresión de Windows, con el driver que ya
está puesto. Nada se desinstala y **Fudo sigue imprimiendo igual**.

---

## ⛔ LO QUE NO SE HACE, Y ES IMPORTANTE

**Existe una forma de forzar el acceso USB y no se usa:** cambiarle el driver a
la impresora en Windows (Zadig / WinUSB) dejaría que el navegador la tome —
**y con eso Fudo deja de imprimir.**

Es romper el servicio del café para ganar una comodidad nuestra. **No se
propone ni se prueba en el computador del local.**

---

## CÓMO LO RESUELVE FUDO — confirmado por su documentación

Esto salió del atlas (`docs/atlas-fudo.md`, pregunta C1), y confirma que el
camino del puente no es un rodeo nuestro: es el mismo que ellos tomaron.

**Fudo instala DOS cosas en el computador del local:**

| | Qué dice su pantalla de configuración |
|---|---|
| Una **extensión de Chrome** | *"permite que el navegador pueda encontrar impresoras conectadas"* |
| Una **aplicación de Windows** | *"permite que Fudo acceda a las impresoras conectadas"* |

**Su cadena completa, paso a paso:**

1. El garzón confirma la comanda en la app.
2. La orden va al servidor de Fudo en la nube.
3. El servidor devuelve la comanda en JSON a la aplicación del navegador.
4. **La extensión del navegador hace un `HTTP POST` a `http://localhost:<puerto>`**
   hacia el agente de impresión local.
5. **El agente traduce el JSON a ESC/POS.**
6. El agente inyecta los bytes en el puerto (USB, serie o red).
7. Sale el papel.

> **Corrección histórica:** durante un tiempo el proyecto dio por hecho que Fudo
> no instalaba nada en el computador del local, deducido de *"si cierro la
> pestaña deja de imprimir"*. Eso era cierto **y no probaba** lo otro. La
> respuesta estaba en la pantalla que usa la gente, no en razonar sobre el
> síntoma.

---

## CÓMO QUEDA NUESTRO PUENTE

Un programa chico en el computador del local que hace **dos cosas y ninguna
más**:

| | |
|---|---|
| **Escucha a Supabase** | se suscribe a una cola de impresión y espera. **No abre ningún puerto**: la conexión sale de él |
| **Le pide a Windows que imprima** | manda los bytes ESC/POS crudos a la cola de impresión, con el driver que ya está |

### Por qué NO copiamos el modelo de Fudo exactamente

Fudo usa `localhost` — la extensión le habla al agente en la misma máquina. Eso
funciona **solo para esa computadora**.

**Nosotros necesitamos que el garzón imprima desde el teléfono**, y ahí ese
modelo se cae:

- Una página en `https` **no puede llamar a `http://192.168.x.x`** — el
  navegador lo bloquea por contenido mixto.
- Y `localhost` solo le sirve a esa misma máquina.

**Por eso el puente no recibe nada: se suscribe.** Sin conexión entrante no hay
contenido mixto, ni firewall, ni IP fija que averiguar.

### Las tres cosas que este diseño evita

1. **No pelea con Windows por el aparato** — que es lo que falló en la medición.
2. **No hay contenido mixto ni firewall**, porque nadie le habla de afuera.
3. **Funciona desde cualquier teléfono del local**, y desde fuera también.

### Lo que cuesta, dicho sin adornos

Hay que **instalarlo en ese computador y dejarlo arrancando con Windows**. Es
una visita al local — **la misma visita que Fudo ya cobró** con su extensión y
su aplicación. No existe una versión de esto sin programa instalado: eso es
exactamente lo que se midió.

---

## DATOS SUELTOS QUE VALEN

### Una sola impresora, un solo papel

Jhon confirmó que **todo sale por la misma Xprinter del mesón**: no hay que
partir la comanda entre cocina y barra. Eso ahorra trabajo real.

⚠️ El día que haya un segundo local con dos impresoras, **esa división será una
decisión nueva y no un supuesto heredado**.

### Marcas que Fudo desaconseja

**DINON** y **OCOM** — por *"problemas de compatibilidad, cortes erróneos y
fallas en la impresión de comandas"*.

Las que recomienda: **EPSON TM-T20 II/III**, **EPSON TM-T88**, **Bixolon SRP
350**, **3nStar RPT0008**.

Vale anotarlo: el día que haya que comprar impresora para otro local, esa lista
es experiencia ajena gratis.

### Boletas con código PDF417 (formato chileno)

Para eso Fudo solo lista **EPSON TM-T20 II/III** y **3nStar RPT0008**. No toda
térmica sirve.

**Hoy no aplica** —la boleta sale por Mercado Pago y esa línea no se cruza— pero
se anota por si algún día cambia.

### Lo que Fudo NO documenta, y habrá que decidir nosotros

Del atlas, pregunta G1: **cuando se anula un producto ya comandado, las guías de
Fudo no dicen si se imprime un ticket físico de "ANULACIÓN" en la cocina**, o si
el garzón avisa de viva voz. Solo documentan el caso de la pantalla de cocina
(KDS).

Es una decisión que nos va a tocar tomar a nosotros.

---

## LA HERRAMIENTA DE PRUEBA

**`impresora-prueba.html`**, en la raíz del repositorio. Es una página suelta
que no toca la app ni la base.

**Qué hace:**
- Prueba las dos vías: USB directo y puerto serie
- Anota `vendorId` y `productId` aunque después falle todo — ese dato sirve
  igual para construir el puente
- Botón **"Solo avanzar papel"**: manda diez bytes (despertar + saltos de
  línea), sin texto ni corte. Separa *"¿me escucha?"* de *"¿entiende lo que le
  mando?"*
- Selector de velocidad para el puerto serie (9600 … 115200)
- Botón para **soltar la impresora** — mientras esté tomada, Fudo no imprime

**Cómo se usa:** se abre en el Chrome del computador del local, con el local
tranquilo. Sirve para repetir esta misma medición en otro local o con otra
impresora.

⚠️ **En el puerto serie, "Escrito" no prueba nada:** `write()` termina cuando el
sistema se hizo cargo de los bytes, no cuando la impresora los recibió. **La
única pregunta que vale es si salió papel.**

---

## EL ORDEN DE TRABAJO

**El puente va PRIMERO entre las cosas grandes, y AISLADO** — sin tocar la app
ni la base.

Es la lección de §0.5 aplicada antes de escribir: **si falla, que falle solo**,
y que se sepa en dos días y no en dos meses. Es una pieza chica —recibe un texto
e imprime— y no tiene por qué saber nada de inventario.

**Pero no antes de que las comandas sean confiables.** Construir el puente ahora
sería tener un cartero listo para cartas que todavía no se escriben.

**Necesita que Jhon vaya al local** para instalarlo.

---

## LA CORRECCIÓN DEL 7 DE SEPTIEMBRE — el puente no instala nada

**Lo que yo había escrito, y estaba mal:** el plan de la visita al local
empezaba con *"instalá Node.js desde nodejs.org"*. Jhon lo frenó con el
argumento correcto:

> *"me preocupa mucho que me digas que tengo que instalar nodejs… si quiero
> vender este proyecto a cafeterías debe ser fácil de instalar. No me interesa
> si es difícil de construir la infraestructura, pero que sea fácil para el
> cliente."*

**Tiene razón, y el error de fondo es de método, no de herramienta:** yo elegí
lo que me resultaba cómodo de escribir y lo cargué en la cuenta del cliente.
Un café no puede depender de que alguien le instale herramientas de
programador — y menos si esto se vende.

### Lo que NO cambió, y conviene decirlo

**Sigue haciendo falta un programa en el computador del local.** Eso no era una
elección: está medido (las dos vías del navegador están cerradas) y **Fudo hace
exactamente lo mismo** — una extensión de Chrome y una aplicación de Windows.
Lo que cambió no es *si* hay un programa: es **cuánto le cuesta al cliente
ponerlo**.

### Cómo quedó

| | Antes (mal) | Ahora |
|---|---|---|
| Qué instala el cliente | Node.js + `npm install` | **nada** |
| Qué se descarga | una carpeta con `package.json` | **3 archivos, ~15 KB** |
| Cómo se abre | tres `.bat` distintos | **un doble clic** |
| La impresora | escribir el nombre exacto a mano | **se elige de una lista** |
| El local | editar un archivo en el Bloc de notas | **se elige de una lista** |
| Arrancar con Windows | arrastrar un acceso directo | **te lo pregunta** |

**Está escrito en PowerShell**, que Windows trae de fábrica desde Windows 7,
junto con .NET. No hay nada que bajar, nada que actualizar y nada que se rompa
cuando salga una versión nueva de algo.

### Las dos opciones que se descartaron, y por qué

**Un `.exe` de 115 MB.** Se probó de verdad: `bun build --compile` produce un
ejecutable de Windows desde acá. **Se descartó por dos razones**, y la segunda
pesa más que la primera:

1. Pesa 115 MB para hacer algo que entra en 15 KB.
2. **Un `.exe` sin firmar que se baja de internet dispara SmartScreen** —ese
   *"Windows protegió tu PC"*— y no es raro que un antivirus lo marque, porque
   los ejecutables empaquetados así se parecen a lo que hace el malware.
   **Para algo que se le va a entregar a un cliente, eso es peor que un
   archivo de texto.** Firmarlo cuesta plata y trámite, y no lo justifica.

**Imprimir desde el navegador con `window.print()`.** No necesita nada
instalado, y por eso vale mirarlo: pero sólo funciona **desde ese mismo
computador** —el garzón imprime desde el teléfono— y no da control del corte ni
de la alineación. Sirve para una hoja carta, no para una comanda.

### La regla que queda escrita

> **Lo difícil va de nuestro lado. Lo del cliente tiene que ser un doble clic.**
> Si una decisión de arquitectura le agrega un paso a quien compra el sistema,
> hay que buscar otra — aunque de este lado cueste más.
