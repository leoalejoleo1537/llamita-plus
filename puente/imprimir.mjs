/* HABLARLE A LA IMPRESORA. Vive aparte de `puente.mjs` a propósito: es la
   mitad que puede fallar en el local, y así `probar.mjs` la usa sin tocar la
   base ni la red. Un cálculo con dos dueños se desincroniza — acá el que
   arma los bytes es UNO solo, y lo usan los dos programas.               */
import { writeFileSync, unlinkSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

/* ---------- ESC/POS: los pocos comandos que hacen falta ----------
   La impresora habla ESC/POS, que es el estándar que el propio Fudo exige.
   No hace falta una librería: son cuatro secuencias de bytes. */
export const ESC = {
  init:   '\x1b\x40',          // despertar y limpiar lo anterior
  centro: '\x1b\x61\x01',
  izq:    '\x1b\x61\x00',
  grande: '\x1b\x21\x30',
  normal: '\x1b\x21\x00',
  feed:   '\n\n\n\n',
  corte:  '\x1d\x56\x00',
};

/* El papel sale en la tabla de caracteres de la impresora, no en UTF-8: si se
   le manda una "ñ" cruda salen dos símbolos raros. Se traduce a CP437, que es
   la que traen de fábrica estas térmicas. */
const CP437 = {'á':'\xa0','é':'\x82','í':'\xa1','ó':'\xa2','ú':'\xa3',
  'ñ':'\xa4','Ñ':'\xa5','Á':'A','É':'E','Í':'I','Ó':'O','Ú':'U',
  'ü':'\x81','Ü':'U','°':'\xf8','·':'-','─':'-','→':'->','✓':'*'};
export const aPapel = t => String(t).replace(/[^\x00-\x7f]/g, c => CP437[c] ?? '?');

export function bytes(papel){
  const cuerpo = ESC.init + ESC.izq + aPapel(papel) + ESC.feed + ESC.corte;
  return Buffer.from(cuerpo, 'latin1');
}

/* ---------- imprimir: se le PIDE a Windows, no se le quita el aparato ----
   El spooler acepta un trabajo "RAW", que pasa los bytes tal cual sin que el
   driver los reinterprete. Es lo que hace falta para ESC/POS. */
export function imprimir(cfg, papel){
  const archivo = join(tmpdir(), 'llamita-' + Date.now() + '.bin');
  writeFileSync(archivo, bytes(papel));
  const ps = `
    $ErrorActionPreference = 'Stop'
    Add-Type -Namespace W -Name Spool -MemberDefinition @'
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
    $b = [System.IO.File]::ReadAllBytes(${JSON.stringify(archivo)})
    $h = [IntPtr]::Zero
    if (-not [W.Spool]::OpenPrinter(${JSON.stringify(cfg.impresora)}, [ref]$h, [IntPtr]::Zero)) {
      throw "No encuentro la impresora ${cfg.impresora}"
    }
    $di = New-Object W.Spool+DOCINFO
    [void][W.Spool]::StartDocPrinter($h, 1, $di)
    [void][W.Spool]::StartPagePrinter($h)
    $escritos = 0
    [void][W.Spool]::WritePrinter($h, $b, $b.Length, [ref]$escritos)
    [void][W.Spool]::EndPagePrinter($h)
    [void][W.Spool]::EndDocPrinter($h)
    [void][W.Spool]::ClosePrinter($h)
    if ($escritos -ne $b.Length) { throw "La impresora tomo $escritos de $($b.Length) bytes" }
  `;
  try {
    execFileSync('powershell', ['-NoProfile','-NonInteractive','-Command', ps],
                 {stdio:['ignore','pipe','pipe']});
  } finally {
    try { unlinkSync(archivo); } catch { /* si no se puede borrar, da igual */ }
  }
}


/* El papel de prueba. Lleva las tildes y la ñ a propósito: si salen mal, se
   ve acá y no la primera vez que una comanda diga "Medialuna de jamon". */
export function imprimirPrueba(cfg){
  imprimir(cfg, [
    '      LLAMITA',
    '   ---------------------',
    '   Papel de prueba',
    '   Sede: ' + cfg.sede,
    '   ' + new Date().toLocaleString('es-CL'),
    '   ---------------------',
    '   Acentos: á é í ó ú ñ Ñ ü',
    '   Si esto se lee bien,',
    '   el puente esta listo.',
  ].join('\n'));
}
