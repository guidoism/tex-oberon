MODULE TextFrames; (*JG 8.10.90 / NW 10.5.2013 / 11.2.2017*)
  IMPORT Modules, Input, Display, Viewers, Fonts, Texts, Oberon, MenuViewers;

  CONST replace* = 0; insert* = 1; delete* = 2; unmark* = 3; (*message id*)
    BS = 8X; TAB = 9X; CR = 0DX; DEL = 7FX;

  TYPE Line = POINTER TO LineDesc;
    LineDesc = RECORD
      len: LONGINT;
      wid: INTEGER;
      eot: BOOLEAN;
      next: Line
    END;

    Location* = RECORD
      org*, pos*: LONGINT;
      dx*, x*, y*: INTEGER;
      lin: Line
    END;

    Frame* = POINTER TO FrameDesc;
    FrameDesc* = RECORD
      (Display.FrameDesc)
      text*: Texts.Text;
      org*: LONGINT;
      col*: INTEGER;
      lsp*: INTEGER;
      left*, right*, top*, bot*: INTEGER;
      markH*: INTEGER;
      time*: LONGINT;
      hasCar*, hasSel*, hasMark: BOOLEAN;
      carloc*: Location;
      selbeg*, selend*: Location;
      trailer: Line
    END;

    UpdateMsg* = RECORD (Display.FrameMsg)
      id*: INTEGER;
      text*: Texts.Text;
      beg*, end*: LONGINT
    END;

    CopyOverMsg = RECORD (Display.FrameMsg)
      text: Texts.Text;
      beg, end: LONGINT
    END;

  VAR TBuf*, DelBuf: Texts.Buffer;
    menuH*, barW*, left*, right*, top*, bot*, lsp*: INTEGER; (*standard sizes*)
    asr, dsr, selH, markW, eolW: INTEGER;
    nextCh: CHAR;
    ScrollMarker: Oberon.Marker;
    W, KW: Texts.Writer; (*keyboard writer*)

  PROCEDURE Min (i, j: INTEGER): INTEGER;
  BEGIN IF i < j THEN j := i END ;
    RETURN j
  END Min;

  (*------------------display support------------------------*)

  PROCEDURE ReplConst (col: INTEGER; F: Frame; X, Y, W, H: INTEGER; mode: INTEGER);
  BEGIN
    IF X + W <= F.X + F.W THEN Display.ReplConst(col, X, Y, W, H, mode)
    ELSIF X < F.X + F.W THEN Display.ReplConst(col, X, Y, F.X + F.W - X, H, mode)
    END
  END ReplConst;

  PROCEDURE FlipSM(X, Y: INTEGER);
    VAR DW, DH, CL: INTEGER;
  BEGIN DW := Display.Width; DH := Display.Height; CL := DW;
    IF X < CL THEN
      IF X < 3 THEN X := 3 ELSIF X > DW - 4 THEN X := DW - 4 END
    ELSE
      IF X < CL + 3 THEN X := CL + 4 ELSIF X > CL + DW - 4 THEN X := CL + DW - 4 END
    END ;
    IF Y < 6 THEN Y := 6 ELSIF Y > DH - 6 THEN Y := DH - 6 END;
    Display.CopyPattern(Display.white, Display.updown, X-4, Y-4, Display.invert)
  END FlipSM;

  PROCEDURE UpdateMark (F: Frame);  (*in scroll bar*)
    VAR oldH: INTEGER;
  BEGIN oldH := F.markH; F.markH := F.org * F.H DIV (F.text.len + 1);
    IF F.hasMark & (F.left >= barW) & (F.markH # oldH) THEN
      Display.ReplConst(Display.white, F.X + 1, F.Y + F.H - 1 - oldH, markW, 1, Display.invert);
      Display.ReplConst(Display.white, F.X + 1, F.Y + F.H - 1 - F.markH, markW, 1, Display.invert)
    END
  END UpdateMark;

  PROCEDURE SetChangeMark (F: Frame; on: BOOLEAN);  (*in corner*)
  BEGIN
    IF F.H > menuH THEN
      IF on THEN  Display.CopyPattern(Display.white, Display.block, F.X+F.W-12, F.Y+F.H-12, Display.paint)
      ELSE Display.ReplConst(F.col, F.X+F.W-12, F.Y+F.H-12, 8, 8, Display.replace)
      END
    END
  END SetChangeMark;

  PROCEDURE Width (VAR R: Texts.Reader; len: LONGINT): INTEGER;
    VAR patadr, pos: LONGINT; ox, dx, x, y, w, h: INTEGER;
  BEGIN pos := 0; ox := 0;
    WHILE pos < len DO
      Fonts.GetPat(R.fnt, nextCh, dx, x, y, w, h, patadr);
      ox := ox + dx; INC(pos); Texts.Read(R, nextCh)
    END;
    RETURN ox
  END Width;

  PROCEDURE DisplayLine (F: Frame; L: Line;
    VAR R: Texts.Reader; X, Y: INTEGER; len: LONGINT);
    VAR patadr, NX,  dx, x, y, w, h: INTEGER;
  BEGIN NX := F.X + F.W;
    WHILE (nextCh # CR) & (R.fnt # NIL) DO
      Fonts.GetPat(R.fnt, nextCh, dx, x, y, w, h, patadr);
      IF (X + x + w <= NX) & (h # 0) THEN
        Display.CopyPattern(R.col, patadr, X + x, Y + y, Display.invert)
      END;
      X := X + dx; INC(len); Texts.Read(R, nextCh)
    END;
    L.len := len + 1; L.wid := X + eolW - (F.X + F.left);
    L.eot := R.fnt = NIL; Texts.Read(R, nextCh)
  END DisplayLine;

  PROCEDURE Validate (T: Texts.Text; VAR pos: LONGINT);
    VAR R: Texts.Reader;
  BEGIN
    IF pos > T.len THEN pos := T.len
    ELSIF pos > 0 THEN
      DEC(pos); Texts.OpenReader(R, T, pos);
      REPEAT Texts.Read(R, nextCh); INC(pos) UNTIL R.eot OR (nextCh = CR)
    ELSE pos := 0
    END
  END Validate;

  PROCEDURE Mark* (F: Frame; on: BOOLEAN);
  BEGIN
    IF (F.H > 0) & (F.left >= barW) & ((F.hasMark & ~on) OR (~F.hasMark & on)) THEN
      Display.ReplConst(Display.white, F.X + 1, F.Y + F.H - 1 - F.markH, markW, 1, Display.invert)
    END;
    F.hasMark := on
  END Mark;

  PROCEDURE Restore* (F: Frame);
    VAR R: Texts.Reader; L, l: Line; curY, botY: INTEGER;
  BEGIN  Display.ReplConst(F.col, F.X, F.Y, F.W, F.H, Display.replace);
    IF F.left >= barW THEN
      Display.ReplConst(Display.white, F.X + barW - 1, F.Y, 1, F.H, Display.invert)
    END;
    Validate(F.text, F.org);
    botY := F.Y + F.bot + dsr;
    Texts.OpenReader(R, F.text, F.org); Texts.Read(R, nextCh);
    L := F.trailer; curY := F.Y + F.H - F.top - asr;
    WHILE ~L.eot & (curY >= botY) DO
      NEW(l);
      DisplayLine(F, l, R, F.X + F.left, curY, 0);
      L.next := l; L := l; curY := curY - lsp
    END;
    L.next := F.trailer;
    F.markH := F.org * F.H DIV (F.text.len + 1)
  END Restore;

  PROCEDURE Suspend* (F: Frame);
  BEGIN  F.trailer.next := F.trailer
  END Suspend;

  PROCEDURE Extend* (F: Frame; newY: INTEGER);
    VAR R: Texts.Reader; L, l: Line;
    org: LONGINT; curY, botY: INTEGER;
  BEGIN Display.ReplConst(F.col, F.X, newY, F.W, F.Y - newY, Display.replace);
    IF F.left >= barW THEN
      Display.ReplConst(Display.white, F.X + barW - 1, newY, 1, F.Y - newY, Display.invert)
    END;
    botY := F.Y + F.bot + dsr; F.H := F.H + F.Y - newY; F.Y := newY;
    IF F.trailer.next = F.trailer THEN Validate(F.text, F.org) END;
    L := F.trailer; org := F.org; curY := F.Y + F.H - F.top - asr;
    WHILE (L.next # F.trailer) & (curY >= botY) DO
      L := L.next; org := org + L.len; curY := curY - lsp
    END;
    botY := F.Y + F.bot + dsr;
    Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
    WHILE ~L.eot & (curY >= botY) DO
      NEW(l);
      DisplayLine(F, l, R, F.X + F.left, curY, 0);
      L.next := l; L := l; curY := curY - lsp
    END;
    L.next := F.trailer;
    F.markH := F.org * F.H DIV (F.text.len + 1)
  END Extend;

  PROCEDURE Reduce* (F: Frame; newY: INTEGER);
    VAR L: Line; curY, botY: INTEGER;
  BEGIN F.H := F.H + F.Y - newY; F.Y := newY;
    botY := F.Y + F.bot + dsr;
    L := F.trailer; curY := F.Y + F.H - F.top - asr;
    WHILE (L.next # F.trailer) & (curY >= botY) DO
      L := L.next; curY := curY - lsp
    END;
    L.next := F.trailer;
    IF curY + asr > F.Y THEN
      Display.ReplConst(F.col, F.X + F.left, F.Y, F.W - F.left, curY + asr - F.Y, Display.replace)
    END;
    F.markH := F.org * F.H DIV (F.text.len + 1); Mark(F, TRUE)
  END Reduce;

  PROCEDURE Show* (F: Frame; pos: LONGINT);
    VAR R: Texts.Reader; L, L0: Line;
      org: LONGINT; curY, botY, Y0: INTEGER;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      Validate(F.text, pos);
      IF pos < F.org THEN Mark(F, FALSE);
        Display.ReplConst(F.col, F.X + F.left, F.Y, F.W - F.left, F.H, Display.replace);
        botY := F.Y; F.Y := F.Y + F.H; F.H := 0;
        F.org := pos; F.trailer.next := F.trailer; Extend(F, botY); Mark(F, TRUE)
      ELSIF pos > F.org THEN
        org := F.org; L := F.trailer.next; curY := F.Y + F.H - F.top - asr;
        WHILE (L.next # F.trailer) & (org # pos) DO
          org := org + L.len; L := L.next; curY := curY - lsp;
        END;
        IF org = pos THEN
          F.org := org; F.trailer.next := L; Y0 := curY;
          WHILE L.next # F.trailer DO (*!*)
            org := org + L.len; L := L.next; curY := curY - lsp
          END;
          Display.CopyBlock (F.X + F.left, curY - dsr, F.W - F.left, Y0 + asr - (curY - dsr),
              F.X + F.left, curY - dsr + F.Y + F.H - F.top - asr - Y0, 0);
          curY := curY + F.Y + F.H - F.top - asr - Y0;
          Display.ReplConst(F.col, F.X + F.left, F.Y, F.W - F.left, curY - dsr - F.Y, Display.replace);
          botY := F.Y + F.bot + dsr;
          org := org + L.len; curY := curY - lsp;
          Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
          WHILE ~L.eot & (curY >= botY) DO
            NEW(L0); DisplayLine(F, L0, R, F.X + F.left, curY, 0);
            L.next := L0; L := L0; curY := curY - lsp
          END;
          L.next := F.trailer; UpdateMark(F)
        ELSE Mark(F, FALSE);
          Display.ReplConst(F.col, F.X + F.left, F.Y, F.W - F.left, F.H, Display.replace);
          botY := F.Y; F.Y := F.Y + F.H; F.H := 0;
          F.org := pos; F.trailer.next := F.trailer; Extend(F, botY);
          Mark(F, TRUE)
        END
      END
    END ;
    SetChangeMark(F, F.text.changed)
  END Show;

  PROCEDURE LocateLine (F: Frame; y: INTEGER; VAR loc: Location);
    VAR L: Line; org: LONGINT; cury: INTEGER;
  BEGIN org := F.org; L := F.trailer.next; cury := F.H - F.top - asr; 
    WHILE (L.next # F.trailer) & (cury > y + dsr) DO
      org := org + L.len; L := L.next; cury := cury - lsp
    END;
    loc.org := org; loc.lin := L; loc.y := cury
  END LocateLine;

  PROCEDURE LocateString (F: Frame; x, y: INTEGER; VAR loc: Location);
    VAR R: Texts.Reader;
      patadr, bpos, pos, lim: LONGINT;
      bx, ex, ox, dx, u, v, w, h: INTEGER;
  BEGIN LocateLine(F, y, loc);
    lim := loc.org + loc.lin.len - 1;
    bpos := loc.org; bx := F.left;
    pos := loc.org; ox := F.left;
    Texts.OpenReader(R, F.text, loc.org); Texts.Read(R, nextCh);
    REPEAT
      WHILE (pos # lim) & (nextCh > " ") DO (*scan string*)
        Fonts.GetPat(R.fnt, nextCh, dx, u, v, w, h, patadr);
        INC(pos); ox := ox + dx; Texts.Read(R, nextCh)
      END;
      ex := ox;
      WHILE (pos # lim) & (nextCh <= " ") DO (*scan gap*)
        Fonts.GetPat(R.fnt, nextCh, dx, u, v, w, h, patadr);
        INC(pos); ox := ox + dx; Texts.Read(R, nextCh)
      END;
      IF (pos # lim) & (ox <= x) THEN
        Fonts.GetPat(R.fnt, nextCh, dx, u, v, w, h, patadr);
        bpos := pos; bx := ox;
        INC(pos); ox := ox + dx; Texts.Read(R, nextCh)
      ELSE pos := lim
      END
    UNTIL pos = lim;
    loc.pos := bpos; loc.dx := ex - bx; loc.x := bx
  END LocateString;

  PROCEDURE LocateChar (F: Frame; x, y: INTEGER; VAR loc: Location);
    VAR R: Texts.Reader;
      patadr, pos, lim: LONGINT;
      ox, dx, u, v, w, h: INTEGER;
  BEGIN LocateLine(F, y, loc);
    lim := loc.org + loc.lin.len - 1;
    pos := loc.org; ox := F.left; dx := eolW;
    Texts.OpenReader(R, F.text, loc.org);
    WHILE pos # lim DO
      Texts.Read(R, nextCh);
      Fonts.GetPat(R.fnt, nextCh, dx, u, v, w, h, patadr);
      IF ox + dx <= x THEN
        INC(pos); ox := ox + dx;
        IF pos = lim THEN dx := eolW END
      ELSE lim := pos
      END
    END ;
    loc.pos := pos; loc.dx := dx; loc.x := ox
  END LocateChar;

  PROCEDURE LocatePos (F: Frame; pos: LONGINT; VAR loc: Location);
    VAR T: Texts.Text; R: Texts.Reader; L: Line;
      org: LONGINT; cury: INTEGER;  
  BEGIN T := F.text;
    org := F.org; L := F.trailer.next; cury := F.H - F.top - asr;
    IF pos < org THEN pos := org END;
    WHILE (L.next # F.trailer) & (pos >= org + L.len) DO
      org := org + L.len; L := L.next; cury := cury - lsp
    END;
    IF pos >= org + L.len THEN pos := org + L.len - 1 END;    
    Texts.OpenReader(R, T, org); Texts.Read(R, nextCh);
    loc.org := org; loc.pos := pos; loc.lin := L;
    loc.x := F.left + Width(R, pos - org); loc.y := cury
  END LocatePos;

  PROCEDURE Pos* (F: Frame; X, Y: INTEGER): LONGINT;
    VAR loc: Location;
  BEGIN LocateChar(F, X - F.X, Y - F.Y, loc); RETURN loc.pos
  END Pos;

  PROCEDURE FlipCaret (F: Frame);
  BEGIN
    IF (F.carloc.x < F.W) & (F.carloc.y >= 10) & (F.carloc.x + 12 < F.W) THEN
      Display.CopyPattern(Display.white, Display.hook, F.X + F.carloc.x, F.Y + F.carloc.y - 10, Display.invert)
    END
  END FlipCaret;

  PROCEDURE SetCaret* (F: Frame; pos: LONGINT);
  BEGIN LocatePos(F, pos, F.carloc); FlipCaret(F); F.hasCar := TRUE
  END SetCaret;

  PROCEDURE TrackCaret* (F: Frame; X, Y: INTEGER; VAR keysum: SET);
    VAR loc: Location; keys: SET;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      LocateChar(F, X - F.X, Y - F.Y, F.carloc);
      FlipCaret(F); keysum := {};
      REPEAT Input.Mouse(keys, X, Y); keysum := keysum + keys;
        Oberon.DrawMouseArrow(X, Y); LocateChar(F, X - F.X, Y - F.Y, loc);
        IF loc.pos # F.carloc.pos THEN FlipCaret(F); F.carloc := loc; FlipCaret(F) END
      UNTIL keys = {};
      F.hasCar := TRUE
    END
  END TrackCaret;

  PROCEDURE RemoveCaret* (F: Frame);
  BEGIN IF F.hasCar THEN FlipCaret(F); F.hasCar := FALSE END
  END RemoveCaret;

  PROCEDURE FlipSelection (F: Frame; VAR beg, end: Location);
    VAR L: Line; Y: INTEGER;
  BEGIN L := beg.lin; Y := F.Y + beg.y - 2;
    IF L = end.lin THEN ReplConst(Display.white, F, F.X + beg.x, Y, end.x - beg.x, selH, Display.invert)
    ELSE
      ReplConst(Display.white, F, F.X + beg.x, Y, F.left + L.wid - beg.x, selH, Display.invert);
      L := L.next; Y := Y - lsp;
      WHILE L # end.lin DO
        ReplConst(Display.white, F, F.X + F.left, Y, L.wid, selH, Display.invert);
        L := L.next; Y := Y - lsp
      END;
      ReplConst(Display.white, F, F.X + F.left, Y, end.x - F.left, selH, Display.invert)
    END
  END FlipSelection;

  PROCEDURE SetSelection* (F: Frame; beg, end: LONGINT);
  BEGIN
    IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend) END;
    LocatePos(F, beg, F.selbeg); LocatePos(F, end, F.selend);
    IF F.selbeg.pos < F.selend.pos THEN
      FlipSelection(F, F.selbeg, F.selend); F.time := Oberon.Time(); F.hasSel := TRUE
    END
  END SetSelection;

  PROCEDURE TrackSelection* (F: Frame; X, Y: INTEGER; VAR keysum: SET);
    VAR loc: Location; keys: SET;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend) END;
      LocateChar(F, X - F.X, Y - F.Y, loc);
      IF F.hasSel & (loc.pos = F.selbeg.pos) & (F.selend.pos = F.selbeg.pos + 1) THEN
        LocateChar(F, F.left, Y - F.Y, F.selbeg)
      ELSE F.selbeg := loc
      END;
      INC(loc.pos); loc.x := loc.x + loc.dx; F.selend := loc;
      FlipSelection(F, F.selbeg, F.selend); keysum := {};
      REPEAT
        Input.Mouse(keys, X, Y);
        keysum := keysum + keys;
        Oberon.DrawMouseArrow(X, Y);
        LocateChar(F, X - F.X, Y - F.Y, loc);
        IF loc.pos < F.selbeg.pos THEN loc := F.selbeg END;
        INC(loc.pos); loc.x := loc.x + loc.dx;
        IF loc.pos < F.selend.pos THEN FlipSelection(F, loc, F.selend); F.selend := loc
        ELSIF loc.pos > F.selend.pos THEN FlipSelection(F, F.selend, loc); F.selend := loc
        END
      UNTIL keys = {};
      F.time := Oberon.Time(); F.hasSel := TRUE
    END
  END TrackSelection;

  PROCEDURE RemoveSelection* (F: Frame);
  BEGIN IF F.hasSel THEN FlipSelection(F, F.selbeg, F.selend); F.hasSel := FALSE END
  END RemoveSelection;

  PROCEDURE TrackLine* (F: Frame; X, Y: INTEGER; VAR org: LONGINT; VAR keysum: SET);
    VAR old, new: Location; keys: SET;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      LocateLine(F, Y - F.Y, old);
      ReplConst(Display.white, F, F.X + F.left, F.Y + old.y - dsr, old.lin.wid, 2, Display.invert);
      keysum := {};
      REPEAT Input.Mouse(keys, X, Y);
        keysum := keysum + keys;
        Oberon.DrawMouse(ScrollMarker, X, Y);
        LocateLine(F, Y - F.Y, new);
        IF new.org # old.org THEN
          ReplConst(Display.white, F, F.X + F.left, F.Y + old.y - dsr, old.lin.wid, 2, Display.invert);
          ReplConst(Display.white, F, F.X + F.left, F.Y + new.y - dsr, new.lin.wid, 2, Display.invert);
          old := new
        END
       UNTIL keys = {};
       ReplConst(Display.white, F, F.X + F.left, F.Y + new.y - dsr, new.lin.wid, 2, Display.invert);
       org := new.org
    ELSE org := 0   (*<----*)
    END
  END TrackLine;

  PROCEDURE TrackWord* (F: Frame; X, Y: INTEGER; VAR pos: LONGINT; VAR keysum: SET);
    VAR old, new: Location; keys: SET;
  BEGIN
    IF F.trailer.next # F.trailer THEN
      LocateString(F, X - F.X, Y - F.Y, old);
      ReplConst(Display.white, F, F.X + old.x, F.Y + old.y - dsr, old.dx, 2, Display.invert);
      keysum := {};
      REPEAT
        Input.Mouse(keys, X, Y); keysum := keysum + keys;
        Oberon.DrawMouseArrow(X, Y);
        LocateString(F, X - F.X, Y - F.Y, new);
        IF new.pos # old.pos THEN
          ReplConst(Display.white, F, F.X + old.x, F.Y + old.y - dsr, old.dx, 2, Display.invert);
          ReplConst(Display.white, F, F.X + new.x, F.Y + new.y - dsr, new.dx, 2, Display.invert);
          old := new
        END
      UNTIL keys = {};
      ReplConst(Display.white, F, F.X + new.x, F.Y + new.y - dsr, new.dx, 2, Display.invert);
      pos := new.pos
    ELSE pos := 0  (*<----*)
    END
  END TrackWord;
  
  PROCEDURE Replace* (F: Frame; beg, end: LONGINT);
    VAR R: Texts.Reader; L: Line;
      org, len: LONGINT; curY, wid: INTEGER;
  BEGIN
    IF end > F.org THEN
      IF beg < F.org THEN beg := F.org END;
      org := F.org; L := F.trailer.next; curY := F.Y + F.H - F.top - asr; 
      WHILE (L # F.trailer) & (org + L.len <= beg) DO
        org := org + L.len; L := L.next; curY := curY - lsp
      END;
      IF L # F.trailer THEN
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        len := beg - org; wid := Width(R, len);
        ReplConst(F.col, F, F.X + F.left + wid, curY - dsr, L.wid - wid, lsp, Display.replace);
        DisplayLine(F, L, R, F.X + F.left + wid, curY, len);
        org := org + L.len; L := L.next; curY := curY - lsp;
        WHILE (L # F.trailer) & (org <= end) DO
          Display.ReplConst(F.col, F.X + F.left, curY - dsr, F.W - F.left, lsp, Display.replace);
          DisplayLine(F, L, R, F.X + F.left, curY, 0);
          org := org + L.len; L := L.next; curY := curY - lsp
        END
      END
    END;
    UpdateMark(F)
  END Replace;

  PROCEDURE Insert* (F: Frame; beg, end: LONGINT);
    VAR R: Texts.Reader; L, L0, l: Line;
      org, len: LONGINT; curY, botY, Y0, Y1, Y2, dY, wid: INTEGER;
  BEGIN
    IF beg < F.org THEN F.org := F.org + (end - beg)
    ELSE
      org := F.org; L := F.trailer.next; curY := F.Y + F.H - F.top - asr; 
      WHILE (L # F.trailer) & (org + L.len <= beg) DO
        org := org + L.len; L := L.next; curY := curY - lsp
      END;
      IF L # F.trailer THEN
        botY := F.Y + F.bot + dsr;
        Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
        len := beg - org; wid := Width(R, len);
        ReplConst (F.col, F, F.X + F.left + wid, curY - dsr, L.wid - wid, lsp, Display.replace);
        DisplayLine(F, L, R, F.X + F.left + wid, curY, len);
        org := org + L.len; curY := curY - lsp;
        Y0 := curY; L0 := L.next;
        WHILE (org <= end) & (curY >= botY) DO
          NEW(l);
          Display.ReplConst(F.col, F.X + F.left, curY - dsr, F.W - F.left, lsp, Display.replace);
          DisplayLine(F, l, R, F.X + F.left, curY, 0);
          L.next := l; L := l;
          org := org + L.len; curY := curY - lsp
        END;
        IF L0 # L.next THEN Y1 := curY;
          L.next := L0;
          WHILE (L.next # F.trailer) & (curY >= botY) DO
            L := L.next; curY := curY - lsp
          END;
          L.next := F.trailer;
          dY := Y0 - Y1;
          IF Y1 > curY + dY THEN
            Display.CopyBlock(F.X + F.left, curY + dY + lsp - dsr, F.W - F.left, Y1 - curY - dY,
              F.X + F.left, curY + lsp - dsr, 0);
            Y2 := Y1 - dY
          ELSE Y2 := curY
          END;
          curY := Y1; L := L0;
          WHILE curY # Y2 DO
            Display.ReplConst(F.col, F.X + F.left, curY - dsr, F.W - F.left, lsp, Display.replace);
            DisplayLine(F, L, R, F.X + F.left, curY, 0);
            L := L.next; curY := curY - lsp
          END
        END
      END 
    END;
    UpdateMark(F)
  END Insert;

  PROCEDURE Delete* (F: Frame; beg, end: LONGINT);
    VAR R: Texts.Reader; L, L0, l: Line;
      org, org0, len: LONGINT; curY, botY, Y0, Y1, wid: INTEGER;
  BEGIN
    IF end <= F.org THEN F.org := F.org - (end - beg)
    ELSE
      IF beg < F.org THEN
        F.trailer.next.len := F.trailer.next.len + (F.org - beg);
        F.org := beg
      END;
      org := F.org; L := F.trailer.next; curY := F.Y + F.H - F.top - asr;
      WHILE (L # F.trailer) & (org + L.len <= beg) DO
        org := org + L.len; L := L.next; curY := curY - lsp
      END;
      IF L # F.trailer THEN
        botY := F.Y + F.bot + dsr;
        org0 := org; L0 := L; Y0 := curY;
        WHILE (L # F.trailer) & (org <= end) DO
          org := org + L.len; L := L.next; curY := curY - lsp
        END;
        Y1 := curY;
        Texts.OpenReader(R, F.text, org0); Texts.Read(R, nextCh);
        len := beg - org0; wid := Width(R, len);
        ReplConst (F.col, F, F.X + F.left + wid, Y0 - dsr, L0.wid - wid, lsp, Display.replace);
        DisplayLine(F, L0, R, F.X + F.left + wid, Y0, len);
        Y0 := Y0 - lsp;
        IF L # L0.next THEN
          L0.next := L;
          L := L0; org := org0 + L0.len;
          WHILE L.next # F.trailer DO
            L := L.next; org := org + L.len; curY := curY - lsp
          END;
          Display.CopyBlock(F.X + F.left, curY + lsp - dsr, F.W - F.left, Y1 - curY,
              F.X + F.left, curY + lsp - dsr + (Y0 - Y1), 0);
          curY := curY + (Y0 - Y1);
          Display.ReplConst (F.col, F.X + F.left, F.Y, F.W - F.left, curY + lsp - (F.Y + dsr), Display.replace);
          Texts.OpenReader(R, F.text, org); Texts.Read(R, nextCh);
          WHILE ~L.eot & (curY >= botY) DO
            NEW(l);
            DisplayLine(F, l, R, F.X + F.left, curY, 0);
            L.next := l; L := l; curY := curY - lsp
          END;
          L.next := F.trailer
        END
      END
    END;
    UpdateMark(F)
  END Delete;

  PROCEDURE Recall*(VAR B: Texts.Buffer);
  BEGIN B := TBuf; NEW(TBuf); Texts.OpenBuf(TBuf)
  END Recall;

  (*------------------message handling------------------------*)

  PROCEDURE RemoveMarks (F: Frame);
  BEGIN RemoveCaret(F); RemoveSelection(F)
  END RemoveMarks;

  PROCEDURE NotifyDisplay* (T: Texts.Text; op: INTEGER; beg, end: LONGINT);
    VAR M: UpdateMsg;
  BEGIN M.id := op; M.text := T; M.beg := beg; M.end := end; Viewers.Broadcast(M)
  END NotifyDisplay;

  PROCEDURE Call* (F: Frame; pos: LONGINT; new: BOOLEAN);
    VAR S: Texts.Scanner; res: INTEGER;
  BEGIN
    Texts.OpenScanner(S, F.text, pos); Texts.Scan(S);
    IF (S.class = Texts.Name) & (S.line = 0) THEN
      Oberon.SetPar(F, F.text, pos + S.len); Oberon.Call(S.s, res);
      IF res > 0 THEN
        Texts.WriteString(W, "Call error: "); Texts.WriteString(W, Modules.importing);
        IF res = 1 THEN Texts.WriteString(W, " module not found")
        ELSIF res = 2 THEN  Texts.WriteString(W, " bad version")
        ELSIF res = 3 THEN Texts.WriteString(W, " imports ");
          Texts.WriteString(W, Modules.imported); Texts.WriteString(W, " with bad key");
        ELSIF res = 4 THEN Texts.WriteString(W, " corrupted obj file")
        ELSIF res = 5 THEN Texts.WriteString(W, " command not found")
        ELSIF res = 7 THEN Texts.WriteString(W, " insufficient space")
        END;
        Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
      END
    END
  END Call;

  PROCEDURE Write* (F: Frame; ch: CHAR; fnt: Fonts.Font; col, voff: INTEGER);
    VAR buf: Texts.Buffer;
  BEGIN (*F.hasCar*)
    IF ch = BS THEN  (*backspace*)
      IF F.carloc.pos > F.org THEN
        Texts.Delete(F.text, F.carloc.pos - 1, F.carloc.pos, DelBuf); SetCaret(F, F.carloc.pos - 1)
      END
    ELSIF ch = 3X THEN (* ctrl-c  copy*)
      IF F.hasSel THEN
        NEW(TBuf); Texts.OpenBuf(TBuf); Texts.Save(F.text, F.selbeg.pos, F.selend.pos, TBuf)
      END
    ELSIF ch = 16X THEN (*ctrl-v  paste*)
      NEW(buf); Texts.OpenBuf(buf); Texts.Copy(TBuf, buf); Texts.Insert(F.text, F.carloc.pos, buf);
      SetCaret(F, F.carloc.pos + TBuf.len)
    ELSIF ch = 18X THEN (*ctrl-x,  cut*)
      IF F.hasSel THEN
        NEW(TBuf); Texts.OpenBuf(TBuf); Texts.Delete(F.text, F.selbeg.pos, F.selend.pos, TBuf)
      END
    ELSIF (20X <= ch) & (ch <= DEL) OR (ch = CR) OR (ch = TAB) THEN
      KW.fnt := fnt; KW.col := col; KW.voff := voff; Texts.Write(KW, ch);
      Texts.Insert(F.text, F.carloc.pos, KW.buf);
      SetCaret(F, F.carloc.pos + 1)
    END
  END Write;

  PROCEDURE Defocus* (F: Frame);
  BEGIN RemoveCaret(F)
  END Defocus;

  PROCEDURE Neutralize* (F: Frame);
  BEGIN RemoveMarks(F)
  END Neutralize;

  PROCEDURE Modify* (F: Frame; id, dY, Y, H: INTEGER);
  BEGIN
    Mark(F, FALSE); RemoveMarks(F); SetChangeMark(F,  FALSE);
    IF id = MenuViewers.extend THEN
      IF dY > 0 THEN Display.CopyBlock(F.X, F.Y, F.W, F.H, F.X, F.Y + dY, 0); F.Y := F.Y + dY END;
      Extend(F, Y)
    ELSIF id = MenuViewers.reduce THEN
      Reduce(F, Y + dY);
      IF dY > 0 THEN Display.CopyBlock(F.X, F.Y, F.W, F.H, F.X, Y, 0); F.Y := Y END
    END;
    IF F.H > 0 THEN Mark(F, TRUE); SetChangeMark(F,  F.text.changed) END
  END Modify;

  PROCEDURE Open* (F: Frame; H: Display.Handler; T: Texts.Text; org: LONGINT;
        col, left, right, top, bot, lsp: INTEGER);
    VAR L: Line;
  BEGIN NEW(L);
    L.len := 0; L.wid := 0; L.eot := FALSE; L.next := L;
    F.handle := H; F.text := T; F.org := org; F.trailer := L;
    F.left := left; F.right := right; F.top := top; F.bot := bot;
    F.lsp := lsp; F.col := col; F.hasMark := FALSE; F.hasCar := FALSE; F.hasSel := FALSE
  END Open;

  PROCEDURE Copy* (F: Frame; VAR F1: Frame);
  BEGIN NEW(F1);
    Open(F1, F.handle, F.text, F.org, F.col, F.left, F.right, F.top, F.bot, F.lsp)
  END Copy;

  PROCEDURE CopyOver(F: Frame; text: Texts.Text; beg, end: LONGINT);
    VAR buf: Texts.Buffer;
  BEGIN
    IF F.hasCar THEN
      NEW(buf); Texts.OpenBuf(buf);
      Texts.Save(text, beg, end, buf); Texts.Insert(F.text, F.carloc.pos, buf);
      SetCaret(F, F.carloc.pos + (end - beg))
    END
  END CopyOver;

  PROCEDURE GetSelection* (F: Frame; VAR text: Texts.Text; VAR beg, end, time: LONGINT);
  BEGIN
    IF F.hasSel THEN
      IF F.text = text THEN
        IF F.selbeg.pos < beg THEN beg := F.selbeg.pos END ;  (*leftmost*)
        IF F.time > time THEN end := F.selend.pos; time := F.time END ; (*last selected*)
      ELSIF F.time > time THEN
        text := F.text; beg := F.selbeg.pos; end := F.selend.pos; time := F.time
      END
    END
  END GetSelection;

  PROCEDURE Update* (F: Frame; VAR M: UpdateMsg);
  BEGIN (*F.text = M.text*) SetChangeMark(F, FALSE);
    RemoveMarks(F); Oberon.RemoveMarks(F.X, F.Y, F.W, F.H);
    IF M.id = replace THEN Replace(F, M.beg, M.end)
    ELSIF M.id = insert THEN Insert(F, M.beg, M.end)
    ELSIF M.id = delete THEN Delete(F, M.beg, M.end)
    END ;
    SetChangeMark(F,  F.text.changed)
  END Update;

  PROCEDURE Edit* (F: Frame; X, Y: INTEGER; Keys: SET);
    VAR M: CopyOverMsg;
      text: Texts.Text;
      buf: Texts.Buffer;
      v: Viewers.Viewer;
      beg, end, time, pos: LONGINT;
      keysum: SET;
      fnt: Fonts.Font;
      col, voff: INTEGER;
  BEGIN
    IF X < F.X + Min(F.left, barW) THEN  (*scroll bar*)
      Oberon.DrawMouse(ScrollMarker, X, Y); keysum := Keys;
      IF Keys = {2} THEN   (*ML, scroll up*)
        TrackLine(F, X, Y, pos, keysum);
        IF (pos >= 0) & (keysum = {2}) THEN
          SetChangeMark(F, FALSE);
          RemoveMarks(F); Oberon.RemoveMarks(F.X, F.Y, F.W, F.H);
          Show(F, pos)
        END
      ELSIF Keys = {1} THEN   (*MM*)  keysum := Keys;
        REPEAT Input.Mouse(Keys, X, Y); keysum := keysum + Keys;
          Oberon.DrawMouse(ScrollMarker, X, Y)
        UNTIL Keys = {};
        IF keysum # {0, 1, 2} THEN
          IF 0 IN keysum THEN pos := 0
          ELSIF 2 IN keysum THEN pos := F.text.len - 100
          ELSE pos := (F.Y + F.H - Y) * (F.text.len) DIV F.H
          END ;
          SetChangeMark(F, FALSE);
          RemoveMarks(F); Oberon.RemoveMarks(F.X, F.Y, F.W, F.H);
          Show(F, pos)
        END
      ELSIF Keys = {0} THEN   (*MR, scroll down*)
        TrackLine(F, X, Y, pos, keysum);
        IF keysum = {0} THEN
          SetChangeMark(F, FALSE);
          RemoveMarks(F); Oberon.RemoveMarks(F.X, F.Y, F.W, F.H);
          Show(F, F.org*2 - pos - 100)
        END
      END
    ELSE  (*text area*)
      Oberon.DrawMouseArrow(X, Y);
      IF 0 IN Keys THEN  (*MR: select*)
        TrackSelection(F, X, Y, keysum);
        IF F.hasSel THEN
          IF keysum = {0, 2} THEN (*MR, ML: delete text*)
            Oberon.GetSelection(text, beg, end, time);
            Texts.Delete(text, beg, end, TBuf);
            Oberon.PassFocus(Viewers.This(F.X, F.Y)); SetCaret(F, beg)
          ELSIF keysum = {0, 1} THEN  (*MR, MM: copy to caret*)
            Oberon.GetSelection(text, beg, end, time);
            M.text := text; M.beg := beg; M.end := end;
            Oberon.FocusViewer.handle(Oberon.FocusViewer, M)
          END
        END
      ELSIF 1 IN Keys THEN  (*MM: call*)
        TrackWord(F, X, Y, pos, keysum);
        IF (pos >= 0) & ~(0 IN keysum) THEN Call(F, pos, 2 IN keysum) END
      ELSIF 2 IN Keys THEN  (*ML: set caret*)
        Oberon.PassFocus(Viewers.This(F.X, F.Y));
        TrackCaret(F, X, Y, keysum);
        IF keysum = {2, 1} THEN (*ML, MM: copy from selection to caret*)
          Oberon.GetSelection(text, beg, end, time);
           IF time >= 0 THEN
            NEW(TBuf); Texts.OpenBuf(TBuf);
            Texts.Save(text, beg, end, TBuf); Texts.Insert(F.text, F.carloc.pos, TBuf);
            SetSelection(F, F.carloc.pos, F.carloc.pos + (end  - beg));
            SetCaret(F, F.carloc.pos + (end - beg))
          ELSIF TBuf # NIL THEN
            NEW(buf); Texts.OpenBuf(buf);
            Texts.Copy(TBuf, buf); Texts.Insert(F.text, F.carloc.pos, buf);
            SetCaret(F, F.carloc.pos + buf.len)
          END
        ELSIF keysum = {2, 0} THEN (*ML, MR: copy looks*)
          Oberon.GetSelection(text, beg, end, time);
          IF time >= 0 THEN
            Texts.Attributes(F.text, F.carloc.pos, fnt, col, voff);
            IF fnt # NIL THEN Texts.ChangeLooks(text, beg, end, {0,1,2}, fnt, col, voff) END
          END
        END
      END
    END
  END Edit;

  PROCEDURE Handle* (F: Display.Frame; VAR M: Display.FrameMsg);
    VAR F1: Frame; buf: Texts.Buffer;
  BEGIN
    CASE F OF Frame:
      CASE M OF
      Oberon.InputMsg:
        IF M.id = Oberon.track THEN Edit(F, M.X, M.Y, M.keys)
        ELSIF M.id = Oberon.consume THEN
          IF F.hasCar THEN Write(F, M.ch, M.fnt, M.col, M.voff) END
        END |
      Oberon.ControlMsg:
        IF M.id = Oberon.defocus THEN Defocus(F)
        ELSIF M.id = Oberon.neutralize THEN Neutralize(F)
        END |
      Oberon.SelectionMsg:
        GetSelection(F, M.text, M.beg, M.end, M.time) |
      Oberon.CopyMsg: Copy(F, F1); M.F := F1 |
      MenuViewers.ModifyMsg: Modify(F, M.id, M.dY, M.Y, M.H) |
      CopyOverMsg: CopyOver(F, M.text, M.beg, M.end) |
      UpdateMsg: IF F.text = M.text THEN Update(F, M) END
      END
    END
  END Handle;

  (*creation*)

  PROCEDURE Menu (name, commands: ARRAY OF CHAR): Texts.Text;
    VAR T: Texts.Text;
  BEGIN NEW(T); T.notify := NotifyDisplay;  Texts.Open(T, "");
    Texts.WriteString(W, name); Texts.WriteString(W, " | ");  Texts.WriteString(W, commands);
    Texts.Append(T, W.buf); RETURN T
  END Menu;

  PROCEDURE Text* (name: ARRAY OF CHAR): Texts.Text;
    VAR T: Texts.Text;
  BEGIN NEW(T); T.notify := NotifyDisplay; Texts.Open(T, name); RETURN T
  END Text;

  PROCEDURE NewMenu* (name, commands: ARRAY OF CHAR): Frame;
    VAR F: Frame; T: Texts.Text;
  BEGIN NEW(F); T := Menu(name, commands);
    Open(F, Handle, T, 0, Display.white, left DIV 4, 0, 0, 0, lsp); RETURN F
  END NewMenu;

  PROCEDURE NewText* (text: Texts.Text; pos: LONGINT): Frame;
    VAR F: Frame;
  BEGIN NEW(F);
    Open(F, Handle, text, pos, Display.black, left, right, top, bot, lsp); RETURN F
  END NewText;

BEGIN NEW(TBuf); NEW(DelBuf);
  Texts.OpenBuf(TBuf); Texts.OpenBuf(DelBuf);
  lsp := Fonts.Default.height; menuH := lsp + 2; barW := menuH;
  left := barW + lsp DIV 2;
  right := lsp DIV 2;
  top := lsp DIV 2; bot := lsp DIV 2;
  asr := Fonts.Default.maxY;
  dsr := -Fonts.Default.minY;
  selH := lsp; markW := lsp DIV 2;
  eolW := lsp DIV 2;
  ScrollMarker.Fade := FlipSM; ScrollMarker.Draw := FlipSM;
  Texts.OpenWriter(W); Texts.OpenWriter(KW)
END TextFrames.
