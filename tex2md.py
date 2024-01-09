#!/bin/bash

# File name without extension
filename="oberon"

# Step 1: Convert TeX to XML
latexml --includestyles "$filename.tex" --preload=[bindings.sty.ltxml] --output="$filename.xml"

# Step 2: Convert XML to HTML
latexmlpost "$filename.xml" --format=html5 --destination="$filename.html"
