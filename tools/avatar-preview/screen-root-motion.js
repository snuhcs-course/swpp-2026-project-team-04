import * as THREE from './vendor/three/build/three.module.js';

/** Match the detected pelvis's screen location, not a fictitious metric z. */
export class ScreenRootMotion {
  constructor(group,bones){
    this.group=group;this.origin=group.position.clone();this.lastSeen=-Infinity;
    this.anchor=bones.find(b=>['pelvis','hips'].includes(b.name.toLowerCase().replace(/[^a-z]/g,'')));
  }
  reset(){this.group.position.copy(this.origin);this.group.updateMatrixWorld(true);this.lastSeen=-Infinity;}
  update(anchor,camera,viewport,now,dt){
    const alpha=1-Math.exp(-Math.min(Math.max(dt,.001),.1)/.07);
    if(!this.anchor)return false;
    const valid=anchor&&[anchor.x,anchor.y,anchor.imageAspect,viewport.width,viewport.height].every(Number.isFinite)&&
      anchor.x>=0&&anchor.x<=1&&anchor.y>=0&&anchor.y<=1&&anchor.imageAspect>0&&viewport.width>0&&viewport.height>0;
    if(!valid){
      if(now-this.lastSeen>500){this.group.position.lerp(this.origin,alpha*.4);this.group.updateMatrixWorld(true);}
      return false;
    }
    // Camera preview uses BoxFit.cover. Reproduce its centered crop, rather
    // than stretching image coordinates when screen/image aspect differs.
    const imageWidth=Math.max(viewport.width,viewport.height*anchor.imageAspect);
    const imageHeight=imageWidth/anchor.imageAspect;
    const u=(anchor.x*imageWidth-(imageWidth-viewport.width)/2)/viewport.width;
    const v=(anchor.y*imageHeight-(imageHeight-viewport.height)/2)/viewport.height;
    this.group.updateMatrixWorld(true);camera.updateMatrixWorld(true);
    const current=this.anchor.getWorldPosition(new THREE.Vector3());
    const cameraPosition=camera.getWorldPosition(new THREE.Vector3());
    const ray=new THREE.Vector3(2*u-1,1-2*v,.5).unproject(camera).sub(cameraPosition).normalize();
    if(Math.abs(ray.z)<1e-6)return false;
    const distance=(current.z-cameraPosition.z)/ray.z;
    if(!Number.isFinite(distance)||distance<=0)return false;
    const target=cameraPosition.addScaledVector(ray,distance);
    const desired=this.group.position.clone().add(target.sub(current));desired.z=this.origin.z;
    this.group.position.lerp(desired,alpha);this.group.updateMatrixWorld(true);this.lastSeen=now;
    return true;
  }
}
