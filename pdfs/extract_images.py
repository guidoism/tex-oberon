import fitz, io
done = set()
f = fitz.open('PO.System.pdf')
for p in f:
    #print(p)
    for i in p.get_images():
        xref = i[0]
        if xref not in done:
            done.add(xref)
            d = f.extract_image(xref)
            ext = d['ext']
            img = open(f'image.{xref}.{ext}', 'wb')
            img.write(d['image'])
            img.close()
