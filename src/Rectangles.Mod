MODULE Rectangles;  (*NW 25.2.90 / 18.4.2013*)
  IMPORT SYSTEM, Display, Files, Input, Texts, Oberon, Graphics, GraphicFrames;

  TYPE
    Rectangle* = POINTER TO RectDesc;
    RectDesc* = RECORD (Graphics.ObjectDesc)
        lw*, vers*: INTEGER
      END ;

  VAR method*: Graphics.Method;
    tack*, grey*: INTEGER;

  PROCEDURE New*;
    VAR r: Rectangle;
  BEGIN NEW(r); r.do := method; Graphics.New(r)
  END New;

  PROCEDURE Copy(src, dst: Graphics.Object);
  BEGIN dst.x := src.x; dst.y := src.y; dst.w := src.w; dst.h := src.h; dst.col := src.col;
    dst(Rectangle).lw := src(Rectangle).lw; dst(Rectangle).vers := src(Rectangle).vers
  END Copy;

  PROCEDURE mark(f: GraphicFrames.Frame; col, x, y: INTEGER);
  BEGIN GraphicFrames.ReplConst(f, col, x+1, y+1, 4, 4, 0)
  END mark;

  PROCEDURE Draw(obj: Graphics.Object; VAR M: Graphics.Msg);
    VAR x, y, w, h, lw, col: INTEGER; f: GraphicFrames.Frame;

    PROCEDURE draw(f: GraphicFrames.Frame; col, x, y, w, h, lw: INTEGER);
    BEGIN
      GraphicFrames.ReplConst(f, col, x, y, w, lw, Display.replace);
      GraphicFrames.ReplConst(f, col, x+w-lw, y, lw, h, Display.replace);
      GraphicFrames.ReplConst(f, col, x, y+h-lw, w, lw, Display.replace);
      GraphicFrames.ReplConst(f, col, x, y, lw, h, Display.replace)
    END draw;

  BEGIN
    CASE M OF GraphicFrames.DrawMsg:
      x := obj.x + M.x; y := obj.y + M.y; w := obj.w; h := obj.h; f := M.f;
      lw := obj(Rectangle).lw;
      IF (x < f.X1) & (x+w > f.X) & (y < f.Y1) & (y+h > f.Y) THEN
        IF M.col = Display.black THEN col := obj.col ELSE col := M.col END ;
        IF M.mode = 0 THEN
          draw(f, col, x, y, w, h, lw);
          IF obj.selected THEN mark(f, Display.white, x, y) END
        ELSIF M.mode = 1 THEN mark(f, Display.white, x, y)  (*normal -> selected*)
        ELSIF M.mode = 2 THEN mark(f, Display.black, x, y)   (*selected -> normal*)
        ELSIF M.mode = 3 THEN draw(f, Display.black, x, y, w, h, lw); mark(f, Display.black, x, y)  (*erase*)
        END
      END
    END
  END Draw;

  PROCEDURE Selectable(obj: Graphics.Object; x, y: INTEGER): BOOLEAN;
  BEGIN
    RETURN (obj.x <= x) & (x <= obj.x + 4) & (obj.y <= y) & (y <= obj.y + 4)
  END Selectable;

  PROCEDURE Change(obj: Graphics.Object; VAR M: Graphics.Msg);
    VAR x0, y0, x1, y1, dx, dy: INTEGER; k: SET;
  BEGIN
    CASE M OF
    Graphics.WidMsg: obj(Rectangle).lw := M.w |
    Graphics.ColorMsg: obj.col := M.col
    END
  END Change;

  PROCEDURE Read(obj: Graphics.Object; VAR R: Files.Rider; VAR C: Graphics.Context);
    VAR b: BYTE; len: INTEGER;
  BEGIN Files.ReadByte(R, b); (*len*);
    Files.ReadByte(R, b); obj(Rectangle).lw := b;
    Files.ReadByte(R, b); obj(Rectangle).vers := b;
  END Read;

  PROCEDURE Write(obj: Graphics.Object; cno: INTEGER; VAR W: Files.Rider; VAR C: Graphics.Context);
  BEGIN Graphics.WriteObj(W, cno, obj); Files.WriteByte(W, 2);
    Files.WriteByte(W, obj(Rectangle).lw); Files.WriteByte(W, obj(Rectangle).vers)
  END Write;

(* PROCEDURE Print(obj: Graphics.Object; x, y: INTEGER);
    VAR w, h, lw, s: INTEGER;
  BEGIN INC(x, obj.x * 4); INC(y, obj.y * 4); w := obj.w * 4; h := obj.h * 4;
    lw := obj(Rectangle).lw * 2; s := obj(Rectangle).vers;
    Printer.ReplConst(x, y, w, lw);
    Printer.ReplConst(x+w-lw, y, lw, h);
    Printer.ReplConst(x, y+h-lw, w, lw);
    Printer.ReplConst(x, y, lw, h);
    IF s > 0 THEN Printer.ReplPattern(x, y, w, h, s) END
  END Print; *)

  PROCEDURE Make*;  (*command*)
    VAR x0, x1, y0, y1: INTEGER;
      R: Rectangle;
      G: GraphicFrames.Frame;
  BEGIN G := GraphicFrames.Focus();
    IF (G # NIL) & (G.mark.next # NIL) THEN
      GraphicFrames.Deselect(G);
      x0 := G.mark.x; y0 := G.mark.y; x1 := G.mark.next.x; y1 := G.mark.next.y;
      NEW(R); R.col := Oberon.CurCol;
      R.w := ABS(x1-x0); R.h := ABS(y1-y0);
      IF x1 < x0 THEN x0 := x1 END ;
      IF y1 < y0 THEN y0 := y1 END ;
      R.x := x0 - G.x; R.y := y0 - G.y;
      R.lw := Graphics.width; R.vers := 0; R.do := method;
      Graphics.Add(G.graph, R);
      GraphicFrames.Defocus(G); GraphicFrames.DrawObj(G, R)
    END
  END Make;

BEGIN NEW(method);
  method.module := "Rectangles"; method.allocator := "New";
  method.new := New; method.copy := Copy; method.draw := Draw;
  method.selectable := Selectable; method.change := Change;
  method.read := Read; method.write := Write; (*method.print := Print*)
  tack := SYSTEM.ADR($0707 4122 1408 1422 4100$);
  grey := SYSTEM.ADR($2004 0000 1111 1111 0000 0000 4444 4444 0000 0000$)
END Rectangles.
