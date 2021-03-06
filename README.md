# Project Oberon TeX Typesetting Project

Project Oberon is an amazing piece of computer science and amazing
tool for teaching. The book and the code demonstrate, without any tiny
amount of doubt, that it is possible to build a usable computing
system small enough to fit in the head of a normal programmer. That,
in my not-so-humble opinion, is a truly great achievement and I am in
awe of Niklaus Wirth and Jürg Gutknecht for it.

The last edition -- from 2013 -- could use some tender loving care.
It should look beautiful.

This project is an attempt to:

0. Liberate the text from the un-editable PDF sources.
1. Typeset the book using (plain) TeX and Knuth's own `taocpmac.tex` macros.
2. Add the full (typeset) source code to the book for those of us who like reading code in bed.
3. Convert it into a Literate Programming project where code is more liberally scattered amongst the prose and "tangled" into the final product.

Being a document with TeX sources, instead of a dead PDF, future
Project Oberon engineers will be able to modify the text to keep it
up-to-date with the running source code.

I have a dream that we -- as the Oberon community -- can edit and publish this
book. I would love for this to be printed as a nice hardcover that can sit
right next to my Art of Computer Programming books.

PDF and code taken from http://www.projectoberon.com

## Progress



- [x] Copy text / basic typesetting
- [x] First proofreading pass
- [ ] Second proofreading pass

## Building

    luatex oberon.tex

A recent in-progress PDF can be found in the Releases

## Quotes

The requirement of many megabytes of store for an operating system is, albeit commonly tolerated, absurd and another hallmark of user-unfriendliness, or perhaps manufacturer friendliness.


