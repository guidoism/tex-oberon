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

declarationsequence  = ('CONST' sp+ (constdeclaration sp* ';' sp*)*)?
                       ('TYPE' sp+ (typedeclaration sp* ';' sp* )*)?
                       vars:('VAR' sp+ (variabledeclaration sp* ';' sp*)*)?
                       (proceduredeclaration ';' sp*)*
{
  vars = vars[2].map(v => v[0])
  let last = vars.length - 1
  vars = vars.map((v, i) => (v + (i == 0 ? '\\1\\6' : (i > 0 && i == last ? '\\2\\6' : '\\6'))))
  vars = '\\&{vars} ' + vars.join('\n')
  return [vars].join('\n')
}

importlist           = 'IMPORT' sp* import sp* ("," sp* import)* sp* ';'
import               = ident sp* (':=' sp* ident)?
statementsequence    = head:statement tail:(sp* ';' sp* statement)*
{
  //console.warn('tail: ', tail)
  return head
}

statement            = (assignment / procedurecall / ifstatement /
                        casestatement / whilestatement / repeatstatement /
                        forstatement)?
constdeclaration     = identdef sp* '=' sp* constexpression
constexpression      = expression
typedeclaration      = identdef sp* '=' sp* structype
variabledeclaration  = i:identlist ':' sp* t:type
{
  i = i.map(j => `\\\\{${j[0]}}`).join(', ')
  if (t.toUpperCase() === t) { t = `\\.{${t}}` }
  return `${i}: ${t}`
}

identlist            = head:identdef tail:(sp* ',' sp* identdef)*
{
  // TODO: I think we still need to deal with the optional '*'
  return [head[0]].concat(tail.map(o => o[3][0]))
}

identdef             = ident '*'?
type                 = structype / qualident
structype            = arraytype / recordtype / pointertype / proceduretype
arraytype            = 'ARRAY' sp* length (sp* ',' sp* length)* sp* 'OF' sp+ type
length               = constexpression
recordtype           = 'RECORD' sp* ('(' sp* basetype sp* ')')? sp* fieldlistsequence? sp* 'END'
pointertype          = 'POINTER' sp* 'TO' sp* type
proceduretype        = 'PROCEDURE' sp* formalparameters?
proceduredeclaration = procedureheading sp* ';' sp* procedurebody sp* ident
procedureheading     = 'PROCEDURE' sp* identdef sp* formalparameters?
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
fieldlistsequence    = fieldlist (sp* ';' sp* fieldlist sp*)*
fieldlist            = identlist sp* ':' sp* type
basetype          = qualident
assignment        = a:designator sp* ':=' sp* b:expression
{
  // TODO: Make sure designator with qualident and selector works properly
  //console.warn(b)
  return `${a[0]} \\K ${b}`
}

designator        = qualident selector*
qualident         = ident '.' qualident / ident
selector          = '.' ident / '[' explist ']' / '^' / '(' qualident ')'
explist           = expression (sp* ',' sp* expression)*
relation          = '=' / '#' / '<=' / '<' / '>=' / '>' / 'IN' / 'IS'
expression        = simpleexpression (sp* relation sp* simpleexpression)?
simpleexpression  = ('+' / '-')? term sp* (addoperator sp* term sp*)*
addoperator       = '+' / '-' / 'OR'
muloperator       = '*' / '/' / 'DIV' / 'MOD' / '&'
term              = head:factor (sp* muloperator sp* factor)*
{
  console.warn('term:', head)
}


factor            = a:(number / string / 'NIL' / 'TRUE' / 'FALSE' /
                    set / designator actualparameters? / '(' expression ')' / '~' factor)
actualparameters  = '(' sp* explist? sp* ')'
formalparameters  = '(' (fpsection sp* (';' sp* fpsection)*)? sp* ')' sp* (':' sp* qualident)?
fpsection         = 'VAR'? sp* ident sp* (',' sp* ident)* sp* ':' sp* formaltype
formaltype        = ('ARRAY OF' sp*)* qualident
set               = '{' sp* (element sp* (sp* ',' sp* element)*)? '}'
element           = expression (sp* '..' sp* expression)*
string            = '"' inside:(!'"' character)+ '"' / digit hexdigit? 'X'
{
  console.warn('string:', inside)
  return inside
}

number            = real / integer
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
ident             = !keyword head:alpha tail:alphanum* { return head + tail.join('') }
alpha             = [a-zA-Z]
digit             = [0-9]
hexdigit          = [0-9a-fA-F]
alphanum          = alpha / digit
character         = [\x20-\uFFFF]
sp                = [ \t\r\n\f] / comment
comment           = '(*' (!'*)' character)* '*)'
keyword           = 'ARRAY' / 'IMPORT' / 'RETURN' / 'BEGIN' / 'THEN' / 'BY' / 'IS' / 'TO' / 'CASE' / 'LOOP' / 'TYPE' / 'DIV' / 'MODULE' / 'VAR' / 'DO' / 'NIL' / 'WHILE' / 'ELSE' / 'OF' / 'WITH' / 'ELSIF' / 'END' / 'POINTER' / 'EXIT' / 'PROCEDURE' / 'FOR' / 'RECORD' / 'IF' / 'REPEAT' / 'UNTIL'
