# El puente de impresión — Llamita

> Un programa chico que corre en **el computador del local** y hace **dos cosas
> y ninguna más**: le pregunta a Llamita si hay algo que imprimir, y le pide a
> Windows que lo imprima.

---

## 🟢 No instala nada

**Windows ya trae todo lo que hace falta** — PowerShell y .NET vienen de
fábrica desde Windows 7. No hay que instalar Node, ni Python, ni abrir una
terminal, ni actualizar nada nunca.

Son **tres archivos chicos**, unos 15 KB en total:

| Archivo | Para qué |
|---|---|
| **`Llamita Impresora.bat`** | el que se abre con doble clic |
| `Llamita-Impresora.ps1` | el programa |
| `Configurar impresora.bat` | para cambiar de impresora más adelante |

⚠️ **Este `.ps1` va guardado en UTF-8 CON BOM.** PowerShell 5.1 —el de Windows
10— lee un `.ps1` sin BOM como texto ANSI, y ahí las tildes salen convertidas en
basura. Hay una prueba que falla si alguien lo guarda sin él.

---

## Instalarlo — 2 minutos, sin conocimientos técnicos

1. Copiar la carpeta al computador (por ejemplo a `C:\Llamita`).
2. Doble clic en **`Llamita Impresora.bat`**.
3. Sale una **lista numerada de las impresoras** del computador → escribir el
   número de la de comandas y Enter.
4. Sale una **lista de los locales** → elegir cuál es.
5. Pregunta si mandar **un papel de prueba**. Decir que sí.
6. Pregunta si **arrancar solo** cada vez que se prenda el computador. Decir
   que sí.

Listo. La ventana se puede minimizar y queda trabajando.

**Nada de escribir el nombre de la impresora a mano** — se elige de la lista.
Ese era el paso donde se equivoca todo el mundo, porque hay que copiarlo con
las mayúsculas y los espacios exactos.

---

## Por qué existe, en una frase

**El navegador no puede hablarle a la impresora.** Está medido en el local el
2026-09-01, no supuesto:

| Se probó | Resultado |
|---|---|
| ¿El navegador VE la impresora? | **Sí** — `Printer-80` |
| ¿Puede abrirla por USB? | **NO** · `SecurityError` al abrirla |
| ¿Aparece como puerto serie? | **NO** · se escribió y el papel no se movió |

**Y no es que Fudo no la suelte.** Windows toma la impresora con su driver al
instalarla y **no la suelta nunca**. Fudo no se apodera del aparato: le pide a
Windows que imprima. **Este puente hace exactamente lo mismo** — le manda un
trabajo *RAW* al spooler, con el driver que ya está puesto. Por eso **Fudo
sigue imprimiendo igual**.

⚠️ **Existe una forma de forzarlo y NO se hace:** cambiarle el driver a la
impresora (Zadig / WinUSB) dejaría que el navegador la tome, **y con eso Fudo
deja de imprimir**. Es romper el servicio del café para ganar una comodidad
nuestra. Hay una prueba que falla si alguien lo mete en el código.

## Por qué no recibe conexiones

Si el garzón imprime desde el **teléfono**, el puente no puede simplemente
"escuchar en un puerto": una página en `https` no puede llamar a
`http://192.168.x.x` —el navegador lo bloquea— y `localhost` sólo le sirve a
ese mismo computador.

**Entonces el puente no recibe nada: pregunta.** Cada tres segundos. La
conexión sale de él, así que no hay firewall que abrir ni IP que averiguar, y
funciona desde cualquier teléfono del local — y desde fuera también.

Tres segundos de espera para una comanda no los nota nadie, y a cambio el
programa no necesita ni una librería.

---

## Si algo no funciona

| Lo que se ve | Qué es |
|---|---|
| *"No encuentro la impresora"* | se cambió o se reinstaló. Doble clic en **`Configurar impresora.bat`** y elegirla de nuevo |
| Dice *escuchando* y no sale nada | mirá **Ajustes → Impresión** en la app: si el papel dice *esperando*, el puente no lo está viendo; si dice *no salió*, ahí está el motivo escrito |
| *"sin conexión · sigo intentando"* | se cayó el wifi. Vuelve solo cuando vuelve la red |
| Sale el papel con símbolos raros | la tabla de caracteres de la impresora. Se cambia el número `codigo` en la configuración (437 y 850 son los habituales) |
| Windows dice que bloqueó el archivo | botón derecho sobre el `.bat` → Propiedades → **Desbloquear** |

**Nada de lo que pase acá toca el inventario ni las ventas.** Si el puente
falla, lo único que no ocurre es que salga un papel — la comanda ya quedó
guardada, y se puede volver a mandar a imprimir desde **Ajustes → Impresión**.

---

## Para un café nuevo

**No hay que tocar el código.** Las sedes se leen de la base, así que la lista
del paso 4 sale sola. Lo único que cambiaría, si el café tiene su propia base
de datos, son las dos líneas de arriba del `.ps1` — `$UrlPorDefecto` y
`$LlavePorDefecto`.
