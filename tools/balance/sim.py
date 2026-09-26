import re, random, math, statistics, sys
SRC='src/shared/Config/'
T=[]
for m in re.finditer(r'Id = "(\w+)", Name = "([^"]+)", Rarity = "(\w+)", Value = (\d+), Weight = (\d+), SpawnArea = "(\w+)"', open(SRC+'Treasures.luau').read()):
    T.append(dict(id=m[1],name=m[2],rar=m[3],val=int(m[4]),w=int(m[5]),area=m[6]))
ORDER=["Common","Uncommon","Rare","Epic","Legendary","Mythic","Secret"]
SP=[]
for m in re.finditer(r'Area = "(\w+)", Position = [^}]*?MinRarity = "(\w+)", MaxRarity = "(\w+)"', open(SRC+'WorldLayout.luau').read()):
    SP.append((m[1],m[2],m[3]))
SP += [("Wilds","Rare","Rare"),("Ruins","Epic","Legendary"),("Ruins","Legendary","Mythic")]
W=dict(Common=100,Uncommon=45,Rare=18,Epic=6,Legendary=1.6,Mythic=0.35,Secret=0.05)
CAP=dict(Epic=2,Legendary=1,Mythic=1,Secret=1)
MUT=[("Rainbow",6,0.003),("Moonlit",4,0.02),("Diamond",3,0.012),("Gold",2,0.03),("Silver",1.5,0.06)]
def roll_mut():
    r=random.random()
    for n,m,c in MUT:
        if r<c: return m
        r-=c
    return 1
def night_wave(n=20):
    pts=random.sample(SP,min(n,len(SP)))
    out=[];cnt={}
    for area,mn,mx in pts:
        a,b=ORDER.index(mn),ORDER.index(mx)
        cands=[t for t in T if t['area']==area and a<=ORDER.index(t['rar'])<=b and cnt.get(t['rar'],0)<CAP.get(t['rar'],99)]
        if not cands: continue
        per={}
        for t in cands: per[t['rar']]=per.get(t['rar'],0)+1
        ws=[W[t['rar']]/per[t['rar']] for t in cands]
        t=random.choices(cands,ws)[0]
        cnt[t['rar']]=cnt.get(t['rar'],0)+1
        out.append((t,roll_mut()))
    return out
def speed(ratio):
    for mx,s in [(0.05,1.1),(0.1,1.05),(0.25,1),(0.5,.9),(0.75,.75),(1,.6),(1.5,.45),(9e9,.3)]:
        if ratio<=mx: return s
def sim(cfg,hours=10,share=0.35,picks=4,bench_s=90,verbose=False):
    cash=0;strength=1000;asc=0;tier=0;slots=cfg['tiers'][0][0];vault=[];bench=0
    events={};t=0;cycle=330
    tiers=cfg['tiers'];benches=cfg['benches']
    log=[]
    while t<hours*3600:
        loot=night_wave(cfg.get('maxactive',20))
        loot.sort(key=lambda x:-x[0]['val']*x[1])
        got=0
        for tr,m in loot:
            if got>=picks: break
            if speed(tr['w']/strength)<0.6: continue
            p = share if ORDER.index(tr['rar'])>=3 else 0.8
            if random.random()<p:
                got+=1
                inc=tr['val']/100*m
                cash+=inc*20
                strength+=math.ceil(tr['w']*0.1)
                vault.append(inc); vault.sort(reverse=True)
                if len(vault)>slots:
                    sold=vault.pop(); cash+=sold*60
        # training this cycle
        bg=benches[bench][1]*cfg['trainmul']**asc
        strength+= bg*(bench_s/1.6)*2.2
        income=sum(vault)*cfg['ascmul'](asc)*1.18
        cash+=income*cycle
        t+=cycle
        # purchases
        if tier+1<len(tiers) and cash>=tiers[tier+1][1]:
            cash-=tiers[tier+1][1]; tier+=1; slots=tiers[tier][0]; events.setdefault(f'vault{slots}',t/60)
        for i in range(bench+1,len(benches)):
            if benches[i][2]<=asc and cash>=benches[i][0]*1.5:
                cash-=benches[i][0]; bench=i; events.setdefault(f'bench{i}',t/60)
        req=cfg['req'](asc); cost=cfg['cost'](asc+1)
        if strength>=req and cash>=cost:
            asc+=1; events[f'asc{asc}']=t/60; strength=1000; cash=0
            if cfg.get('reset_vault'): 
                keep=vault[:cfg.get('keep',0)]; vault=keep
        if verbose and int(t/3600)!=int((t-cycle)/3600):
            log.append((round(t/3600,1),round(income),round(cash),asc,slots,round(strength)))
    return events,log,income
