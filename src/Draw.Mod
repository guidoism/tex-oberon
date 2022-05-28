MODULE Draw; (*NW 29.6.88 / 12.11.94 / 18.11.2013*)

  IMPORT Files, Fonts, Viewers, Texts, Oberon,
    TextFrames, MenuViewers, Graphics, GraphicFrames;

  CONST Menu = "System.Close  System.Copy  System.Grow  Draw.Delete  Draw.Ticks  Draw.Restore  Draw.Store";

  VAR W: Texts.Writer;

  (*Exported commands:
    Open, Delete,
    SetWidth, ChangeColor, ChangeWidth, ChangeFont,
    Store, Print, Macro, Ticks, Restore*)

  PROCEDURE Open*;
    VAR X, Y: INTEGER;
      beg, end, t: LONGINT;
      G: Graphics.Graph;
      F: GraphicFrames.Frame;
      V: Viewers.Viewer;
      S: Texts.Scanner;
      text: Texts.Text;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF (S.class = Texts.Char) & (S.c = "^") THEN
      Oberon.GetSelection(text, beg, end, t);
      IF t >= 0 THEN Texts.OpenScanner(S, text, beg); Texts.Scan(S) END
    END ;
    IF S.class = Texts.Name THEN
      NEW(G); Graphics.Open(G, S.s);
      NEW(F); GraphicFrames.Open(F, G);
      Oberon.AllocateUserViewer(Oberon.Par.vwr.X, X, Y);
      V := MenuViewers.New(TextFrames.NewMenu(S.s, Menu), F, TextFrames.menuH, X, Y)
    END
  END Open;

  PROCEDURE Delete*;
    VAR F: GraphicFrames.Frame;
  BEGIN
    IF Oberon.Par.frame = Oberon.Par.vwr.dsc THEN
      F := Oberon.Par.vwr.dsc.next(GraphicFrames.Frame);
      GraphicFrames.Erase(F); Graphics.Delete(F.graph)
    END
  END Delete;

  PROCEDURE GetArg(VAR S: Texts.Scanner);
    VAR T: Texts.Text; beg, end, time: LONGINT;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF (S.class = Texts.Char) & (S.c = "^") THEN
      Oberon.GetSelection(T, beg, end, time);
      IF time >= 0 THEN Texts.OpenScanner(S, T, beg); Texts.Scan(S) END
    END
  END GetArg;

  PROCEDURE SetWidth*;
    VAR S: Texts.Scanner;
  BEGIN GetArg(S);
    IF (S.class = Texts.Int) & (S.i > 0) & (S.i < 7) THEN Graphics.SetWidth(S.i) END
  END SetWidth;

  PROCEDURE ChangeColor*;
    VAR S: Texts.Scanner; CM: Graphics.ColorMsg;
  BEGIN GetArg(S);
    IF S.class = Texts.Int THEN
      CM.col := S.i MOD 16; GraphicFrames.Change(GraphicFrames.Selected(), CM)
    END
  END ChangeColor;

  PROCEDURE ChangeWidth*;
    VAR S: Texts.Scanner; WM: Graphics.WidMsg;
  BEGIN GetArg(S);
    IF S.class = Texts.Int THEN
      WM.w := S.i; GraphicFrames.Change(GraphicFrames.Selected(), WM)
    END
  END ChangeWidth;

  PROCEDURE ChangeFont*;
    VAR S: Texts.Scanner; FM: Graphics.FontMsg;
  BEGIN GetArg(S);
    IF S.class = Texts.Name THEN
      FM.fnt := Fonts.This(S.s);
      IF FM.fnt # NIL THEN GraphicFrames.Change(GraphicFrames.Selected(), FM) END
    END
  END ChangeFont;

  PROCEDURE Redraw(Q: BOOLEAN);
    VAR v: Viewers.Viewer; G: GraphicFrames.Frame;
  BEGIN
    IF Oberon.Par.frame = Oberon.Par.vwr.dsc THEN v := Oberon.Par.vwr
    ELSE v := Oberon.MarkedViewer()
    END ;
    IF (v # NIL) & (v.dsc # NIL) & (v.dsc.next IS GraphicFrames.Frame) THEN
      G := v.dsc.next(GraphicFrames.Frame); G.ticked := Q OR ~G.ticked; GraphicFrames.Restore(G)
    END
  END Redraw;

  PROCEDURE Ticks*;
  BEGIN Redraw(FALSE)
  END Ticks;

  PROCEDURE Restore*;
  BEGIN Redraw(TRUE)
  END Restore;

  PROCEDURE Backup (VAR name: ARRAY OF CHAR);
    VAR res, i: INTEGER; ch: CHAR;
      bak: ARRAY 32 OF CHAR;
  BEGIN i := 0; ch := name[0];
    WHILE ch > 0X DO bak[i] := ch; INC(i); ch := name[i] END ;
    IF i < 28 THEN
      bak[i] := "."; bak[i+1] := "B"; bak[i+2] := "a"; bak[i+3] := "k"; bak[i+4] := 0X;
      Files.Rename(name, bak, res)
    END
  END Backup;

  PROCEDURE Store*;
    VAR S: Texts.Scanner;
      Menu: TextFrames.Frame; G: GraphicFrames.Frame;
      v: Viewers.Viewer;
  BEGIN
    IF Oberon.Par.frame = Oberon.Par.vwr.dsc THEN
      Menu := Oberon.Par.vwr.dsc(TextFrames.Frame); G := Menu.next(GraphicFrames.Frame);
      Texts.OpenScanner(S, Menu.text, 0); Texts.Scan(S);
      IF S.class = Texts.Name THEN
        Texts.WriteString(W, S.s); Texts.WriteString(W, " storing");
        Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
        Backup(S.s); GraphicFrames.Store(G, S.s)
      END
    ELSE
      Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
      IF S.class = Texts.Name THEN
        v := Oberon.MarkedViewer();
        IF (v.dsc # NIL) & (v.dsc.next IS GraphicFrames.Frame) THEN
          G := v.dsc.next(GraphicFrames.Frame);
          Texts.WriteString(W, S.s); Texts.WriteString(W, " storing");
          Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
          Backup(S.s); GraphicFrames.Store(G, S.s)
        END
      END
    END
  END Store;

  PROCEDURE Macro*;
    VAR S: Texts.Scanner;
      T: Texts.Text;
      time, beg, end: LONGINT;
      Lname: ARRAY 32 OF CHAR;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S);
    IF S.class = Texts.Name THEN
      Lname := S.s; Texts.Scan(S);
      IF S.class = Texts.Name THEN GraphicFrames.Macro(Lname, S.s) END ;
    END
  END Macro;

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "Draw - NW 9.8.2013");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
END Draw.
