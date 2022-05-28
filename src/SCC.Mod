MODULE SCC; (*NW 13.11.87 / 22.8.90 Ceres-2; nRF24L01+ version PR 21.7.13 / 23.12.13*)
  IMPORT SYSTEM, Kernel;

  CONST
    swi = -60; spiData = -48; spiCtrl = -44;
    netSelect = 1; spiFast = 2; netEnable = 3;
    HdrSize = 8; MaxPayload = 512; SubPacket = 32; Wait = 50; SendTries = 50;
    MaxPacket = (HdrSize + MaxPayload + SubPacket-1) DIV SubPacket *
SubPacket;

  TYPE Header* =
    RECORD valid*: BOOLEAN;
      dadr*, sadr*, typ*: BYTE;
      len*: INTEGER (*of data following header*)
    END ;

  VAR
    filter*: BOOLEAN; Adr*: BYTE; rcvd: INTEGER;
    rx: RECORD
      hd: Header;
      dat: ARRAY MaxPacket-HdrSize OF BYTE
    END;

  PROCEDURE SPICtrl(s: SET);
  BEGIN SYSTEM.PUT(spiCtrl, s);
    IF netEnable IN s THEN LED(55H) ELSE LED(0) END
  END SPICtrl;

  PROCEDURE SPI(n: INTEGER);
  BEGIN (*send (& rcv into shift reg) one byte or word, at current speed*)
    SYSTEM.PUT(spiData, n); REPEAT UNTIL SYSTEM.BIT(spiCtrl, 0) (*wait until done*)
  END SPI;

  PROCEDURE StartCmd(cmd: INTEGER);
  BEGIN SPICtrl({netSelect}); SPI(cmd)
  END StartCmd;

  PROCEDURE WriteReg1(reg, dat: INTEGER);  (*disables radio!*)
  BEGIN StartCmd(reg + 20H); SPI(dat); SPICtrl({}) (*W_REGISTER*)
  END WriteReg1;

  PROCEDURE SubRcv(dst: INTEGER);
    VAR i, dat: INTEGER;
  BEGIN
    StartCmd(061H); (*R_RX_PAYLOAD, disables radio*)
    SPICtrl({netSelect, spiFast});
    FOR i := 0 TO SubPacket-4 BY 4 DO
      SPI(-1); SYSTEM.GET(spiData, dat); SYSTEM.PUT(dst+i, dat)
    END;
    SPICtrl({}); WriteReg1(7, 40H); (*done; STATUS <= clear RX_DR*)
    SPICtrl({netEnable}) (*enable radio*)
  END SubRcv;

  PROCEDURE SubSnd(src: INTEGER; VAR timeout: BOOLEAN);
    VAR i, dat, res, t1, try: INTEGER; x, status: BYTE;
  BEGIN (*already in xmit mode*)
    StartCmd(0A0H); (*W_TX_PAYLOAD*)
    SPICtrl({netSelect, spiFast});
    FOR i := 0 TO SubPacket-4 BY 4 DO
      SYSTEM.GET(src+i, dat); SPI(dat)
    END;
    SPICtrl({}); (*end W_TX_PAYLOAD command*)
    try := 0;
    SPICtrl({netEnable, netSelect}); (*start xmit pulse, start NOP cmd*)
    REPEAT
      t1 := Kernel.Time() + Wait;
      REPEAT (*wait for sent or retransmits exceeded*);
        SPI(0FFH); SYSTEM.GET(spiData, status); (*NOP*)
        res := status DIV 10H MOD 4;
        SPICtrl({}); SPICtrl({netSelect}) (*end & restart NOP cmd, end =10us pulse on enable*)
      UNTIL res # 0;
      IF res = 2 THEN WriteReg1(7, 20H) (*TX_DS: sent, ack received; reset it*)
      ELSIF res = 1 THEN WriteReg1(7, 10H); INC(try); (*MAX_RT: retransmits exceeded; reset it*)
        IF try = SendTries THEN res := 0
        ELSE REPEAT UNTIL Kernel.Time() >= t1;
          SPICtrl({netEnable, netSelect}); (*start xmit pulse, start NOP cmd again*)
        END
      END
    UNTIL res # 1;
    timeout := (res # 2)
  END SubSnd;

  PROCEDURE Flush();
  BEGIN StartCmd(0E1H); SPICtrl({}); StartCmd(0E2H); SPICtrl({})
(*FLUSH_TX, FLUSH_RX*)
  END Flush;

  PROCEDURE ResetRcv;
  BEGIN SYSTEM.PUT(SYSTEM.ADR(rx), 0); rx.hd.len := 0; rcvd := 0
  END ResetRcv;

  PROCEDURE Listen(b: BOOLEAN);
  BEGIN
    WriteReg1(0, 07EH + ORD(b)); (*CONFIG <= mask ints; EN_CRC(2 byte), PWR_UP, PRX/PTX*)
    WriteReg1(7, 70H); (*STATUS <= clear ints*)
    IF b THEN SPICtrl({netEnable}) END (*turn radio on*)
  END Listen;

  PROCEDURE Start*(filt: BOOLEAN);
    VAR n: INTEGER;
  BEGIN filter := filt; Adr := 0;
    SYSTEM.GET(swi, n); n := n DIV 4 MOD 10H * 10 + 5;
    WriteReg1(5, n); (*RF_CH <= channel: 5, 15, 25...*)
    WriteReg1(6, 07H); (*RF_SETUP <= 1Mb for better range, 0dBm*)
    WriteReg1(11H, SubPacket); (*RX_PW_P0 <= pipe 0 payload width*)
    Flush(); Listen(TRUE); ResetRcv
  END Start;

  PROCEDURE SendPacket*(VAR head: Header; dat: ARRAY OF BYTE);
    VAR len, i, off: INTEGER; timeout: BOOLEAN; payload: ARRAY SubPacket
OF BYTE;
  BEGIN (*let any receive ack finish before turning radio off*)
    i := Kernel.Time() + Wait;
    REPEAT SPICtrl({netEnable, netSelect}); SPI(0FFH); SPICtrl({netEnable}) (*NOP*)
    UNTIL Kernel.Time() >= i;
    IF Adr = 0 THEN Adr := i MOD 100H END;
    Listen(FALSE);
    head.sadr := Adr; head.valid := TRUE;
    SYSTEM.COPY(SYSTEM.ADR(head), SYSTEM.ADR(payload), HdrSize DIV 4);
    i := HdrSize; off := 0; len := head.len;
    WHILE (len > 0) & (i < SubPacket) DO payload[i] := dat[off]; INC(i); INC(off); DEC(len) END;
    WHILE i < SubPacket DO payload[i] := 0; INC(i) END;
    SubSnd(SYSTEM.ADR(payload), timeout);
    WHILE ~timeout & (len # 0) DO i := 0; (*send the rest*)
      WHILE (len > 0) & (i < SubPacket) DO payload[i] := dat[off]; INC(i); INC(off); DEC(len) END;
      WHILE i < SubPacket DO payload[i] := 0; INC(i) END;
      SubSnd(SYSTEM.ADR(payload), timeout)
    END;
    Listen(TRUE)
  END SendPacket;

  PROCEDURE Available*(): INTEGER;
  BEGIN (*packet already rcvd*)
    RETURN rx.hd.len - rcvd
  END Available;

  PROCEDURE Receive*(VAR x: BYTE);
  BEGIN (*packet already rcvd*)
    IF rcvd < rx.hd.len THEN x := rx.dat[rcvd]; INC(rcvd) ELSE x := 0 END
  END Receive;

  PROCEDURE Rcvd(time: INTEGER): BOOLEAN;
    VAR status, fifoStatus: BYTE; rcvd: BOOLEAN;
  BEGIN time := time + Kernel.Time();
    REPEAT
      SPICtrl({netEnable, netSelect}); SPI(17H); (*R_REGISTER FIFO_STATUS*)
      SYSTEM.GET(spiData, status); SPI(-1); SYSTEM.GET(spiData, fifoStatus); SPICtrl({netEnable});
      rcvd := ODD(status DIV 40H) OR ~ODD(fifoStatus) (*RX_DR (data ready) or RX FIFO not empty*)
    UNTIL rcvd OR (Kernel.Time() >= time);
    RETURN rcvd
  END Rcvd;

  PROCEDURE ReceiveHead*(VAR head: Header);  (*actually, recv whole packet*)
    VAR adr, n: INTEGER;
  BEGIN head.valid := FALSE;
    IF Rcvd(0) THEN
      ResetRcv; adr := SYSTEM.ADR(rx); SubRcv(adr);
      n := (rx.hd.len + HdrSize - 1) DIV SubPacket;
      IF (rx.hd.len <= MaxPayload)
          & ((rx.hd.dadr = 0FFH) OR ~filter OR (Adr = 0) OR (rx.hd.dadr = Adr)) THEN
        WHILE (n > 0) & Rcvd(Wait) DO
          INC(adr, SubPacket); SubRcv(adr); DEC(n)
        END;
        rx.hd.valid := (n = 0)
      ELSE WHILE Rcvd(Wait) DO SubRcv(adr) END; ResetRcv  (*discard packet*)
      END;
      head := rx.hd
    END
  END ReceiveHead;

  PROCEDURE Skip*(m: INTEGER);
    VAR dmy: BYTE;
  BEGIN WHILE m # 0 DO Receive(dmy); DEC(m) END
  END Skip;

  PROCEDURE Stop*;
  BEGIN SPICtrl({}); Flush(); ResetRcv
  END Stop;

BEGIN Start(TRUE)
END SCC.
