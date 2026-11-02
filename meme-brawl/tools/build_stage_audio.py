#!/usr/bin/env python3
"""Original map atmospheres and nonverbal creature motifs, not source recordings."""
from pathlib import Path
import hashlib, json, subprocess, tempfile, wave
import numpy as np
from build_character_audio import RATE, tone, note
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/stages'
NAMES=['gugu','dog','cat','naiwa','niulai','kangaroo']
STYLES=['muffled glacial electronic ambience and synthetic bird calls','sub bass and abrasive metal',
        'lazy muted plucks and rolling crumbs','wet low drone and synthetic frog laugh',
        'sparse mournful strings and muffled hoof falls','busy street electronics and abstract delivery chimes']


def creature(kind, duration=1.5):
    t=np.arange(round(duration*RATE))/RATE
    phase=t/duration
    if kind==0:
        # Four subdued rounded syllables, with room reflections.
        freq=280+65*np.sin(t*15)+35*np.sin(t*32)
        env=np.maximum(0,np.sin(phase*np.pi*4))**2*np.sin(np.pi*phase)
        signal=(np.sin(2*np.pi*np.cumsum(freq)/RATE)+.25*np.sin(2*np.pi*np.cumsum(freq*2.3)/RATE))*env*.4
    else:
        freq=90+80*np.maximum(0,np.sin(t*25))
        env=np.maximum(0,np.sin(t*25))**3*np.sin(np.pi*phase)
        signal=np.tanh(2*np.sin(2*np.pi*np.cumsum(freq)/RATE))*env*.4
    for delay,gain in [(.19,.22),(.41,.13)]:
        count=round(delay*RATE)
        signal[count:]+=signal[:-count]*gain
    return signal


def compose(kind):
    rng=np.random.default_rng(8830+kind)
    bpm=[64,80,72,66,56,128][kind]
    beat=60/bpm
    duration=beat*48
    size=round(duration*RATE)
    out=np.zeros((size,2))
    t=np.arange(size)/RATE
    # Integer cycles ensure that the continuous bed closes at its boundary.
    hz=round([52,38,78,43,55,65][kind]*duration)/duration
    bed=(np.sin(2*np.pi*hz*t)+.35*np.sin(2*np.pi*hz*2*t))*.035
    out[:,0]+=bed;out[:,1]+=bed

    def add(signal,start,gain=.1,pan=0):
        idx=(round(start*RATE)+np.arange(len(signal)))%size
        out[idx,0]+=signal*gain*np.sqrt((1-pan)/2)
        out[idx,1]+=signal*gain*np.sqrt((1+pan)/2)

    for bar in range(12):
        at=bar*beat*4
        root=[50,38,57,33,36,43][kind]+[0,-3,-5,-2][bar%4]
        if kind in [0,4]:
            for interval in [0,7,10]:
                add(tone(note(root+12+interval),beat*5,4,rng),at,.05 if kind==0 else .07,(-.4 if interval==0 else .4))
        for step in range(16):
            at=(bar*4+step/4)*beat
            if kind==0 and step in [0,10]:
                add(tone(note(root+24+[0,7][step//10]),beat*2,0,rng),at,.06)
            elif kind==1 and step in [0,4,8,11,14]:
                add(tone(note(root),beat*.8,1,rng),at,.2)
            elif kind==2 and step in [0,7,12]:
                add(tone(note(root+12+[0,7,3][step%3]),beat*.8,2,rng),at,.14)
            elif kind==3 and step in [0,3,10]:
                add(tone(note(root),beat*1.2,3,rng),at,.11)
            elif kind==5 and step%2==0:
                add(tone(note(root+(12 if step%4 else 0)),beat*.7,5,rng),at,.19)
            if (kind in [1,5] and step in [0,8,14]) or (kind==4 and step in [0,10]):
                ts=np.arange(round(.32*RATE))/RATE
                hit=np.sin(2*np.pi*(43*ts+2*(1-np.exp(-ts*30))))*np.exp(-ts*17)
                add(hit,at,.3)
            if kind in [1,2,3,5] and step%4==0:
                length=.5 if kind==1 else .16
                noise=rng.normal(0,.4,round(length*RATE))
                if kind in [2,3]: noise=np.convolve(noise,np.ones(19)/19,mode='same')
                env=np.sin(np.linspace(0,np.pi,len(noise)))**2
                add(noise*env,at,.045 if kind!=1 else .09,(-.5 if step%8 else .5))
        if kind in [0,3] and bar in [1,4,8,11]:
            add(creature(kind),bar*beat*4+beat,.2,-.4)
        if kind==5 and bar%3==1:
            for j,pitch in enumerate([79,83,86]):
                add(tone(note(pitch),.19,2,rng),bar*4*beat+j*.14,.09,.4)
    out=np.tanh(out)
    out*=.6/max(np.abs(out).max(),.001)
    return out,bpm


def main():
    ROOT.mkdir(parents=True,exist_ok=True)
    manifest={'type':'original procedural map soundtrack','recorded_meme_voices':False,'files':{}}
    with tempfile.TemporaryDirectory() as temp:
        for kind,name in enumerate(NAMES):
            pcm,bpm=compose(kind)
            entries=[(name+'_bgm',pcm)]
            if kind in [0,3]:
                signal=creature(kind)
                entries.append((name+'_echo',np.column_stack([signal,signal])))
            if kind==0:
                signal=creature(0,.85)*.5
                entries.append(('gugu_home',np.column_stack([signal,signal])))
            for filename,data in entries:
                wav=Path(temp)/'stage.wav'
                with wave.open(str(wav),'wb') as output:
                    output.setnchannels(2);output.setsampwidth(2);output.setframerate(RATE)
                    output.writeframes(np.round(np.clip(data,-1,1)*32767).astype('<i2').tobytes())
                path=ROOT/(filename+'.ogg')
                subprocess.run(['ffmpeg','-v','error','-nostdin','-y','-i',str(wav),'-c:a','libvorbis','-q:a','5',str(path)],check=True)
                manifest['files'][path.name]={'style':STYLES[kind],'bpm':bpm,'duration':len(data)/RATE,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print('Generated six map atmospheres, two distant creature motifs and one quiet home call')

if __name__=='__main__': main()
