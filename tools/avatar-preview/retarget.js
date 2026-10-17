import * as THREE from './vendor/three/build/three.module.js';
const clean=name=>name.toLowerCase().replace(/[^a-z0-9]/g,'');
const v=(p)=>new THREE.Vector3(p.x,-p.y,-p.z);
const midpoint=(a,b)=>a.clone().add(b).multiplyScalar(.5);
const valid=p=>p&&Number.isFinite(p.x)&&Number.isFinite(p.y)&&Number.isFinite(p.z)&&(p.visibility??1)>=.55&&(p.presence??1)>=.5;
function frame(side,up){
  if(side.lengthSq()<1e-6||up.lengthSq()<1e-6)return null;
  up.normalize();side.addScaledVector(up,-side.dot(up)).normalize();
  if(side.lengthSq()<.5)return null;
  const z=side.clone().cross(up).normalize();
  return new THREE.Quaternion().setFromRotationMatrix(new THREE.Matrix4().makeBasis(side,up,z));
}

/** Direction-based retargeting. Keeps bone lengths and model bind axes intact. */
export class PoseRetargeter {
  constructor(model,bones){
    this.model=model;this.bones=bones;this.entries=[];this.lastSeen=0;this.hipsLast=0;this.count=0;
    this.rest=new Map(bones.map(b=>[b,b.quaternion.clone()]));
    const byName=new Map(bones.map(b=>[clean(b.name),b]));
    const find=(...names)=>names.map(n=>byName.get(clean(n))).find(Boolean);
    const point=b=>b?.getWorldPosition(new THREE.Vector3());
    model.updateMatrixWorld(true);
    const leftArm=find('upperarm_l','UpperArm.L'),rightArm=find('upperarm_r','UpperArm.R');
    const leftLeg=find('thigh_l','UpperLeg.L','Thigh.L'),rightLeg=find('thigh_r','UpperLeg.R','Thigh.R');
    this.hips=find('Hips','pelvis');
    // Robot's torso and pelvis are siblings under Root, so rotate their common parent.
    if(byName.has('torso'))this.hips=find('Root');
    if(this.hips&&leftArm&&rightArm&&leftLeg&&rightLeg){
      this.restFrame=frame(point(leftArm).sub(point(rightArm)),midpoint(point(leftArm),point(rightArm)).sub(midpoint(point(leftLeg),point(rightLeg))));
      this.hipsWorld=this.hips.getWorldQuaternion(new THREE.Quaternion());
    }
    const add=(bone,child,start,end)=>{
      if(!bone||!child)return;
      const q=bone.getWorldQuaternion(new THREE.Quaternion());
      const local=point(child).sub(point(bone)).normalize().applyQuaternion(q.clone().invert());
      this.entries.push({bone,local,start,end,last:0});
    };
    for(const [side,shoulder,elbow,wrist,hip,knee,ankle,toe] of [['l',11,13,15,23,25,27,31],['r',12,14,16,24,26,28,32]]){
      const upper=find(`upperarm_${side}`,`UpperArm.${side}`),lower=find(`lowerarm_${side}`,`LowerArm.${side}`),hand=find(`hand_${side}`,`Hand.${side}`);
      const thigh=find(`thigh_${side}`,`UpperLeg.${side}`,`Thigh.${side}`),calf=find(`calf_${side}`,`LowerLeg.${side}`,`Leg.${side}`),foot=find(`foot_${side}`,`Foot.${side}`),ball=find(`ball_${side}`,`Toes.${side}`);
      add(upper,lower,[shoulder],[elbow]);add(lower,hand,[elbow],[wrist]);
      add(thigh,calf,[hip],[knee]);add(calf,foot,[knee],[ankle]);add(foot,ball,[ankle],[toe]);
    }
    add(find('neck_01','Neck'),find('head','Head'),[11,12],[7,8]);
    // Parents must be solved before children, independently of exported bone order.
    const depth=b=>{let n=0;while(b.parent){b=b.parent;n++;}return n;};
    this.entries.sort((a,b)=>depth(a.bone)-depth(b.bone));
  }
  reset(){for(const [bone,q] of this.rest)bone.quaternion.copy(q);this.model.updateMatrixWorld(true);this.lastSeen=0;}
  update(world,now,dt=.05){
    const alpha=1-Math.exp(-Math.min(Math.max(dt,.001),.15)/.085);
    const sample=ids=>ids.every(i=>valid(world?.[i]))?ids.map(i=>v(world[i])).reduce((a,b)=>a.add(b),new THREE.Vector3()).multiplyScalar(1/ids.length):null;
    let solved=0;
    const ls=sample([11]),rs=sample([12]),lh=sample([23]),rh=sample([24]);
    if(this.restFrame&&ls&&rs&&lh&&rh){
      const targetFrame=frame(ls.clone().sub(rs),midpoint(ls,rs).sub(midpoint(lh,rh)));
      if(targetFrame){
        const target=targetFrame.multiply(this.restFrame.clone().invert()).multiply(this.hipsWorld);
        const parent=this.hips.parent.getWorldQuaternion(new THREE.Quaternion()).invert();
        this.hips.quaternion.slerp(parent.multiply(target),alpha);this.model.updateMatrixWorld(true);this.hipsLast=now;solved++;
      }
    }
    if(this.hips&&now-this.hipsLast>500&&!(ls&&rs&&lh&&rh)){
      this.hips.quaternion.slerp(this.rest.get(this.hips),alpha*.4);this.model.updateMatrixWorld(true);
    }
    for(const entry of this.entries){
      const a=sample(entry.start),b=sample(entry.end);
      if(!a||!b||a.distanceToSquared(b)<1e-6){
        if(now-entry.last>500)entry.bone.quaternion.slerp(this.rest.get(entry.bone),alpha*.4);
        entry.bone.updateWorldMatrix(false,true);continue;
      }
      const desired=b.sub(a).normalize();
      const currentWorld=entry.bone.getWorldQuaternion(new THREE.Quaternion());
      const currentDirection=entry.local.clone().applyQuaternion(currentWorld).normalize();
      const rotation=new THREE.Quaternion().setFromUnitVectors(currentDirection,desired);
      const targetWorld=rotation.multiply(currentWorld);
      const parent=entry.bone.parent.getWorldQuaternion(new THREE.Quaternion()).invert();
      entry.bone.quaternion.slerp(parent.multiply(targetWorld),alpha);
      entry.bone.updateWorldMatrix(false,true);entry.last=now;solved++;
    }
    if(solved){this.lastSeen=now;this.count++;}
    return solved;
  }
}
