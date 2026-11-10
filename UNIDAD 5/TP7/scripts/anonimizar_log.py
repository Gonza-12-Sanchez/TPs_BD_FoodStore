"""Sanitización del laboratorio. Revisar manualmente antes de compartir otros logs."""
import re

def anonimizar(texto, secretos=()):
    for secreto in sorted((s for s in secretos if s),key=len,reverse=True):
        texto=texto.replace(secreto,'<CLAVE_OCULTA>')
    texto=re.sub(r'Clave(?:DePruebaU5|Incorrecta\d+|NuevaLaboratorio|Corta)[^\s\x27\x22,)]*',
                 '<CLAVE_OCULTA>',texto)
    cuentas={}
    def cuenta(m):
        valor=m.group(0)
        if valor not in cuentas: cuentas[valor]=f'cuenta{len(cuentas)+1:03}@ejemplo.test'
        return cuentas[valor]
    texto=re.sub(r'[\w.+-]+@[\w.-]+\.[A-Za-z]{2,}',cuenta,texto)
    texto=texto.replace('127.0.0.1','192.0.2.10').replace('::1','2001:db8::10')
    texto=re.sub(r'PersonaDemo\d+','PersonaSintetica',texto)
    texto=re.sub(r'ApellidoDemo\d+','ApellidoSintetico',texto)
    texto=re.sub(r'TEL_DEMO_\d+','<TELEFONO_OCULTO>',texto)
    texto=re.sub(r'\$2[aby]\$\d\d\$[./A-Za-z0-9]{53}','<HASH_OCULTO>',texto)
    return texto

if __name__=='__main__':
    import argparse
    from pathlib import Path
    p=argparse.ArgumentParser();p.add_argument('entrada');p.add_argument('salida')
    a=p.parse_args()
    Path(a.salida).write_text(anonimizar(Path(a.entrada).read_text()),encoding='utf-8')
