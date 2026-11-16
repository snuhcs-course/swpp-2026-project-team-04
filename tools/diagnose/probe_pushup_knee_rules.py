"""Conservative causal knee guards, selected with development-only group CV."""
import json
import warnings
from pathlib import Path

import numpy as np
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.tree import DecisionTreeClassifier, export_text
from threadpoolctl import threadpool_limits

from infer_pushup_mlp import ExportedBinaryMlp
from pushup_span_mlp import align_order, coordinates, vector
from score_pushup_nine import match, read_sources

ROOT = Path('C:/SWPP/iter4/pushup-nine-benchmark')
OUT = ROOT / 'knee-focus/rules'


def angle(a, b, c):
    x, y = a-b, c-b
    norm = np.linalg.norm(x, axis=1)*np.linalg.norm(y, axis=1)
    return np.degrees(np.arccos(np.clip(np.sum(x*y, axis=1)/np.maximum(norm, 1e-6), -1, 1)))


def geometry(p):
    """p follows the 13-joint MLP order; hidden points remain NaN."""
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', RuntimeWarning)
        arms = np.stack([np.linalg.norm(p[:,1]-p[:,3],axis=1)+np.linalg.norm(p[:,3]-p[:,5],axis=1),
                         np.linalg.norm(p[:,2]-p[:,4],axis=1)+np.linalg.norm(p[:,4]-p[:,6],axis=1)])
        scale = np.nanmean(arms,axis=0)
        scale[scale<2] = np.nan
        sy = np.nanmean(p[:,1:3,1],axis=1)
        wy = np.nanmean(p[:,5:7,1],axis=1)
        hy = np.nanmean(p[:,7:9,1],axis=1)
        ky = np.nanmean(p[:,9:11,1],axis=1)
        ay = np.nanmean(p[:,11:13,1],axis=1)
        ka = np.stack([angle(p[:,7],p[:,9],p[:,11]),angle(p[:,8],p[:,10],p[:,12])])
        ha = np.stack([angle(p[:,1],p[:,7],p[:,9]),angle(p[:,2],p[:,8],p[:,10])])
        knee_hand = (p[:,9:11,1]-p[:,5:7,1])/scale[:,None]
        shin = (p[:,11:13,1]-p[:,9:11,1])/scale[:,None]
        values = dict(knee_mean=np.nanmean(ka,axis=0),knee_both=np.nanmax(ka,axis=0),
                      knee_either=np.nanmin(ka,axis=0),hip_mean=np.nanmean(ha,axis=0),
                      hip_both=np.nanmax(ha,axis=0),hip_either=np.nanmin(ha,axis=0),
                      knee_wrist=(ky-wy)/scale,ankle_knee=(ay-ky)/scale,
                      hip_wrist=(hy-wy)/scale,hip_shoulder=(hy-sy)/scale,
                      knee_wrist_abs=np.abs((ky-wy)/scale),
                      wrist_shoulder=(wy-sy)/scale,
                      knee_wrist_both=np.nanmax(knee_hand,axis=1),
                      knee_wrist_either=np.nanmin(knee_hand,axis=1),
                      ankle_knee_both=np.nanmax(shin,axis=1),
                      ankle_knee_either=np.nanmin(shin,axis=1))
        names, features = [], []
        for key,val in values.items():
            for q in [10,50,90]:
                names.append(f'{key}_p{q}')
                features.append(float(np.nanpercentile(val,q)) if np.isfinite(val).sum()>=3 else np.nan)
            names.append(f'{key}_visible')
            features.append(float(np.isfinite(val).mean()))
        return names,np.array(features)


def build(replay, events, manifest=None):
    rows, xs, networks = [], [], []
    with replay.open(encoding='utf8') as fp:
        for line in fp:
            source=json.loads(line); key=source['source_id']
            indices,ts,p=coordinates(source)
            proposals=events[key]['events']['app_default']
            by_event={}
            if manifest:
                rec=manifest[key]
                units=sorted((u for u in rec['units'] if not u.get('confirmed_duplicate_of')),
                             key=lambda u:(u['end'],u['start'],u['unit_id']))
                paired,_=match(units,proposals,rec['fps'])
                by_event={j:units[i] for i,j in paired.items()}
            last=-1
            for j,(frame,label) in enumerate(proposals):
                pos=indices.searchsorted(frame)
                start=ts.searchsorted(max(last+1,ts[pos]-1600))
                names,x=geometry(p[start:pos+1])
                xs.append(x);networks.append(vector(ts[start:pos+1],p[start:pos+1]))
                unit=by_event.get(j,{})
                rows.append(dict(source_id=key,frame=int(frame),label=unit.get('label'),
                                 split=manifest[key]['split'] if manifest else 'phone',
                                 group=manifest[key]['group_id'] if manifest else key,
                                 unit_id=unit.get('unit_id'),rule=label))
                last=ts[pos]
    net=ExportedBinaryMlp(ROOT/'span-wide-mlp/binary-model.npz')
    with threadpool_limits(limits=1):
        labels,probs=net.predict(np.array(networks))
    for r,lab,prob in zip(rows,labels,probs):
        r['baseline']=str(lab);r['baseline_p']=float(prob)
    if manifest is None:
        saved=json.loads((ROOT/'span-wide-mlp/stream-binary-results.json').read_text())['phone_fixture_checks']['predictions']
        existing={(r['source_id'],frame):label for r in saved for frame,label in r['events']}
        for row in rows:
            key=(row['source_id'],row['frame'])
            if key in existing:
                row['baseline']='normal' if existing[key]=='normal' else 'invalid'
    return names,np.array(xs),rows


def single_rule(x,y,budget):
    """One threshold, at least 3 observed frames. Missing evidence never rejects."""
    best=(-1,None)
    normal=(y==0);knee=(y==1)
    for col in range(x.shape[1]):
        if col%4==3:
            continue
        for sign in [-1,1]:
            vals=sign*x[:,col]
            candidates=np.unique(np.nanquantile(vals[normal],np.linspace(1-budget,1,25)))
            for threshold in candidates:
                pred=vals>threshold
                fpr=float(pred[normal].mean());tpr=float(pred[knee].mean())
                if fpr<=budget and tpr>best[0]:
                    best=(tpr,dict(col=col,sign=sign,threshold=float(threshold)))
    return best[1]


def predict_rule(x,rule):
    return rule['sign']*x[:,rule['col']]>rule['threshold']


def tree_input(x):
    filled=np.nan_to_num(x,nan=-999.)
    filled[:,3::4]=0
    return filled


def tree_probability(tree,x):
    # A geometrically unknown branch cannot establish knee support.
    result=np.zeros(len(x))
    structure=tree.tree_
    for i,row in enumerate(x):
        node=0
        while structure.children_left[node]!=structure.children_right[node]:
            col=structure.feature[node]
            if not np.isfinite(row[col]):
                node=-1
                break
            node=structure.children_left[node] if row[col]<=structure.threshold[node] else structure.children_right[node]
        if node>=0:
            value=structure.value[node,0]
            result[i]=value[1]/value.sum()
    return result


def fitted_guard(candidate, train_x, y, target_x):
    if candidate['kind']=='single':
        return predict_rule(target_x,candidate['rule'])
    tree=DecisionTreeClassifier(max_depth=candidate['depth'],min_samples_leaf=candidate['leaf'],random_state=164)
    tree.fit(tree_input(train_x),y)
    threshold=float(np.quantile(tree_probability(tree,train_x[y==0]),1-candidate['budget']))
    return tree_probability(tree,target_x)>threshold


def phone_report(rows, rejected, gold):
    source_rows={key:[] for key in gold}
    for i,row in enumerate(rows):
        source_rows[row['source_id']].append((i,row))
    total=dict(normal=0,knees=0,normal_before=0,normal_after=0,knees_before=0,knees_after=0,
               pure_knee_accepted_before=0,pure_knee_accepted_after=0)
    records=[]
    for key,items in source_rows.items():
        truth=['normal' if v=='valid' else v for v in (gold[key].get('labelled') or [])]
        if not truth:
            continue
        before=[r['baseline'] for i,r in items]
        after=['invalid' if rejected[i] else r['baseline'] for i,r in items]
        # Freeze event-index alignment using baseline binary output; no relabel-driven rematching.
        n,m=len(truth),len(before)
        cost=np.zeros((n+1,m+1),dtype=int)
        cost[:,m]=np.arange(n,-1,-1);cost[n,:]=np.arange(m,-1,-1)
        binary=['normal' if t=='normal' else 'invalid' for t in truth]
        for i in reversed(range(n)):
            for j in reversed(range(m)):
                cost[i,j]=min(cost[i+1,j+1]+(binary[i]!=before[j]),cost[i+1,j]+1,cost[i,j+1]+1)
        i=j=0;pairs={}
        while i<n or j<m:
            if i<n and j<m and cost[i,j]==cost[i+1,j+1]+(binary[i]!=before[j]):
                pairs[i]=j;i+=1;j+=1
            elif i<n and cost[i,j]==cost[i+1,j]+1:
                i+=1
            else:
                j+=1
        for i,t in enumerate(truth):
            a=before[pairs[i]] if i in pairs else 'no_event'
            b=after[pairs[i]] if i in pairs else 'no_event'
            if t=='normal':
                total['normal']+=1;total['normal_before']+=a=='normal';total['normal_after']+=b=='normal'
            elif t=='kneesDown':
                total['knees']+=1;total['knees_before']+=a=='invalid';total['knees_after']+=b=='invalid'
        pure=set(truth)=={'kneesDown'}
        if pure:
            total['pure_knee_accepted_before']+=before.count('normal')
            total['pure_knee_accepted_after']+=after.count('normal')
        records.append(dict(source_id=key,truth=truth,pure_knee=pure,accepted_before=before.count('normal'),
                            accepted_after=after.count('normal')))
    return dict(total=total,recordings=records)


def main():
    OUT.mkdir(parents=True,exist_ok=True)
    cache=OUT/'geometry.npz'
    manifest=read_sources(ROOT/'native-all/units.jsonl')
    events=read_sources(ROOT/'span-wide-mlp/proposals.jsonl')
    if cache.exists():
        data=np.load(cache);x=data['x'];names=list(data['names'])
        rows=json.loads((OUT/'rows.json').read_text())
    else:
        names,x,rows=build(ROOT/'native-all/replay.jsonl',events,manifest)
        np.savez_compressed(cache,x=x,names=names)
        (OUT/'rows.json').write_text(json.dumps(rows))
    ids=np.array([i for i,r in enumerate(rows) if r['split']=='development' and r['label'] in ('normal','kneesDown')])
    y=np.array([rows[i]['label']=='kneesDown' for i in ids],dtype=int)
    group=np.array([rows[i]['group'] for i in ids]);xx=x[ids]
    folds=list(StratifiedGroupKFold(n_splits=5,shuffle=True,random_state=164).split(xx,y,group))
    ranking=[]
    for budget in [.002,.005,.01,.02,.03,.05]:
        pred=np.zeros(len(ids),dtype=bool)
        for a,b in folds:
            rule=single_rule(xx[a],y[a],budget)
            pred[b]=predict_rule(xx[b],rule)
        rule=single_rule(xx,y,budget)
        ranking.append(dict(kind='single',budget=budget,normal_loss=float(pred[y==0].mean()),
                            knee_reject=float(pred[y==1].mean()),rule=rule,name=names[rule['col']]))
    # Tiny auditable trees, tune the probability threshold on training normals.
    filled=tree_input(xx)
    for depth in [2,3,4]:
        for leaf in [15,40,80]:
            for budget in [.005,.01,.02,.05]:
                pred=np.zeros(len(ids),dtype=bool)
                for a,b in folds:
                    tree=DecisionTreeClassifier(max_depth=depth,min_samples_leaf=leaf,random_state=164)
                    tree.fit(filled[a],y[a])
                    p=tree_probability(tree,xx[a])
                    threshold=np.quantile(p[y[a]==0],1-budget)
                    pred[b]=tree_probability(tree,xx[b])>threshold
                ranking.append(dict(kind='tree',depth=depth,leaf=leaf,budget=budget,
                                    normal_loss=float(pred[y==0].mean()),knee_reject=float(pred[y==1].mean())))
    ranking.sort(key=lambda r:(r['normal_loss']>.02,-r['knee_reject'],r['normal_loss']))
    results=[]
    for candidate in ranking:
        if candidate['kind']=='single':
            reject=predict_rule(x,candidate['rule'])
        else:
            tree=DecisionTreeClassifier(max_depth=candidate['depth'],min_samples_leaf=candidate['leaf'],random_state=164)
            tree.fit(filled,y)
            threshold=float(np.quantile(tree_probability(tree,xx[y==0]),1-candidate['budget']))
            reject=tree_probability(tree,x)>threshold
            candidate['threshold']=threshold
            candidate['tree_text']=export_text(tree,feature_names=names)
        report=dict(candidate)
        for split in ['development','holdout']:
            items=[i for i,r in enumerate(rows) if r['split']==split]
            categories={}
            for label in ['normal','kneesDown','insufficientDepth','incompleteExtension','shouldersNotLevel','armsStraight']:
                ii=[i for i in items if rows[i]['label']==label]
                categories[label]=dict(proposals=len(ii),baseline_normal=sum(rows[i]['baseline']=='normal' for i in ii),
                                       guard_rejected=sum(bool(reject[i]) for i in ii),
                                       final_normal=sum(rows[i]['baseline']=='normal' and not reject[i] for i in ii))
            report[split]=categories
        results.append(report)
    report=dict(note='Holdout is reused benchmark previously inspected, not fresh unseen evaluation. Guard never adds events.',
                development_normal=int((y==0).sum()),development_knee=int((y==1).sum()),rankings=results)
    phonecache=OUT/'phone-geometry.npz'
    phonegold=read_sources(ROOT/'span-wide-mlp/fixtures-proposals.jsonl')
    if phonecache.exists():
        px=np.load(phonecache)['x'];pr=json.loads((OUT/'phone-rows.json').read_text())
    else:
        _,px,pr=build(ROOT/'span-source-fixtures.jsonl',phonegold)
        np.savez_compressed(phonecache,x=px)
        (OUT/'phone-rows.json').write_text(json.dumps(pr))
    for candidate in report['rankings']:
        predicted=fitted_guard(candidate,xx,y,px)
        candidate['phone']=phone_report(pr,predicted,phonegold)
        predicted_web=fitted_guard(candidate,xx,y,x)
        for split in ['development','holdout']:
            normal=[i for i,r in enumerate(rows) if r['split']==split and r['label']=='normal' and r['baseline']=='normal']
            candidate[split]['currently_accepted_normal_loss']=sum(bool(predicted_web[i]) for i in normal)
            candidate[split]['currently_accepted_normal_count']=len(normal)
    (OUT/'results.json').write_text(json.dumps(report,indent=2))
    for r in results[:10]:
        print({k:v for k,v in r.items() if k not in ('tree_text','development','holdout')},r['holdout']['normal'],r['holdout']['kneesDown'],flush=True)


if __name__=='__main__':
    main()
