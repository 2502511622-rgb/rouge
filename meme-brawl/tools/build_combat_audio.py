#!/usr/bin/env python3
"""Generate original layered arcade combat SFX, with no sampled game audio."""
from pathlib import Path
import hashlib, json, subprocess, tempfile, wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1] / 'assets/audio/combat'
SPECS = {
 'swing':(.16,260,0), 'kick':(.21,170,1), 'hit_light':(.14,145,2),
 'hit_medium':(.22,105,3), 'hit_heavy':(.34,64,4), 'block':(.15,680,5),
 'metal':(.30,980,6), 'slash':(.27,420,7), 'sonic':(.42,350,8),
 'shard':(.27,1450,9), 'slime':(.33,120,10), 'quake':(.48,44,11),
 'uppercut':(.31,200,12), 'counter':(.36,900,13), 'ex':(.38,320,14),
 'ca':(.68,70,15), 'land':(.22,68,16), 'power':(.44,240,17), 'throw':(.36,80,18),
}
RATE = 44100


def make(name, duration, base, seed):
    rng = np.random.default_rng(9100+seed)
    t = np.arange(int(RATE*duration))/RATE
    phase = t/duration
    noise = rng.uniform(-1,1,len(t))
    # Broadband transient + low body thump + a separate resonant/material layer.
    body_noise = np.convolve(noise,np.ones(21)/21,mode='same')
    high_noise = noise-np.convolve(noise,np.ones(7)/7,mode='same')
    thump = np.sin(2*np.pi*(base*t + base*.06*(1-np.exp(-t/0.025))))*np.exp(-t*22)
    click = high_noise*np.exp(-t*95)
    signal = .63*thump+.55*body_noise*np.exp(-t*16)+.25*click
    if name in ['swing','kick','slash','uppercut']:
        envelope = np.sin(np.pi*phase)**1.6
        sweep = np.sin(2*np.pi*(base*t+1600*t*t))
        signal = (.68*body_noise+.18*high_noise+.15*sweep)*envelope
    elif name in ['metal','block','counter','shard']:
        ring = sum(np.sin(2*np.pi*base*ratio*t)*np.exp(-t*(12+i*3)) for i,ratio in enumerate([1,1.43,2.17,2.91]))*.17
        signal = .8*signal+ring
    elif name == 'sonic':
        freq = base+110*np.sin(t*25)
        signal = np.sin(2*np.pi*np.cumsum(freq)/RATE)*np.exp(-t*7)*.48 + body_noise*.35*np.exp(-t*10)
    elif name == 'slime':
        bubbles = np.sin(2*np.pi*(base*t+60*np.sin(t*18)))*np.exp(-t*9)
        signal = .55*bubbles+.2*body_noise*np.exp(-t*12)
    elif name in ['quake','ca','land','throw']:
        rumble = np.sin(2*np.pi*base*t)*np.exp(-t*9)
        signal = signal*.7+rumble*.6+body_noise*.8*np.exp(-t*8)
    elif name in ['ex','power']:
        charge = np.sin(2*np.pi*(base*t+800*t*t))*np.sin(np.pi*phase)**1.4
        signal = charge*.6+high_noise*.1*np.sin(np.pi*phase)
    if name == 'hit_heavy': signal += .28*np.sin(2*np.pi*43*t)*np.exp(-t*12)
    # Short fades remove clicks at file boundaries; each clip has headroom.
    signal *= np.minimum(1,t/.002)*np.minimum(1,(duration-t)/.018)
    signal = np.tanh(signal*1.8)
    signal *= .82/max(float(np.max(np.abs(signal))),.001)
    delay = np.concatenate([np.zeros(53),signal[:-53]])
    stereo = np.column_stack([signal,.94*signal+.06*delay])
    return np.round(np.clip(stereo,-.95,.95)*32767).astype('<i2')


def main():
    ROOT.mkdir(parents=True,exist_ok=True)
    report = {'type':'original procedural audio','sample_rate':RATE,'clips':{}}
    with tempfile.TemporaryDirectory() as work:
        for name,spec in SPECS.items():
            pcm=make(name,*spec)
            wav=Path(work)/f'{name}.wav'
            with wave.open(str(wav),'wb') as output:
                output.setnchannels(2);output.setsampwidth(2);output.setframerate(RATE);output.writeframes(pcm.tobytes())
            target=ROOT/f'{name}.ogg'
            subprocess.run(['ffmpeg','-nostdin','-y','-v','error','-i',str(wav),'-c:a','libvorbis','-q:a','5',str(target)],check=True)
            report['clips'][name]={'duration':spec[0],'peak':float(np.abs(pcm.astype(float)).max()/32767),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    (ROOT/'manifest.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Generated {len(SPECS)} original combat clips')

if __name__=='__main__': main()
