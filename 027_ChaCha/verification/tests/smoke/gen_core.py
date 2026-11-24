import sys, random
import os
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'models'))
import chacha20poly1305_ref as m
def beats(b, W):
    out=[]
    for i in range(0,len(b),W):
        out.append(int.from_bytes(b[i:i+W],'little'))
    return out
def gen(name, DW, key, nonce, aad, msg, decrypt, badtag=False):
    W=DW//8
    ct,tag=m.aead_encrypt(key,nonce,aad,msg)
    if decrypt:
        t=bytearray(tag)
        if badtag: t[3]^=0x10
        inp = beats(aad,W)+beats(ct,W)+beats(bytes(t),W)
        out = beats(msg,W) if not badtag else beats(msg,W)
    else:
        inp = beats(aad,W)+beats(msg,W)
        out = beats(ct,W)+beats(tag,W)
    fmt='%0'+str(DW//4)+'x\n'
    open(name+'_in.hex','w').write(''.join(fmt%x for x in inp))
    open(name+'_out.hex','w').write(''.join(fmt%x for x in out))
    return len(inp),len(out)
if __name__=='__main__':
    hx=bytes.fromhex
    key=bytes(range(0x80,0xA0)); nonce=hx("070000004041424344454647"); aad=hx("50515253c0c1c2c3c4c5c6c7")
    pt=(b"Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it.")
    open('key.hex','w').write('%064x\n'%int.from_bytes(key,'little'))
    open('nonce.hex','w').write('%024x\n'%int.from_bytes(nonce,'little'))
    for DW in (32,64,128,256):
        print(DW,'enc',gen('enc%d'%DW,DW,key,nonce,aad,pt,False),'dec',gen('dec%d'%DW,DW,key,nonce,aad,pt,True),'bad',gen('bad%d'%DW,DW,key,nonce,aad,pt,True,True))
    # random messages for DW=64
    random.seed(11)
    for i,(a,mm) in enumerate([(0,0),(0,1),(1,0),(16,16),(17,63),(0,64),(5,65),(130,200),(0,127),(12,1280)]):
        A=bytes(random.getrandbits(8) for _ in range(a)); M=bytes(random.getrandbits(8) for _ in range(mm))
        r=gen('r%d_enc'%i,64,key,nonce,A,M,False); r2=gen('r%d_dec'%i,64,key,nonce,A,M,True)
        open('r%d.len'%i,'w').write('%d %d\n'%(a,mm))
        print(i,a,mm,r,r2)
