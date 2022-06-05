module               = 'MODULE' sp+ name:ident ';' sp+ importlist? sp* declarationsequence sp*
                       ('BEGIN' sp+ statementsequence)? sp* 'END' sp+ ident sp* '.' sp* { return name }
declarationsequence  = ('CONST' sp+ (constdeclaration sp* ';' sp*)*)?
                       ('TYPE' sp+ (typedeclaration sp* ';' sp* )*)?
                       ('VAR' sp+ (variabledeclaration sp* ';' sp*)*)?
                       (proceduredeclaration ';' sp*)*
importlist           = 'IMPORT' sp* import sp* ("," sp* import)* sp* ';'
import               = ident sp* (':=' sp* ident)?
statementsequence    = statement (sp* ';' sp* statement)*
statement            = (assignment / procedurecall / ifstatement /
                        casestatement / whilestatement / repeatstatement /
                        forstatement)?
constdeclaration     = identdef sp* '=' sp* constexpression
constexpression      = expression
typedeclaration      = identdef sp* '=' sp* structype
variabledeclaration  = identlist ':' sp* type
identlist            = identdef (sp* ',' sp* identdef)*
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
assignment        = designator sp* ':=' sp* expression
designator        = qualident selector*
qualident         = ident '.' qualident / ident
selector          = '.' ident / '[' explist ']' / '^' / '(' qualident ')'
explist           = expression (sp* ',' sp* expression)*
relation          = '=' / '#' / '<=' / '<' / '>=' / '>' / 'IN' / 'IS'
expression        = simpleexpression (sp* relation sp* simpleexpression)?
simpleexpression  = ('+' / '-')? term sp* (addoperator sp* term sp*)*
addoperator       = '+' / '-' / 'OR'
muloperator       = '*' / '/' / 'DIV' / 'MOD' / '&'
term              = factor (sp* muloperator sp* factor)*
factor            = number / string / 'NIL' / 'TRUE' / 'FALSE' /
                    set / designator actualparameters? / '(' expression ')' / '~' factor
actualparameters  = '(' sp* explist? sp* ')'
formalparameters  = '(' (fpsection sp* (';' sp* fpsection)*)? sp* ')' sp* (':' sp* qualident)?
fpsection         = 'VAR'? sp* ident sp* (',' sp* ident)* sp* ':' sp* formaltype
formaltype        = ('ARRAY OF' sp*)* qualident
set               = '{' sp* (element sp* (sp* ',' sp* element)*)? '}'
element           = expression (sp* '..' sp* expression)*
string            = '"' (!'"' character)+ '"' / digit hexdigit? 'X'
number            = real / integer
integer           = digit hexdigit* 'H' / digit+
real              = digit+ '.' digit+ scalefactor?
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
