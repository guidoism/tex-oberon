MODULE Files;  (*NW 11.1.86 / 22.9.93 / 25.5.95 / 25.12.95 / 15.8.2013*)
  IMPORT SYSTEM, Kernel, FileDir;

  (*A file consists of a sequence of pages. The first page
    contains the header. Part of the header is the page table, an array
    of disk addresses to the pages. A file is referenced through riders.
    A rider indicates a current position and refers to a file*)

  CONST MaxBufs    = 4;
      HS        = FileDir.HeaderSize;
      SS        = FileDir.SectorSize;
      STS       = FileDir.SecTabSize;
      XS        = FileDir.IndexSize;

  TYPE  DiskAdr = INTEGER;
      File*    = POINTER TO FileDesc;
      Buffer  = POINTER TO BufferRecord;
      Index   = POINTER TO IndexRecord;

    Rider* =
      RECORD eof*: BOOLEAN;
        res*: INTEGER;
        file: File;
        apos, bpos: INTEGER;
        buf: Buffer
      END ;

    FileDesc =
      RECORD next: INTEGER; (*list of files invisible to the GC*)
        nofbufs, aleng, bleng: INTEGER;
        modH, registered: BOOLEAN;
        firstbuf: Buffer;
        sechint: DiskAdr;
        name: FileDir.FileName;
        date: INTEGER;
        ext:  ARRAY FileDir.ExTabSize OF Index;
        sec: FileDir.SectorTable
      END ;

    BufferRecord =
      RECORD apos, lim: INTEGER;
        mod: BOOLEAN;
        next: Buffer;
        data: FileDir.DataSector
      END ;

    IndexRecord =
      RECORD adr: DiskAdr;
        mod: BOOLEAN;
        sec: FileDir.IndexSector
      END ;

    (*aleng * SS + bleng = length (including header)
      apos * SS + bpos = current position
      0 <= bpos <= lim <= SS
      0 <= apos <= aleng < PgTabSize
      (apos < aleng) & (lim = SS) OR (apos = aleng) *)

  VAR root: INTEGER (*File*);  (*list of open files*)

  PROCEDURE Check(s: ARRAY OF CHAR;
        VAR name: FileDir.FileName; VAR res: INTEGER);
    VAR i: INTEGER; ch: CHAR;
  BEGIN ch := s[0]; i := 0;
    IF (ch >= "A") & (ch <= "Z") OR (ch >= "a") & (ch <= "z") THEN
      REPEAT name[i] := ch; INC(i); ch := s[i]
      UNTIL ~((ch >= "0") & (ch <= "9") OR (ch >= "A") & (ch <= "Z")
        OR (ch >= "a") & (ch <= "z") OR (ch = ".")) OR (i = FileDir.FnLength);
      IF i = FileDir.FnLength THEN res := 4
      ELSIF ch = 0X THEN res := 0;
        WHILE i < FileDir.FnLength DO name[i] := 0X; INC(i) END
      ELSE res := 5
      END
    ELSIF ch = 0X THEN name[0] := 0X; res := -1
    ELSE res := 3
    END
  END Check;

  PROCEDURE Old*(name: ARRAY OF CHAR): File;
    VAR i, k, res: INTEGER;
      f: File;
      header: DiskAdr;
      buf: Buffer;
      F: FileDir.FileHd;
      namebuf: FileDir.FileName;
      inxpg: Index;
  BEGIN f := NIL; Check(name, namebuf, res);
    IF res = 0 THEN
      FileDir.Search(namebuf, header);
      IF header # 0 THEN
        f := SYSTEM.VAL(File, root);
        WHILE (f # NIL) & (f.sec[0] # header) DO f := SYSTEM.VAL(File, f.next) END ;
        IF f = NIL THEN (*file not yet present*)
          NEW(buf); buf.apos := 0; buf.next := buf; buf.mod := FALSE;
          F := SYSTEM.VAL(FileDir.FileHd, SYSTEM.ADR(buf.data));
          Kernel.GetSector(header, buf.data); ASSERT(F.mark = FileDir.HeaderMark);
          NEW(f); f.aleng := F.aleng; f.bleng := F.bleng; f.date := F.date;
          IF f.aleng = 0 THEN buf.lim := f.bleng ELSE buf.lim := SS END ;
          f.firstbuf := buf; f.nofbufs := 1; f.name := namebuf; f.registered := TRUE;
          f.sec := F.sec;
          k := (f.aleng + (XS-STS)) DIV XS; i := 0;
          WHILE i < k DO
            NEW(inxpg); inxpg.adr := F.ext[i]; inxpg.mod := FALSE;
            Kernel.GetSector(inxpg.adr, inxpg.sec); f.ext[i] := inxpg; INC(i)
          END ;
          WHILE i < FileDir.ExTabSize DO f.ext[i] := NIL; INC(i) END ;
          f.sechint := header; f.modH := FALSE; f.next := root; root := SYSTEM.VAL(INTEGER, f)
        END
      END
    END ;
    RETURN f
  END Old;

  PROCEDURE New*(name: ARRAY OF CHAR): File;
    VAR i, res: INTEGER;
      f: File;
      buf: Buffer;
      F: FileDir.FileHd;
      namebuf: FileDir.FileName;
  BEGIN f := NIL; Check(name, namebuf, res);
    IF res <= 0 THEN
      NEW(buf); buf.apos := 0; buf.mod := TRUE; buf.lim := HS; buf.next := buf;
      F := SYSTEM.VAL(FileDir.FileHd, SYSTEM.ADR(buf.data));
      F.mark := FileDir.HeaderMark;
      F.aleng := 0; F.bleng := HS; F.name := namebuf;
      F.date := Kernel.Clock();
      NEW(f); f.aleng := 0; f.bleng := HS; f.modH := TRUE;
      f.registered := FALSE; f.date := F.date;
      f.firstbuf := buf; f.nofbufs := 1; f.name := namebuf; f.sechint := 0;
      i := 0;
      REPEAT f.ext[i] := NIL; F.ext[i] := 0; INC(i) UNTIL i = FileDir.ExTabSize;
      i := 0;
      REPEAT f.sec[i] := 0; F.sec[i] := 0; INC(i) UNTIL i = STS
    END ;
    RETURN f
  END New;

  PROCEDURE UpdateHeader(f: File; VAR F: FileDir.FileHeader);
    VAR k: INTEGER;
  BEGIN F.aleng := f.aleng; F.bleng := f.bleng;
    F.sec := f.sec; k := (f.aleng + (XS-STS)) DIV XS;
    WHILE k > 0 DO DEC(k); F.ext[k] := f.ext[k].adr END
  END UpdateHeader;

  PROCEDURE ReadBuf(f: File; buf: Buffer; pos: INTEGER);
    VAR sec: DiskAdr;
  BEGIN
    IF pos < STS THEN sec := f.sec[pos]
    ELSE sec := f.ext[(pos-STS) DIV XS].sec[(pos-STS) MOD XS]
    END ;
    Kernel.GetSector(sec, buf.data);
    IF pos < f.aleng THEN buf.lim := SS ELSE buf.lim := f.bleng END ;
    buf.apos := pos; buf.mod := FALSE
  END ReadBuf;

  PROCEDURE WriteBuf(f: File; buf: Buffer);
    VAR i, k: INTEGER;
      secadr: DiskAdr; inx: Index;
  BEGIN 
    IF buf.apos < STS THEN
      secadr := f.sec[buf.apos];
      IF secadr = 0 THEN
        Kernel.AllocSector(f.sechint, secadr);
        f.modH := TRUE; f.sec[buf.apos] := secadr; f.sechint := secadr
      END ;
      IF buf.apos = 0 THEN
        UpdateHeader(f, SYSTEM.VAL(FileDir.FileHeader, buf.data)); f.modH := FALSE
      END
    ELSE i := (buf.apos - STS) DIV XS; inx := f.ext[i];
      IF inx = NIL THEN
        NEW(inx); inx.adr := 0; inx.sec[0] := 0; f.ext[i] := inx; f.modH := TRUE
      END ;
      k := (buf.apos - STS) MOD XS; secadr := inx.sec[k];
      IF secadr = 0 THEN
        Kernel.AllocSector(f.sechint, secadr);
        f.modH := TRUE; inx.mod := TRUE; inx.sec[k] := secadr; f.sechint := secadr
      END
    END ;
    Kernel.PutSector(secadr, buf.data); buf.mod := FALSE
  END WriteBuf;

  PROCEDURE Buf(f: File; pos: INTEGER): Buffer;
    VAR buf: Buffer;
  BEGIN buf := f.firstbuf;
    WHILE (buf.apos # pos) & (buf.next # f.firstbuf) DO buf := buf.next END ;
    IF buf.apos # pos THEN buf := NIL END ;
    RETURN buf
  END Buf;

  PROCEDURE GetBuf(f: File; pos: INTEGER): Buffer;
    VAR buf: Buffer;
  BEGIN buf := f.firstbuf;
    WHILE (buf.apos # pos) & (buf.next # f.firstbuf) DO buf := buf.next END ;
    IF buf.apos # pos THEN 
      IF f.nofbufs < MaxBufs THEN  (*allocate new buffer*)
        NEW(buf); buf.next := f.firstbuf.next; f.firstbuf.next := buf; INC(f.nofbufs)
      ELSE (*reuse a buffer*) f.firstbuf := buf;
        IF buf.mod THEN WriteBuf(f, buf) END
      END ;
      IF pos <= f.aleng THEN ReadBuf(f, buf, pos) ELSE buf.apos := pos; buf.lim := 0; buf.mod := FALSE END
    END ;
    RETURN buf
  END GetBuf;

  PROCEDURE Unbuffer(f: File);
    VAR i, k: INTEGER;
      buf: Buffer;
      inx: Index;
      head: FileDir.FileHeader;
  BEGIN buf := f.firstbuf;
    REPEAT
      IF buf.mod THEN WriteBuf(f, buf) END ;
      buf := buf.next
    UNTIL buf = f.firstbuf;
    k := (f.aleng + (XS-STS)) DIV XS; i := 0;
    WHILE i < k DO
      inx := f.ext[i]; INC(i);
      IF inx.mod THEN
        IF inx.adr = 0 THEN
          Kernel.AllocSector(f.sechint, inx.adr); f.sechint := inx.adr; f.modH := TRUE
        END ;
        Kernel.PutSector(inx.adr, inx.sec); inx.mod := FALSE
      END
    END ;
    IF f.modH THEN
      Kernel.GetSector(f.sec[0], head); UpdateHeader(f, head);
      Kernel.PutSector(f.sec[0], head); f.modH := FALSE
    END
  END Unbuffer;

  PROCEDURE Register*(f: File);
  BEGIN
    IF (f # NIL) & (f.name[0] # 0X) THEN
      Unbuffer(f);
      IF ~f.registered THEN
        FileDir.Insert(f.name, f.sec[0]); f.registered := TRUE; f.next := root; root := SYSTEM.VAL(INTEGER, f)
      END
    END
  END Register;

  PROCEDURE Close*(f: File);
  BEGIN
    IF f # NIL THEN Unbuffer(f) END
  END Close;

  PROCEDURE Purge*(f: File);
    VAR a, i, j, k: INTEGER;
      ind: FileDir.IndexSector;
  BEGIN
    IF f # NIL THEN a := f.aleng + 1; f.aleng := 0; f.bleng := HS;
      IF a <= STS THEN i := a;
      ELSE i := STS; DEC(a, i); j := (a-1) MOD XS; k := (a-1) DIV XS;
        WHILE k >= 0 DO
          Kernel.GetSector(f.ext[k].adr, ind);
          REPEAT DEC(j); Kernel.FreeSector(ind[j]) UNTIL j = 0;
          Kernel.FreeSector(f.ext[k].adr); j := XS; DEC(k)
        END
      END ;
      REPEAT DEC(i); Kernel.FreeSector(f.sec[i]) UNTIL i = 0
    END
  END Purge;

  PROCEDURE Delete*(name: ARRAY OF CHAR; VAR res: INTEGER);
    VAR adr: DiskAdr;
        namebuf: FileDir.FileName;
  BEGIN Check(name, namebuf, res);
    IF res = 0 THEN
      FileDir.Delete(namebuf, adr);
      IF adr = 0 THEN res := 2 END
    END
  END Delete;

  PROCEDURE Rename*(old, new: ARRAY OF CHAR; VAR res: INTEGER);
    VAR adr: DiskAdr;
        oldbuf, newbuf: FileDir.FileName;
        head: FileDir.FileHeader;
  BEGIN Check(old, oldbuf, res);
    IF res = 0 THEN
      Check(new, newbuf, res);
      IF res = 0 THEN
        FileDir.Delete(oldbuf, adr);
        IF adr # 0 THEN
          FileDir.Insert(newbuf, adr);
          Kernel.GetSector(adr, head); head.name := newbuf; Kernel.PutSector(adr, head)
        ELSE res := 2
        END
      END
    END
  END Rename;

  PROCEDURE Length*(f: File): INTEGER;
  BEGIN RETURN f.aleng * SS + f.bleng - HS
  END Length;

  PROCEDURE Date*(f: File): INTEGER;
  BEGIN RETURN f.date
  END Date;

  (*---------------------------Read---------------------------*)

  PROCEDURE Set*(VAR r: Rider; f: File; pos: INTEGER);
    VAR a, b: INTEGER;
  BEGIN  r.eof := FALSE; r.res := 0;
    IF f # NIL THEN
      IF pos < 0 THEN a := 0; b := HS
      ELSIF pos < f.aleng * SS + f.bleng - HS THEN
        a := (pos + HS) DIV SS; b := (pos + HS) MOD SS;
      ELSE a := f.aleng; b := f.bleng
      END ;
      r.file := f; r.apos := a; r.bpos := b; r.buf := f.firstbuf
    ELSE r.file:= NIL
    END
  END Set;

  PROCEDURE Pos*(VAR r: Rider): INTEGER;
  BEGIN RETURN r.apos * SS + r.bpos - HS
  END Pos;

  PROCEDURE Base*(VAR r: Rider): File;
  BEGIN RETURN r.file
  END Base;

  PROCEDURE ReadByte*(VAR r: Rider; VAR x: BYTE);
    VAR buf: Buffer;
  BEGIN
    IF r.apos # r.buf.apos THEN r.buf := GetBuf(r.file, r.apos) END ;
    IF r.bpos < r.buf.lim THEN x := r.buf.data[r.bpos]; INC(r.bpos)
    ELSIF r.apos < r.file.aleng THEN
      INC(r.apos); buf := Buf(r.file, r.apos);
      IF buf = NIL THEN
        IF r.buf.mod THEN WriteBuf(r.file, r.buf) END ;
        ReadBuf(r.file, r.buf, r.apos)
      ELSE r.buf := buf
      END ;
      x := r.buf.data[0]; r.bpos := 1
    ELSE x := 0; r.eof := TRUE
    END
  END ReadByte;

  PROCEDURE ReadBytes*(VAR r: Rider; VAR x: ARRAY OF BYTE; n: INTEGER);
    VAR i: INTEGER;
  BEGIN i := 0;  (*this implementation is to be improved*)
    WHILE i < n DO ReadByte(r, x[i]); INC(i) END
  END ReadBytes;

  PROCEDURE Read*(VAR r: Rider; VAR ch: CHAR);
    VAR buf: Buffer;  (*same as ReadByte*)
  BEGIN
    IF r.apos # r.buf.apos THEN r.buf := GetBuf(r.file, r.apos) END ;
    IF r.bpos < r.buf.lim THEN ch := CHR(r.buf.data[r.bpos]); INC(r.bpos)
    ELSIF r.apos < r.file.aleng THEN
      INC(r.apos); buf := Buf(r.file, r.apos);
      IF buf = NIL THEN
        IF r.buf.mod THEN WriteBuf(r.file, r.buf) END ;
        ReadBuf(r.file, r.buf, r.apos)
      ELSE r.buf := buf
      END ;
      ch := CHR(r.buf.data[0]); r.bpos := 1
    ELSE ch := 0X; r.eof := TRUE
    END
  END Read;

  PROCEDURE ReadInt*(VAR R: Rider; VAR x: INTEGER);
    VAR x0, x1, x2, x3: BYTE;
  BEGIN ReadByte(R, x0); ReadByte(R, x1); ReadByte(R, x2); ReadByte(R, x3);
    x := ((x3 * 100H + x2) * 100H + x1) * 100H + x0
  END ReadInt;

  PROCEDURE ReadSet*(VAR R: Rider; VAR s: SET);
    VAR n: INTEGER;
  BEGIN ReadInt(R, SYSTEM.VAL(INTEGER, s))
  END ReadSet;

  PROCEDURE ReadReal*(VAR R: Rider; VAR x: REAL);
    VAR n: INTEGER;
  BEGIN ReadInt(R, SYSTEM.VAL(INTEGER, x))
  END ReadReal;

  PROCEDURE ReadString*(VAR R: Rider; VAR x: ARRAY OF CHAR);
    VAR i: INTEGER; ch: CHAR;
  BEGIN i := 0; Read(R, ch);
    WHILE ch # 0X DO
      IF i < LEN(x)-1 THEN x[i] := ch; INC(i) END ;
      Read(R, ch)
    END ;
    x[i] := 0X
  END ReadString;

  PROCEDURE ReadNum*(VAR R: Rider; VAR x: INTEGER);
    VAR n, y: INTEGER; b: BYTE;
  BEGIN n := 32; y := 0; ReadByte(R, b);
    WHILE b >= 80H DO y := ROR(y + b-80H, 7); DEC(n, 7); ReadByte(R, b) END ;
    IF n <= 4 THEN x := ROR(y + b MOD 10H, 4) ELSE x := ASR(ROR(y + b, 7), n-7) END
  END ReadNum;
        
  (*---------------------------Write---------------------------*)

  PROCEDURE NewExt(f: File);
    VAR i, k: INTEGER; ext: Index;
  BEGIN k := (f.aleng - STS) DIV XS;
    NEW(ext); ext.adr := 0; ext.mod := TRUE; f.ext[k] := ext; i := XS;
    REPEAT DEC(i); ext.sec[i] := 0 UNTIL i = 0
  END NewExt;

  PROCEDURE WriteByte*(VAR r: Rider; x: BYTE);
    VAR f: File; buf: Buffer;
  BEGIN
    IF r.apos # r.buf.apos THEN r.buf := GetBuf(r.file, r.apos); END ;
    IF r.bpos >= r.buf.lim THEN
      IF r.bpos < SS THEN
        INC(r.buf.lim); INC(r.file.bleng); r.file.modH := TRUE
      ELSE f := r.file; WriteBuf(f, r.buf); INC(r.apos); buf := Buf(r.file, r.apos);
        IF buf = NIL THEN
          IF r.apos <= f.aleng THEN ReadBuf(f, r.buf, r.apos)
          ELSE r.buf.apos := r.apos; r.buf.lim := 1; f.aleng := f.aleng + 1; f.bleng := 1; f.modH := TRUE;
            IF (f.aleng - STS) MOD XS = 0 THEN NewExt(f) END
          END
        ELSE r.buf := buf
        END ;
        r.bpos := 0
      END
    END ;
    r.buf.data[r.bpos] := x; INC(r.bpos); r.buf.mod := TRUE
  END WriteByte;

  PROCEDURE WriteBytes*(VAR r: Rider; x: ARRAY OF BYTE; n: INTEGER);
    VAR i: INTEGER;
  BEGIN i := 0; (*this implementation is to be improed*)
    WHILE i < n DO WriteByte(r, x[i]); INC(i) END
  END WriteBytes;

  PROCEDURE Write*(VAR r: Rider; ch: CHAR);
    VAR f: File; buf: Buffer;
  BEGIN (*same as WriteByte*)
    IF r.apos # r.buf.apos THEN r.buf := GetBuf(r.file, r.apos); END ;
    IF r.bpos >= r.buf.lim THEN
      IF r.bpos < SS THEN
        INC(r.buf.lim); INC(r.file.bleng); r.file.modH := TRUE
      ELSE f := r.file; WriteBuf(f, r.buf); INC(r.apos); buf := Buf(r.file, r.apos);
        IF buf = NIL THEN
          IF r.apos <= f.aleng THEN ReadBuf(f, r.buf, r.apos)
          ELSE r.buf.apos := r.apos; r.buf.lim := 1; f.aleng := f.aleng + 1; f.bleng := 1; f.modH := TRUE;
            IF (f.aleng - STS) MOD XS = 0 THEN NewExt(f) END
          END
        ELSE r.buf := buf
        END ;
        r.bpos := 0
      END
    END ;
    r.buf.data[r.bpos] := ORD(ch); INC(r.bpos); r.buf.mod := TRUE
  END Write;

  PROCEDURE WriteInt*(VAR R: Rider; x: INTEGER);
  BEGIN WriteByte(R, x MOD 100H);
    WriteByte(R, x DIV 100H MOD 100H);
    WriteByte(R, x DIV 10000H MOD 100H);
    WriteByte(R, x DIV 1000000H MOD 100H)
  END WriteInt;

  PROCEDURE WriteSet*(VAR R: Rider; s: SET);
  BEGIN WriteInt(R, ORD(s))
  END WriteSet;

  PROCEDURE WriteReal*(VAR R: Rider; x: REAL);
  BEGIN  WriteInt(R, ORD(x))
  END WriteReal;

  PROCEDURE WriteString*(VAR R: Rider; x: ARRAY OF CHAR);
    VAR i: INTEGER; ch: CHAR;
  BEGIN i := 0;
    REPEAT ch := x[i]; Write(R, ch); INC(i) UNTIL ch = 0X
  END WriteString;

  PROCEDURE WriteNum*(VAR R: Rider; x: INTEGER);
  BEGIN
    WHILE (x < -40H) OR (x >= 40H) DO WriteByte(R, x MOD 80H + 80H); x := ASR(x, 7) END ;
    WriteByte(R, x MOD 80H)
  END WriteNum;

  (*---------------------------System use---------------------------*)

  PROCEDURE Init*;
  BEGIN root := 0; Kernel.Init; FileDir.Init
  END Init;

  PROCEDURE RestoreList*; (*after mark phase of garbage collection*)
    VAR f, f0: INTEGER;

    PROCEDURE mark(f: INTEGER): INTEGER;
      VAR m: INTEGER;
    BEGIN
      IF f = 0 THEN m := -1 ELSE SYSTEM.GET(f-4, m) END ;
      RETURN m
    END mark;

  BEGIN (*field "next" has offset 0*)
    WHILE mark(root) = 0 DO SYSTEM.GET(root, root) END ;
    f := root;
    WHILE f # 0 DO
      f0 := f;
      REPEAT SYSTEM.GET(f0, f0) UNTIL mark(f0) # 0;
      SYSTEM.PUT(f, f0); f := f0
    END
  END RestoreList;

END Files.