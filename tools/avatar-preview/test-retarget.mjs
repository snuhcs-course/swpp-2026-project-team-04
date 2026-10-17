import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import * as THREE from './vendor/three/build/three.module.js';
import {PoseRetargeter} from './retarget.js';
function rig(id){
  const bytes=readFileSync(new URL(`./models/${id}.glb`,import.meta.url));
  const data=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString());
  const joints=new Set(data.skins.flatMap(s=>s.joints));
  const nodes=data.nodes.map((n,i)=>{
    const o=joints.has(i)?new THREE.Bone():new THREE.Object3D();o.name=THREE.PropertyBinding.sanitizeNodeName(n.name??String(i));
    if(n.matrix)o.applyMatrix4(new THREE.Matrix4().fromArray(n.matrix));
    else{if(n.translation)o.position.fromArray(n.translation);if(n.rotation)o.quaternion.fromArray(n.rotation);if(n.scale)o.scale.fromArray(n.scale);}
    return o;
  });
  data.nodes.forEach((n,i)=>(n.children??[]).forEach(c=>nodes[i].add(nodes[c])));
  const model=new THREE.Group();data.scenes[data.scene??0].nodes.forEach(i=>model.add(nodes[i]));model.updateMatrixWorld(true);
  return {model,bones:nodes.filter(b=>b.isBone)};
}
const p=(x,y,z=0)=>({x,y,z,visibility:1,presence:1});
const pose=Array.from({length:33},()=>p(0,0));
Object.assign(pose,{7:p(.07,-.7),8:p(-.07,-.7),11:p(.2,-.5),12:p(-.2,-.5),13:p(.45,-.3),14:p(-.3,-.85),15:p(.6,-.55),16:p(-.3,-1.1),23:p(.12,0),24:p(-.12,0),25:p(.15,.4),26:p(-.2,.3,.2),27:p(.15,.8),28:p(-.2,.65,.3),31:p(.15,.85,-.15),32:p(-.2,.7,.15)});
for(const id of ['astronaut','robot','mannequiny','xcvg']){
  const {model,bones}=rig(id),target=new PoseRetargeter(model,bones);
  assert.equal(target.entries.length,11,`${id}: expected arms, legs, feet, neck`);assert.ok(target.restFrame,`${id}: torso mapping`);
  for(let i=0;i<90;i++)assert.equal(target.update(pose,1000+i*50,.05),12);
  for(const entry of target.entries){
    const actual=entry.local.clone().applyQuaternion(entry.bone.getWorldQuaternion(new THREE.Quaternion()));
    const avg=ids=>ids.map(i=>new THREE.Vector3(pose[i].x,-pose[i].y,-pose[i].z)).reduce((a,b)=>a.add(b),new THREE.Vector3()).multiplyScalar(1/ids.length);
    const desired=avg(entry.end).sub(avg(entry.start)).normalize();
    assert.ok(actual.dot(desired)>.995,`${id}/${entry.bone.name}: direction alignment ${actual.dot(desired)}`);
  }
  for(const bone of bones)assert.ok(bone.quaternion.toArray().every(Number.isFinite));
  for(let i=0;i<150;i++)assert.equal(target.update(null,10000+i*50,.05),0);
  for(const [bone,q] of target.rest)assert.ok(bone.quaternion.angleTo(q)<.001,`${id}: lost tracking recovery`);
  const invalid=pose.map(p=>({...p,x:NaN}));assert.equal(target.update(invalid,20000,.05),0);
  target.update(pose,21000,.05);target.reset();for(const [bone,q] of target.rest)assert.deepEqual(bone.quaternion.toArray(),q.toArray());
  console.log(`PASS ${id}: ${bones.length} bones, 12 mappings; direction, finite rotations, lost tracking, reset`);
}
