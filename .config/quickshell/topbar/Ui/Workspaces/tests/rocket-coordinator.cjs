const fs = require('fs');
const vm = require('vm');
const assert = require('assert/strict');
const base = require('node:path').resolve(__dirname, '../../..') + '/';
const motion = vm.createContext({});
const flight = vm.createContext({Motion: motion});
const monitor = vm.createContext({Motion: motion});
for (const [file, context] of [['OrbitalMotion.js',motion],['OrbitFlight.js',flight],['MonitorTransfer.js',monitor]])
    vm.runInContext(fs.readFileSync(base+'Ui/Workspaces/'+file,'utf8').replace(/^\.(pragma|import).*$/gm,''),context);
const functions = fs.readFileSync(base+'Services/WorkspaceRocket.qml','utf8').match(/^    function [\s\S]*?^    }/gm).join('\n');
function fixture() {
    const callbacks=[];
    const noop=()=>{};
    const rocket=vm.createContext({Motion:motion,Flight:flight,MonitorTransfer:monitor,Qt:{callLater:fn=>callbacks.push(fn)},retry:{stop:noop,restart:noop},fade:{stop:noop,start:noop},
        focusedMonitor:'A',monitorName:'A',scenes:{},transfer:null,bodies:[],destination:'',destinationId:-1,pose:null,heading:0,elapsed:0,trailPoints:[],trailRevision:0,trailOpacity:1,stage:'idle',departureMonitor:''});
    Object.defineProperty(rocket,'travelling',{get:()=>rocket.transfer!==null});
    vm.runInContext(functions,rocket);
    for (const [name,screen,ids] of [['A',{x:0,y:373,width:2048,height:1152},[1,2,3]],['B',{x:2048,y:0,width:1920,height:1080},[6,7,8]]]) {
        const centers=Object.fromEntries(ids.map((id,i)=>[id,[screen.x+300+i*48,screen.y+21]]));
        const scene={activeId:ids[0],externalDeparture:false,captures:[],flight:flight.create(ids[0],centers[ids[0]]),
            departureState(){return {state:this.flight,body:{id:this.flight.orbitId,center:centers[this.flight.orbitId],live:true,settled:true}}},
            arrivalTarget(){return {id:this.activeId,center:centers[this.activeId],live:true,settled:true}},
            displayDeparture(){},
            acceptFlight(state){this.captures.push(state.orbitId); this.flight=Object.assign({},state);}
        };
        rocket.scenes[name]={screen,scene};
    }
    function tick(dt) {
        rocket.advance(dt);
        if(rocket.travelling) {
            assert.ok(motion.finitePose(rocket.pose));
            const turn=Math.atan2(Math.sin(rocket.heading-Math.atan2(rocket.pose.v[1],rocket.pose.v[0])),Math.cos(rocket.heading-Math.atan2(rocket.pose.v[1],rocket.pose.v[0])));
            assert.ok(Math.abs(turn)<1e-7,'heading must follow motion without independent rotation');
        }
        while(callbacks.length) callbacks.shift()();
    }
    return {rocket,tick};
}
for (const fps of [30,60,144,240]) {
    const dt=1/fps;
    {
        const {rocket:r,tick}=fixture();
        r.focusedMonitor='B'; r.followFocus();
        while(r.transfer.mode!=='departure')tick(dt);
        const plan=r.transfer.plan, pose=r.pose;
        r.scenes.B.scene.activeId=7; r.followFocus();
        assert.equal(r.transfer.plan,plan,'new request must not rewrite a departure already in progress');
        assert.equal(r.pose,pose);
        for(let i=0;i<fps*8 && r.travelling;i++)tick(dt);
        assert.equal(r.travelling,false);
        assert.deepEqual(r.scenes.B.scene.captures,[7],'prelaunch change should go directly to the latest workspace after realignment');
    }
    {
        const {rocket:r,tick}=fixture();
        r.focusedMonitor='B'; r.followFocus();
        while(r.transfer.mode!=='departure')tick(dt);
        tick(dt);
        const plan=r.transfer.plan, pose=r.pose;
        r.focusedMonitor='A'; r.followFocus();
        assert.equal(r.transfer.plan,plan,'cancellation must finish the current orbital departure');
        assert.equal(r.pose,pose);
        for(let i=0;i<fps*4 && r.travelling;i++)tick(dt);
        assert.equal(r.travelling,false);
        assert.equal(r.scenes.A.scene.externalDeparture,false);
        assert.deepEqual(r.scenes.A.scene.captures,[1]);
        assert.deepEqual(r.scenes.B.scene.captures,[]);
    }
    {
        const {rocket:r,tick}=fixture();
        r.focusedMonitor='B'; r.followFocus();
        while(r.stage!=='transfer')tick(dt);
        const plan=r.transfer.plan;
        for(let i=0;i<fps*4 && r.scenes.B.scene.captures.length===0;i++) {
            const elapsed=r.transfer.elapsed, pose=r.pose;
            r.focusedMonitor=i%2?'A':'B';
            r.scenes.B.scene.activeId=i%3+6;
            r.followFocus();
            assert.equal(r.transfer.plan,plan,'airborne plan must survive repeated switches');
            assert.equal(r.transfer.elapsed,elapsed,'new focus must not restart flight time');
            assert.equal(r.pose,pose,'request must not move or rotate the rocket');
            tick(dt);
        }
        assert.deepEqual(r.scenes.B.scene.captures,[6],'committed flight must land once');
        r.focusedMonitor='A'; r.followFocus();
        for(let i=0;i<fps*8 && r.travelling;i++)tick(dt);
        assert.equal(r.monitorName,'A','latest focus must be followed after landing');
        assert.equal(r.travelling,false);
    }
}
console.log('Passed coordinator departure retargeting, cancellation, per-frame airborne request churn, latest-focus capture and heading/motion alignment at 30/60/144/240 FPS.');
