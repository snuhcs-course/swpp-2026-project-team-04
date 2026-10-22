import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
const items=[
 {id:'astronaut',name:'Astronaut',author:'MrLentereng / ThunderWare Games',license:'CC0',url:'https://mrlentereng.itch.io/rigged-low-poly-astronaut'},
 {id:'robot',name:'Corebreaker Robot',author:'Donitz',license:'CC0',url:'https://donitz.itch.io/corebreaker-robot-model'},
 {id:'mannequiny',name:'GDQuest Mannequiny',author:'GDQuest',license:'CC BY 4.0 (art) / MIT (code)',url:'https://github.com/gdquest-demos/godot-3d-mannequin'},
 {id:'xcvg',name:'XCVG Humanoid',author:'XCVG',license:'CC0',url:'https://opengameart.org/content/rigged-and-animated-humanoid'}
];
const $=id=>document.getElementById(id),scene=new THREE.Scene();scene.background=new THREE.Color('#182131');
const camera=new THREE.PerspectiveCamera(38,1,.01,100);camera.position.set(2.7,1.8,4.2);
const renderer=new THREE.WebGLRenderer({antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;$('viewport').append(renderer.domElement);
const controls=new OrbitControls(camera,renderer.domElement);controls.target.set(0,.9,0);controls.enableDamping=true;
scene.add(new THREE.HemisphereLight(0xe3f2ff,0x535b69,2.5));const light=new THREE.DirectionalLight(0xffffff,3);light.position.set(3,5,4);scene.add(light);const fill=new THREE.DirectionalLight(0x9dbfff,2);fill.position.set(-3,2,-2);scene.add(fill);
scene.add(new THREE.GridHelper(8,32,0x52627a,0x29374a));
const marker=new THREE.Mesh(new THREE.SphereGeometry(.025,16,12),new THREE.MeshBasicMaterial({color:0x76dfb2,depthTest:false}));marker.renderOrder=3;scene.add(marker);
let model,helper,bones=[],bases=new Map(),selected=null,playing=false,token=0,frames=0;
const sliders=[];
for(const axis of ['x','y','z']){const label=document.createElement('label');label.textContent=`${axis.toUpperCase()} rotation`;const out=document.createElement('output');out.textContent='0°';const range=document.createElement('input');range.type='range';range.min=-120;range.max=120;range.value=0;range.step=1;range.setAttribute('aria-label',`${axis.toUpperCase()} rotation`);label.append(out,range);$('sliders').append(label);range.addEventListener('input',()=>{stop();apply();});sliders.push({axis,range,out});}
function stop(){playing=false;$('play').textContent='관절 움직임 시작';}
function apply(){if(!selected)return;const values=sliders.map(s=>{s.out.textContent=`${s.range.value}°`;return THREE.MathUtils.degToRad(+s.range.value);});selected.quaternion.copy(bases.get(selected)).multiply(new THREE.Quaternion().setFromEuler(new THREE.Euler(...values)));}
function selectBone(){selected=bones[+$('bones').value];sliders.forEach(s=>{s.range.value=0;s.out.textContent='0°';});if(selected)selected.quaternion.copy(bases.get(selected));}
$('bones').addEventListener('change',()=>{stop();selectBone();});
$('play').onclick=()=>{playing=!playing;$('play').textContent=playing?'일시 정지':'관절 움직임 시작';};
$('reset').onclick=()=>{stop();bones.forEach(b=>b.quaternion.copy(bases.get(b)));sliders.forEach(s=>s.range.value=0);apply();};
$('skeleton').onchange=()=>{if(helper)helper.visible=$('skeleton').checked;};
$('wireframe').onchange=()=>{model?.traverse(o=>{if(o.isMesh){for(const m of Array.isArray(o.material)?o.material:[o.material])m.wireframe=$('wireframe').checked;}});};
async function load(item){const ticket=++token;stop();$('status').textContent=`${item.name} 불러오는 중…`;document.querySelectorAll('nav button').forEach(b=>b.classList.toggle('active',b.dataset.id===item.id));
 try{const gltf=await new GLTFLoader().loadAsync(`./models/${item.id}.glb`);if(ticket!==token)return;
 if(model){scene.remove(model);model.traverse(o=>{o.geometry?.dispose();if(o.material)for(const m of Array.isArray(o.material)?o.material:[o.material])m.dispose();});}if(helper){scene.remove(helper);helper.dispose();}
 model=new THREE.Group();const root=gltf.scene;root.updateMatrixWorld(true);let box=new THREE.Box3().setFromObject(root);const size=box.getSize(new THREE.Vector3());const factor=1.8/size.y;root.scale.multiplyScalar(factor);root.updateMatrixWorld(true);box=new THREE.Box3().setFromObject(root);const center=box.getCenter(new THREE.Vector3());root.position.sub(new THREE.Vector3(center.x,box.min.y,center.z));model.add(root);scene.add(model);model.updateMatrixWorld(true);
 bones=[];bases=new Map();let meshes=0;root.traverse(o=>{if(o.isBone){bones.push(o);bases.set(o,o.quaternion.clone());}if(o.isSkinnedMesh)meshes++;});
 $('bones').replaceChildren(...bones.map((b,i)=>{const opt=document.createElement('option');opt.value=i;opt.textContent=b.name;return opt;}));let preferred=bones.findIndex(b=>/upperarm[._]?[lr]$/i.test(b.name));$('bones').value=Math.max(0,preferred);selectBone();
 helper=new THREE.SkeletonHelper(root);helper.material.depthTest=false;helper.renderOrder=2;helper.visible=$('skeleton').checked;scene.add(helper);$('wireframe').onchange();
 $('credits').replaceChildren();const link=document.createElement('a');link.href=item.url;link.target='_blank';link.rel='noopener';link.textContent=item.name;$('credits').append(link,document.createElement('br'),`${item.author} · ${item.license}`,document.createElement('br'),'변경: GLB 변환, 테스트용 기본 자세 정리');const license=document.createElement('a');license.href=item.id==='mannequiny'?'https://creativecommons.org/licenses/by/4.0/':'https://creativecommons.org/publicdomain/zero/1.0/';license.textContent='라이선스 보기';license.target='_blank';license.rel='noopener';$('credits').append(document.createElement('br'),license);
 $('status').textContent=`${item.name} · ${bones.length} joints · ${meshes} skinned meshes · local GLB`;
 window.avatarLab={id:item.id,bones,model,renderer,scene,camera,get selected(){return selected;},get frames(){return frames;},setAngle(axis,degrees){const s=sliders.find(s=>s.axis===axis);s.range.value=degrees;apply();}};
 }catch(e){console.error(e);$('status').textContent=`모델 로드 실패: ${e.message}`;}}
for(const item of items){const button=document.createElement('button');button.textContent=item.name;button.dataset.id=item.id;button.onclick=()=>load(item);$('models').append(button);}
new ResizeObserver(()=>{const w=$('viewport').clientWidth,h=$('viewport').clientHeight;renderer.setSize(w,h);camera.aspect=w/h;camera.updateProjectionMatrix();}).observe($('viewport'));
renderer.setAnimationLoop(t=>{frames++;if(playing&&selected){const axis=$('axis').value;sliders.forEach(s=>s.range.value=s.axis===axis?Math.round(Math.sin(t*.002)*55):0);apply();}if(selected){selected.getWorldPosition(marker.position);marker.visible=true;}else marker.visible=false;controls.update();renderer.render(scene,camera);});
load(items[0]);
