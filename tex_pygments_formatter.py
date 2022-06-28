from pygments.formatter import Formatter
from pygments.token import Token
import re, sys

def p(s):
    print(s, file=sys.stderr)

# \&{begin}
# \\{SYSTEM}
# \|{i}
    
class CWEBTexFormatter(Formatter):
    def format(self, tokensource, outfile):
        tokensource = list(tokensource)
        open('/tmp/tokens.txt', 'w').write('\n'.join([f'{k}: {repr(v)}' for k, v in tokensource]))
        outfile.write('\\input cwebmac\n'.encode())
        outfile.write('\\parindent=0cm\n'.encode())
        outfile.write('\\B\n'.encode())
        for ttype, value in tokensource:
            #outfile.write(f'{ttype}:{value}\n'.encode())
            if ttype == Token.Keyword.Reserved:
                outfile.write(('\\&{' + value.lower() + '}').encode())
            elif ttype == Token.Name.Builtin:
                outfile.write(('\\.{' + value + '}').encode())
            elif ttype == Token.Name.Builtin.Pseudo:
                outfile.write(('\\.{' + value + '}').encode())
            elif ttype == Token.Name:
                if value.upper() == value:
                    outfile.write(('\\.{' + value + '}').encode())
                else:
                    outfile.write(('\\\\{' + value + '}').encode())
            elif ttype == Token.Text and re.match(r'\s+', value):
                if value == '\n\n':
                    value = '\\7\n'
                elif value == '\n':
                    value = '\\6\n'
                #value = value.replace(' ', '\\ ')
                outfile.write(value.encode())
                #print(repr(value).encode(), file=sys.stderr)
            elif ttype == Token.Operator and value == '&':
                outfile.write('\\land\ '.encode())
            elif ttype == Token.Operator and value == '#':
                outfile.write('\\ne\ '.encode())
            elif ttype == Token.Operator and value == ':=':
                outfile.write('\\K\ '.encode())
            elif ttype == Token.Comment.Multiline:
                outfile.write(value.replace('&', ' and ').encode())
            else:
                p(f'{value} ({ttype})')
                outfile.write(value.encode())
            
        outfile.write('\\bye\n'.encode())


        
