MODULE Curves;  (*NW 8.11.90 / 18.4.2013*)
  IMPORT Display, Files, Oberon, Graphics, GraphicFrames;

  TYPE
    Curve* = POINTER TO CurveDesc;

    CurveDesc* = RECORD (Graphics.ObjectDesc)
        kind*, lw*: INTEGER
      END ;

  (*kind: 0 = up-line, 1 = down-line, 2 = circle, 3 = ellipse*)

  VAR method*: Graphics.Method;

  PROCEDURE Dot(f: GraphicFrames.Frame; col, x, y: INTEGER);
  BEGIN
    IF (x >= f.X) & (x+7 < f.X1) & (y >= f.Y) & (x+7 < f.Y1) THEN Display.Dot(col, x, y, Display.replace) END
  END Dot;

  PROCEDURE mark(f: GraphicFrames.Frame; col, x, y: INTEGER);
  BEGIN DEC(x, 3); DEC(y, 3);
    IF (x >= f.X) & (x+7 < f.X1) & (y >= f.Y) & (y+7 < f.Y1) THEN
      IF col = Display.black THEN Display.ReplConst(Display.black, x, y, 7, 7, Display.replace)
      ELSE Display.CopyPattern(col, GraphicFrames.tack, x, y, Display.replace)
      END
    END
  END mark;

  PROCEDURE line(f: GraphicFrames.Frame; col: INTEGER; x, y, w, h, d: LONGINT);
    VAR x1, y1, u: LONGINT;
  BEGIN
    IF h < w THEN
      x1 := x+w; u := (h-w) DIV 2;
      IF d = -1 THEN INC(y, h) END ;
      WHILE x < x1 DO
        Dot(f, col, x, y); INC(x);
        IF u < 0 THEN INC(u, h) ELSE INC(u, h-w); INC(y, d) END
      END
    ELSE y1 := y+h; u := (w-h) DIV 2;
      IF d = -1 THEN INC(x, w) END ;
      WHILE y < y1 DO
        Dot(f, col, x, y); INC(y);
        IF u < 0 THEN INC(u, w) ELSE INC(u, w-h); INC(x, d) END
      END
    END
  END line;

  PROCEDURE circle(f: GraphicFrames.Frame; col: INTEGER; x0, y0, r: LONGINT);
    VAR x, y, u: LONGINT;
  BEGIN u := 1 - r; x := r; y := 0;
    WHILE y <= x DO
      Dot(f, col, x0+x, y0+y);
      Dot(f, col, x0+y, y0+x);
      Dot(f, col, x0-y, y0+x);
      Dot(f, col, x0-x, y0+y);
      Dot(f, col, x0-x, y0-y);
      Dot(f, col, x0-y, y0-x);
      Dot(f, col, x0+y, y0-x);
      Dot(f, col, x0+x, y0-y);
      IF u < 0 THEN INC(u, 2*y+3) ELSE INC(u, 2*(y-x)+5); DEC(x) END ;
      INC(y)
    END
  END circle;

  PROCEDURE ellipse(f: GraphicFrames.Frame; col: INTEGER; x0, y0, a, b: LONGINT);
    VAR x, y, y1, aa, bb, d, g, h: LONGINT;
  BEGIN aa := a*a; bb := b*b;
    h := (aa DIV 4) - b*aa + bb; g := (9*aa DIV 4) - 3*b*aa + bb; x := 0; y := b;
    WHILE g < 0 DO
      Dot(f, col, x0+x, y0+y);
      Dot(f, col, x0-x, y0+y);
      Dot(f, col, x0-x, y0-y);
      Dot(f, col, x0+x, y0-y);
      IF h < 0 THEN d := (2*x+3)*bb; INC(g, d)
      ELSE d := (2*x+3)*bb - 2*(y-1)*aa; INC(g, d + 2*aa); DEC(y)
      END ;
      INC(h, d); INC(x)
    END ;
    y1 := y; h := (bb DIV 4) - a*bb + aa; x := a; y := 0;
    WHILE y <= y1 DO
      Dot(f, col, x0+x, y0+y);
      Dot(f, col, x0-x, y0+y);
      Dot(f, col, x0-x, y0-y);
      Dot(f, col, x0+x, y0-y);
      IF h < 0 THEN INC(h, (2*y+3)*aa) ELSE INC(h, (2*y+3)*aa - 2*(x-1)*bb); DEC(x) END ;
      INC(y)
    END
  END ellipse;

  PROCEDURE New*;
    VAR c: Curve;
  BEGIN NEW(c); c.do := method; Graphics.New(c)
  END New;

  PROCEDURE Copy(src, dst: Graphics.Object);
  BEGIN dst.x := src.x; dst.y := src.y; dst.w := src.w; dst.h := src.h; dst.col := src.col;
    dst(Curve).kind := src(Curve).kind; dst(Curve).lw := src(Curve).lw
  END Copy;

  PROCEDURE Draw(obj: Graphics.Object; VAR M: Graphics.Msg);
    VAR x, y, w, h, col: INTEGER; f: GraphicFrames.Frame;
  BEGIN
    CASE M OF  GraphicFrames.DrawMsg:
      x := obj.x + M.x; y := obj.y + M.y; w := obj.w; h := obj.h; f := M.f;
      IF M.col = Display.black THEN col := obj.col ELSE col := M.col END ;
      IF (x < f.X1) & (f.X <= x+w) & (y < f.Y1) & (f.Y <= y+h) THEN
        IF obj(Curve).kind = 0 THEN  (*up-line*)
          IF M.mode = 0 THEN
            IF obj.selected THEN mark(f, Display.white, x, y) END ;
            line(f, col, x, y, w, h, 1)
          ELSIF M.mode = 1 THEN mark(f, Display.white, x, y)
          ELSIF M.mode = 2 THEN mark(f, f.col, x, y)
          ELSIF M.mode = 3 THEN mark(f, Display.black, x, y); line(f, Display.black, x, y, w, h, 1)
          END
        ELSIF obj(Curve).kind = 1 THEN  (*down-line*)
          IF M.mode = 0 THEN
            IF obj.selected THEN mark(f, Display.white, x, y+h) END ;
            line(f, col, x, y, w, h, -1)
          ELSIF M.mode = 1 THEN mark(f, Display.white, x, y+h)
          ELSIF M.mode = 2 THEN mark(f, f.col, x, y+h)
          ELSIF M.mode = 3 THEN mark(f, Display.black, x, y+h); line(f, Display.black, x, y, w, h, -1)
          END
        ELSIF obj(Curve).kind = 2 THEN  (*circle*)
          w := w DIV 2;
          IF M.mode = 0 THEN
            IF obj.selected THEN mark(f, Display.white, x+w, y) END ;
            circle(f, col, x+w, y+w, w)
          ELSIF M.mode = 1 THEN mark(f, Display.white, x+w, y)
          ELSIF M.mode = 2 THEN mark(f, f.col, x+w, y)
          ELSIF M.mode = 3 THEN mark(f, Display.black, x+w, y); circle(f, Display.black, x+w, y+w, w)
          END
        ELSIF obj(Curve).kind = 3 THEN  (*ellipse*)
          w := w DIV 2; h := h DIV 2;
          IF M.mode = 0 THEN
            IF obj.selected THEN mark(f, Display.white, x+w, y) END ;
            ellipse(f, col, x+w, y+h, w, h)
          ELSIF M.mode = 1 THEN mark(f, Display.white, x+w, y)
          ELSIF M.mode = 2 THEN mark(f, f.col, x+w, y)
          ELSIF M.mode = 3 THEN mark(f, Display.black, x+w, y); ellipse(f, Display.black, x+w, y+h, w, h)
          END
        END
      END
    END
  END Draw;

  PROCEDURE Selectable(obj: Graphics.Object; x, y: INTEGER): BOOLEAN;
    VAR xm, y0, w, h: INTEGER; res: BOOLEAN;
  BEGIN
    IF obj(Curve).kind <= 1 THEN  (*line*)
      w := obj.w; h := obj.h;
      IF obj(Curve).kind = 1 THEN y0 := obj.y + h; h := -h ELSE y0 := obj.y END ;
      res := (obj.x <= x) & (x < obj.x + w) & (ABS(y-y0)*w - (x-obj.x)*h < w*4)
    ELSE (*circle or ellipse*)
      xm := obj.w DIV 2 + obj.x;
      res := (xm - 4 <= x) & (x <= xm + 4) & (obj.y - 4 <= y) & (y <= obj.y + 4)
    END ;
    RETURN res
  END Selectable;

  PROCEDURE Change(obj: Graphics.Object; VAR M: Graphics.Msg);
  BEGIN
    IF M IS Graphics.ColorMsg THEN obj.col := M(Graphics.ColorMsg).col END
  END Change;

  PROCEDURE Read(obj: Graphics.Object; VAR R: Files.Rider; VAR C: Graphics.Context);
    VAR len: BYTE;
  BEGIN Files.ReadByte(R, len); Files.ReadByte(R, len); obj(Curve).kind := len;
    Files.ReadByte(R, len); obj(Curve).lw := len
  END Read;

  PROCEDURE Write(obj: Graphics.Object; cno: INTEGER; VAR W: Files.Rider; VAR C: Graphics.Context);
  BEGIN Graphics.WriteObj(W, cno, obj);
    Files.WriteByte(W, 2); Files.WriteByte(W, obj(Curve).kind); Files.WriteByte(W, obj(Curve).lw)
  END Write;

  PROCEDURE MakeLine*;  (*command*)
    VAR x0, x1, y0, y1: INTEGER;
      c: Curve;
      G: GraphicFrames.Frame;
  BEGIN G := GraphicFrames.Focus();
    IF (G # NIL) & (G.mark.next # NIL) THEN
      GraphicFrames.Deselect(G);
      x0 := G.mark.x; y0 := G.mark.y; x1 := G.mark.next.x; y1 := G.mark.next.y;
      NEW(c); c.col := Oberon.CurCol;
      c.w := ABS(x1-x0); c.h := ABS(y1-y0); c.lw := Graphics.width;
      IF x0 <= x1 THEN c.x := x0;
        IF y0 <= y1 THEN c.kind := 0; c.y := y0 ELSE c.kind := 1; c.y := y1 END
      ELSE c.x := x1;
        IF y1 < y0 THEN c.kind := 0; c.y := y1 ELSE c.kind := 1; c.y := y0 END
      END ;
      DEC(c.x, G.x); DEC(c.y, G.y); c.do := method;
      Graphics.Add(G.graph, c);
      GraphicFrames.Defocus(G); GraphicFrames.DrawObj(G, c)
    END
  END MakeLine;

  PROCEDURE MakeCircle*;  (*command*)
    VAR x0, y0, r: INTEGER;
      c: Curve;
      G: GraphicFrames.Frame;
  BEGIN G := GraphicFrames.Focus();
    IF (G # NIL) & (G.mark.next # NIL) THEN
      GraphicFrames.Deselect(G);
      x0 := G.mark.x; y0 := G.mark.y; r := ABS(G.mark.next.x-x0);
      IF r > 4 THEN
        NEW(c); c.x := x0 - r - G.x; c.y := y0 - r - G.y; c.w := 2*r+1; c.h := c.w;
        c.kind := 2; c.col := Oberon.CurCol;
        c.lw := Graphics.width; c.do := method;
        Graphics.Add(G.graph, c);
        GraphicFrames.Defocus(G); GraphicFrames.DrawObj(G, c)
      END
    END
  END MakeCircle;

  PROCEDURE MakeEllipse*;  (*command*)
    VAR x0, y0, a, b: INTEGER;
      c: Curve;
      G: GraphicFrames.Frame;
  BEGIN G := GraphicFrames.Focus();
    IF (G # NIL) & (G.mark.next # NIL) & (G.mark.next.next # NIL) THEN
      GraphicFrames.Deselect(G);
      x0 := G.mark.x; y0 := G.mark.y;
      a := ABS(G.mark.next.x-x0); b := ABS(G.mark.next.next.y - y0);
      IF (a > 4) & (b > 4) THEN
        NEW(c); c.x := x0 - a - G.x; c.y := y0 - b - G.y; c.w := 2*a+1; c.h := 2*b+1;
        c.kind := 3; c.col := Oberon.CurCol;
        c.lw := Graphics.width; c.do := method;
        Graphics.Add(G.graph, c);
        GraphicFrames.Defocus(G); GraphicFrames.DrawObj(G, c)
      END
    END
  END MakeEllipse;

BEGIN NEW(method); method.module := "Curves"; method.allocator := "New";
  method.new := New; method.copy := Copy; method.draw := Draw;
  method.selectable := Selectable; method.change := Change;
  method.read := Read; method.write := Write
END Curves.
