// Bundled into the Flutter asset. No camera, MediaPipe, network, or raw video.
import * as THREE from './vendor/three/build/three.module.js';
import {GLTFLoader} from './vendor/three/examples/jsm/loaders/GLTFLoader.js';
import {PoseRetargeter, applyExercisePosePrior} from './retarget.js';
import {ScreenRootMotion} from './screen-root-motion.js';
import {ElbowHighlight} from './elbow-highlight.js';
import {FixedPushUpRig} from './fixed-pushup.js';
const host=data=>window.AvatarHost?.postMessage(JSON.stringify(data));
try {
  const scene=new THREE.Scene();scene.background=new THREE.Color('#dcd8d1');
  const camera=new THREE.PerspectiveCamera(40,1,.01,60);camera.position.set(0,1.15,4.4);camera.lookAt(0,1.15,0);
  const renderer=new THREE.WebGLRenderer({antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));
  renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1;renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;document.body.append(renderer.domElement);
  scene.fog=new THREE.Fog('#dcd8d1',12,30);
  scene.add(new THREE.HemisphereLight(0xfbfaf7,0x8a919b,1.7));
  const key=new THREE.DirectionalLight(0xfff5e8,2.4);key.position.set(3,5,4);key.castShadow=true;key.shadow.mapSize.set(1024,1024);key.shadow.bias=-.0005;key.shadow.normalBias=.02;
  Object.assign(key.shadow.camera,{left:-2.5,right:2.5,top:2.5,bottom:-2.5,near:.5,far:20});key.shadow.camera.updateProjectionMatrix();scene.add(key);
  const fill=new THREE.DirectionalLight(0xe4ecf6,1.1);fill.position.set(-3,2,-2);scene.add(fill);
  const rim=new THREE.DirectionalLight(0xfffaf2,1.2);rim.position.set(0,3,-4.4);scene.add(rim);
  const grid=new THREE.GridHelper(6,24,0x8496ad,0x6f8299);grid.material.transparent=true;grid.material.opacity=.35;grid.position.y=.002;scene.add(grid);
  const floor=new THREE.Mesh(new THREE.CircleGeometry(2.4,64),new THREE.MeshStandardMaterial({color:0x5c718b,roughness:.9,metalness:0}));floor.rotation.x=-Math.PI/2;floor.position.y=-.002;floor.receiveShadow=true;scene.add(floor);
  // Arena shell: enclosed room so every camera angle (front or 45° opponent view) sees a wall behind the avatar. Emissive-only accents, no extra lights.
  const env=new THREE.Group();scene.add(env);
  const roomHalf=8,roomHeight=6;
  const wallMat=new THREE.MeshStandardMaterial({color:0xd6d1c9,roughness:.95,metalness:0});
  const panelMat=new THREE.MeshStandardMaterial({color:0xa49e95,roughness:.9,metalness:0});
  const cyan=new THREE.MeshBasicMaterial({color:0x2f8796,transparent:true,opacity:.6});
  const cyanSoft=new THREE.MeshBasicMaterial({color:0x2f8796,transparent:true,opacity:.3});
  const violet=new THREE.MeshBasicMaterial({color:0xd9843f,transparent:true,opacity:.55});
  const ground=new THREE.Mesh(new THREE.PlaneGeometry(roomHalf*2,roomHalf*2),new THREE.MeshStandardMaterial({color:0x6a7c93,roughness:.9,metalness:0}));ground.rotation.x=-Math.PI/2;ground.position.y=-.09;ground.receiveShadow=true;env.add(ground);
  const ceiling=new THREE.Mesh(new THREE.PlaneGeometry(roomHalf*2,roomHalf*2),wallMat);ceiling.rotation.x=Math.PI/2;ceiling.position.y=roomHeight;env.add(ceiling);
  const wallGeo=new THREE.PlaneGeometry(roomHalf*2,roomHeight),panelGeo=new THREE.BoxGeometry(1.7,3.2,.06),seamGeo=new THREE.BoxGeometry(.03,3.2,.02),stripGeo=new THREE.BoxGeometry(roomHalf*2,.04,.02);
  for(let i=0;i<4;i++){
    const side=new THREE.Group();side.rotation.y=i*Math.PI/2;env.add(side);
    const wall=new THREE.Mesh(wallGeo,wallMat);wall.position.set(0,roomHeight/2,-roomHalf);side.add(wall);
    for(let x=-6;x<=6;x+=2){const panel=new THREE.Mesh(panelGeo,panelMat);panel.position.set(x,2.1,-roomHalf+.03);side.add(panel);}
    for(const x of [-5,-1,1,5]){const seam=new THREE.Mesh(seamGeo,cyanSoft);seam.position.set(x,2.1,-roomHalf+.07);side.add(seam);}
    const base=new THREE.Mesh(stripGeo,cyan);base.position.set(0,.3,-roomHalf+.02);side.add(base);
    const crown=new THREE.Mesh(stripGeo,violet);crown.position.set(0,3.95,-roomHalf+.02);side.add(crown);
  }
  const platform=new THREE.Mesh(new THREE.CylinderGeometry(2.75,2.85,.08,64),new THREE.MeshStandardMaterial({color:0x4f6580,roughness:.85,metalness:0}));platform.position.y=-.05;platform.receiveShadow=true;env.add(platform);
  const platformRing=new THREE.Mesh(new THREE.RingGeometry(2.62,2.68,96),cyan);platformRing.rotation.x=-Math.PI/2;platformRing.position.y=-.006;env.add(platformRing);
  const message=document.getElementById('status'),credits=document.getElementById('credits');
  const elbowNote=document.getElementById('elbow-note'),elbowNoteText=elbowNote?.textContent??'',shoulderNote='고정 푸쉬업은 어깨 하강으로 동작이 연동됩니다';
  const attribution={soma:'SOMA · NVIDIA · CC BY 4.0',soma_training:'SOMA · NVIDIA · CC BY 4.0',soma_active:'SOMA · NVIDIA · CC BY 4.0',soma_studio:'SOMA · NVIDIA · CC BY 4.0',astronaut:'Astronaut · MrLentereng / ThunderWare Games · CC0',robot:'Corebreaker Robot · Donitz · CC0',mannequiny:'Mannequiny · GDQuest · CC BY 4.0 · GLB 변환',xcvg:'Humanoid · XCVG · CC0'};
  let chunks=[],id='',generation=0,group,retargeter,rootMotion,elbows,pushUpRig,mirror=false,screenAnchor=null,active=true,last=performance.now(),lastSeen=0,pose=null,exercise='push_up',opponentView=false,pushUpDepth=0,pushUpKneeLeft=0,pushUpKneeRight=0,pushUpFault=null,lastDepthAt=-Infinity;
  const dispose=object=>object?.traverse(o=>{o.geometry?.dispose();for(const m of o.material?(Array.isArray(o.material)?o.material:[o.material]):[]){for(const value of Object.values(m))if(value?.isTexture)value.dispose();m.dispose();}});
  function resize(){const width=innerWidth,height=innerHeight;renderer.setSize(width,height);camera.aspect=width/height;const front=opponentView&&exercise==='push_up';const radius=front?Math.max(3.3,2.15/camera.aspect):Math.max(4.4,2.6/camera.aspect);const angle=opponentView?Math.PI/4:0;const target=front?.42:1.15;camera.position.set(radius*Math.sin(angle),target+(front?.42:.15),radius*Math.cos(angle)*(front?-1:1));camera.lookAt(0,target,0);rim.position.set(-camera.position.x,3,-camera.position.z);camera.updateProjectionMatrix();}
  window.addEventListener('resize',resize);resize();
  window.AvatarBridge={
    beginModel(name){generation++;id=name;chunks=[];pose=null;screenAnchor=null;retargeter=null;rootMotion=null;pushUpRig=null;elbows?.clear();elbows=null;message.textContent='아바타를 불러오는 중…';},
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
        root.traverse(o=>{if(o.isMesh){o.castShadow=true;o.frustumCulled=false;}});
        if(name==='soma'){
          // SOMA only: light athletic matte finish. Swapping the material keeps SkinnedMesh skeleton/bind matrices.
          const swapped=new Map(),swap=m=>{if(swapped.has(m))return swapped.get(m);const next=new THREE.MeshStandardMaterial({color:0xdfe5ec,roughness:.58,metalness:.02,normalMap:m?.normalMap??null,side:m?.side??THREE.FrontSide});swapped.set(m,next);for(const value of Object.values(m??{}))if(value?.isTexture&&value!==next.normalMap)value.dispose();m?.dispose();return next;};
          root.traverse(o=>{if(o.isMesh)o.material=Array.isArray(o.material)?o.material.map(swap):swap(o.material);});
        }
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
      const nextExercise=payload.exercise==='squat'?'squat':'push_up';
      if(exercise!==nextExercise){pushUpRig?.reset();pushUpRig=null;rootMotion?.reset();exercise=nextExercise;pushUpDepth=0;pushUpKneeLeft=0;pushUpKneeRight=0;pushUpFault=null;lastDepthAt=-Infinity;resize();}
      if(Number.isFinite(payload.pushUpDepth)){pushUpDepth=payload.pushUpDepth;lastDepthAt=performance.now();}pushUpKneeLeft=Number.isFinite(payload.pushUpKneeLeft)?payload.pushUpKneeLeft:0;pushUpKneeRight=Number.isFinite(payload.pushUpKneeRight)?payload.pushUpKneeRight:0;pushUpFault=payload.pushUpFault??null;
      if(opponentView!==!!payload.opponentView){opponentView=!!payload.opponentView;resize();}
      renderer.domElement.style.transform=payload.mirror?'scaleX(-1)':'';
    },
    setActive(value){active=value;if(!value){pose=null;screenAnchor=null;pushUpFault=null;lastDepthAt=-Infinity;retargeter?.reset();rootMotion?.reset();elbows?.clear();}},
    dispose(){active=false;generation++;renderer.setAnimationLoop(null);elbows?.clear();dispose(group);dispose(floor);dispose(grid);dispose(env);renderer.dispose();window.removeEventListener('resize',resize);}
  };
  renderer.domElement.addEventListener('webglcontextlost',e=>{e.preventDefault();host({type:'error',message:'WebGL context lost'});});
  renderer.setAnimationLoop(now=>{
    const dt=(now-last)/1000;last=now;if(!active)return;
    if(retargeter){
      const visible=pose&&now-lastSeen<500?pose:null;
      const fixed=opponentView&&exercise==='push_up';
      if(fixed&&!pushUpRig)pushUpRig=new FixedPushUpRig(group,retargeter);
      const depthStale=now-lastDepthAt>=1000;
      const solved=fixed?pushUpRig.update(depthStale?0:pushUpDepth,visible&&!depthStale?pushUpFault:null,now,dt,visible&&!depthStale?pushUpKneeLeft:0,visible&&!depthStale?pushUpKneeRight:0):retargeter.update(opponentView?applyExercisePosePrior(visible,exercise):visible,now,dt);
      const moving=fixed?false:rootMotion?.update(visible?screenAnchor:null,camera,{width:innerWidth,height:innerHeight},now,dt);
      if(fixed){elbows?.clear();if(elbowNote&&elbowNote.textContent!==shoulderNote)elbowNote.textContent=shoulderNote;}
      else{if(elbowNote&&elbowNote.textContent!==elbowNoteText)elbowNote.textContent=elbowNoteText;elbows?.update(visible,camera,innerWidth,innerHeight,mirror,dt);}
      message.textContent=fixed?(depthStale?'자세 인식을 기다리는 중':(visible?'고정 푸쉬업 자세 · 깊이 연동':'몸 전체가 카메라에 들어오게 해주세요')):(solved?`실시간 관절 연결 · ${solved}개 방향${moving?' · 위치 연동':''}`:'몸 전체가 카메라에 들어오게 해주세요');
    }
    renderer.render(scene,camera);
  });
  host({type:'ready'});
}catch(error){host({type:'error',message:error.message});document.getElementById('status').textContent='3D 렌더러 시작 실패';}
