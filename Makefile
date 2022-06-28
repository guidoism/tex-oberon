all:
	luatex oberon.tex
	open oberon.pdf


format:
	pegjs -o parser.js grammar.pegjs
	cat parser.js parser_stub.js > parser_highlighter.js
	#node parser_highlighter.js patterns/fmt_test_01.Mod > aaa.tex
	node parser_highlighter.js src/Kernel.Mod > aaa.tex
	cat aaa.tex
	luatex aaa
	open aaa.pdf


formatpyg:
	pygmentize -f tex_pygments_formatter.py:CWEBTexFormatter -x -l modula2 src/Kernel.Mod > tmp/pyg.tex && luatex tmp/pyg.tex && open pyg.pdf

.PHONY ptop:
ptop:
	mkdir -p ptop-src
	ptop -c ptop.cfg src/Curves.Mod ptop-src/Curves.Mod
	ptop -c ptop.cfg src/Display.Mod ptop-src/Display.Mod
	ptop -c ptop.cfg src/Draw.Mod ptop-src/Draw.Mod
	ptop -c ptop.cfg src/Edit.Mod ptop-src/Edit.Mod
	ptop -c ptop.cfg src/FileDir.Mod ptop-src/FileDir.Mod
	ptop -c ptop.cfg src/Files.Mod ptop-src/Files.Mod
	ptop -c ptop.cfg src/Fonts.Mod ptop-src/Fonts.Mod
	ptop -c ptop.cfg src/GraphicFrames.Mod ptop-src/GraphicFrames.Mod
	ptop -c ptop.cfg src/Graphics.Mod ptop-src/Graphics.Mod
	ptop -c ptop.cfg src/GraphTool.Mod ptop-src/GraphTool.Mod
	ptop -c ptop.cfg src/Input.Mod ptop-src/Input.Mod
	ptop -c ptop.cfg src/Kernel.Mod ptop-src/Kernel.Mod
	ptop -c ptop.cfg src/MenuViewers.Mod ptop-src/MenuViewers.Mod
	ptop -c ptop.cfg src/Modules.Mod ptop-src/Modules.Mod
	ptop -c ptop.cfg src/Net.Mod ptop-src/Net.Mod
	ptop -c ptop.cfg src/Oberon.Mod ptop-src/Oberon.Mod
	ptop -c ptop.cfg src/ORB.Mod ptop-src/ORB.Mod
	ptop -c ptop.cfg src/ORG.Mod ptop-src/ORG.Mod
	ptop -c ptop.cfg src/ORP.Mod ptop-src/ORP.Mod
	ptop -c ptop.cfg src/ORS.Mod ptop-src/ORS.Mod
	ptop -c ptop.cfg src/ORTool.Mod ptop-src/ORTool.Mod
	ptop -c ptop.cfg src/Rectangles.Mod ptop-src/Rectangles.Mod
	ptop -c ptop.cfg src/SCC.Mod ptop-src/SCC.Mod
	ptop -c ptop.cfg src/System.Mod ptop-src/System.Mod
	ptop -c ptop.cfg src/TextFrames.Mod ptop-src/TextFrames.Mod
	ptop -c ptop.cfg src/Texts.Mod ptop-src/Texts.Mod
	ptop -c ptop.cfg src/Viewers.Mod ptop-src/Viewers.Mod

.PHONY sourcecode:
sourcecode: 
	-rm src.tex
	touch src.tex
	echo '\\beginsubsection 18.1. VIEWERS.' >> src.tex
	echo '\\begintt ' >> src.tex
	cat src/Viewers.Mod >> src.tex
	echo '\\endtt ' >> src.tex

	echo '\\beginsubsection 18.2. TEXTS.' >> src.tex
	echo '\\begintt ' >> src.tex
	cat src/Texts.Mod >> src.tex
	echo '\\endtt ' >> src.tex

	echo '\\eject' >> src.tex
	echo '\\beginsubsection 18.2. DISPLAY.' >> src.tex
	echo '\\begintt ' >> src.tex
	cat src/Display.Mod >> src.tex
	echo '\\endtt ' >> src.tex




src-highlight.tex: ptop
	rm src.tex
	touch src.tex
	echo '\beginsubsection 18.1. VIEWERS.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Viewers.Mod >> src.tex
	echo '\beginsubsection 18.2. TEXTS.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Texts.Mod >> src.tex
	echo '\beginsubsection 18.3. OBERON.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Oberon.Mod >> src.tex
	echo '\beginsubsection 18.4. MODULES.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Modules.Mod >> src.tex
	echo '\beginsubsection 18.5. FILES.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Files.Mod >> src.tex
	echo '\beginsubsection 18.6. FILEDIR.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/FileDir.Mod >> src.tex
	echo '\beginsubsection 18.7. KERNEL.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Kernel.Mod >> src.tex


	echo '\beginsubsection 18.. NET.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Net.Mod >> src.tex

	echo '\beginsubsection 18.. CURVES.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Curves.Mod >> src.tex
	echo '\beginsubsection 18.. DISPLAY.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Display.Mod >> src.tex
	echo '\beginsubsection 18.. DRAW.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Draw.Mod >> src.tex
	echo '\beginsubsection 18.. EDIT.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Edit.Mod >> src.tex
	echo '\beginsubsection 18.. FONTS.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Fonts.Mod >> src.tex
	echo '\beginsubsection 18.. GRAPHICFRAMES.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/GraphicFrames.Mod >> src.tex
	echo '\beginsubsection 18.. GRAPHICS.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Graphics.Mod >> src.tex
	echo '\beginsubsection 18.. GRAPHTOOL.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/GraphTool.Mod >> src.tex
	echo '\beginsubsection 18.. INPUT.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Input.Mod >> src.tex
	echo '\beginsubsection 18.. MENUVIEWERS.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/MenuViewers.Mod >> src.tex
	echo '\beginsubsection 18.. ORB.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/ORB.Mod >> src.tex
	echo '\beginsubsection 18.. ORG.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/ORG.Mod >> src.tex
	echo '\beginsubsection 18.. ORP.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/ORP.Mod >> src.tex
	echo '\beginsubsection 18.. ORS.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/ORS.Mod >> src.tex
	echo '\beginsubsection 18.. ORTOOL.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/ORTool.Mod >> src.tex
	echo '\beginsubsection 18.. RECTANGLES.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/Rectangles.Mod >> src.tex
	echo '\beginsubsection 18.. SCC.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/SCC.Mod >> src.tex
	echo '\beginsubsection 18.. SYSTEM.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/System.Mod >> src.tex
	echo '\beginsubsection 18.. TEXTFRAMES.' >> src.tex
	highlight -S oberon -O tex -i ptop-src/TextFrames.Mod >> src.tex
	luatex src
	open src.pdf
