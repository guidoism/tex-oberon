MODULE Oberon; (*JG 6.9.90 / 23.9.93 / 13.8.94 / NW 14.4.2013 / 22.12.2015*)
  IMPORT SYSTEM, Kernel, Files, Modules, Input, Display, Viewers, Fonts, Texts;

  CONST (*message ids*)
    consume* = 0; track* = 1; defocus* = 0; neutralize* = 1; mark* = 2;
    off = 0; idle = 1; active = 2;   (*task states*)
    BasicCycle = 20;
    ESC = 1BX; SETSTAR = 1AX;

  TYPE Painter* = PROCEDURE (x, y: INTEGER);
    Marker* = RECORD Fade*, Draw*: Painter END;
    
    Cursor* = RECORD
        marker*: Marker; on*: BOOLEAN; X*, Y*: INTEGER
    END;

    InputMsg* = RECORD (Display.FrameMsg)
      id*: INTEGER;
      keys*: SET;
      X*, Y*: INTEGER;
      ch*: CHAR;
      fnt*: Fonts.Font;
      col*, voff*: INTEGER
    END;

    SelectionMsg* = RECORD (Display.FrameMsg)
      time*: LONGINT;
      text*: Texts.Text;
      beg*, end*: LONGINT
    END;

    ControlMsg* = RECORD (Display.FrameMsg)
      id*, X*, Y*: INTEGER
    END;

    CopyMsg* = RECORD (Display.FrameMsg)
      F*: Display.Frame
    END;

    Task* = POINTER TO TaskDesc;

    Handler* = PROCEDURE;

    TaskDesc* = RECORD
      state, nextTime, period*: INTEGER;
      next: Task;
      handle: Handler
    END;

  VAR User*: ARRAY 8 OF CHAR; Password*: LONGINT;
    Arrow*, Star*: Marker;
    Mouse, Pointer: Cursor;
    FocusViewer*: Viewers.Viewer;
    Log*: Texts.Text;

    Par*: RECORD
      vwr*: Viewers.Viewer;
      frame*: Display.Frame;
      text*: Texts.Text;
      pos*: LONGINT
    END;

    CurFnt*: Fonts.Font;
    CurCol*, CurOff*: INTEGER;
    NofTasks*: INTEGER;

    CurTask: Task;
    DW, DH, CL: INTEGER;
    ActCnt: INTEGER; (*action count for GC*)
    Mod: Modules.Module;

  (*user identification*)

  PROCEDURE Code(VAR s: ARRAY OF CHAR): LONGINT;
    VAR i: INTEGER; a, b, c: LONGINT;
  BEGIN
    a := 0; b := 0; i := 0;
    WHILE s[i] # 0X DO
      c := b; b := a; a := (c MOD 509 + 1) * 127 + ORD(s[i]);
      INC(i)
    END;
    IF b >= 32768 THEN b := b - 65536 END;
    RETURN b * 65536 + a
  END Code;

  PROCEDURE SetUser* (VAR user, password: ARRAY OF CHAR);
  BEGIN User := user; Password := Code(password)
  END SetUser;

  PROCEDURE Clock*(): LONGINT;
  BEGIN RETURN Kernel.Clock()
  END Clock;

  PROCEDURE SetClock* (d: LONGINT);
  BEGIN Kernel.SetClock(d)
  END SetClock;

  PROCEDURE Time*(): LONGINT;
  BEGIN RETURN Kernel.Time()
  END Time;

  (*cursor handling*)

  PROCEDURE FlipArrow (X, Y: INTEGER);
  BEGIN
    IF X < CL THEN
      IF X > DW - 15 THEN X := DW - 15 END
    ELSE
      IF X > CL + DW - 15 THEN X := CL + DW - 15 END
    END;
    IF Y < 14 THEN Y := 14 ELSIF Y > DH THEN Y := DH END;
    Display.CopyPattern(Display.white, Display.arrow, X, Y - 14, Display.invert)
  END FlipArrow;
     
  PROCEDURE FlipStar (X, Y: INTEGER);
  BEGIN
    IF X < CL THEN
      IF X < 7 THEN X := 7 ELSIF X > DW - 8 THEN X := DW - 8 END
    ELSE
      IF X < CL + 7 THEN X := CL + 7 ELSIF X > CL + DW - 8 THEN X := CL + DW - 8 END
    END ;
    IF Y < 7 THEN Y := 7 ELSIF Y > DH - 8 THEN Y := DH - 8 END;
    Display.CopyPattern(Display.white, Display.star, X - 7, Y - 7, Display.invert)
  END FlipStar;

  PROCEDURE OpenCursor(VAR c: Cursor);
  BEGIN c.on := FALSE; c.X := 0; c.Y := 0
  END OpenCursor;
 
  PROCEDURE FadeCursor(VAR c: Cursor);
  BEGIN IF c.on THEN c.marker.Fade(c.X, c.Y); c.on := FALSE END
  END FadeCursor;

  PROCEDURE DrawCursor(VAR c: Cursor; m: Marker; x, y: INTEGER);
  BEGIN
    IF c.on & ((x # c.X) OR (y # c.Y) OR (m.Draw # c.marker.Draw)) THEN
      c.marker.Fade(c.X, c.Y); c.on := FALSE
    END;
    IF ~c.on THEN
      m.Draw(x, y); c.marker := m; c.X := x; c.Y := y; c.on := TRUE
    END
  END DrawCursor;

  PROCEDURE DrawMouse*(m: Marker; x, y: INTEGER);
  BEGIN DrawCursor(Mouse, m, x, y)
  END DrawMouse;

  PROCEDURE DrawMouseArrow*(x, y: INTEGER);
  BEGIN DrawCursor(Mouse, Arrow, x, y)
  END DrawMouseArrow;

  PROCEDURE FadeMouse*;
  BEGIN FadeCursor(Mouse)
  END FadeMouse;

  PROCEDURE DrawPointer*(x, y: INTEGER);
  BEGIN DrawCursor(Pointer, Star, x, y)
  END DrawPointer;

  (*display management*)

  PROCEDURE RemoveMarks* (X, Y, W, H: INTEGER);
  BEGIN
    IF (Mouse.X > X - 16) & (Mouse.X < X + W + 16) & (Mouse.Y > Y - 16) & (Mouse.Y < Y + H + 16) THEN
      FadeCursor(Mouse)
    END;
    IF (Pointer.X > X - 8) & (Pointer.X < X + W + 8) & (Pointer.Y > Y - 8) & (Pointer.Y < Y + H + 8) THEN
      FadeCursor(Pointer)
    END
  END RemoveMarks;

  PROCEDURE HandleFiller (V: Display.Frame; VAR M: Display.FrameMsg);
  BEGIN
    CASE M OF
    InputMsg: IF M.id = track THEN DrawCursor(Mouse, Arrow, M.X, M.Y) END |
    ControlMsg: IF M.id = mark THEN DrawCursor(Pointer, Star, M.X, M.Y) END |
    Viewers.ViewerMsg:
      IF (M.id = Viewers.restore) & (V.W > 0) & (V.H > 0) THEN
        RemoveMarks(V.X, V.Y, V.W, V.H);
        Display.ReplConst(Display.black, V.X, V.Y, V.W, V.H, Display.replace)
      ELSIF (M.id = Viewers.modify) & (M.Y < V.Y) THEN
        RemoveMarks(V.X, M.Y, V.W, V.Y - M.Y);
        Display.ReplConst(Display.black, V.X, M.Y, V.W, V.Y - M.Y, Display.replace)
      END
    END
  END HandleFiller;

  PROCEDURE OpenDisplay* (UW, SW, H: INTEGER);
    VAR Filler: Viewers.Viewer;
  BEGIN
     Input.SetMouseLimits(Viewers.curW + UW + SW, H);
     Display.ReplConst(Display.black, Viewers.curW, 0, UW + SW, H, Display.replace);
     NEW(Filler); Filler.handle := HandleFiller;
     Viewers.InitTrack(UW, H, Filler); (*init user track*)
     NEW(Filler); Filler.handle := HandleFiller;
     Viewers.InitTrack(SW, H, Filler) (*init system track*)
  END OpenDisplay;

  PROCEDURE DisplayWidth* (X: INTEGER): INTEGER;
  BEGIN RETURN DW
  END DisplayWidth;

  PROCEDURE DisplayHeight* (X: INTEGER): INTEGER;
  BEGIN RETURN DH
  END DisplayHeight;

  PROCEDURE OpenTrack* (X, W: INTEGER);
    VAR Filler: Viewers.Viewer;
  BEGIN
    NEW(Filler); Filler.handle := HandleFiller;
    Viewers.OpenTrack(X, W, Filler)
  END OpenTrack;

  PROCEDURE UserTrack* (X: INTEGER): INTEGER;
  BEGIN RETURN X DIV DW * DW
  END UserTrack;

  PROCEDURE SystemTrack* (X: INTEGER): INTEGER;
  BEGIN RETURN X DIV DW * DW + DW DIV 8 * 5
  END SystemTrack;

  PROCEDURE UY (X: INTEGER): INTEGER;
    VAR h: INTEGER;
      fil, bot, alt, max: Display.Frame;
  BEGIN
    Viewers.Locate(X, 0, fil, bot, alt, max);
    IF fil.H >= DH DIV 8 THEN h := DH ELSE h := max.Y + max.H DIV 2 END ;
    RETURN h
  END UY;

  PROCEDURE AllocateUserViewer* (DX: INTEGER; VAR X, Y: INTEGER);
  BEGIN
    IF Pointer.on THEN X := Pointer.X; Y := Pointer.Y
    ELSE X := DX DIV DW * DW; Y := UY(X)
    END
  END AllocateUserViewer;

  PROCEDURE SY (X: INTEGER): INTEGER;
    VAR H0, H1, H2, H3, y: INTEGER;
      fil, bot, alt, max: Display.Frame;
  BEGIN H3 := DH - DH DIV 3;
    H2 := H3 - H3 DIV 2; H1 := DH DIV 5; H0 := DH DIV 10;
    Viewers.Locate(X, DH, fil, bot, alt, max);
    IF fil.H >= DH DIV 8 THEN y := DH
    ELSIF max.H >= DH - H0 THEN y := max.Y + H3
    ELSIF max.H >= H3 - H0 THEN y := max.Y + H2
    ELSIF max.H >= H2 - H0 THEN y := max.Y + H1
    ELSIF max # bot THEN y := max.Y + max.H DIV 2
    ELSIF bot.H >= H1 THEN y := bot.H DIV 2
    ELSE y := alt.Y + alt.H DIV 2
    END ;
    RETURN y
  END SY;

  PROCEDURE AllocateSystemViewer* (DX: INTEGER; VAR X, Y: INTEGER);
  BEGIN
    IF Pointer.on THEN X := Pointer.X; Y := Pointer.Y
    ELSE X := DX DIV DW * DW + DW DIV 8 * 5; Y := SY(X)
    END
  END AllocateSystemViewer;

  PROCEDURE MarkedViewer* (): Viewers.Viewer;
  BEGIN RETURN Viewers.This(Pointer.X, Pointer.Y)
  END MarkedViewer;

  PROCEDURE PassFocus* (V: Viewers.Viewer);
    VAR M: ControlMsg;
  BEGIN M.id := defocus; FocusViewer.handle(FocusViewer, M); FocusViewer := V
  END PassFocus;

  PROCEDURE OpenLog*(T: Texts.Text);
  BEGIN Log := T
  END OpenLog;

  (*command interpretation*)
  PROCEDURE SetPar*(F: Display.Frame; T: Texts.Text; pos: LONGINT);
  BEGIN Par.vwr := Viewers.This(F.X, F.Y); Par.frame := F; Par.text := T; Par.pos := pos
  END SetPar;

  PROCEDURE Call* (name: ARRAY OF CHAR; VAR res: INTEGER);
    VAR mod: Modules.Module; P: Modules.Command;
      i, j: INTEGER; ch: CHAR;
      Mname, Cname: ARRAY 32 OF CHAR;
  BEGIN i := 0; ch := name[0];
    WHILE (ch # ".") & (ch # 0X) DO Mname[i] := ch; INC(i); ch := name[i] END ;
    IF ch = "." THEN
      Mname[i] := 0X; INC(i);
      Modules.Load(Mname, mod); res := Modules.res;
      IF Modules.res = 0 THEN
        j := 0; ch := name[i]; INC(i);
        WHILE ch # 0X DO Cname[j] := ch; INC(j); ch := name[i]; INC(i) END ;
        Cname[j] := 0X;
        P := Modules.ThisCommand(mod, Cname); res := Modules.res;
        IF Modules.res = 0 THEN P END
      END
    ELSE res := 5
    END
  END Call;

  PROCEDURE GetSelection* (VAR text: Texts.Text; VAR beg, end, time: LONGINT);
    VAR M: SelectionMsg;
  BEGIN
    M.time := -1; Viewers.Broadcast(M); time := M.time;
    IF time >= 0 THEN text := M.text; beg := M.beg; end := M.end END
  END GetSelection;

  PROCEDURE GC;
    VAR mod: Modules.Module;
  BEGIN
    IF (ActCnt <= 0) OR (Kernel.allocated >= Kernel.heapLim - Kernel.heapOrg - 10000H) THEN
      mod := Modules.root; LED(21H);
      WHILE mod # NIL DO
        IF mod.name[0] # 0X THEN Kernel.Mark(mod.ptr) END ;
        mod := mod.next
      END ;
      LED(23H);
      Files.RestoreList; LED(27H);
      Kernel.Scan; LED(20H);
      ActCnt := BasicCycle
    END
  END GC;

  PROCEDURE NewTask*(h: Handler; period: INTEGER): Task;
    VAR t: Task;
  BEGIN NEW(t); t.state := off; t.next := t; t.handle := h; t.period := period; RETURN t
  END NewTask;
  
  PROCEDURE Install* (T: Task);
  BEGIN
    IF T.state = off THEN
      T.next := CurTask.next; CurTask.next := T; T.state := idle; T.nextTime := 0; INC(NofTasks)
    END
  END Install;

  PROCEDURE Remove* (T: Task);
    VAR t: Task;
  BEGIN
    IF T.state # off THEN t := T;
      WHILE t.next # T DO t := t.next END ;
      t.next := T.next; T.state := off; T.next := NIL; CurTask := t; DEC(NofTasks)
    END
  END Remove;

  PROCEDURE Collect* (count: INTEGER);
  BEGIN ActCnt := count
  END Collect;

  PROCEDURE SetFont* (fnt: Fonts.Font);
  BEGIN CurFnt := fnt
  END SetFont;

  PROCEDURE SetColor* (col: INTEGER);
  BEGIN CurCol := col
  END SetColor;

  PROCEDURE SetOffset* (voff: INTEGER);
  BEGIN CurOff := voff
  END SetOffset;

  PROCEDURE Loop*;
    VAR V: Viewers.Viewer; M: InputMsg; N: ControlMsg;
       prevX, prevY, X, Y, t: INTEGER; keys: SET; ch: CHAR;
  BEGIN
    REPEAT
      Input.Mouse(keys, X, Y);
      IF Input.Available() > 0 THEN Input.Read(ch);
        IF ch = ESC THEN
          N.id := neutralize; Viewers.Broadcast(N); FadeCursor(Pointer); LED(0)
        ELSIF ch = SETSTAR THEN
          N.id := mark; N.X := X; N.Y := Y; V := Viewers.This(X, Y); V.handle(V, N)
        ELSE M.id := consume; M.ch := ch; M.fnt := CurFnt; M.col := CurCol; M.voff := CurOff;
          FocusViewer.handle(FocusViewer, M); DEC(ActCnt)
        END
      ELSIF keys # {} THEN
        M.id := track; M.X := X; M.Y := Y; M.keys := keys;
        REPEAT V := Viewers.This(M.X, M.Y); V.handle(V, M); Input.Mouse(M.keys, M.X, M.Y)
        UNTIL M.keys = {};
        DEC(ActCnt)
      ELSE
        IF (X # prevX) OR (Y # prevY) OR ~Mouse.on THEN
          M.id := track; M.X := X; 
          IF Y >= Display.Height THEN Y := Display.Height END ;
          M.Y := Y; M.keys := keys; V := Viewers.This(X, Y); V.handle(V, M); prevX := X; prevY := Y
        END;
        CurTask := CurTask.next; t := Kernel.Time();
        IF t >= CurTask.nextTime THEN
          CurTask.nextTime := t + CurTask.period; CurTask.state := active; CurTask.handle; CurTask.state := idle
        END
      END
    UNTIL FALSE
  END Loop;

  PROCEDURE Reset*;
  BEGIN
    IF CurTask.state = active THEN Remove(CurTask) END ;
    SYSTEM.LDREG(14, Kernel.stackOrg); (*reset stack pointer*) Loop
  END Reset;

BEGIN User[0] := 0X;
  Arrow.Fade := FlipArrow; Arrow.Draw := FlipArrow;
  Star.Fade := FlipStar; Star.Draw := FlipStar;
  OpenCursor(Mouse); OpenCursor(Pointer);

  DW := Display.Width; DH := Display.Height; CL := DW;
  OpenDisplay(DW DIV 8 * 5, DW DIV 8 * 3, DH);
  FocusViewer := Viewers.This(0, 0);
  CurFnt := Fonts.Default; CurCol := Display.white; CurOff := 0;

  ActCnt := 0; CurTask := NewTask(GC, 1000); Install(CurTask);
  Modules.Load("System", Mod); Mod := NIL; Loop
END Oberon.