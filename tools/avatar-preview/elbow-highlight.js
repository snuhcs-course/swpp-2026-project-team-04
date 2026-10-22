import * as THREE from './vendor/three/build/three.module.js';
const clean=name=>name.toLowerCase().replace(/[^a-z0-9]/g,'');

// Same image-plane definition as Flutter angleDegrees/measurePose. Display only:
// this module never changes a landmark, bone quaternion, or rep-judge threshold.
export function elbowAngle(points,side){
  const indices=side==='left'?[11,13,15]:[12,14,16];
  const p=indices.map(i=>points?.[i]);
  if(p.some(v=>!v||!Number.isFinite(v.x)||!Number.isFinite(v.y)||(v.visibility??0)<.6))return null;
  const [a,b,c]=p,ux=a.x-b.x,uy=a.y-b.y,vx=c.x-b.x,vy=c.y-b.y;
  const norm=Math.hypot(ux,uy)*Math.hypot(vx,vy);
  if(norm<1e-8)return null;
  return Math.acos(THREE.MathUtils.clamp((ux*vx+uy*vy)/norm,-1,1))*180/Math.PI;
}

export class ElbowHighlight {
  constructor(canvas,bones){
    this.canvas=canvas;this.ctx=canvas.getContext('2d');this.angles={};
    const byName=new Map(bones.map(b=>[clean(b.name),b]));
    this.arms=['left','right'].map(side=>{
      const suffix=side==='left'?'l':'r';
      return {side,bones:['upperarm','lowerarm','hand'].map(part=>byName.get(`${part}${suffix}`))};
    });
  }
  clear(){this.ctx.clearRect(0,0,this.canvas.width,this.canvas.height);this.angles={};}
  update(points,camera,width,height,mirror,dt){
    const ratio=Math.min(globalThis.devicePixelRatio||1,2);
    if(this.canvas.width!==Math.round(width*ratio)||this.canvas.height!==Math.round(height*ratio)){
      this.canvas.width=Math.round(width*ratio);this.canvas.height=Math.round(height*ratio);
    }
    const ctx=this.ctx;ctx.setTransform(ratio,0,0,ratio,0,0);ctx.clearRect(0,0,width,height);
    camera.updateMatrixWorld(true);const labels=[];
    for(const arm of this.arms){
      const raw=elbowAngle(points,arm.side);
      if(raw===null||arm.bones.some(b=>!b)){delete this.angles[arm.side];continue;}
      const alpha=1-Math.exp(-Math.max(.001,Math.min(dt,.1))/.075);
      const previous=this.angles[arm.side]??raw,angle=previous+(raw-previous)*alpha;this.angles[arm.side]=angle;
      const p=arm.bones.map(b=>b.getWorldPosition(new THREE.Vector3()).project(camera));
      if(p.some(v=>v.z < -1||v.z > 1))continue;
      const [shoulder,elbow,wrist]=p.map(v=>({x:(mirror?1-v.x:1+v.x)*width/2,y:(1-v.y)*height/2}));
      if(elbow.x<0||elbow.x>width||elbow.y<0||elbow.y>height)continue;
      const bend=THREE.MathUtils.clamp((170-angle)/90,0,1);
      const color=new THREE.Color('#75bdd1').lerp(new THREE.Color('#ffc34d'),bend).getStyle();
      ctx.save();ctx.strokeStyle=color;ctx.fillStyle=color;ctx.lineJoin='round';ctx.lineCap='round';
      ctx.globalAlpha=.3+.4*bend;ctx.lineWidth=4+4*bend;
      ctx.beginPath();ctx.moveTo(shoulder.x,shoulder.y);ctx.lineTo(elbow.x,elbow.y);ctx.lineTo(wrist.x,wrist.y);ctx.stroke();
      ctx.globalAlpha=1;ctx.shadowColor=color;ctx.shadowBlur=5+8*bend;
      ctx.lineWidth=2.5;ctx.beginPath();ctx.arc(elbow.x,elbow.y,7+5*bend,0,Math.PI*2);ctx.stroke();
      ctx.beginPath();ctx.arc(elbow.x,elbow.y,3,0,Math.PI*2);ctx.fill();ctx.shadowBlur=0;
      // Arc around the actual rendered bend, not a fabricated angle or pose.
      const a=Math.atan2(shoulder.y-elbow.y,shoulder.x-elbow.x),b=Math.atan2(wrist.y-elbow.y,wrist.x-elbow.x);
      const delta=Math.atan2(Math.sin(b-a),Math.cos(b-a));
      ctx.beginPath();ctx.arc(elbow.x,elbow.y,18+4*bend,a,a+delta,delta<0);ctx.stroke();
      const text=`${arm.side==='left'?'왼':'오른'} ${Math.round(angle)}°`;
      ctx.font='bold 12px sans-serif';const badgeWidth=ctx.measureText(text).width+16;
      let x=elbow.x+(elbow.x>width/2?22:-22-badgeWidth),y=elbow.y-34;
      x=THREE.MathUtils.clamp(x,4,Math.max(4,width-badgeWidth-4));y=THREE.MathUtils.clamp(y,4,Math.max(4,height-30));
      if(labels.some(r=>x<r.x+r.w&&x+badgeWidth>r.x&&y<r.y+26&&y+26>r.y))y=Math.min(height-30,y+32);
      ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(elbow.x,elbow.y);ctx.lineTo(x+badgeWidth/2,y+24);ctx.stroke();
      ctx.fillStyle='rgba(10,18,28,.9)';ctx.fillRect(x,y,badgeWidth,24);ctx.strokeRect(x,y,badgeWidth,24);
      ctx.fillStyle=color;ctx.textBaseline='middle';ctx.fillText(text,x+8,y+12);labels.push({x,y,w:badgeWidth});ctx.restore();
    }
  }
}
