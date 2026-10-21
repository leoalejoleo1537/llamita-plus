/* Catálogo P1. Todas las escrituras pasan por una sola RPC atómica. */
let PANEL = { filas:[], grupos:[], areas:[], ficha:null, carga:0, apertura:0, guardando:false, intento:null };
function panelPermitido(){ return !!(PERMISOS.puede_editar && ['central','plaza'].includes(SEDE)); }
function panelMensaje(texto){ $('panel-mensaje').textContent=texto; }
async function panelRPC(nombre,args){
  const {data,error}=await sb.rpc(nombre,args);
  if(error)throw error;
  return data;
}
async function panelCargar(){
  if(!panelPermitido())return;
  const carga=++PANEL.carga;
  panelMensaje('Cargando catálogo…');
  try{
    const [catalogo,areas]=await Promise.all([
      panelRPC('panel_productos_listar',{p_consulta:$('panel-q').value.trim()}),
      panelRPC('areas_operativas_listar',{p_sede:'plaza',p_incluir_archivadas:false})
    ]);
    if(carga!==PANEL.carga||!panelPermitido())return;
    PANEL.filas=catalogo.productos||[]; PANEL.grupos=catalogo.grupos||[];
    PANEL.areas=(areas||[]).filter(a=>a.estado==='activa'&&a.ubicacion_activa);
    $('panel-lista').innerHTML=PANEL.filas.map(p=>`<button type="button" class="panel-fila" data-panel-id="${esc(p.id)}"><span><strong>${esc(p.producto)}</strong><small>${esc(p.unidad||'Unidad pendiente')} · Maestro #${esc(p.id)}</small></span><span>${p.costo_pendiente?'Costo pendiente':`Costo: ${Number(p.costo_compra).toLocaleString('es-CL')}`}</span></button>`).join('');
    panelMensaje(PANEL.filas.length===100?'Mostrando los primeros 100 insumos. Busca por nombre para acotar.':PANEL.filas.length?`${PANEL.filas.length} insumos`:'No hay coincidencias. Puedes crear un nuevo insumo.');
  }catch(e){if(carga===PANEL.carga)panelMensaje(e.message||'No se pudo cargar el catálogo. Vuelve a buscar.');}
}
function panelCerrar(){
  if(PANEL.guardando)return;
  ++PANEL.apertura; PANEL.ficha=null; PANEL.intento=null;
  $('panel-ficha').hidden=true; $('panel-lista').hidden=false; $('panel-busqueda').hidden=false;
}
function panelCosto(){
  $('panel-costo').disabled=$('panel-pendiente').checked;
  if($('panel-pendiente').checked)$('panel-costo').value='0';
}
async function panelAbrir(id=null){
  if(!panelPermitido()||PANEL.guardando)return;
  const apertura=++PANEL.apertura;
  panelMensaje('');
  $('panel-error').textContent=''; PANEL.intento=null;
  try{
    const ficha=id?(await panelRPC('panel_productos_listar',{p_maestro_id:Number(id)})).productos?.[0]:null;
    if(apertura!==PANEL.apertura||!panelPermitido())return;
    if(id&&!ficha)throw Error('Este maestro ya no está disponible. Actualiza la búsqueda.');
    PANEL.ficha=ficha;
    $('panel-nombre').value=ficha?.producto||''; $('panel-unidad').value=ficha?.unidad||'';
    $('panel-grupo').innerHTML='<option value="">Elige un grupo existente</option>'+[...new Set([...PANEL.grupos,...(ficha?.rubro?[ficha.rubro]:[])])].map(g=>`<option>${esc(g)}</option>`).join('');
    $('panel-grupo').value=ficha?.rubro||''; $('panel-grupo').disabled=!!ficha;
    $('panel-pendiente').checked=ficha?.costo_pendiente??true; $('panel-costo').value=ficha?.costo_compra??0; panelCosto();
    $('panel-ficha-titulo').textContent=ficha?'Editar insumo':'Nuevo insumo';
    $('panel-identidad').textContent=ficha?`Producto maestro #${ficha.id} · Bodega`:'Se creará un único producto maestro en Bodega.';
    const reps=(ficha?.representaciones||[]).filter(r=>r.activo==='SÍ');
    $('panel-representacion-label').hidden=reps.length<2;
    $('panel-representacion').innerHTML='<option value="">Elige la representación enlazada</option>'+reps.map(r=>`<option value="${esc(r.id)}">#${esc(r.id)} · ${esc(r.producto)} · ${esc(r.unidad||'sin unidad')}</option>`).join('');
    if(reps.length===1)$('panel-representacion').value=String(reps[0].id);
    $('panel-lista').hidden=true; $('panel-busqueda').hidden=true; $('panel-ficha').hidden=false;
    await panelAreas(apertura);
    if(apertura===PANEL.apertura){$('panel-nombre').focus();$('panel-ficha').scrollIntoView({block:'start'});}
  }catch(e){panelMensaje(e.message||'No se pudo abrir el insumo.');}
}
async function panelAreas(apertura=PANEL.apertura){
  $('panel-guardar').disabled=true; $('panel-areas').textContent='Cargando áreas y secciones…';
  const rep=$('panel-representacion').value;
  try{
    const secciones=await Promise.all(PANEL.areas.map(a=>panelRPC('area_secciones_listar',{p_area_id:a.id,p_incluir_archivadas:false})));
    if(apertura!==PANEL.apertura||rep!==$('panel-representacion').value)return;
    $('panel-areas').innerHTML=PANEL.areas.map((a,i)=>{
      const c=(PANEL.ficha?.configuraciones||[]).find(c=>String(c.area_id)===String(a.id)&&String(c.producto_id)===rep);
      return `<div class="panel-area" data-area="${esc(a.id)}"><label class="panel-check"><input type="checkbox" class="panel-area-usar"${c?' checked disabled':''}>${esc(a.nombre)}</label><div class="panel-area-config"${c?'':' hidden'}><div class="panel-datos"><label>Sección física<select class="panel-seccion"><option value="">Sin sección</option>${(secciones[i]||[]).filter(s=>s.estado==='activa'||s.id===c?.seccion_id).map(s=>`<option value="${esc(s.id)}"${s.id===c?.seccion_id?' selected':''}>${esc(s.nombre)}</option>`).join('')}</select></label><label>Mínimo<input class="panel-min" type="number" min="0" step="any" value="${c?.stock_min??''}" placeholder="Sin límite"></label><label>Máximo<input class="panel-max" type="number" min="0" step="any" value="${c?.stock_max??''}" placeholder="Sin límite"></label></div><label class="panel-check"><input type="radio" name="panel-principal" value="${esc(a.id)}"${c?.es_principal?' checked':''}>Área principal</label></div></div>`;
    }).join('')+'<label class="panel-check"><input type="radio" name="panel-principal" value=""'+((PANEL.ficha?.configuraciones||[]).some(c=>String(c.producto_id)===rep&&c.es_principal)?'':' checked')+'>Sin área principal</label>';
    $('panel-guardar').disabled=false;
  }catch(e){$('panel-areas').textContent='No se pudieron cargar las secciones. Cierra y vuelve a abrir la ficha.';$('panel-error').textContent=e.message;}
}
function panelDatos(){
  const areas=[...$('panel-areas').querySelectorAll('[data-area]')].filter(el=>el.querySelector('.panel-area-usar').checked).map(el=>{
    const numero=sel=>el.querySelector(sel).value===''?null:Number(el.querySelector(sel).value);
    const min=numero('.panel-min'),max=numero('.panel-max');
    if(min!==null&&max!==null&&min>max)throw Error('El mínimo no puede superar el máximo.');
    return {area_id:el.dataset.area,seccion_id:el.querySelector('.panel-seccion').value||null,stock_min:min,stock_max:max,es_principal:el.querySelector('[type=radio]').checked};
  });
  const rep=$('panel-representacion').value;
  if(areas.length&&!$('panel-representacion-label').hidden&&!rep)throw Error('Elige explícitamente la representación de Local 1.');
  return {nombre:$('panel-nombre').value.trim(),unidad:$('panel-unidad').value.trim(),rubro:$('panel-grupo').value,costo_compra:Number($('panel-costo').value),costo_pendiente:$('panel-pendiente').checked,representacion_id:rep?Number(rep):null,areas};
}
async function panelGuardar(event){
  event.preventDefault();
  if(PANEL.guardando||!panelPermitido())return;
  $('panel-error').textContent='';
  try{
    const solicitud={p_maestro_id:PANEL.ficha?.id??null,p_revision:PANEL.ficha?.catalogo_revision??null,p_datos:panelDatos()};
    const firma=JSON.stringify(solicitud);
    if(PANEL.intento?.firma!==firma)PANEL.intento={firma,referencia:crypto.randomUUID()};
    PANEL.guardando=true; $('panel-campos').disabled=true; $('panel-guardar').textContent='Guardando…';
    const resultado=await panelRPC('panel_producto_guardar',{...solicitud,p_referencia:PANEL.intento.referencia});
    PANEL.guardando=false; panelCerrar();
    await panelCargar();
    panelMensaje(`Insumo #${resultado.maestro_id} guardado. ${solicitud.p_maestro_id?'Nombre, unidad y costo sincronizados.':'Nuevas fichas con saldo cero.'} No se movieron existencias.`);
  }catch(e){$('panel-error').textContent=e.message||'No se recibió confirmación. Reintenta sin cambiar la ficha para recuperar el mismo resultado.';}
  finally{PANEL.guardando=false;$('panel-campos').disabled=false;$('panel-guardar').textContent='Guardar insumo';}
}
$('panel-busqueda').addEventListener('submit',e=>{e.preventDefault();panelCargar();});
$('panel-nuevo').addEventListener('click',()=>panelAbrir());
$('panel-cerrar').addEventListener('click',panelCerrar);
$('panel-pendiente').addEventListener('change',panelCosto);
$('panel-representacion').addEventListener('change',()=>{$('panel-error').textContent='';panelAreas();});
$('panel-lista').addEventListener('click',e=>{const b=e.target.closest('[data-panel-id]');if(b)panelAbrir(b.dataset.panelId);});
$('panel-areas').addEventListener('change',e=>{
  if(e.target.matches('.panel-area-usar')){
    const box=e.target.closest('[data-area]'); box.querySelector('.panel-area-config').hidden=!e.target.checked;
    if(!e.target.checked&&box.querySelector('[type=radio]').checked)$('panel-areas').querySelector('[type=radio][value=""]').checked=true;
  }
});
$('panel-ficha').addEventListener('submit',panelGuardar);
