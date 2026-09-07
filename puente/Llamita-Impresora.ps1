# =============================================================================
#  LLAMITA · el puente de impresion
# =============================================================================
#  Corre en el computador del local. Hace dos cosas y ninguna mas:
#
#    1. le pregunta cada pocos segundos a Llamita si hay algo que imprimir
#    2. le PIDE a Windows que lo imprima, con el driver que ya esta puesto
#
#  NO INSTALA NADA. Windows ya trae PowerShell y .NET, que es todo lo que hace
#  falta. No hay Node, ni npm, ni terminal, ni una version que actualizar.
#
#  ATENCION AL GUARDAR ESTE ARCHIVO: va en UTF-8 CON BOM. PowerShell 5.1 —el
#  que viene con Windows 10— lee un .ps1 sin BOM como si fuera texto ANSI, y
#  ahi las tildes del papel de prueba salen convertidas en basura. Con BOM lo
#  lee bien. Hay una prueba que falla si alguien lo guarda sin el.
#
#  POR QUE NO LE HABLA A LA IMPRESORA DIRECTO: esta medido en el local el
#  2026-09-01. El navegador la VE pero no puede abrirla —Windows se queda con
#  ella y no la suelta— y por puerto serie no aparece. Fudo hace exactamente lo
#  mismo que este puente: no se apodera del aparato, le pide a Windows.
#
#  POR QUE NO ABRE NINGUN PUERTO: si el garzon imprime desde el telefono, una
#  pagina en https no puede llamar a una direccion de la red local. Entonces el
#  puente no recibe nada: pregunta. Sin conexion entrante no hay firewall, ni
#  IP que averiguar, y funciona desde cualquier telefono.
# =============================================================================

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'Llamita - impresora'

$CarpetaCfg = Join-Path $env:APPDATA 'Llamita'
$ArchivoCfg = Join-Path $CarpetaCfg 'impresora.json'

# Los datos de Llamita Plus. Son los mismos que ya viajan en la app: la llave
# es la PUBLICABLE, la que puede leer y escribir solo lo que las politicas
# permiten. Un cliente nuevo cambia estas dos lineas y nada mas.
$UrlPorDefecto   = 'https://iuryhsjucblmebdogewa.supabase.co'
$LlavePorDefecto = 'sb_publishable_NxrNACdDllRjfRYeMmsGJw_sqWO0DrC'

function Escribir($texto, $color = 'Gray') { Write-Host $texto -ForegroundColor $color }
function Titulo($texto) {
  Write-Host ''
  Write-Host "  $texto" -ForegroundColor Cyan
  Write-Host ('  ' + ('-' * $texto.Length)) -ForegroundColor DarkGray
}

# -----------------------------------------------------------------------------
#  HABLARLE A LA IMPRESORA
# -----------------------------------------------------------------------------
#  Se le manda un trabajo "RAW" al spooler: los bytes pasan tal cual, sin que el
#  driver los reinterprete. Es lo que hace falta para ESC/POS —el idioma de las
#  termicas— y es lo que permite que Fudo siga imprimiendo igual, porque no le
#  quitamos el aparato a nadie.
Add-Type -Namespace Llamita -Name Spool -MemberDefinition @'
  [DllImport("winspool.drv", CharSet=CharSet.Auto, SetLastError=true)]
  public static extern bool OpenPrinter(string src, out IntPtr h, IntPtr d);
  [DllImport("winspool.drv", SetLastError=true)]
  public static extern bool ClosePrinter(IntPtr h);
  [DllImport("winspool.drv", CharSet=CharSet.Auto, SetLastError=true)]
  public static extern bool StartDocPrinter(IntPtr h, int lvl, [In,MarshalAs(UnmanagedType.LPStruct)] DOCINFO di);
  [DllImport("winspool.drv", SetLastError=true)] public static extern bool EndDocPrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)] public static extern bool StartPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)] public static extern bool EndPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError=true)] public static extern bool WritePrinter(IntPtr h, byte[] b, int n, out int w);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Auto)] public class DOCINFO {
    [MarshalAs(UnmanagedType.LPTStr)] public string pDocName = "Llamita";
    [MarshalAs(UnmanagedType.LPTStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPTStr)] public string pDataType = "RAW"; }
'@

function Convertir-APapel($texto, $codigo) {
  # El papel NO sale en UTF-8: sale en la tabla de caracteres de la impresora.
  # Si se le manda una "n con tilde" cruda salen dos simbolos raros. Lo traduce
  # .NET, que ya sabe hacerlo bien — mucho mejor que una tabla escrita a mano.
  # De paso, la linea divisoria existe de verdad en la CP437 y sale como linea.
  $enc = [System.Text.Encoding]::GetEncoding(
    [int]$codigo,
    [System.Text.EncoderFallback]::ReplacementFallback,
    [System.Text.DecoderFallback]::ReplacementFallback)
  return $enc.GetBytes($texto)
}

function Armar-Papel($texto, $codigo) {
  $ESC_INIT  = [byte[]](0x1B, 0x40)              # despertar y limpiar
  $ESC_IZQ   = [byte[]](0x1B, 0x61, 0x00)        # alinear a la izquierda
  $AVANCE    = [byte[]](0x0A, 0x0A, 0x0A, 0x0A)  # que el papel salga del cabezal
  $CORTE     = [byte[]](0x1D, 0x56, 0x00)        # y recien ahi, cortar
  # El avance ANTES del corte no es decoracion: sin el, la cuchilla corta
  # encima de la ultima linea y el ticket sale sin su pie.
  $cuerpo = Convertir-APapel $texto $codigo
  return $ESC_INIT + $ESC_IZQ + $cuerpo + $AVANCE + $CORTE
}

function Imprimir($impresora, $texto, $codigo) {
  $bytes = Armar-Papel $texto $codigo
  $h = [IntPtr]::Zero
  if (-not [Llamita.Spool]::OpenPrinter($impresora, [ref]$h, [IntPtr]::Zero)) {
    throw "No encuentro la impresora '$impresora'"
  }
  try {
    $di = New-Object Llamita.Spool+DOCINFO
    [void][Llamita.Spool]::StartDocPrinter($h, 1, $di)
    [void][Llamita.Spool]::StartPagePrinter($h)
    $escritos = 0
    [void][Llamita.Spool]::WritePrinter($h, $bytes, $bytes.Length, [ref]$escritos)
    [void][Llamita.Spool]::EndPagePrinter($h)
    [void][Llamita.Spool]::EndDocPrinter($h)
    if ($escritos -ne $bytes.Length) {
      throw "La impresora tomo $escritos de $($bytes.Length) bytes"
    }
  } finally { [void][Llamita.Spool]::ClosePrinter($h) }
}

function Papel-De-Prueba($cfg) {
  $t = @(
    '      LLAMITA',
    '   ---------------------',
    '   Papel de prueba',
    "   Sede: $($cfg.sede)",
    "   $(Get-Date -Format 'dd/MM/yyyy HH:mm')",
    '   ---------------------',
    '   Acentos: a e i o u n',
    '   Con tilde: ',
    '   Si esto se lee bien,',
    '   el puente esta listo.'
  ) -join "`n"
  # Los acentos van aparte para que, si la tabla de caracteres esta mal, se vea
  # exactamente en que linea se rompe y no en todo el papel.
  $t = $t -replace 'Con tilde: ', "Con tilde: $([char]0xE1)$([char]0xE9)$([char]0xED)$([char]0xF3)$([char]0xFA) $([char]0xF1)"
  Imprimir $cfg.impresora $t $cfg.codigo
}

# -----------------------------------------------------------------------------
#  HABLARLE A LLAMITA
# -----------------------------------------------------------------------------
#  Se pregunta cada pocos segundos en vez de mantener una conexion abierta. Es
#  mas simple, no necesita librerias, y sobrevive a que se caiga el wifi un
#  rato: cuando vuelve, sigue preguntando. Tres segundos de espera para una
#  comanda no los nota nadie.
function Llamar-Llamita($cfg, $metodo, $ruta, $cuerpo) {
  $cabeceras = @{
    'apikey'        = $cfg.llave
    'Authorization' = "Bearer $($cfg.llave)"
    'Content-Type'  = 'application/json'
    'Prefer'        = 'return=minimal'
  }
  $url = "$($cfg.url)/rest/v1/$ruta"
  if ($cuerpo) {
    return Invoke-RestMethod -Uri $url -Method $metodo -Headers $cabeceras -Body ($cuerpo | ConvertTo-Json -Compress)
  }
  return Invoke-RestMethod -Uri $url -Method $metodo -Headers $cabeceras
}

# -----------------------------------------------------------------------------
#  LA PRIMERA VEZ · elegir impresora y sede
# -----------------------------------------------------------------------------
function Listar-Impresoras {
  # `Get-Printer` no existe en todos los Windows. Si no esta, se pregunta por
  # el otro camino, que existe desde siempre. Una lista vacia se dice, no se
  # deja pasar en silencio.
  try   { return @(Get-Printer | Select-Object -ExpandProperty Name) }
  catch { return @(Get-CimInstance -ClassName Win32_Printer | Select-Object -ExpandProperty Name) }
}

function Elegir-De-Lista($titulo, $opciones) {
  Titulo $titulo
  for ($i = 0; $i -lt $opciones.Count; $i++) {
    Write-Host ("   {0}) {1}" -f ($i + 1), $opciones[$i]) -ForegroundColor White
  }
  Write-Host ''
  while ($true) {
    $r = Read-Host '   Escribi el numero y apreta Enter'
    $n = 0
    if ([int]::TryParse($r, [ref]$n) -and $n -ge 1 -and $n -le $opciones.Count) {
      return $opciones[$n - 1]
    }
    Escribir '   Ese numero no esta en la lista. Proba de nuevo.' 'Yellow'
  }
}

function Configurar {
  Titulo 'Configuracion · se hace una sola vez'

  $impresoras = Listar-Impresoras
  if (-not $impresoras -or $impresoras.Count -eq 0) {
    Escribir '   No encontre ninguna impresora instalada en este computador.' 'Red'
    Escribir '   Instalala primero desde Windows y volve a abrir este programa.' 'Red'
    Read-Host '   Enter para salir'
    exit 1
  }
  $impresora = Elegir-De-Lista 'Cual es la impresora de comandas?' $impresoras

  $cfg = [ordered]@{
    impresora = $impresora
    sede      = ''
    url       = $UrlPorDefecto
    llave     = $LlavePorDefecto
    codigo    = 437
  }

  # Las sedes se traen de Llamita en vez de escribirlas acá: asi este mismo
  # programa sirve para otro cafe sin tocarle una linea.
  $sedes = @()
  try {
    $filas = Llamar-Llamita $cfg 'GET' 'mesas?select=sede&limit=2000' $null
    $sedes = @($filas | Select-Object -ExpandProperty sede -Unique)
  } catch { }

  if ($sedes.Count -gt 0) { $cfg.sede = Elegir-De-Lista 'De que local es esta impresora?' $sedes }
  else {
    Titulo 'De que local es esta impresora?'
    Escribir '   No pude leer la lista (puede ser que no haya internet todavia).' 'Yellow'
    $cfg.sede = Read-Host '   Escribi el nombre del local, tal como esta en Llamita'
  }

  if (-not (Test-Path $CarpetaCfg)) { [void](New-Item -ItemType Directory -Path $CarpetaCfg) }
  $cfg | ConvertTo-Json | Set-Content -Path $ArchivoCfg -Encoding UTF8
  Escribir ''
  Escribir "   Listo. Guardado en $ArchivoCfg" 'Green'
  return $cfg
}

function Leer-Configuracion {
  if (Test-Path $ArchivoCfg) {
    try { return (Get-Content $ArchivoCfg -Raw | ConvertFrom-Json) } catch { }
  }
  return $null
}

function Ofrecer-Arranque {
  # Que se levante solo con Windows. Se PREGUNTA en vez de hacerlo callado:
  # un programa que se mete solo en el arranque sin avisar es exactamente lo
  # que la gente desinstala con desconfianza.
  $inicio = [Environment]::GetFolderPath('Startup')
  $acceso = Join-Path $inicio 'Llamita Impresora.lnk'
  if (Test-Path $acceso) { return }
  Write-Host ''
  $r = Read-Host '   Queres que arranque solo cada vez que se prenda el computador? (s/n)'
  if ($r -notmatch '^[sS]') { return }
  $bat = Join-Path $PSScriptRoot 'Llamita Impresora.bat'
  if (-not (Test-Path $bat)) { Escribir '   No encontre el archivo para el acceso directo.' 'Yellow'; return }
  $w = New-Object -ComObject WScript.Shell
  $l = $w.CreateShortcut($acceso)
  $l.TargetPath       = $bat
  $l.WorkingDirectory = $PSScriptRoot
  $l.Description      = 'Llamita - puente de impresion'
  $l.Save()
  Escribir '   Listo: va a arrancar solo.' 'Green'
}

# -----------------------------------------------------------------------------
#  EL TRABAJO
# -----------------------------------------------------------------------------
function Vaciar-Cola($cfg) {
  # De a uno y en orden. Dos papeles saliendo a la vez en una termica es un
  # papel ilegible; y el orden importa porque una anulacion despues de su
  # comanda cuenta una historia, y al reves no cuenta nada.
  while ($true) {
    $ruta = "lama_impresiones?sede=eq.$([uri]::EscapeDataString($cfg.sede))" +
            "&estado=eq.pendiente&order=creada_at.asc&limit=1&select=*"
    $filas = @(Llamar-Llamita $cfg 'GET' $ruta $null)
    if ($filas.Count -eq 0) { return }
    $f = $filas[0]
    $hora = Get-Date -Format 'HH:mm:ss'
    try {
      Imprimir $cfg.impresora $f.contenido $cfg.codigo
      Llamar-Llamita $cfg 'PATCH' "lama_impresiones?id=eq.$($f.id)" `
        @{ estado = 'impresa'; impresa_at = (Get-Date).ToUniversalTime().ToString('o') } | Out-Null
      Escribir "   [$hora]  salio  ·  $($f.tipo) #$($f.id)" 'Green'
    } catch {
      # Queda escrito POR QUE fallo, en la fila que fallo. Un papel que no sale
      # y no deja rastro es la peor falla que puede tener esto: nadie va a
      # buscar lo que parece estar bien.
      $motivo = ($_.Exception.Message -split "`n")[0]
      if ($motivo.Length -gt 300) { $motivo = $motivo.Substring(0, 300) }
      try {
        Llamar-Llamita $cfg 'PATCH' "lama_impresiones?id=eq.$($f.id)" `
          @{ estado = 'error'; error = $motivo } | Out-Null
      } catch { }
      Escribir "   [$hora]  NO SALIO  ·  $($f.tipo) #$($f.id)  ·  $motivo" 'Red'
      return   # si la impresora esta caida, no tiene sentido seguir intentando
    }
  }
}

# -----------------------------------------------------------------------------
#  ARRANQUE
# -----------------------------------------------------------------------------
Clear-Host
Write-Host ''
Write-Host '   LLAMITA · impresora' -ForegroundColor Cyan
Write-Host '   ==================' -ForegroundColor DarkGray

$cfg = Leer-Configuracion
$primeraVez = $false
if (-not $cfg -or $args -contains '-configurar') { $cfg = Configurar; $primeraVez = $true }

Write-Host ''
Escribir "   Impresora:  $($cfg.impresora)" 'White'
Escribir "   Local:      $($cfg.sede)" 'White'

if ($primeraVez -or ($args -contains '-probar')) {
  Write-Host ''
  $r = Read-Host '   Mando un papel de prueba? (s/n)'
  if ($r -match '^[sS]') {
    try { Papel-De-Prueba $cfg; Escribir '   Mandado. Fijate si salio el papel.' 'Green' }
    catch { Escribir "   No salio: $($_.Exception.Message)" 'Red' }
  }
  Ofrecer-Arranque
}

Write-Host ''
Escribir '   Escuchando. Podes minimizar esta ventana.' 'DarkGray'
Escribir '   Para cambiar la impresora, cerra y abri con -configurar.' 'DarkGray'
Write-Host ''

$avisoDeRed = $false
while ($true) {
  try {
    Vaciar-Cola $cfg
    if ($avisoDeRed) { Escribir "   [$(Get-Date -Format 'HH:mm:ss')]  volvio la conexion" 'Green'; $avisoDeRed = $false }
  } catch {
    # La red se cae. Se dice UNA vez y no en cada vuelta: un mensaje repetido
    # cada tres segundos se convierte en ruido que nadie lee.
    if (-not $avisoDeRed) {
      Escribir "   [$(Get-Date -Format 'HH:mm:ss')]  sin conexion · sigo intentando" 'Yellow'
      $avisoDeRed = $true
    }
  }
  Start-Sleep -Seconds 3
}
