all:
	luatex oberon.tex
	open oberon.pdf


format:
	pegjs -o parser.js grammar.pegjs
	cat parser.js parser_stub.js > parser_highlighter.js
	node parser_highlighter.js patterns/01.Mod 


formatpyg:
	pygmentize -f tex_pygments_formatter.py:CWEBTexFormatter -x -l modula2 src/Kernel.Mod > tmp/pyg.tex && luatex tmp/pyg.tex && open pyg.pdf





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




src-highlight.tex: 
	rm src.tex
	touch src.tex
	echo '\beginsubsection 18.1. VIEWERS.' >> src.tex
	highlight -S oberon -O tex -i src/Viewers.Mod >> src.tex
	echo '\beginsubsection 18.2. TEXTS.' >> src.tex
	highlight -S oberon -O tex -i src/Texts.Mod >> src.tex
	echo '\beginsubsection 18.3. OBERON.' >> src.tex
	highlight -S oberon -O tex -i src/Oberon.Mod >> src.tex
	echo '\beginsubsection 18.4. MODULES.' >> src.tex
	highlight -S oberon -O tex -i src/Modules.Mod >> src.tex
	echo '\beginsubsection 18.5. FILES.' >> src.tex
	highlight -S oberon -O tex -i src/Files.Mod >> src.tex
	echo '\beginsubsection 18.6. FILEDIR.' >> src.tex
	highlight -S oberon -O tex -i src/FileDir.Mod >> src.tex
	echo '\beginsubsection 18.7. KERNEL.' >> src.tex
	highlight -S oberon -O tex -i src/Kernel.Mod >> src.tex


	echo '\beginsubsection 18.. NET.' >> src.tex
	highlight -S oberon -O tex -i src/Net.Mod >> src.tex

	echo '\beginsubsection 18.. CURVES.' >> src.tex
	highlight -S oberon -O tex -i src/Curves.Mod >> src.tex
	echo '\beginsubsection 18.. DISPLAY.' >> src.tex
	highlight -S oberon -O tex -i src/Display.Mod >> src.tex
	echo '\beginsubsection 18.. DRAW.' >> src.tex
	highlight -S oberon -O tex -i src/Draw.Mod >> src.tex
	echo '\beginsubsection 18.. EDIT.' >> src.tex
	highlight -S oberon -O tex -i src/Edit.Mod >> src.tex
	echo '\beginsubsection 18.. FONTS.' >> src.tex
	highlight -S oberon -O tex -i src/Fonts.Mod >> src.tex
	echo '\beginsubsection 18.. GRAPHICFRAMES.' >> src.tex
	highlight -S oberon -O tex -i src/GraphicFrames.Mod >> src.tex
	echo '\beginsubsection 18.. GRAPHICS.' >> src.tex
	highlight -S oberon -O tex -i src/Graphics.Mod >> src.tex
	echo '\beginsubsection 18.. GRAPHTOOL.' >> src.tex
	highlight -S oberon -O tex -i src/GraphTool.Mod >> src.tex
	echo '\beginsubsection 18.. INPUT.' >> src.tex
	highlight -S oberon -O tex -i src/Input.Mod >> src.tex
	echo '\beginsubsection 18.. MENUVIEWERS.' >> src.tex
	highlight -S oberon -O tex -i src/MenuViewers.Mod >> src.tex
	echo '\beginsubsection 18.. ORB.' >> src.tex
	highlight -S oberon -O tex -i src/ORB.Mod >> src.tex
	echo '\beginsubsection 18.. ORG.' >> src.tex
	highlight -S oberon -O tex -i src/ORG.Mod >> src.tex
	echo '\beginsubsection 18.. ORP.' >> src.tex
	highlight -S oberon -O tex -i src/ORP.Mod >> src.tex
	echo '\beginsubsection 18.. ORS.' >> src.tex
	highlight -S oberon -O tex -i src/ORS.Mod >> src.tex
	echo '\beginsubsection 18.. ORTOOL.' >> src.tex
	highlight -S oberon -O tex -i src/ORTool.Mod >> src.tex
	echo '\beginsubsection 18.. RECTANGLES.' >> src.tex
	highlight -S oberon -O tex -i src/Rectangles.Mod >> src.tex
	echo '\beginsubsection 18.. SCC.' >> src.tex
	highlight -S oberon -O tex -i src/SCC.Mod >> src.tex
	echo '\beginsubsection 18.. SYSTEM.' >> src.tex
	highlight -S oberon -O tex -i src/System.Mod >> src.tex
	echo '\beginsubsection 18.. TEXTFRAMES.' >> src.tex
	highlight -S oberon -O tex -i src/TextFrames.Mod >> src.tex

