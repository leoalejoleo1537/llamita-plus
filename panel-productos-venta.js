/* P3: catálogo comercial neutral y recetas manuales. Solo consume RPC protegidas. */
let PANEL_TAB_ACTIVO='insumos';
let PANEL_VENTA={filas:[],ingredientes:[],ficha:null,componentes:[],carga:0,guardando:false,intento:null,retornoKey:null};

function panelTabCambiar(tab){
  PANEL_TAB_ACTIVO=tab==='ventas'?'ventas':'insumos';
  const ventas=PANEL_TAB_ACTIVO==='ventas';
  $('panel-insumos').hidden=ventas;$('panel-ventas').hidden=!ventas;
  $('panel-tab-insumos').setAttribute('aria-selected',String(!ventas));
  $('panel-tab-ventas').setAttribute('aria-selected',String(ventas));
  $('panel-tab-insumos').tabIndex=ventas?-1:0;$('panel-tab-ventas').tabIndex=ventas?0:-1;
  if($('view-productos').style.display!=='none')panelVistaCargar();
}
function panelVistaCargar(){
  if(PANEL_TAB_ACTIVO==='ventas')panelVentasCargar();else panelCargar();
}
function panelVentaMensaje(texto){$('panel-venta-mensaje').textContent=texto;}
async function panelVentasCargar(){
  if(!panelPermitido())return;
  const carga=++PANEL_VENTA.carga;
  panelVentaMensaje('Cargando productos de venta…');
  try{
    const datos=await panelRPC('panel_ventas_listar',{p_consulta:$('panel-venta-q').value.trim()});
    if(carga!==PANEL_VENTA.carga||PANEL_TAB_ACTIVO!=='ventas')return;
    PANEL_VENTA.filas=datos.productos||[];
    $('panel-venta-lista').innerHTML=PANEL_VENTA.filas.map(p=>`<button type="button" class="panel-fila" data-panel-venta-id="${esc(p.id)}"><span><strong>${esc(p.nombre)}</strong><small>${p.ingredientes} ingrediente${p.ingredientes===1?'':'s'} · ${Number(p.precio_venta).toLocaleString('es-CL',{maximumFractionDigits:6})}</small></span><span class="panel-estado ${p.estado==='listo'?'listo':''}">${p.estado==='listo'?'Lista':'Borrador'}</span></button>`).join('');
    panelVentaMensaje(PANEL_VENTA.filas.length===100?'Mostrando los primeros 100. Busca por nombre para acotar.':PANEL_VENTA.filas.length?`${PANEL_VENTA.filas.length} productos de venta`:'No hay coincidencias. Puedes crear uno manualmente.');
  }catch(e){if(carga===PANEL_VENTA.carga)panelVentaMensaje(e.message||'No se pudo cargar el catálogo comercial.');}
}
async function panelVentaIngredientesCargar(){
  const datos=await panelRPC('panel_ingredientes_listar',{p_consulta:''});
  PANEL_VENTA.ingredientes=datos.ingredientes||[];
}
function panelVentaCerrar(){
  if(PANEL_VENTA.guardando)return;
  PANEL_VENTA.ficha=null;PANEL_VENTA.componentes=[];PANEL_VENTA.intento=null;PANEL_VENTA.retornoKey=null;
  $('panel-venta-ficha').hidden=true;$('panel-venta-lista').hidden=false;$('panel-venta-busqueda').hidden=false;
  $('panel-venta-error').textContent='';
}
function panelVentaMaestros(){
  const mapa=new Map();
  for(const i of PANEL_VENTA.ingredientes)if(!mapa.has(String(i.maestro_id)))mapa.set(String(i.maestro_id),i);
  return [...mapa.values()].sort((a,b)=>a.producto.localeCompare(b.producto,'es'));
}
function panelVentaComponenteNuevo(){
  return {key:crypto.randomUUID(),maestro_id:'',asignacion_id:'',cantidad:1};
}
function panelVentaPintarComponentes(){
  const maestros=panelVentaMaestros();
  $('panel-venta-componentes').innerHTML=PANEL_VENTA.componentes.map((c,indice)=>{
    const fuentes=PANEL_VENTA.ingredientes.filter(i=>String(i.maestro_id)===String(c.maestro_id));
    return `<div class="panel-componente" data-pv-key="${esc(c.key)}">
      <span class="panel-orden" aria-hidden="true">${indice+1}</span>
      <label>Insumo<select class="pv-insumo"><option value="">Selecciona un insumo</option>${maestros.map(m=>`<option value="${esc(m.maestro_id)}"${String(m.maestro_id)===String(c.maestro_id)?' selected':''}>${esc(m.producto)} · ${esc(m.unidad||'sin unidad')}</option>`).join('')}</select></label>
      <label>Área de origen<select class="pv-origen"${c.maestro_id?'':' disabled'}><option value="">Selecciona un área</option>${fuentes.map(f=>`<option value="${esc(f.asignacion_id)}"${String(f.asignacion_id)===String(c.asignacion_id)?' selected':''}>${esc(f.area)}${f.seccion?' · '+esc(f.seccion):''}</option>`).join('')}</select></label>
      <label>Cantidad<input class="pv-cantidad" type="number" min="0.000001" max="999999999999" step="any" value="${esc(c.cantidad)}" required></label>
      <div class="panel-componente-acciones"><button type="button" data-pv-mover="arriba" aria-label="Subir ingrediente"${indice===0?' disabled':''}>↑</button><button type="button" data-pv-mover="abajo" aria-label="Bajar ingrediente"${indice===PANEL_VENTA.componentes.length-1?' disabled':''}>↓</button><button type="button" data-pv-quitar aria-label="Quitar ingrediente">Quitar</button></div>
    </div>`;
  }).join('');
  $('panel-venta-sin-componentes').hidden=PANEL_VENTA.componentes.length>0;
}
async function panelVentaAbrir(id=null){
  if(!panelPermitido()||PANEL_VENTA.guardando)return;
  $('panel-venta-error').textContent='';PANEL_VENTA.intento=null;
  try{
    const [detalle]=await Promise.all([
      id?panelRPC('panel_ventas_listar',{p_producto_venta_id:id}):Promise.resolve({productos:[]}),
      panelVentaIngredientesCargar()
    ]);
    const ficha=id?(detalle.productos||[])[0]:null;
    if(id&&!ficha)throw Error('Este producto de venta ya no está disponible.');
    PANEL_VENTA.ficha=ficha;
    PANEL_VENTA.componentes=(ficha?.componentes||[]).map(c=>({
      key:crypto.randomUUID(),maestro_id:String(c.maestro_id),asignacion_id:String(c.asignacion_id),cantidad:Number(c.cantidad)
    }));
    $('panel-venta-nombre').value=ficha?.nombre||'';$('panel-venta-precio').value=ficha?.precio_venta??0;
    $('panel-venta-titulo').textContent=ficha?'Editar producto de venta':'Nuevo producto de venta';
    $('panel-venta-identidad').textContent=ficha?`Identidad comercial neutral · revisión ${ficha.revision}`:'Se creará en borrador y no se publicará en ningún POS.';
    $('panel-venta-lista').hidden=true;$('panel-venta-busqueda').hidden=true;$('panel-venta-ficha').hidden=false;
    panelVentaPintarComponentes();$('panel-venta-nombre').focus();
  }catch(e){panelVentaMensaje(e.message||'No se pudo abrir el producto de venta.');}
}
function panelVentaDatos(estado){
  const componentes=PANEL_VENTA.componentes.map((c,i)=>{
    const cantidad=Number(c.cantidad);
    if(!c.maestro_id)throw Error(`Elige el insumo de la línea ${i+1}.`);
    if(!c.asignacion_id)throw Error(`Elige el área de origen de la línea ${i+1}.`);
    if(!Number.isFinite(cantidad)||cantidad<=0)throw Error(`La cantidad de la línea ${i+1} debe ser positiva.`);
    return {asignacion_id:c.asignacion_id,cantidad};
  });
  if(estado==='listo'&&!componentes.length)throw Error('Añade al menos un ingrediente antes de marcar la receta lista.');
  return {nombre:$('panel-venta-nombre').value.trim(),precio_venta:Number($('panel-venta-precio').value),estado,componentes};
}
async function panelVentaGuardar(event){
  event.preventDefault();
  if(PANEL_VENTA.guardando||!panelPermitido())return;
  $('panel-venta-error').textContent='';
  try{
    const estado=event.submitter?.value==='listo'?'listo':'borrador';
    const solicitud={p_producto_venta_id:PANEL_VENTA.ficha?.id||null,p_revision:PANEL_VENTA.ficha?.revision??null,p_datos:panelVentaDatos(estado)};
    const firma=JSON.stringify(solicitud);
    if(PANEL_VENTA.intento?.firma!==firma)PANEL_VENTA.intento={firma,referencia:crypto.randomUUID()};
    PANEL_VENTA.guardando=true;$('panel-venta-campos').disabled=true;
    const resultado=await panelRPC('panel_venta_guardar',{...solicitud,p_referencia:PANEL_VENTA.intento.referencia});
    PANEL_VENTA.guardando=false;panelVentaCerrar();await panelVentasCargar();
    panelVentaMensaje(`${estado==='listo'?'Receta lista':'Borrador guardado'} · ${resultado.ingredientes} ingrediente${resultado.ingredientes===1?'':'s'}. No se movió stock ni se creó una reserva.`);
  }catch(e){$('panel-venta-error').textContent=e.message||'No se pudo guardar. Reintenta sin cambiar la ficha para recuperar el mismo resultado.';}
  finally{PANEL_VENTA.guardando=false;$('panel-venta-campos').disabled=false;}
}
function panelVentaCrearInsumo(){
  if(!PANEL_VENTA.componentes.length)PANEL_VENTA.componentes.push(panelVentaComponenteNuevo());
  const pendiente=PANEL_VENTA.componentes.find(c=>!c.maestro_id)||PANEL_VENTA.componentes.at(-1);
  PANEL_VENTA.retornoKey=pendiente.key;
  abrirPanelProductos({origen:'producto-venta',requiereRepresentacion:true,requiereArea:true});
}
async function panelVentaRetornarInsumo(resultado){
  panelTabCambiar('ventas');pickTab('productos');
  await panelVentaIngredientesCargar();
  const opciones=PANEL_VENTA.ingredientes.filter(i=>Number(i.maestro_id)===Number(resultado.maestro_id)||Number(i.producto_id)===Number(resultado.representacion_id));
  const fila=PANEL_VENTA.componentes.find(c=>c.key===PANEL_VENTA.retornoKey)||PANEL_VENTA.componentes.find(c=>!c.maestro_id);
  if(fila&&opciones.length){fila.maestro_id=String(opciones[0].maestro_id);fila.asignacion_id=String(opciones[0].asignacion_id);}
  PANEL_VENTA.retornoKey=null;$('panel-venta-ficha').hidden=false;$('panel-venta-lista').hidden=true;$('panel-venta-busqueda').hidden=true;
  panelVentaPintarComponentes();panelVentaMensaje('Insumo creado y seleccionado. Confirma su cantidad y área de origen antes de guardar la receta.');
}

$('view-productos').querySelector('.panel-tabs').addEventListener('click',e=>{const b=e.target.closest('[data-panel-tab]');if(b)panelTabCambiar(b.dataset.panelTab);});
$('view-productos').querySelector('.panel-tabs').addEventListener('keydown',e=>{if(!['ArrowLeft','ArrowRight'].includes(e.key))return;e.preventDefault();const tab=PANEL_TAB_ACTIVO==='insumos'?'ventas':'insumos';panelTabCambiar(tab);$(`panel-tab-${tab}`).focus();});
$('panel-venta-busqueda').addEventListener('submit',e=>{e.preventDefault();panelVentasCargar();});
$('panel-venta-nuevo').addEventListener('click',()=>panelVentaAbrir());
$('panel-venta-cerrar').addEventListener('click',panelVentaCerrar);
$('panel-venta-lista').addEventListener('click',e=>{const b=e.target.closest('[data-panel-venta-id]');if(b)panelVentaAbrir(b.dataset.panelVentaId);});
$('panel-venta-agregar').addEventListener('click',()=>{PANEL_VENTA.componentes.push(panelVentaComponenteNuevo());panelVentaPintarComponentes();});
$('panel-venta-crear-insumo').addEventListener('click',panelVentaCrearInsumo);
$('panel-venta-componentes').addEventListener('change',e=>{
  const fila=e.target.closest('[data-pv-key]'),c=PANEL_VENTA.componentes.find(x=>x.key===fila?.dataset.pvKey);if(!c)return;
  if(e.target.matches('.pv-insumo')){c.maestro_id=e.target.value;c.asignacion_id='';panelVentaPintarComponentes();}
  if(e.target.matches('.pv-origen'))c.asignacion_id=e.target.value;
});
$('panel-venta-componentes').addEventListener('input',e=>{if(!e.target.matches('.pv-cantidad'))return;const c=PANEL_VENTA.componentes.find(x=>x.key===e.target.closest('[data-pv-key]').dataset.pvKey);if(c)c.cantidad=e.target.value;});
$('panel-venta-componentes').addEventListener('click',e=>{
  const fila=e.target.closest('[data-pv-key]');if(!fila)return;const i=PANEL_VENTA.componentes.findIndex(x=>x.key===fila.dataset.pvKey);if(i<0)return;
  if(e.target.closest('[data-pv-quitar]'))PANEL_VENTA.componentes.splice(i,1);
  else if(e.target.closest('[data-pv-mover="arriba"]')&&i>0)[PANEL_VENTA.componentes[i-1],PANEL_VENTA.componentes[i]]=[PANEL_VENTA.componentes[i],PANEL_VENTA.componentes[i-1]];
  else if(e.target.closest('[data-pv-mover="abajo"]')&&i<PANEL_VENTA.componentes.length-1)[PANEL_VENTA.componentes[i+1],PANEL_VENTA.componentes[i]]=[PANEL_VENTA.componentes[i],PANEL_VENTA.componentes[i+1]];
  else return;
  panelVentaPintarComponentes();
});
$('panel-venta-ficha').addEventListener('submit',panelVentaGuardar);
