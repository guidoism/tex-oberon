MODULE Graphics;   (*NW 21.12.89 / 18.11.201 / 8.4.2016*)
  IMPORT SYSTEM, Files, Modules, Fonts, (*Printer,*) Texts, Oberon;

  CONST NameLen* = 32; GraphFileId = 0FAX; LibFileId = 0FBX;

  TYPE
    Graph* = POINTER TO GraphDesc;
    Object* = POINTER TO ObjectDesc;
    Method* = POINTER TO MethodDesc;

    Line* = POINTER TO LineDesc;
    Caption* = POINTER TO CaptionDesc;
    Macro* = POINTER TO MacroDesc;

    ObjectDesc* = RECORD
        x*, y*, w*, h*: INTEGER;
        col*: BYTE;
        selected*, marked*: BOOLEAN;
        do*: Method;
        next: Object
      END ;

    Msg* = RECORD END ;
    WidMsg* = RECORD (Msg) w*: INTEGER END ;
    ColorMsg* = RECORD (Msg) col*: INTEGER END ;
    FontMsg* = RECORD (Msg) fnt*: Fonts.Font END ;
    Name* = ARRAY NameLen OF CHAR;

    GraphDesc* = RECORD
        time*: LONGINT;
        sel*, first: Object;
        changed*: BOOLEAN
      END ;

    MacHead* = POINTER TO MacHeadDesc;
    MacExt* = POINTER TO MacExtDesc;
    Library* = POINTER TO LibraryDesc;

    MacHeadDesc* = RECORD
        name*: Name;
        w*, h*: INTEGER;
        ext*: MacExt;
        lib*: Library;
        first: Object;
        next: MacHead
      END ;

    LibraryDesc* = RECORD
        name*: Name;
        first: MacHead;
        next: Library
      END ;

    MacExtDesc* = RECORD END ;

    Context* = RECORD
        nofonts, noflibs, nofclasses: INTEGER;
        font: ARRAY 10 OF Fonts.Font;
        lib: ARRAY 4 OF Library;
        class: ARRAY 6 OF Modules.Command
      END;

    MethodDesc* = RECORD
        module*, allocator*: Name;
        new*: Modules.Command;
        copy*: PROCEDURE (from, to: Object);
        draw*, change*: PROCEDURE (obj: Object; VAR msg: Msg);
        selectable*: PROCEDURE (obj: Object; x, y: INTEGER): BOOLEAN;
        read*: PROCEDURE (obj: Object; VAR R: Files.Rider; VAR C: Context);
        write*: PROCEDURE (obj: Object; cno: INTEGER; VAR R: Files.Rider; VAR C: Context);
        print*: PROCEDURE (obj: Object; x, y: INTEGER)
      END ;

    LineDesc* = RECORD (ObjectDesc)
        unused*: INTEGER
      END ;

    CaptionDesc* = RECORD (ObjectDesc)
        pos*, len*: INTEGER
      END ;

    MacroDesc* = RECORD (ObjectDesc)
        mac*: MacHead
      END ;

  VAR width*, res*: INTEGER;
    new: Object;
    T*: Texts.Text;  (*captions*)
    LineMethod*, CapMethod*, MacMethod* : Method;
    GetLib0: PROCEDURE (name: ARRAY OF CHAR; replace: BOOLEAN; VAR Lib: Library);

    FirstLib: Library;
    W, TW, XW: Texts.Writer;

  PROCEDURE New*(obj: Object);
  BEGIN new := obj
  END New;

  PROCEDURE Add*(G: Graph; obj: Object);
  BEGIN obj.marked := FALSE; obj.selected := TRUE; obj.next := G.first;
    G.first := obj; G.sel := obj; G.time := Oberon.Time(); G.changed := TRUE
  END Add;

  PROCEDURE ThisObj*(G: Graph; x, y: INTEGER): Object;
    VAR obj: Object;
  BEGIN obj := G.first;
    WHILE (obj # NIL) & ~obj.do.selectable(obj, x ,y) DO obj := obj.next END ;
    RETURN obj
  END ThisObj;

  PROCEDURE SelectObj*(G: Graph; obj: Object);
  BEGIN
    IF obj # NIL THEN obj.selected := TRUE; G.sel := obj; G.time := Oberon.Time() END
  END SelectObj;

  PROCEDURE SelectArea*(G: Graph; x0, y0, x1, y1: INTEGER);
    VAR obj: Object; t: INTEGER;
  BEGIN obj := G.first;
    IF x1 < x0 THEN t := x0; x0 := x1; x1 := t END ;
    IF y1 < y0 THEN t := y0; y0 := y1; y1 := t END ;
    WHILE obj # NIL DO
      IF (x0 <= obj.x) & (obj.x + obj.w <= x1) & (y0 <= obj.y) & (obj.y + obj.h <= y1) THEN
        obj.selected := TRUE; G.sel := obj
      END ;
      obj := obj.next
    END ;
    IF G.sel # NIL THEN G.time := Oberon.Time() END
  END SelectArea;

  PROCEDURE Draw*(G: Graph; VAR M: Msg);
    VAR obj: Object;
  BEGIN obj := G.first;
    WHILE obj # NIL DO obj.do.draw(obj, M); obj := obj.next END
  END Draw;

  PROCEDURE List*(G: Graph);
    VAR obj: Object; tag: INTEGER;
  BEGIN obj := G.first;
    WHILE obj # NIL DO
      Texts.Write(XW, 9X); Texts.WriteHex(XW, ORD(obj)); Texts.Write(XW, 9X);
      Texts.WriteInt(XW, obj.x, 5); Texts.WriteInt(XW, obj.y, 5); Texts.WriteInt(XW, obj.w, 5); Texts.WriteInt(XW, obj.h, 5);
      Texts.Write(XW, "/"); SYSTEM.GET(ORD(obj)-8, tag); Texts.WriteHex(XW, tag);
      SYSTEM.GET(ORD(obj)-4, tag); Texts.WriteHex(XW, tag); Texts.WriteLn(XW); obj := obj.next
    END ;
    Texts.Append(Oberon.Log, XW.buf)
  END List;

  (*----------------procedures operating on selection -------------------*)

  PROCEDURE Deselect*(G: Graph);
    VAR obj: Object;
  BEGIN obj := G.first; G.sel := NIL; G.time := 0;
    WHILE obj # NIL DO obj.selected := FALSE; obj := obj.next END
  END Deselect;

  PROCEDURE DrawSel*(G: Graph; VAR M: Msg);
    VAR obj: Object;
  BEGIN obj := G.first;
    WHILE obj # NIL DO
      IF obj.selected THEN obj.do.draw(obj, M) END ;
      obj := obj.next
    END
  END DrawSel;

  PROCEDURE Change*(G: Graph; VAR M: Msg);
    VAR obj: Object;
  BEGIN obj := G.first; G.changed := TRUE;
    WHILE obj # NIL DO
      IF obj.selected THEN obj.do.change(obj, M) END ;
      obj := obj.next
    END
  END Change;

  PROCEDURE Move*(G: Graph; dx, dy: INTEGER);
    VAR obj, ob0: Object; x0, x1, y0, y1: INTEGER;
  BEGIN obj := G.first; G.changed := TRUE;
    WHILE obj # NIL DO
      IF obj.selected & ~(obj IS Caption) THEN
        x0 := obj.x; x1 := obj.w + x0; y0 := obj.y; y1 := obj.h + y0;
        IF dx = 0 THEN (*vertical move*)
          ob0 := G.first;
          WHILE ob0 # NIL DO
            IF ~ob0.selected & (ob0 IS Line) & (x0 <= ob0.x) & (ob0.x <= x1) & (ob0.w < ob0.h) THEN
              IF (y0 <= ob0.y) & (ob0.y <= y1) THEN
                INC(ob0.y, dy); DEC(ob0.h, dy); ob0.marked := TRUE
              ELSIF (y0 <= ob0.y + ob0.h) & (ob0.y + ob0.h <= y1) THEN
                INC(ob0.h, dy); ob0.marked := TRUE
              END
            END ;
            ob0 := ob0.next
          END
        ELSIF dy = 0 THEN (*horizontal move*)
          ob0 := G.first;
          WHILE ob0 # NIL DO
            IF ~ob0.selected & (ob0 IS Line) & (y0 <= ob0.y) & (ob0.y <= y1) & (ob0.h < ob0.w) THEN
              IF (x0 <= ob0.x) & (ob0.x <= x1) THEN
                INC(ob0.x, dx); DEC(ob0.w, dx); ob0.marked := TRUE
              ELSIF (x0 <= ob0.x + ob0.w) & (ob0.x + ob0.w <= x1) THEN
                INC(ob0.w, dx); ob0.marked := TRUE
              END
            END ;
            ob0 := ob0.next
          END
        END
      END ;
      obj := obj.next
    END ;
    obj := G.first; (*now move*)
    WHILE obj # NIL DO
      IF obj.selected THEN INC(obj.x, dx); INC(obj.y, dy) END ;
      obj.marked := FALSE; obj := obj.next
    END
  END Move;

  PROCEDURE Copy*(Gs, Gd: Graph; dx, dy: INTEGER);
    VAR obj: Object;
  BEGIN obj := Gs.first; Gd.changed := TRUE;
    WHILE obj # NIL DO
      IF obj.selected THEN
        obj.do.new; obj.do.copy(obj, new); INC(new.x, dx); INC(new.y, dy);
        obj.selected := FALSE; Add(Gd, new)
      END ;
      obj := obj.next
    END ;
    new := NIL
  END Copy;

  PROCEDURE Delete*(G: Graph);
    VAR obj, pred: Object;
  BEGIN G.sel := NIL; G.changed := TRUE; obj := G.first;
    WHILE (obj # NIL) & obj.selected DO obj := obj.next END ;
    G.first := obj;
    IF obj # NIL THEN
      pred := obj; obj := obj.next;
      WHILE obj # NIL DO
        IF obj.selected THEN pred.next := obj.next ELSE pred := obj END ;
        obj := obj.next
      END
    END
  END Delete;

  (* ---------------------- Storing ----------------------- *)

  PROCEDURE WMsg(s0, s1: ARRAY OF CHAR);
  BEGIN Texts.WriteString(W, s0); Texts.WriteString(W, s1);
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END WMsg;

  PROCEDURE InitContext(VAR C: Context);
  BEGIN C.nofonts := 0; C.noflibs := 0; C.nofclasses := 4;
    C.class[1] := LineMethod.new; C.class[2] := CapMethod.new; C.class[3] := MacMethod.new
  END InitContext;

  PROCEDURE FontNo*(VAR W: Files.Rider; VAR C: Context; fnt: Fonts.Font): INTEGER;
    VAR fno: INTEGER;
  BEGIN fno := 0;
    WHILE (fno < C.nofonts) & (C.font[fno] # fnt) DO INC(fno) END ;
    IF fno = C.nofonts THEN
      Files.WriteByte(W, 0); Files.WriteByte(W, 0); Files.WriteByte(W, fno);
      Files.WriteString(W, fnt.name); C.font[fno] := fnt; INC(C.nofonts)
    END ;
    RETURN fno
  END FontNo;

  PROCEDURE StoreElems(VAR W: Files.Rider; VAR C: Context; obj: Object);
    VAR cno: INTEGER;
  BEGIN
    WHILE obj # NIL DO
      cno := 1;
      WHILE (cno < C.nofclasses) & (obj.do.new # C.class[cno]) DO INC(cno) END ;
      IF cno = C.nofclasses THEN
        Files.WriteByte(W, 0); Files.WriteByte(W, 2); Files.WriteByte(W, cno);
        Files.WriteString(W, obj.do.module); Files.WriteString(W, obj.do.allocator);
        C.class[cno] := obj.do.new; INC(C.nofclasses)
      END ;
      obj.do.write(obj, cno, W, C); obj := obj.next
    END ;
    Files.WriteByte(W, 255)
  END StoreElems;

  PROCEDURE Store*(G: Graph; VAR W: Files.Rider);
    VAR C: Context;
  BEGIN InitContext(C); StoreElems(W, C, G.first); G.changed := FALSE
  END Store;

  PROCEDURE WriteObj*(VAR W: Files.Rider; cno: INTEGER; obj: Object);
  BEGIN Files.WriteByte(W, cno); Files.WriteInt(W, obj.y * 10000H + obj.x);
    Files.WriteInt(W, obj.h * 10000H + obj.w); Files.WriteByte(W, obj.col)
  END WriteObj;

  PROCEDURE WriteFile*(G: Graph; name: ARRAY OF CHAR);
    VAR F: Files.File; W: Files.Rider; C: Context;
  BEGIN F := Files.New(name); Files.Set(W, F, 0); Files.Write(W, GraphFileId);
    InitContext(C); StoreElems(W, C, G.first); Files.Register(F)
  END WriteFile;

  PROCEDURE Print*(G: Graph; x0, y0: INTEGER);
    VAR obj: Object;
  BEGIN obj := G.first;
    WHILE obj # NIL DO obj.do.print(obj, x0, y0); obj := obj.next END
  END Print;

  (* ---------------------- Loading ------------------------ *)

  PROCEDURE GetClass*(module, allocator: ARRAY OF CHAR; VAR com: Modules.Command);
    VAR mod: Modules.Module;
  BEGIN Modules.Load(module, mod);
    IF mod # NIL THEN
      com := Modules.ThisCommand(mod, allocator);
      IF com = NIL THEN WMsg(allocator, " unknown") END
    ELSE WMsg(module, " not available"); com := NIL
    END
  END GetClass;

  PROCEDURE Font*(VAR R: Files.Rider; VAR C: Context): Fonts.Font;
    VAR fno: BYTE;
  BEGIN Files.ReadByte(R, fno); RETURN C.font[fno]
  END Font;

  PROCEDURE ReadObj(VAR R: Files.Rider; obj: Object);
    VAR xy, wh: INTEGER; dmy: BYTE;
  BEGIN Files.ReadInt(R, xy); obj.y := xy DIV 10000H; obj.x := xy * 10000H DIV 10000H;
    Files.ReadInt(R, wh); obj.h := wh DIV 10000H; obj.w := wh * 10000H DIV 10000H;
    Files.ReadByte(R, obj.col)
  END ReadObj;

  PROCEDURE LoadElems(VAR R: Files.Rider; VAR C: Context; VAR fobj: Object);
    VAR cno, m, n, len: BYTE; pos: INTEGER;
      obj: Object;
      fnt: Fonts.Font;
      name, name1: ARRAY 32 OF CHAR;
  BEGIN obj := NIL; Files.ReadByte(R, cno);
    WHILE ~R.eof & (cno < 255) DO
      IF cno = 0 THEN
        Files.ReadByte(R, m); Files.ReadByte(R, n); Files.ReadString(R, name);
        IF m = 0 THEN fnt := Fonts.This(name); C.font[n] := fnt
        ELSIF m = 1 THEN GetLib0(name, FALSE, C.lib[n])
        ELSIF m = 2 THEN Files.ReadString(R, name1); GetClass(name, name1, C.class[n])
        END
      ELSIF C.class[cno] # NIL THEN
        C.class[cno];
        ReadObj(R, new);
        new.selected := FALSE; new.marked := FALSE; new.next := obj; obj := new;
        new.do.read(new, R, C)
      ELSE ReadObj(R, new); Files.ReadByte(R, len); pos := Files.Pos(R); Files.Set(R, Files.Base(R), pos + len)
      END ;
      Files.ReadByte(R, cno)
    END ;
    new := NIL; fobj := obj
  END LoadElems;

  PROCEDURE Load*(G: Graph; VAR R: Files.Rider);
    VAR C: Context;
  BEGIN G.sel := NIL; InitContext(C); LoadElems(R, C, G.first)
  END Load;

  PROCEDURE Open*(G: Graph; name: ARRAY OF CHAR);
    VAR tag: CHAR;
      F: Files.File; R: Files.Rider; C: Context;
  BEGIN G.first := NIL; G.sel := NIL; G.time := 0; G.changed := FALSE; F := Files.Old(name);
    IF F # NIL THEN
      Files.Set(R, F, 0); Files.Read(R, tag);
      IF tag = GraphFileId THEN InitContext(C); LoadElems(R, C, G.first); res := 0 ELSE res := 1 END
    ELSE res := 2
    END
  END Open;

  PROCEDURE SetWidth*(w: INTEGER);
  BEGIN width := w
  END SetWidth;

  (* --------------------- Macros / Libraries ----------------------- *)

  PROCEDURE GetLib*(name: ARRAY OF CHAR; replace: BOOLEAN; VAR Lib: Library);
    VAR i, wh: INTEGER; ch: CHAR;
      L: Library; mh: MacHead; obj: Object;
      F: Files.File; R: Files.Rider; C: Context;
      Lname, Fname: ARRAY 32 OF CHAR;
  BEGIN L := FirstLib; i := 0;
    WHILE (L # NIL) & (L.name # name) DO L := L.next END ;
    IF L = NIL THEN
      (*load library from file*) i := 0;
      WHILE name[i] > 0X DO Fname[i] := name[i]; INC(i) END ;
      Fname[i] := "."; Fname[i+1] := "L"; Fname[i+2] := "i"; Fname[i+3] := "b"; Fname[i+4] := 0X;
      F := Files.Old(Fname);
      IF F # NIL THEN
         WMsg("loading ", Fname); Files.Set(R, F, 0); Files.Read(R, ch);
        IF ch = LibFileId THEN
          IF L = NIL THEN NEW(L); L.name := name; L.next := FirstLib; FirstLib := L END ;
          L.first := NIL; InitContext(C); 
          LoadElems(R, C, obj);
          WHILE obj # NIL DO
            NEW(mh); mh.first := obj;
            Files.ReadInt(R, wh); mh.h := wh DIV 10000H MOD 10000H; mh.w := wh MOD 10000H;
            Files.ReadString(R, mh.name);
            mh.lib := L; mh.next := L.first; L.first := mh; LoadElems(R, C, obj)
          END ;
        ELSE L := NIL
        END
      ELSE L := NIL
      END
    END ;
    Lib := L
  END GetLib;

  PROCEDURE NewLib*(Lname: ARRAY OF CHAR): Library;
    VAR L: Library;
  BEGIN NEW(L); L.name := Lname; L.first := NIL;
    L.next := FirstLib; FirstLib := L; RETURN L
  END NewLib;

  PROCEDURE StoreLib*(L: Library; Fname: ARRAY OF CHAR);
    VAR i: INTEGER;
      mh: MacHead;
      F: Files.File; W: Files.Rider;
      C: Context;
      Gname: ARRAY 32 OF CHAR;
  BEGIN L := FirstLib;
    WHILE (L # NIL) & (L.name # Fname) DO L := L.next END ;
    IF L # NIL THEN i := 0;
      WHILE Fname[i] > 0X DO Gname[i] := Fname[i]; INC(i) END ;
      Gname[i] := "."; Gname[i+1] := "L"; Gname[i+2] := "i"; Gname[i+3] := "b"; Gname[i+4] := 0X;
      F := Files.New(Gname); Files.Set(W, F, 0); Files.Write(W, LibFileId);
      InitContext(C); mh := L.first;
      WHILE mh # NIL DO
        StoreElems(W, C, mh.first); Files.WriteInt(W, mh.h * 10000H + mh.w);
        Files.WriteString(W, mh.name); mh := mh.next
      END ;
      Files.WriteByte(W, 255); Files.Register(F)
    ELSE Texts.WriteString(TW, Fname); Texts.WriteString(TW, " not found");
      Texts.WriteLn(TW); Texts.Append(Oberon.Log, TW.buf)
    END
  END StoreLib;

  PROCEDURE RemoveLibraries*;
  BEGIN FirstLib := NIL
  END RemoveLibraries;

  PROCEDURE ThisMac*(L: Library; Mname: ARRAY OF CHAR): MacHead;
    VAR mh: MacHead;
  BEGIN mh := L.first;
    WHILE (mh # NIL) & (mh.name # Mname) DO mh := mh.next END ;
    RETURN mh
  END ThisMac;

  PROCEDURE DrawMac*(mh: MacHead; VAR M: Msg);
    VAR elem: Object;
  BEGIN elem := mh.first;
    WHILE elem # NIL DO elem.do.draw(elem, M); elem := elem.next END
  END DrawMac;

  (* -------------------- Procedures for designing macros---------------------*)

  PROCEDURE OpenMac*(mh: MacHead; G: Graph; x, y: INTEGER);
    VAR obj: Object;
  BEGIN obj := mh.first;
    WHILE obj # NIL DO
      obj.do.new; obj.do.copy(obj, new); INC(new.x, x); INC(new.y, y); new.selected := TRUE;
      Add(G, new); obj := obj.next
    END ;
    new := NIL
  END OpenMac;

  PROCEDURE MakeMac*(G: Graph; VAR head: MacHead);
    VAR x0, y0, x1, y1: INTEGER;
      obj, last: Object;
      mh: MacHead;
  BEGIN obj := G.first; last := NIL; x0 := 1024; x1 := 0; y0 := 1024; y1 := 0;
      WHILE obj # NIL DO
        IF obj.selected THEN
          obj.do.new; obj.do.copy(obj, new); new.next := last; new.selected := FALSE; last := new;
          IF obj.x < x0 THEN x0 := obj.x END ;
          IF obj.x + obj.w > x1 THEN x1 := obj.x + obj.w END ;
          IF obj.y < y0 THEN y0 := obj.y END ;
          IF obj.y + obj.h > y1 THEN y1 := obj.y + obj.h END
        END ;
        obj := obj.next
      END ;
      obj := last;
      WHILE obj # NIL DO
        obj.x := obj.x - x0; obj.y := obj.y - y0; obj := obj.next
      END ;
      NEW(mh); mh.w := x1 - x0; mh.h := y1 - y0; mh.first := last; mh.ext := NIL;
      new := NIL; head := mh
  END MakeMac;

  PROCEDURE InsertMac*(mh: MacHead; L: Library; VAR new: BOOLEAN);
    VAR mh1: MacHead;
  BEGIN mh.lib := L; mh1 := L.first;
    WHILE (mh1 # NIL) & (mh1.name # mh.name) DO mh1 := mh1.next END ;
    IF mh1 = NIL THEN
      new := TRUE; mh.next := L.first; L.first := mh
    ELSE
      new := FALSE; mh1.w := mh.w; mh1.h := mh.h; mh1.first := mh.first
    END
  END InsertMac;

  (* ---------------------------- Line Methods -----------------------------*)

  PROCEDURE NewLine;
    VAR line: Line;
  BEGIN NEW(line); new := line; line.do := LineMethod
  END NewLine;

  PROCEDURE CopyLine(src, dst: Object);
  BEGIN dst.x := src.x; dst.y := src.y; dst.w := src.w; dst.h := src.h; dst.col := src.col
  END CopyLine;

  PROCEDURE ChangeLine(obj: Object; VAR M: Msg);
  BEGIN
    CASE M OF
    WidMsg:
      IF obj.w < obj.h THEN
        IF obj.w <= 7 THEN obj.w := M.w END
      ELSIF obj.h <= 7 THEN obj.h := M.w
      END |
    ColorMsg: obj.col := M.col
    END
  END ChangeLine;

  PROCEDURE LineSelectable(obj: Object; x, y: INTEGER): BOOLEAN;
  BEGIN
    RETURN (obj.x <= x) & (x < obj.x + obj.w) & (obj.y <= y) & (y < obj.y + obj.h)
  END LineSelectable;

  PROCEDURE ReadLine(obj: Object; VAR R: Files.Rider; VAR C: Context);
  BEGIN
  END ReadLine;

  PROCEDURE WriteLine(obj: Object; cno: INTEGER; VAR W: Files.Rider; VAR C: Context);
  BEGIN WriteObj(W, cno, obj)
  END WriteLine;

(*PROCEDURE PrintLine(obj: Object; x, y: INTEGER);
    VAR w, h: INTEGER;
  BEGIN w := obj.w * 2; h := obj.h * 2;
    IF w < h THEN h := 2*h ELSE w := 2*w END ;
    Printer.ReplConst(obj.x * 4 + x, obj.y *4 + y, w, h)
  END PrintLine; *)

  (* ---------------------- Caption Methods ------------------------ *)

  PROCEDURE NewCaption;
    VAR cap: Caption;
  BEGIN NEW(cap); new := cap; cap.do := CapMethod
  END NewCaption;

  PROCEDURE CopyCaption(src, dst: Object);
    VAR ch: CHAR; R: Texts.Reader;
  BEGIN
    dst.x := src.x; dst.y := src.y; dst.w := src.w; dst.h := src.h; dst.col := src.col;
    dst(Caption).pos := T.len + 1; dst(Caption).len := src(Caption).len;
    Texts.Write(TW, 0DX); Texts.OpenReader(R, T, src(Caption).pos);
    Texts.Read(R, ch); TW.fnt := R.fnt;
    WHILE ch > 0DX DO Texts.Write(TW, ch); Texts.Read(R, ch) END ;
    Texts.Append(T, TW.buf)
  END CopyCaption;

  PROCEDURE ChangeCaption(obj: Object;  VAR M: Msg);
    VAR dx, x1, dy, y1, w, w1, h1, len: INTEGER;
      pos: LONGINT;
      ch: CHAR; patadr: INTEGER; fnt: Fonts.Font;
      R: Texts.Reader;
  BEGIN
    CASE M OF
    FontMsg: fnt := M(FontMsg).fnt; w := 0; len := 0; pos := obj(Caption).pos;
      Texts.OpenReader(R, T, pos); Texts.Read(R, ch); dy := R.fnt.minY;
      WHILE ch > 0DX DO
        Fonts.GetPat(fnt, ch, dx, x1, y1, w1, h1, patadr);
        INC(w, dx); INC(len); Texts.Read(R, ch)
      END ;
      INC(obj.y, fnt.minY-dy); obj.w := w; obj.h := fnt.height;
      Texts.ChangeLooks(T, pos, pos+len, {0}, fnt, 0 , 0) |
    ColorMsg: obj.col := M(ColorMsg).col
    END
  END ChangeCaption;

  PROCEDURE CaptionSelectable(obj: Object; x, y: INTEGER): BOOLEAN;
  BEGIN
    RETURN (obj.x <= x) & (x < obj.x + obj.w) & (obj.y <= y) & (y < obj.y + obj.h)
  END CaptionSelectable;

  PROCEDURE ReadCaption(obj: Object; VAR R: Files.Rider; VAR C: Context);
    VAR ch: CHAR; fno: BYTE; len: INTEGER;
  BEGIN obj(Caption).pos := T.len + 1; Texts.Write(TW, 0DX);
    Files.ReadByte(R, fno); TW.fnt := C.font[fno]; len := 0; Files.Read(R, ch);
    WHILE ch > 0DX DO Texts.Write(TW, ch); INC(len); Files.Read(R, ch) END ;
    obj(Caption).len := len; Texts.Append(T, TW.buf)
  END ReadCaption;

  PROCEDURE WriteCaption(obj: Object; cno: INTEGER; VAR W: Files.Rider; VAR C: Context);
    VAR ch: CHAR; fno: BYTE;
      TR: Texts.Reader;
  BEGIN
    IF obj(Caption).len > 0 THEN
      Texts.OpenReader(TR, T, obj(Caption).pos); Texts.Read(TR, ch);
      fno := FontNo(W, C, TR.fnt);
      WriteObj(W, cno, obj); Files.WriteByte(W, fno);
      WHILE ch > 0DX DO  Files.Write(W, ch); Texts.Read(TR, ch) END ;
      Files.Write(W, 0X)
    END
  END WriteCaption;

(*  PROCEDURE PrintCaption(obj: Object; x, y: INTEGER);
    VAR fnt: Fonts.Font;
      i: INTEGER; ch: CHAR;
      R: Texts.Reader;
      s: ARRAY 128 OF CHAR;
  BEGIN
    IF obj(Caption).len > 0 THEN
      Texts.OpenReader(R, T, obj(Caption).pos); Texts.Read(R, ch);
      fnt := R.fnt; DEC(y, fnt.minY*4); i := 0;
      WHILE ch >= " " DO s[i] := ch; INC(i); Texts.Read(R, ch) END ;
      s[i] := 0X;
      IF i > 0 THEN Printer.String(obj.x*4 + x, obj.y*4 + y, s, fnt.name) END
    END
  END PrintCaption; *)

  (* ---------------------- Macro Methods ------------------------ *)

  PROCEDURE NewMacro;
    VAR mac: Macro;
  BEGIN NEW(mac); new := mac; mac.do := MacMethod
  END NewMacro;

  PROCEDURE CopyMacro(src, dst: Object);
  BEGIN dst.x := src.x; dst.y := src.y; dst.w := src.w; dst.h := src.h;
    dst.col := src.col; dst(Macro).mac := src(Macro).mac
  END CopyMacro;

  PROCEDURE ChangeMacro(obj: Object; VAR M: Msg);
  BEGIN
    CASE M OF ColorMsg: obj.col := M.col END
  END ChangeMacro;

  PROCEDURE MacroSelectable(obj: Object; x, y: INTEGER): BOOLEAN;
  BEGIN
    RETURN (obj.x <= x) & (x <= obj.x + 8) & (obj.y <= y) & (y <= obj.y + 8)
  END MacroSelectable;

  PROCEDURE ReadMacro(obj: Object; VAR R: Files.Rider; VAR C: Context);
    VAR lno: BYTE; name: ARRAY 32 OF CHAR;
  BEGIN Files.ReadByte(R, lno);
    Files.ReadString(R, name); obj(Macro).mac := ThisMac(C.lib[lno], name)
  END ReadMacro;

  PROCEDURE WriteMacro(obj: Object; cno: INTEGER; VAR W1: Files.Rider; VAR C: Context);
    VAR lno: INTEGER;
  BEGIN lno := 0;
    WHILE (lno < C.noflibs) & (obj(Macro).mac.lib # C.lib[lno]) DO INC(lno) END ;
    IF lno = C.noflibs THEN
      Files.WriteByte(W1, 0); Files.WriteByte(W1, 1); Files.WriteByte(W1, lno);
      Files.WriteString(W1, obj(Macro).mac.lib.name); C.lib[lno] := obj(Macro).mac.lib; INC(C.noflibs)
    END ;
    WriteObj(W1, cno, obj); Files.WriteByte(W1, lno); Files.WriteString(W1, obj(Macro).mac.name)
  END WriteMacro;

(*  PROCEDURE PrintMacro(obj: Object; x, y: INTEGER);
    VAR elem: Object; mh: MacHead;
  BEGIN mh := obj(Macro).mac;
    IF mh # NIL THEN elem := mh.first;
      WHILE elem # NIL DO elem.do.print(elem, obj.x*4 + x, obj.y*4 + y); elem := elem.next END
    END
  END PrintMacro; *)

  PROCEDURE Notify(T: Texts.Text; op: INTEGER; beg, end: LONGINT);
  BEGIN
  END Notify;

  PROCEDURE InstallDrawMethods*(drawLine, drawCaption, drawMacro: PROCEDURE (obj: Object; VAR msg: Msg));
  BEGIN LineMethod.draw := drawLine; CapMethod.draw := drawCaption; MacMethod.draw := drawMacro
  END InstallDrawMethods;

BEGIN Texts.OpenWriter(W); Texts.OpenWriter(TW);  Texts.OpenWriter(XW);
  width := 1; GetLib0 := GetLib;
  NEW(T); Texts.Open(T, ""); T.notify := Notify;
  NEW(LineMethod); LineMethod.new := NewLine; LineMethod.copy := CopyLine;
  LineMethod.selectable := LineSelectable; LineMethod.change := ChangeLine;
  LineMethod.read := ReadLine; LineMethod.write := WriteLine; (*LineMethod.print := PrintLine;*)
  NEW(CapMethod); CapMethod.new := NewCaption; CapMethod.copy := CopyCaption;
  CapMethod.selectable := CaptionSelectable; CapMethod.change := ChangeCaption;
  CapMethod.read := ReadCaption; CapMethod.write := WriteCaption; (*CapMethod.print := PrintCaption;*)
  NEW(MacMethod); MacMethod.new := NewMacro; MacMethod.copy := CopyMacro;
  MacMethod.selectable := MacroSelectable; MacMethod.change := ChangeMacro;
  MacMethod.read := ReadMacro; MacMethod.write := WriteMacro; (*MacMethod.print := PrintMacro*)
END Graphics.