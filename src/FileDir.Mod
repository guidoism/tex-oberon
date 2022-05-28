MODULE FileDir;   (*NW 12.1.86 / 23.8.90 / 15.8.2013*)
  IMPORT SYSTEM, Kernel;

  (*File Directory is a B-tree with its root page at DirRootAdr.
    Each entry contains a file name and the disk address of the file's head sector*)

  CONST FnLength*    = 32;
        SecTabSize*   = 64;
        ExTabSize*   = 12;
        SectorSize*   = 1024;
        IndexSize*   = SectorSize DIV 4;
        HeaderSize*  = 352;
        DirRootAdr*  = 29;
        DirPgSize*   = 24;
        N = DirPgSize DIV 2;
        DirMark*    = 9B1EA38DH;
        HeaderMark* = 9BA71D86H;
        FillerSize = 52;

  TYPE DiskAdr      = INTEGER;
    FileName*       = ARRAY FnLength OF CHAR;
    SectorTable*    = ARRAY SecTabSize OF DiskAdr;
    ExtensionTable* = ARRAY ExTabSize OF DiskAdr;
    EntryHandler*   = PROCEDURE (name: FileName; sec: DiskAdr; VAR continue: BOOLEAN);

    FileHeader* =
      RECORD (*first page of each file on disk*)
        mark*: INTEGER;
        name*: FileName;
        aleng*, bleng*, date*: INTEGER;
        ext*:  ExtensionTable;
        sec*: SectorTable;
        fill: ARRAY SectorSize - HeaderSize OF BYTE;
      END ;

    FileHd* = POINTER TO FileHeader;
    IndexSector* = ARRAY IndexSize OF DiskAdr;
    DataSector* = ARRAY SectorSize OF BYTE;

    DirEntry* =  (*B-tree node*)
      RECORD
        name*: FileName;
        adr*:  DiskAdr; (*sec no of file header*)
        p*:    DiskAdr  (*sec no of descendant in directory*)
      END ;

    DirPage*  =
      RECORD mark*:  INTEGER;
        m*:     INTEGER;
        p0*:    DiskAdr;  (*sec no of left descendant in directory*)
        fill:  ARRAY FillerSize OF BYTE;
        e*:  ARRAY DirPgSize OF DirEntry
      END ;

  (*Exported procedures: Search, Insert, Delete, Enumerate, Init*)

  PROCEDURE Search*(name: FileName; VAR A: DiskAdr);
    VAR i, L, R: INTEGER; dadr: DiskAdr;
      a: DirPage;
  BEGIN dadr := DirRootAdr; A := 0;
    REPEAT Kernel.GetSector(dadr, a); ASSERT(a.mark = DirMark);
      L := 0; R := a.m; (*binary search*)
      WHILE L < R DO
        i := (L+R) DIV 2;
        IF name <= a.e[i].name THEN R := i ELSE L := i+1 END
      END ;
      IF (R < a.m) & (name = a.e[R].name) THEN A := a.e[R].adr (*found*)
      ELSIF R = 0 THEN dadr := a.p0
      ELSE dadr := a.e[R-1].p
      END ;
    UNTIL (dadr = 0) OR (A # 0)
  END Search;

  PROCEDURE insert(name: FileName;
                   dpg0:  DiskAdr;
                   VAR h: BOOLEAN;
                   VAR v: DirEntry;
                   fad:     DiskAdr);
    (*h = "tree has become higher and v is ascending element"*)
    VAR ch: CHAR;
      i, j, L, R: INTEGER;
      dpg1: DiskAdr;
      u: DirEntry;
      a: DirPage;

  BEGIN (*~h*) Kernel.GetSector(dpg0, a); ASSERT(a.mark = DirMark);
    L := 0; R := a.m; (*binary search*)
    WHILE L < R DO
      i := (L+R) DIV 2;
      IF name <= a.e[i].name THEN R := i ELSE L := i+1 END
    END ;
    IF (R < a.m) & (name = a.e[R].name) THEN
      a.e[R].adr := fad; Kernel.PutSector(dpg0, a)  (*replace*)
    ELSE (*not on this page*)
      IF R = 0 THEN dpg1 := a.p0 ELSE dpg1 := a.e[R-1].p END ;
      IF dpg1 = 0 THEN (*not in tree, insert*)
        u.adr := fad; u.p := 0; h := TRUE; j := 0;
        REPEAT ch := name[j]; u.name[j] := ch; INC(j)
        UNTIL ch = 0X;
        WHILE j < FnLength DO u.name[j] := 0X; INC(j) END ;
      ELSE
        insert(name, dpg1, h, u, fad)
      END ;
      IF h THEN (*insert u to the left of e[R]*)
        IF a.m < DirPgSize THEN
          h := FALSE; i := a.m;
          WHILE i > R DO DEC(i); a.e[i+1] := a.e[i] END ;
          a.e[R] := u; INC(a.m)
        ELSE (*split page and assign the middle element to v*)
          a.m := N; a.mark := DirMark;
          IF R < N THEN (*insert in left half*)
            v := a.e[N-1]; i := N-1;
            WHILE i > R DO DEC(i); a.e[i+1] := a.e[i] END ;
            a.e[R] := u; Kernel.PutSector(dpg0, a);
            Kernel.AllocSector(dpg0, dpg0); i := 0;
            WHILE i < N DO a.e[i] := a.e[i+N]; INC(i) END
          ELSE (*insert in right half*)
            Kernel.PutSector(dpg0, a);
            Kernel.AllocSector(dpg0, dpg0); DEC(R, N); i := 0;
            IF R = 0 THEN v := u
            ELSE v := a.e[N];
              WHILE i < R-1 DO a.e[i] := a.e[N+1+i]; INC(i) END ;
              a.e[i] := u; INC(i)
            END ;
            WHILE i < N DO a.e[i] := a.e[N+i]; INC(i) END
          END ;
          a.p0 := v.p; v.p := dpg0
        END ;
        Kernel.PutSector(dpg0, a)
      END
    END
  END insert;

  PROCEDURE Insert*(name: FileName; fad: DiskAdr);
    VAR  oldroot: DiskAdr;
      h: BOOLEAN; U: DirEntry;
      a: DirPage;
  BEGIN h := FALSE;
    insert(name, DirRootAdr, h, U, fad);
    IF h THEN (*root overflow*)
      Kernel.GetSector(DirRootAdr, a); ASSERT(a.mark = DirMark);
      Kernel.AllocSector(DirRootAdr, oldroot); Kernel.PutSector(oldroot, a);
      a.mark := DirMark; a.m := 1; a.p0 := oldroot; a.e[0] := U;
      Kernel.PutSector(DirRootAdr, a)
    END
  END Insert;


  PROCEDURE underflow(VAR c: DirPage;  (*ancestor page*)
                      dpg0:  DiskAdr;
                      s:     INTEGER;  (*insertion point in c*)
                      VAR h: BOOLEAN); (*c undersize*)
    VAR i, k: INTEGER;
        dpg1: DiskAdr;
        a, b: DirPage;  (*a := underflowing page, b := neighbouring page*)
  BEGIN Kernel.GetSector(dpg0, a); ASSERT(a.mark = DirMark);
    (*h & a.m = N-1 & dpg0 = c.e[s-1].p*)
    IF s < c.m THEN (*b := page to the right of a*)
      dpg1 := c.e[s].p; Kernel.GetSector(dpg1, b); ASSERT(b.mark = DirMark);
      k := (b.m-N+1) DIV 2; (*k = no. of items available on page b*)
      a.e[N-1] := c.e[s]; a.e[N-1].p := b.p0;
      IF k > 0 THEN
        (*move k-1 items from b to a, one to c*) i := 0;
        WHILE i < k-1 DO a.e[i+N] := b.e[i]; INC(i) END ;
        c.e[s] := b.e[i]; b.p0 := c.e[s].p;
        c.e[s].p := dpg1; b.m := b.m - k; i := 0;
        WHILE i < b.m DO b.e[i] := b.e[i+k]; INC(i) END ;
        Kernel.PutSector(dpg1, b); a.m := N-1+k; h := FALSE
      ELSE (*merge pages a and b, discard b*) i := 0;
        WHILE i < N DO a.e[i+N] := b.e[i]; INC(i) END ;
        i := s; DEC(c.m);
        WHILE i < c.m DO c.e[i] := c.e[i+1]; INC(i) END ;
        a.m := 2*N; h := c.m < N
      END ;
      Kernel.PutSector(dpg0, a)
    ELSE (*b := page to the left of a*) DEC(s);
      IF s = 0 THEN dpg1 := c.p0 ELSE dpg1 := c.e[s-1].p END ;
      Kernel.GetSector(dpg1, b); ASSERT(b.mark = DirMark);
      k := (b.m-N+1) DIV 2; (*k = no. of items available on page b*)
      IF k > 0 THEN
        i := N-1;
        WHILE i > 0 DO DEC(i); a.e[i+k] := a.e[i] END ;
        i := k-1; a.e[i] := c.e[s]; a.e[i].p := a.p0;
        (*move k-1 items from b to a, one to c*) b.m := b.m - k;
        WHILE i > 0 DO DEC(i); a.e[i] := b.e[i+b.m+1] END ;
        c.e[s] := b.e[b.m]; a.p0 := c.e[s].p;
        c.e[s].p := dpg0; a.m := N-1+k; h := FALSE;
        Kernel.PutSector(dpg0, a)
      ELSE (*merge pages a and b, discard a*)
        c.e[s].p := a.p0; b.e[N] := c.e[s]; i := 0;
        WHILE i < N-1 DO b.e[i+N+1] := a.e[i]; INC(i) END ;
        b.m := 2*N; DEC(c.m); h := c.m < N
      END ;
      Kernel.PutSector(dpg1, b)
    END
  END underflow;

  PROCEDURE delete(name: FileName;
                   dpg0: DiskAdr;
                   VAR h: BOOLEAN;
                   VAR fad: DiskAdr);
  (*search and delete entry with key name; if a page underflow arises,
    balance with adjacent page or merge; h := "page dpg0 is undersize"*)

    VAR i, L, R: INTEGER;
      dpg1: DiskAdr;
      a: DirPage;

    PROCEDURE del(VAR a: DirPage; R: INTEGER; dpg1: DiskAdr; VAR h: BOOLEAN);
      VAR dpg2: DiskAdr;  (*global: a, R*)
          b: DirPage;
    BEGIN Kernel.GetSector(dpg1, b); ASSERT(b.mark = DirMark); dpg2 := b.e[b.m-1].p;
      IF dpg2 # 0 THEN del(a, R, dpg2, h);
        IF h THEN underflow(b, dpg2, b.m, h); Kernel.PutSector(dpg1, b) END
      ELSE
        b.e[b.m-1].p := a.e[R].p; a.e[R] := b.e[b.m-1];
        DEC(b.m); h := b.m < N; Kernel.PutSector(dpg1, b)
      END
    END del;

  BEGIN (*~h*) Kernel.GetSector(dpg0, a); ASSERT(a.mark = DirMark);
    L := 0; R := a.m; (*binary search*)
    WHILE L < R DO
      i := (L+R) DIV 2;
      IF name <= a.e[i].name THEN R := i ELSE L := i+1 END
    END ;
    IF R = 0 THEN dpg1 := a.p0 ELSE dpg1 := a.e[R-1].p END ;
    IF (R < a.m) & (name = a.e[R].name) THEN
      (*found, now delete*) fad := a.e[R].adr;
      IF dpg1 = 0 THEN  (*a is a leaf page*)
        DEC(a.m); h := a.m < N; i := R;
        WHILE i < a.m DO a.e[i] := a.e[i+1]; INC(i) END
      ELSE del(a, R, dpg1, h);
        IF h THEN underflow(a, dpg1, R, h) END
      END ;
      Kernel.PutSector(dpg0, a)
    ELSIF dpg1 # 0 THEN
      delete(name, dpg1, h, fad);
      IF h THEN underflow(a, dpg1, R, h); Kernel.PutSector(dpg0, a) END
    ELSE (*not in tree*) fad := 0
    END
  END delete;

  PROCEDURE Delete*(name: FileName; VAR fad: DiskAdr);
    VAR h: BOOLEAN; newroot: DiskAdr;
      a: DirPage;
  BEGIN h := FALSE;
    delete(name, DirRootAdr, h, fad);
    IF h THEN (*root underflow*)
      Kernel.GetSector(DirRootAdr, a); ASSERT(a.mark = DirMark);
      IF (a.m = 0) & (a.p0 # 0) THEN
        newroot := a.p0; Kernel.GetSector(newroot, a); ASSERT(a.mark = DirMark);
        Kernel.PutSector(DirRootAdr, a) (*discard newroot*)
      END
    END
  END Delete;

  PROCEDURE enumerate(prefix:   ARRAY OF CHAR;
                      dpg:          DiskAdr;
                      proc:         EntryHandler;
                      VAR continue: BOOLEAN);
    VAR i, j: INTEGER; pfx, nmx: CHAR;
      dpg1: DiskAdr; a: DirPage;
  BEGIN Kernel.GetSector(dpg, a); ASSERT(a.mark = DirMark); i := 0;
    WHILE (i < a.m) & continue DO
      j := 0;
      REPEAT pfx := prefix[j]; nmx := a.e[i].name[j]; INC(j)
      UNTIL (nmx # pfx) OR (pfx = 0X);
      IF nmx >= pfx THEN
        IF i = 0 THEN dpg1 := a.p0 ELSE dpg1 := a.e[i-1].p END ;
        IF dpg1 # 0 THEN enumerate(prefix, dpg1, proc, continue) END ;
        IF pfx = 0X THEN
          IF continue THEN proc(a.e[i].name, a.e[i].adr, continue) END
        ELSE continue := FALSE
        END
      END ;
      INC(i)
    END ;
    IF continue & (i > 0) & (a.e[i-1].p # 0) THEN
      enumerate(prefix, a.e[i-1].p, proc, continue)
    END
  END enumerate;

  PROCEDURE Enumerate*(prefix: ARRAY OF CHAR; proc: EntryHandler);
    VAR b: BOOLEAN;
  BEGIN b := TRUE; enumerate(prefix, DirRootAdr, proc, b)
  END Enumerate;

(* ----- initialization ----- *)

PROCEDURE Init*;
    VAR k: INTEGER;
        A: ARRAY 2000 OF DiskAdr;

    PROCEDURE MarkSectors(VAR A: ARRAY OF DiskAdr; k: INTEGER);
      VAR L, R, i, j, n: INTEGER; x: DiskAdr;
        hd: FileHeader;
        B: IndexSector;

      PROCEDURE sift(VAR A: ARRAY OF DiskAdr; L, R: INTEGER);
        VAR i, j: INTEGER; x: DiskAdr;
      BEGIN j := L; x := A[j];
        REPEAT i := j; j := 2*j + 1;
          IF (j+1 < R) & (A[j] < A[j+1]) THEN INC(j) END ;
          IF (j < R) & (x <= A[j]) THEN A[i] := A[j] END
        UNTIL (j >= R) OR (x > A[j]);
        A[i] := x
      END sift;

    BEGIN L := k DIV 2; R := k; (*heapsort*)
      WHILE L > 0 DO DEC(L); sift(A, L, R) END ;
      WHILE R > 0 DO
        DEC(R); x := A[0]; A[0] := A[R]; A[R] := x; sift(A, L, R)
      END ;
      WHILE L < k DO
        Kernel.GetSector(A[L], hd); ASSERT(hd.mark = HeaderMark);
        IF hd.aleng < SecTabSize THEN j := hd.aleng + 1;
          REPEAT DEC(j); Kernel.MarkSector(hd.sec[j]) UNTIL j = 0
        ELSE j := SecTabSize;
          REPEAT DEC(j); Kernel.MarkSector(hd.sec[j]) UNTIL j = 0;
          n := (hd.aleng - SecTabSize) DIV 256; i := 0;
          WHILE i <= n DO
            Kernel.MarkSector(hd.ext[i]);
            Kernel.GetSector(hd.ext[i], B); (*index sector*)
            IF i < n THEN j := 256 ELSE j := (hd.aleng - SecTabSize) MOD 256 + 1 END ;
            REPEAT DEC(j); Kernel.MarkSector(B[j]) UNTIL j = 0;
            INC(i)
          END
        END ;
        INC(L)
      END
    END MarkSectors;

    PROCEDURE TraverseDir(VAR A: ARRAY OF DiskAdr; VAR k: INTEGER; dpg: DiskAdr);
      VAR i: INTEGER; a: DirPage;
    BEGIN Kernel.GetSector(dpg, a); ASSERT(a.mark = DirMark); Kernel.MarkSector(dpg); i := 0;
      WHILE i < a.m DO
        A[k] := a.e[i].adr; INC(k); INC(i);
        IF k = 2000 THEN MarkSectors(A, k); k := 0 END
      END ;
      IF a.p0 # 0 THEN
        TraverseDir(A, k, a.p0); i := 0;
        WHILE i < a.m DO
          TraverseDir(A, k, a.e[i].p); INC(i)
        END
      END
    END TraverseDir;

  BEGIN k := 0; TraverseDir(A, k, DirRootAdr); MarkSectors(A, k)
  END Init; 
  
END FileDir.
