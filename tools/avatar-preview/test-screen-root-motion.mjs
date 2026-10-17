import assert from 'node:assert/strict';
import * as THREE from './vendor/three/build/three.module.js';
import {ScreenRootMotion} from './screen-root-motion.js';
for(const [width,height,imageAspect] of [[360,480,.75],[360,640,.75],[640,360,4/3]]){
 const group=new THREE.Group(),pelvis=new THREE.Bone();pelvis.name='pelvis';pelvis.position.set(.03,.95,.15);group.add(pelvis);
 const camera=new THREE.PerspectiveCamera(40,width/height,.01,60);camera.position.set(0,1.15,4.4);camera.lookAt(0,1.15,0);camera.updateProjectionMatrix();
 const motion=new ScreenRootMotion(group,[pelvis]);
 function settle(x,y){for(let i=0;i<180;i++)motion.update({x,y,imageAspect},camera,{width,height},1000+i*16,1/60);return pelvis.getWorldPosition(new THREE.Vector3()).project(camera);}
 const center=settle(.5,.5);assert.ok(Math.abs(center.x)<1e-5&&Math.abs(center.y)<1e-5);
 const moved=settle(.6,.65);
 const iw=Math.max(width,height*imageAspect),ih=iw/imageAspect;
 assert.ok(Math.abs(moved.x-(2*(.6*iw-(iw-width)/2)/width-1))<1e-5);
 assert.ok(Math.abs(moved.y-(1-2*(.65*ih-(ih-height)/2)/height))<1e-5);
 // A pose rotation can move the pelvis itself. Root translation must still
 // target that pelvis, not just the model's unchanged object origin.
 pelvis.position.y+=.2;const same=settle(.6,.65);assert.ok(same.distanceTo(moved)<1e-5);
 assert.equal(group.position.z,0);
 const prior=group.position.clone();motion.update(null,camera,{width,height},motion.lastSeen+100,1/60);assert.ok(group.position.equals(prior));
 for(let i=0;i<300;i++)motion.update(null,camera,{width,height},20000+i*16,1/60);
 assert.ok(group.position.length()<1e-5);motion.reset();assert.equal(group.position.length(),0);
 assert.equal(motion.update({x:NaN,y:0,imageAspect},camera,{width,height},30000,1/60),false);
 console.log(`PASS ${width}x${height}: translation, cover crop, pelvis pivot, fixed depth, lost tracking/reset`);
}
