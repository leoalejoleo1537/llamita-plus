# El puente de impresión — Llamita Lama

> Un programa chico que corre en **el computador del local** y hace **dos
> cosas, y ninguna más**: escucha la cola de impresión de Llamita, y le pide a
> Windows que imprima.

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
Windows que imprima. Por eso su programa convive con el driver en vez de
pelearlo — y por eso este puente hace exactamente lo mismo.

⚠️ **Existe una forma de forzarlo y NO se hace:** cambiarle el driver a la
impresora (Zadig/WinUSB) dejaría que el navegador la tome, **y con eso Fudo
deja de imprimir**. Es romper el servicio del café para ganar una comodidad
nuestra.

## Por qué no recibe conexiones

Si el garzón imprime desde el **teléfono**, el puente no puede simplemente
"escuchar en un puerto": una página en `https` no puede llamar a
`http://192.168.x.x` —el navegador lo bloquea— y `localhost` sólo le sirve a
ese mismo computador.

**Entonces el puente no recibe nada: se suscribe a Supabase y saca lo que
aparezca.** La conexión sale de él. Sin conexión entrante no hay contenido
mixto, ni firewall, ni IP fija que averiguar, y funciona desde cualquier
teléfono del local — y también desde fuera del local.

---

## Instalarlo (una sola vez, en el computador del local)

**Hace falta ir al local.** Es la misma visita que Fudo ya cobró con su
extensión de Chrome y su aplicación de Windows.

1. Instalar **Node.js** desde `nodejs.org` (la versión LTS, botón grande).
2. Copiar esta carpeta `puente/` al computador, por ejemplo en
   `C:\\llamita-puente`.
3. Abrir esa carpeta, hacer doble clic en **`instalar.bat`**.
4. Se abre el Bloc de notas con un archivo de configuración. Completar:
   - **la impresora**: su nombre EXACTO como aparece en *Dispositivos e
     impresoras* de Windows (por ejemplo `Printer-80`)
   - **la sede**: `plaza` o `angamos`
5. Guardar, cerrar, y doble clic en **`probar.bat`**. Tiene que salir un papel
   de prueba.
6. Si salió: doble clic en **`arrancar.bat`** y dejar esa ventana abierta.

**Para que arranque solo con Windows:** tecla Windows + R, escribir
`shell:startup`, Enter, y arrastrar ahí un acceso directo de `arrancar.bat`.

---

## Qué hacer si no imprime

| Lo que se ve | Qué es |
|---|---|
| *"No encuentro la impresora"* | el nombre no coincide con el de Windows. Copiarlo tal cual, con mayúsculas y espacios |
| La ventana dice **conectado** y no sale nada | la cola no está en vivo: falta correr `sql/2026-09-lama-cola-de-impresion.sql` |
| Sale el papel cortado o con símbolos raros | la impresora no está en modo ESC/POS. Se arregla en su configuración, no acá |
| La ventana se cerró sola | volver a abrir `arrancar.bat`; el puente vuelve a tomar lo que quedó pendiente |

**Nada de lo que pase acá toca el inventario ni las ventas.** Si el puente
falla, lo único que no ocurre es que salga un papel — la comanda ya quedó
guardada y se puede volver a mandar a imprimir.
