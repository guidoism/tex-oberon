module               = 'MODULE' sp+ name:ident ';' sp+ imports:importlist? sp* declarations:declarationsequence sp*
                       statements:('BEGIN' sp+ statementsequence)? sp* 'END' sp+ ident sp* '.' sp*
{
  statements = statements[2]
  return `\\input cwebmac \\B
\\&{module} \\\\{${name}} \\1\\6
${declarations}

\\&{begin}\\6
${statements}
\\2\\6
\\&{end} \\\\{${name}}.
\\bye
`
}

declarationsequence  = consts:('CONST' sp+ (constdeclaration sp* ';' sp*)*)?
                       types:('TYPE' sp+ (typedeclaration sp* ';' sp* )*)?
                       vars:('VAR' sp+ (variabledeclaration sp* ';' sp*)*)?
                       procs:(proceduredeclaration ';' sp*)*
{
  let newline = (a, i) => {
    if (a.length == 1) return ';\\6\n'
    if (a.length == i+1) return ';\\2\\6\n' // dedent after last
    if (i == 0) return ';\\1\\6\n' // indent after first
    return ';\\6\n'
  }
  let ret = []

  if (consts) {
    consts = consts[2].map(x => x[0])
    console.warn('consts:', consts)
    ret.push('\\&{const} \\1 ' + consts.join(';\\5') + ';\\2\\6')
  }

  if (types) {
    let s = ''
    types.shift() // TYPE keyword
    types.shift() // space
    types = types[0]
    types = types.map(v => v[0])
    if (types.length == 2) {
      s = '\\&{type} ' +
          types[0] + newline(types, 0) +
          types[1] + newline(types, 1)
    }
    else if (types.length > 2) {
      s = '\\&{type} ' +
          types[0] + newline(types, 0) +
          types.slice(1, -1).map(s => s + newline(types, 1)).join('') +
          types[types.length-1] + newline(types, types.length-1)
    }
    else {
      s = '\\&{type} ' + types[0] + ';\\6'
    }
    ret.push(s.trim())
  }
  if (vars) {
    vars.shift() // VAR keyword
    vars.shift() // space
    vars = vars[0]
    vars = vars.map(v => v[0])
    if (vars.length == 2) {
      ret.push('\\&{var} ' +
               vars[0] + newline(vars, 0) +
               vars[1] + newline(vars, 1))
    }
    else if (vars.length > 2) {
      ret.push('\\&{var} ' +
               vars[0] + newline(vars, 0) +
               vars.slice(1, -1).map(s => s + newline(vars, 1)).join('') +
               vars[vars.length-1] + newline(vars, vars.length-1))
    }
    else {
      ret.push('\\&{var} ' + vars[0] + ';\n')
    }
  }
  if (procs) {
    ret.push(procs.map(x => x[0]).join(';\\6\n'))
  }
  return ret.join('\n')
}

importlist           = 'IMPORT' sp* import sp* ("," sp* import)* sp* ';'
import               = ident sp* (':=' sp* ident)?
statementsequence    = head:statement tail:(sp* ';' sp* statement)*
{
  tail = tail.map(s => s[3])
  return [head].concat(tail).join(';\\6\n')
}

statement            = (assignment / procedurecall / ifstatement /
                        casestatement / whilestatement / repeatstatement /
                        forstatement)?
constdeclaration     = a:identdef sp* '=' sp* b:constexpression
{
  return a + ' = ' + b
}

constexpression      = expression
typedeclaration      = i:identdef sp* '=' sp* t:structype
{
  return `${i} = ${t}`
}

variabledeclaration  = i:identlist ':' sp* t:type
{
  return `${i}: ${t}`
}

identlist            = head:identdef tail:(sp* ',' sp* identdef)*
{
  // TODO: I think we still need to deal with the optional '*'
  let all = [head].concat(tail.map(o => o[3]))
  return all.join(', ')
}

identdef             = i:(ident '*'?)
{
  // TODO: Add * for export
  return i[0]
}

type                 = structype / qualident
structype            = arraytype / recordtype / pointertype / proceduretype
arraytype            = 'ARRAY' sp* head:length tail:(sp* ',' sp* length)* sp* 'OF' sp+ type:type
{
  console.warn('arraytype:', head)
  let size = (tail.length > 0) ? [head].concat(tail).join(', ') : head
  return '\\&{array} ' + size + ' \\&{of} ' + type
}

length               = constexpression
recordtype           = 'RECORD' sp* base:('(' sp* basetype sp* ')')? sp* fields:fieldlistsequence? sp* 'END'
{
  let parts = ['\\&{record}']
  if (base) parts.push(' (' + base[2] + ') ')
  if (fields) parts.push(fields.join('; '))
  parts.push('\\&{end}')
  return parts.join(' ')
}

pointertype          = 'POINTER TO' sp* t:type
{
  return '\\&{pointer to} ' + t
}

proceduretype        = 'PROCEDURE' sp* formalparameters?
proceduredeclaration = a:procedureheading sp* ';' sp* b:procedurebody sp* c:ident
{
  // TODO: body
  //return a + '; ' + b + c
  //console.warn('proceduredeclaration', a)
  return a
}

procedureheading     = 'PROCEDURE' sp* a:identdef sp* b:formalparameters?
{
  if (b) console.warn('procedureheading:', b)
  if (b) return '\\&{procedure} ' + a + b
  return '\\&{procedure} ' + a
}

procedurebody        = declarationsequence ('BEGIN' sp* statementsequence)?
                       sp* ('RETURN' sp* expression)? sp* 'END'
procedurecall        = designator sp* actualparameters?
ifstatement          = 'IF' sp* expression sp* 'THEN' sp* statementsequence 
                       (sp* 'ELSIF' sp* expression sp* 'THEN' sp* statementsequence)*
                       (sp* 'ELSE' sp* statementsequence)? sp* 'END'
casestatement        = 'CASE' sp* expression sp* 'OF' sp* case (sp* "|" sp* case sp*)* 'END'
case                 = (caselabellist ':' statementsequence)?
caselabellist        = labelrange (sp* ',' sp* labelrange)*
labelrange           = label (sp* ".." sp* label)?
label                = integer / string / qualident
whilestatement       = 'WHILE' sp* expression sp* 'DO' sp* statementsequence
                       ('ELSIF' sp* expression sp* 'DO' sp* statementsequence)* sp* 'END' sp*
repeatstatement      = 'REPEAT' sp* statementsequence sp* 'UNTIL' sp* expression
forstatement         = 'FOR' sp* ident sp* ':=' sp* expression sp* 'TO' sp* expression sp*
                       ('BY' sp* constexpression)? sp* 'DO' sp* statementsequence sp* 'END'
fieldlistsequence    = head:fieldlist tail:(sp* ';' sp* fieldlist sp*)*
{
  if (tail.length > 0) {
    tail = tail[0][3]
    return [head].concat(tail)
  }
  return [head]
}

fieldlist            = a:identlist sp* ':' sp* b:type
{
  return a + ' : ' + b
}

basetype          = qualident
assignment        = a:designator sp* ':=' sp* b:expression
{
  // TODO: Make sure designator with qualident and selector works properly
  return `${a[0]} \\K\\ ${b}`
}

designator        = a:qualident b:selector*
{
  if (b) return a + b
  return a
}

qualident         = s:(ident '.' qualident / ident)
{
  if (typeof s === 'object') { s = s.join('') }
  return s
}


selector          = '.' ident / '[' explist ']' / '^' / '(' qualident ')'
explist           = expression (sp* ',' sp* expression)*
relation          = '=' / '#' / '<=' / '<' / '>=' / '>' / 'IN' / 'IS'
expression        = head:simpleexpression tail:(sp* relation sp* simpleexpression)?
{
  //console.warn('expression:', head)
  // TODO: tail
  return head
}


simpleexpression  = ('+' / '-')? head:term sp* tail:(addoperator sp* term sp*)*
{
  // TODO: +/-
  // TODO: tail
  return head
}

addoperator       = '+' / '-' / 'OR'
muloperator       = '*' / '/' / 'DIV' / 'MOD' / '&'
term              = head:factor (sp* muloperator sp* factor)*
{
  return head
}


factor            = hexascii / number / string / 'NIL' / 'TRUE' / 'FALSE' /
                    set / designatorwithparams / '(' expression ')' / '~' factor
designatorwithparams = a:designator b:actualparameters?
{
  return a
}

actualparameters  = '(' sp* explist? sp* ')'
formalparameters  = '(' a:(fpsection sp* (';' sp* fpsection)*)? sp* ')' sp* b:(':' sp* qualident)?
{
  let parts = ['(']
  console.warn('formalparameters(a):', a)
  if (a) {
    let params = [a[0]]
    if (a[2].length > 0) params = params.concat(a[2].map(x => x[2]))
    console.warn('formalparameters:', params)
    parts.push(params.join(', '))
  }
  parts.push(')')
  if (b) parts.push(' : ' + b[2])
  return parts.join('')
}

fpsection         = v:'VAR'? sp* idents:ident sp* tail:(',' sp* ident)* sp* ':' sp* t:formaltype
{
  v = v ? '\\&{var} ' : ''
  if (tail) idents = [idents].concat(tail)
  return v + idents.join(', ') + ' : ' + t
}

formaltype        = a:('ARRAY OF' sp*)* b:qualident
{
  if (a) return '\\&{array of} ' + b
  return b
}

set               = '{' sp* s:(element sp* (sp* ',' sp* element)*)? '}'
{
  let head = s[0]
  let tail = s[2].map(c => c[3])
  let list = [head].concat(tail)
  let ret = ' $\\lbrace ' + list.join(', ') + ' \\rbrace$ '
  return ret
}

element           = head:expression tail:(sp* '..' sp* expression)*
{
  // TODO: a..b syntax
  return head
}

hexascii          = a:digit b:hexdigit? 'X'

string            = s:('"' (!'"' character)+ '"')
{
  return '\\.{"' + s[1].map(c => c[1]).join('') + '"}'
}

number            = n:(real / integer)
{
  return '\\T{' + n + '}'
}

integer           = digit hexdigit* 'H' / digits:digit+
{
  return digits.join('')
}

real              = whole:digit+ '.' part:digit+ scale:scalefactor?
{
  TODO: scale
  return whole.join('') + '.' + part.join('')
}

scalefactor       = 'E' ('+' / '-')? digit+
ident             = s:(!keyword alpha alphanum*)
{
  let allcaps = x => (x.toUpperCase() === x)
  s.shift() // Discard negative rule
  s = [s[0]].concat(s[1]).join('')
  if (allcaps(s))
    s = '\\.{' + s + '}'
  else
    s = '\\\\{' + s + '}'
  return s
}



alpha             = [a-zA-Z]
digit             = [0-9]
hexdigit          = [0-9a-fA-F]
alphanum          = alpha / digit
character         = [\x20-\uFFFF]
sp                = [ \t\r\n\f] / comment
comment           = '(*' (!'*)' character)* '*)'
keyword           = 'ARRAY' / 'IMPORT' / 'RETURN' / 'BEGIN' / 'THEN' / 'BY' / 'IS' / 'TO' / 'CASE' / 'LOOP' / 'TYPE' / 'DIV' / 'MODULE' / 'VAR' / 'DO' / 'NIL' / 'WHILE' / 'ELSE' / 'OF' / 'WITH' / 'ELSIF' / 'END' / 'POINTER' / 'EXIT' / 'PROCEDURE' / 'FOR' / 'RECORD' / 'IF' / 'REPEAT' / 'UNTIL'
