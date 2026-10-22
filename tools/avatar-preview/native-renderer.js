// Bundled into the Flutter asset. No camera, MediaPipe, network, or raw video.
import * as THREE from './vendor/three/build/three.module.js';
import {GLTFLoader} from './vendor/three/examples/jsm/loaders/GLTFLoader.js';
import {PoseRetargeter} from './retarget.js';
import {ScreenRootMotion} from './screen-root-motion.js';
import {ElbowHighlight} from './elbow-highlight.js';
const host=data=>window.AvatarHost?.postMessage(JSON.stringify(data));
try {
  const scene=new THREE.Scene();scene.background=new THREE.Color('#182131');
  const camera=new THREE.PerspectiveCamera(40,1,.01,60);camera.position.set(0,1.15,4.4);camera.lookAt(0,1.15,0);
  const renderer=new THREE.WebGLRenderer({antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));
  renderer.toneMapping=THREE.ACESFilmicToneMapping;document.body.append(renderer.domElement);
  scene.add(new THREE.HemisphereLight(0xe3f2ff,0x535b69,2.5));
  const key=new THREE.DirectionalLight(0xffffff,3);key.position.set(3,5,4);scene.add(key);
  const fill=new THREE.DirectionalLight(0x9dbfff,2);fill.position.set(-3,2,-2);scene.add(fill);
  scene.add(new THREE.GridHelper(6,24,0x52627a,0x29374a));
  const message=document.getElementById('status'),credits=document.getElementById('credits');
  const attribution={astronaut:'Astronaut · MrLentereng / ThunderWare Games · CC0',robot:'Corebreaker Robot · Donitz · CC0',mannequiny:'Mannequiny · GDQuest · CC BY 4.0 · GLB 변환',xcvg:'Humanoid · XCVG · CC0'};
  let chunks=[],id='',generation=0,group,retargeter,rootMotion,elbows,mirror=false,screenAnchor=null,active=true,last=performance.now(),lastSeen=0,pose=null;
  const dispose=object=>object?.traverse(o=>{o.geometry?.dispose();for(const m of o.material?(Array.isArray(o.material)?o.material:[o.material]):[]){for(const value of Object.values(m))if(value?.isTexture)value.dispose();m.dispose();}});
  function resize(){const width=innerWidth,height=innerHeight;renderer.setSize(width,height);camera.aspect=width/height;camera.position.z=Math.max(4.4,2.6/camera.aspect);camera.updateProjectionMatrix();}
  window.addEventListener('resize',resize);resize();
  window.AvatarBridge={
    beginModel(name){generation++;id=name;chunks=[];pose=null;screenAnchor=null;retargeter=null;rootMotion=null;elbows?.clear();elbows=null;message.textContent='아바타를 불러오는 중…';},
    appendModel(chunk){chunks.push(chunk);},
    async finishModel(){
      const ticket=generation,name=id;
      try{
        const binary=atob(chunks.join(''));chunks=[];
        const bytes=Uint8Array.from(binary,c=>c.charCodeAt(0));
        const gltf=await new GLTFLoader().parseAsync(bytes.buffer,'');
        if(ticket!==generation){dispose(gltf.scene);return;}
        if(group){scene.remove(group);dispose(group);}
        group=new THREE.Group();const root=gltf.scene;root.updateMatrixWorld(true);
        const box=new THREE.Box3().setFromObject(root),height=box.getSize(new THREE.Vector3()).y;
        if(!Number.isFinite(height)||height<=0)throw Error('Invalid model bounds');
        root.scale.multiplyScalar(1.8/height);root.updateMatrixWorld(true);box.setFromObject(root);
        const center=box.getCenter(new THREE.Vector3());root.position.sub(new THREE.Vector3(center.x,box.min.y,center.z));
        group.add(root);scene.add(group);group.updateMatrixWorld(true);
        const bones=[];root.traverse(o=>{if(o.isBone)bones.push(o);});
        retargeter=new PoseRetargeter(group,bones);rootMotion=new ScreenRootMotion(group,bones);message.textContent='관절 인식을 기다리는 중…';credits.textContent=attribution[name]??name;
        if(name.startsWith('kenney_'))credits.textContent='Kenney · CC0 · '+name.replace('kenney_','');
        if(name.startsWith('kaykit_'))credits.textContent='Kay Lousberg · CC0 · '+name.replace('kaykit_','');
        elbows=new ElbowHighlight(document.getElementById('elbow-overlay'),bones);
        host({type:'modelReady',id:name,bones:bones.length});
      }catch(error){if(ticket===generation){host({type:'error',message:error.message});message.textContent='아바타 로드 실패';}}
    },
    pose(payload){
      pose=payload.landmarks;mirror=!!payload.mirror;screenAnchor=payload.screenAnchor??null;lastSeen=performance.now();
      renderer.domElement.style.transform=payload.mirror?'scaleX(-1)':'';
    },
    setActive(value){active=value;if(!value){pose=null;screenAnchor=null;retargeter?.reset();rootMotion?.reset();elbows?.clear();}},
    dispose(){active=false;generation++;renderer.setAnimationLoop(null);elbows?.clear();dispose(group);renderer.dispose();window.removeEventListener('resize',resize);}
  };
  renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();host({type:'error',message:'WebGL context lost'});});
  renderer.setAnimationLoop(now=>{
    const dt=(now-last)/1000;last=now;if(!active)return;
    if(retargeter){
      const visible=pose&&now-lastSeen<500?pose:null;
      const solved=retargeter.update(visible,now,dt);
      const moving=rootMotion?.update(visible?screenAnchor:null,camera,{width:innerWidth,height:innerHeight},now,dt);
      elbows?.update(visible,camera,innerWidth,innerHeight,mirror,dt);
      message.textContent=solved?`실시간 관절 연결 · ${solved}개 방향${moving?' · 위치 연동':''}`:'몸 전체가 카메라에 들어오게 해주세요';
    }
    renderer.render(scene,camera);
  });
  host({type:'ready'});
}catch(error){host({type:'error',message:error.message});document.getElementById('status').textContent='3D 렌더러 시작 실패';}
