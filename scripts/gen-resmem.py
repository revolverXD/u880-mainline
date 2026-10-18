# Emit a reserved-memory node (fixed-reg regions only, all no-map) from a decompiled live DT.
import re,sys
lines=open(sys.argv[1]).read().split('\n')
s=next(i for i,l in enumerate(lines) if re.match(r'\treserved_memory: reserved-memory \{|\treserved-memory \{',l))
out=[];name=None;reg=None
for l in lines[s+1:]:
    if l=='\t};': break
    m=re.match(r'^\t\t(?:[\w]+: )?([\w,.@-]+) \{$',l)
    if m: name=m.group(1);reg=None;continue
    m=re.match(r'^\t\t\treg = (<[^>]*>);',l)
    if m and name: reg=m.group(1)
    if l=='\t\t};' and name:
        if reg and reg!='<0x00 0x00 0x00 0x00>':
            out.append(f'\t\t{name.replace(",","-")} {{\n\t\t\treg = {reg};\n\t\t\tno-map;\n\t\t}};')
        name=None
print('\treserved_memory: reserved-memory {\n\t\t#address-cells = <2>;\n\t\t#size-cells = <2>;\n\t\tranges;\n')
print('\n'.join(out)); print('\t};')
print(f'// {len(out)} regions',file=sys.stderr)
