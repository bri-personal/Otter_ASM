def byte_color(r_in, g_in, b_in):
    res=0
    
    r = round(r_in/0xFF*0xF)
    g = round(g_in/0xFF*0xF)
    b = round(b_in/0xFF*0xF)
    
    r2 = r&3
    if r2>=2:
        res+=(r&0xE)<<4
    else:
        res+=(r&0xC)<<4
        
    g2 = g&3
    if g2>=2:
        res+=(g&0xE)<<1
    else:
        res+=(g&0xC)<<1
        
    # b can be 0, 3, 12, 15
    if b>13.5:
        res+=3 #binary 11
    elif b>7.5:
        res+=2 #binary 10
    elif b>1.5:
        res+=1 #binary 01
    # else b is 0, no change
    return res


r = 0xfd
g = 0xd0
b = 0x17
res=byte_color(r,g,b)
print(res)