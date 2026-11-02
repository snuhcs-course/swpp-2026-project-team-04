import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import * as THREE from './vendor/three/build/three.module.js';
import {PoseRetargeter} from './retarget.js';
import {FixedPushUpRig,pushUpTemplate} from './fixed-pushup.js';

const top=pushUpTemplate(0),bottom=pushUpTemplate(1.1);
for(const i of [15,16,27,28,31,32])assert.deepEqual(top[i],bottom[i]);
assert.ok(bottom[11].y>top[11].y);
assert.ok(pushUpTemplate(0,'kneesDown')[25].y>top[25].y);
assert.ok(pushUpTemplate(0,'bellyDown')[23].y>top[23].y);

for(const id of ['astronaut','robot','mannequiny','xcvg','soma_training','soma_active','soma_studio']){
  const bytes=readFileSync(new URL(`../../gymrats_app/assets/avatar/models/${id}.glb`,import.meta.url));
  const data=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString());
  const joints=new Set(data.skins.flatMap(s=>s.joints));
  const nodes=data.nodes.map((n,i)=>{
    const o=joints.has(i)?new THREE.Bone():new THREE.Object3D();
    o.name=THREE.PropertyBinding.sanitizeNodeName(n.name??String(i));
    if(n.matrix)o.applyMatrix4(new THREE.Matrix4().fromArray(n.matrix));
    else{if(n.translation)o.position.fromArray(n.translation);if(n.rotation)o.quaternion.fromArray(n.rotation);if(n.scale)o.scale.fromArray(n.scale);}
    return o;
  });
  data.nodes.forEach((n,i)=>(n.children??[]).forEach(c=>nodes[i].add(nodes[c])));
  const model=new THREE.Group();data.scenes[data.scene??0].nodes.forEach(i=>model.add(nodes[i]));
  model.updateMatrixWorld(true);
  const rig=new FixedPushUpRig(model,new PoseRetargeter(model,nodes.filter(b=>b.isBone)));
  assert.equal(rig.chains.length,4,`${id}: 4 limbs mapped`);
  for(let i=0;i<180;i++)rig.update(1.1,null,3000+i*16,1/60);
  for(const c of rig.chains){
    const error=c.end.getWorldPosition(new THREE.Vector3()).distanceTo(c.target);
    assert.ok(Number.isFinite(error)&&error<.15,`${id}: contact drift ${error}`);
  }
  for(const b of nodes)assert.ok(b.quaternion.toArray().every(Number.isFinite));
  console.log(`PASS ${id}: fixed limb targets and bent pose`);
}
