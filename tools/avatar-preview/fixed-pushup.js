import * as THREE from './vendor/three/build/three.module.js';

const clamp=(v,low,high)=>Math.max(low,Math.min(high,v));
const point=(x,y,z)=>({x,y:-y,z:-z,visibility:1,presence:1});
// Joint centers sit above the mesh contact: palm/finger skin below the wrist, sole/heel below the ankle.
const WRIST_LIFT=.05,ANKLE_LIFT=.06,PALM_DROP=.045,SOLE_DROP=.06;
// Hands lie flat on the floor with fingers pointing toward the head.
const FINGER_DIR=new THREE.Vector3(0,0,-1);
// Toe joint center sits above the floor by this fraction of the rig's ankle-to-toe length,
// and the foot rises from the planted ball at FOOT_PITCH so the heel stays clearly raised.
const TOE_LIFT=.15,FOOT_PITCH=55*Math.PI/180;
// Kneeling: the knee joint center sits above the kneecap contact by this fraction of the
// rig's shin length; shins trail back along the floor rising at SHIN_PITCH so the feet
// float just clear of it.
const KNEE_LIFT=.1,SHIN_PITCH=8*Math.PI/180;

// World-space exercise template: body extends along Z, hands and feet stay
// at fixed ground coordinates. The sensor contributes depth and fault only.
export function pushUpTemplate(depth=0,fault=null,kneeAmount=fault==='kneesDown'?1:0){
  const d=clamp(Number.isFinite(depth)?depth/1.1:0,0,1);
  const height=.58-.36*d;
  const tilted=fault==='shouldersNotLevel'?.08:0;
  // Kneeling blend 0 (toes) .. 1 (knees) so the trunk and knees lower continuously.
  const k=fault==='kneesDown'?1:clamp(Number.isFinite(kneeAmount)?kneeAmount:0,0,1);
  const base=height;
  // Elbow bend follows shoulder depth only; arm faults do not alter the pose.
  const bend=d;
  // Shoulder-to-ankle line keeps the trunk rigid; the head continues it for a neutral neck.
  const line=z=>base+(ANKLE_LIFT-base)*(z+.48)/1.32;
  // Kneeling keeps the trunk rigid on the shoulder-to-knee line instead.
  const kneelHips=base+(.025-base)*(.07+.48)/(.48+.48);
  const hips=fault==='bellyDown'?.13:line(.07)+(kneelHips-line(.07))*k;
  const world=Array(33).fill(null);
  world[0]=point(0,line(-.78)+.03,-.78);
  for(const [s,sh,el,wr,hip,knee,ankle,toe,ear] of [[-1,11,13,15,23,25,27,31,7],[1,12,14,16,24,26,28,32,8]]){
    const sy=base+s*tilted;
    world[sh]=point(s*.24,sy,-.48);
    world[wr]=point(s*.30,WRIST_LIFT,-.48);
    // At the top the elbow sits on the shoulder-wrist midline with a .01 rearward
    // offset (~176 degrees), so the plank reads straight-armed yet keeps a natural
    // bend direction; descent moves it outward and back toward the feet.
    world[el]=point(s*(.27+.19*bend),(sy+WRIST_LIFT)/2+.045*bend,-.47+.21*bend);
    world[hip]=point(s*.17,hips,.07);
    world[knee]=point(s*.17,(1-k)*(hips+(ANKLE_LIFT-hips)*(.41/.77))+k*.025,.48);
    world[ankle]=point(s*.17,ANKLE_LIFT,.84);
    world[toe]=point(s*.17,.02,.96);
    world[ear]=point(s*.09,line(-.65)+.04+s*tilted,-.65);
  }
  return world;
}

// Numerical two-joint IK. Targets are captured from the model in its initial
// straight-arm top pose, so they are reachable at depth 0 without re-bending;
// retargeting stays within each model's original bone lengths.
export class FixedPushUpRig {
  constructor(group,retargeter){
    this.group=group;this.retargeter=retargeter;this.origin=group.position.clone();
    const by=(a,b)=>retargeter.entries.find(e=>e.start.length===1&&e.end.length===1&&e.start[0]===a&&e.end[0]===b);
    // Named descendant of a hand/foot bone; absent on rigs without finger or toe bones.
    const find=(root,re)=>{
      let found=null;
      root?.traverse?.(o=>{if(!found&&o!==root&&re.test(o.name||''))found=o;});
      return found;
    };
    this.chains=[[11,13,15,PALM_DROP],[12,14,16,PALM_DROP],[23,25,27,SOLE_DROP],[24,26,28,SOLE_DROP]].map(([a,b,c,drop])=>{
      const upper=by(a,b),lower=by(b,c);
      if(!upper||!lower)return null;
      const end=lower.child,hand=drop===PALM_DROP;
      return {upper:upper.bone,lower:lower.bone,end,
        finger:hand?find(end,/HandMiddle1$/):null,
        index:hand?find(end,/HandIndex1$/):null,
        pinky:hand?find(end,/HandPinky1$/)||find(end,/HandRing1$/):null,
        toe:hand?null:find(end,/ToeBase$/),
        leg:!hand,
        // Leg side from the start landmark: 23=left hip, 24=right hip.
        drop,side:a===23?'left':a===24?'right':null,target:null};
    }).filter(Boolean);
    const pose=pushUpTemplate();
    for(let i=0;i<90;i++)retargeter.update(pose,1000+i*16,.1);
    group.updateMatrixWorld(true);
    const contact=this.chains.map(c=>c.end.getWorldPosition(new THREE.Vector3()).y-c.drop);
    if(contact.length)group.position.y-=Math.min(...contact);
    group.updateMatrixWorld(true);
    this.baseY=group.position.y;
    for(const c of this.chains)c.target=c.end.getWorldPosition(new THREE.Vector3());
    // Plant the toe base at a fixed floor point ahead of the captured ankle and lift the
    // ankle target above it, sized from the rig's own foot length; toeless rigs keep the
    // captured ankle target.
    const floor=this.chains.length?Math.min(...this.chains.map(c=>c.target.y-c.drop)):0;
    // Kneeling data from the captured rig: thigh/shin lengths, floor-level knee height and
    // the horizontal hip-to-ankle heading.
    for(const c of this.chains){
      if(!c.leg)continue;
      const hip=c.upper.getWorldPosition(new THREE.Vector3()),knee=c.lower.getWorldPosition(new THREE.Vector3());
      const heading=c.target.clone().sub(hip).setY(0);
      if(heading.lengthSq()<1e-8){c.leg=false;continue;}
      c.legHeading=heading.normalize();
      c.thigh=hip.distanceTo(knee);
      c.shin=knee.distanceTo(c.target);
      c.kneeY=floor+KNEE_LIFT*c.shin;
    }
    for(const c of this.chains){
      if(!c.toe)continue;
      const len=c.toe.getWorldPosition(new THREE.Vector3()).distanceTo(c.target);
      const heading=c.target.clone().sub(c.upper.getWorldPosition(new THREE.Vector3())).setY(0);
      if(len<1e-4||heading.lengthSq()<1e-8){c.toe=null;continue;}
      heading.normalize();
      c.heading=heading;
      c.toeTarget=c.target.clone().addScaledVector(heading,len*Math.cos(FOOT_PITCH)).setY(floor+TOE_LIFT*len);
      c.target=c.toeTarget.clone().addScaledVector(heading,-len*Math.cos(FOOT_PITCH));
      c.target.y=c.toeTarget.y+len*Math.sin(FOOT_PITCH);
    }
  }
  update(depth,fault,now,dt,kneeLeft=0,kneeRight=0){
    const d=clamp(Number.isFinite(depth)?depth/1.1:0,0,1);
    // Per-leg kneel blend 0 (toes) .. 1 (knees); kneesDown callers get the full kneel on both.
    const amount=v=>fault==='kneesDown'?1:clamp(Number.isFinite(v)?v:0,0,1);
    const kneel={left:amount(kneeLeft),right:amount(kneeRight)};
    // The template trunk uses the average so a single kneeling leg only lowers the hips
    // partway and the arms don't jump; each leg's own blend is applied in the IK below.
    const kneelAvg=(kneel.left+kneel.right)/2;
    const alpha=1-Math.exp(-Math.min(Math.max(dt,.001),.15)/.08);
    this.group.position.y+=(this.baseY-.25*d-this.group.position.y)*alpha;
    this.retargeter.update(pushUpTemplate(depth,fault==='kneesDown'?null:fault,kneelAvg),now,dt);
    this.group.updateMatrixWorld(true);
    const at=o=>o.getWorldPosition(new THREE.Vector3());
    // Iterative IK: each bone in turn swings the end effector toward the target.
    const reach=(bones,end,target)=>{
      for(let i=0;i<10;i++)for(const bone of bones){
        const origin=bone.getWorldPosition(new THREE.Vector3());
        const current=end.getWorldPosition(new THREE.Vector3()).sub(origin);
        const desired=target.clone().sub(origin);
        if(current.lengthSq()<1e-8||desired.lengthSq()<1e-8)continue;
        const turn=new THREE.Quaternion().setFromUnitVectors(current.normalize(),desired.normalize());
        const world=bone.getWorldQuaternion(new THREE.Quaternion());
        const parent=bone.parent.getWorldQuaternion(new THREE.Quaternion()).invert();
        bone.quaternion.slerp(parent.multiply(turn.multiply(world)),.65);
        bone.updateWorldMatrix(false,true);
      }
    };
    // Every limb first solves its captured wrist/ankle target (the normal pose); kneeling
    // legs are blended from that pose below.
    for(const c of this.chains)reach([c.lower,c.upper],c.end,c.target);
    // Rotate only the hand/foot bone about its own origin, after the limb IK has settled, so
    // wrist/ankle anchors and elbows/knees stay put; fingers and toes follow as children.
    const setWorld=(bone,q)=>{
      bone.quaternion.copy(bone.parent.getWorldQuaternion(new THREE.Quaternion()).invert().multiply(q));
      bone.updateWorldMatrix(false,true);
    };
    const aimed=(bone,from,to)=>{
      const world=bone.getWorldQuaternion(new THREE.Quaternion());
      if(from.lengthSq()<1e-8||to.lengthSq()<1e-8)return world;
      return new THREE.Quaternion().setFromUnitVectors(from.normalize(),to.normalize()).multiply(world);
    };
    const align=(bone,from,to)=>setWorld(bone,aimed(bone,from,to));
    for(const c of this.chains){
      if(!c.end?.parent)continue;
      c.end.updateWorldMatrix(true,true);
      const origin=at(c.end);
      if(c.finger){
        align(c.end,at(c.finger).sub(origin),FINGER_DIR.clone());
        // Twist about the finger axis until the knuckle line is level (palm flat); the smaller
        // of the two level solutions keeps the retargeted palm-down side. Skipped when the
        // hand is near edge-on (ambiguous) or side fingers are missing.
        if(c.index&&c.pinky){
          const across=at(c.pinky).sub(at(c.index));across.z=0;
          if(Math.abs(across.x)>.2*across.length())align(c.end,across,new THREE.Vector3(Math.sign(across.x),0,0));
        }
      }else if(c.toeTarget){
        // Aim the foot from the raised ankle at the planted toe base, then dorsiflex the toes
        // about the planted toe base so they lie flat along the floor toward the head (-heading).
        align(c.end,at(c.toe).sub(origin),c.toeTarget.clone().sub(origin));
        const tip=c.toe.children.find(o=>o.isBone)||c.toe.children[0];
        // Retargeted toe rotation, restored as the leg kneels.
        c.toeRest=c.toe.quaternion.clone();
        if(tip)align(c.toe,at(tip).sub(at(c.toe)),c.heading.clone().negate());
      }
    }
    // Kneeling blend from the solved normal pose: the thigh aims at a knee point slid from the
    // normal knee toward the floor-level kneel goal, then shin and foot slerp their world
    // orientations toward the trailing (plantarflexed) kneel pose. Each leg uses its own blend;
    // 0 leaves it untouched.
    for(const c of this.chains){
      if(!c.leg||!c.end?.parent)continue;
      const k=kneel[c.side]??0;
      if(!(k>0))continue;
      const knee=at(c.lower),hip=at(c.upper);
      const shinQ=c.lower.getWorldQuaternion(new THREE.Quaternion()),footQ=c.end.getWorldQuaternion(new THREE.Quaternion());
      const y=Math.max(c.kneeY,hip.y-c.thigh),dy=hip.y-y;
      const ahead=Math.sqrt(Math.max(c.thigh*c.thigh-dy*dy,0));
      reach([c.upper],c.lower,knee.lerp(hip.addScaledVector(c.legHeading,ahead).setY(y),k));
      const back=c.legHeading.clone().multiplyScalar(Math.cos(SHIN_PITCH)).setY(Math.sin(SHIN_PITCH));
      setWorld(c.lower,shinQ.slerp(aimed(c.lower,at(c.end).sub(at(c.lower)),back.clone()),k));
      setWorld(c.end,footQ.slerp(c.toe?aimed(c.end,at(c.toe).sub(at(c.end)),back.clone()):c.end.getWorldQuaternion(new THREE.Quaternion()),k));
      if(c.toe&&c.toeRest){c.toe.quaternion.slerp(c.toeRest,k);c.toe.updateWorldMatrix(false,true);}
    }
    return this.chains.length;
  }
  reset(){this.group.position.copy(this.origin);this.group.updateMatrixWorld(true);this.retargeter.reset();}
}
