Unit Buff;
{$X+}
{
  1/25/91 - Add modified flag, begin implementing file assignments, etc.

 12/03/91 - Modify TBuf.Done to clear AFTER paging out rest of file....
}
Interface
Uses
  MyObj,DOS;
Const
  MaxBlockSize = $4000;  { It's small while still in development, to force
                           out bugs that pop up around the limits on size }

  Margin       = $0100;  { Amount added to a re-size operation to keep it
                           from happening all the time. }

  Abort        = 0;
  Retry        = 1;
  Ignore       = 2;

  ESC          = #27;

Type
  TextPtr      = Word;

  Buf          = Array[0..$fff0] of Char;
  BufPtr       = ^Buf;

  PBuffer      = ^TBuffer;
  Tbuffer      = Object(TBaseObject)
                   Number    : Longint;

                   Constructor Init( MaxSize : Word);

                   Constructor Cpy( P : Pointer;
                                    S : Word);

                   Destructor  Done;                                Virtual;

                   Function    Resize(NewSize : TextPtr): Boolean;  Virtual;

                   Procedure   Clear;                               Virtual;
                   Procedure   JumpTo(Where   : TextPtr);           Virtual;
                   Function    WhereAt: TextPtr;                    Virtual;
                   Function    EndPtr : TextPtr;                    Virtual;
                   Function    PlusLine(Amount : Longint): TextPtr; Virtual;

                   Function    AtEnd:Boolean;                       Virtual;

                   Function    ThisChar : Char;                     Virtual;
                   Function    ASCII(Where : TextPtr): Char;        Virtual;
                   Function    ThisCharP : Pointer;                 Virtual;
                   Procedure   Move(Amount : Longint);              Virtual;
                   Procedure   Delete(Amount : Longint);            Virtual;
                   Procedure   Insert(Var B;
                                          BSize : Word);            Virtual;

                   Procedure   Show(Start,Stop : TextPtr);          Virtual;
                   Procedure   Dump;                                Virtual;
                 private
                   Data     : BufPtr;
                   Size,               { How big is the allocation }
                   Current,            { Text pointer }
                   Last     : TextPtr; { End of text pointer }
                   Modified : Boolean; { True if insert or delete }
               { Methods }
                 End;

  Pbuf         = ^Tbuf;
  Tbuf         = Object(Tbuffer)
                   Constructor Init( MaxSize : Word);
                   Constructor Load(  Name: PathStr );
                   Destructor  Done;                                Virtual;

                   Procedure AssignRead(Name : PathStr); Virtual;
                   Procedure AssignWrite(Name : PathStr);Virtual;

                   Procedure ReadPage;                   Virtual;
                   Procedure WritePage;                  Virtual;
                 private
                   Offset       : Longint;
                   src,dst      : File;
                   srcName,
                   tmpName,
                   dstName      : PathStr;
                 End;

Var
  PointerChar  : Char;
  ErrorFlag    : Byte;

  procedure Error(S : String);

Implementation

  procedure Error(S : String);
  begin
    WriteLn(s);
    ErrorFlag := 1;
  end;


Var
  TempNum : Word;


  Function Numb(I : LongInt;
                L : Byte): String;
  Var
    Tmp : String;
  Begin
    Str(Abs(I),Tmp);
    While Length(Tmp) < L do
      Tmp := '0' + Tmp;
    If I < 0 then
      Tmp[1] := '-';
    Numb := Tmp;
  End; { Function Numb }

  Procedure ShowPointer;
  Begin
    If PointerChar <> #0 then
      Write(PointerChar);
  End;

  Constructor TBuffer.Init(MaxSize : Word);
  Begin
    If (MaxSize >  MaxBlockSize) or
       (MaxSize >= MaxAvail) then    Fail;

    GetMem(Data,MaxSize);
    Size     := MaxSize;
    Current  := 0;
    Last     := 0;
    Modified := False;
    Number   := 0;
  End;

  Constructor TBuffer.Cpy(P : Pointer;
                          S : Word);
  Begin
    If (S >  MaxBlockSize) or
       (S >= MaxAvail) then    Fail;
    Self.Init(S);
    Self.Insert(P^,S);
    Modified := False;
    Current  := 0;
  End;

  Destructor  TBuffer.Done;
  Begin
    Self.Clear;
    FreeMem(Data,Size);
  End;

  Function    TBuffer.Resize(NewSize : TextPtr):Boolean;
  var
    tmp : bufptr;
  begin
    If (Last <= NewSize) AND (NewSize <= MaxBlockSize) then
    begin
      GetMem(Tmp,NewSize);
      If Tmp <> nil then
      begin
        System.Move(Data^,Tmp^,Last);
        FreeMem(Data,Size);
        Size := NewSize;
        Data := Tmp;
        Resize := True;
      end
      else
        Resize := False;
    end
    else
      Resize := False;
  end;

  Procedure   TBuffer.Clear;
  Begin
    If (Current <> 0) OR (Last <> 0) then
    begin
      Current  := 0;
      Last     := 0;
      Modified := True;
    end;
  End;

  Procedure   TBuffer.JumpTo(Where : TextPtr);
  Begin
    If (Where >= 0) and (Where <= Succ(Last) ) then
      Current := Where
    else
      Error('Jump out of range');
  End;

  Function    TBuffer.WhereAt : TextPtr;
  Begin
    WhereAt := Current;
  End;

  Function    TBuffer.EndPtr  : TextPtr;
  Begin
    EndPtr  := Last;
  End;

  Function    TBuffer.PlusLine(Amount : Longint): TextPtr;
  Var
    T,Left : Longint;
  Begin
    Left := Amount;
    T    := Current;
    While (Left <= 0) AND (T > 0) do
    begin
      Dec(T);
      If Data^[T] = #10 then Inc(Left);
    end;

    While (Left > 0) AND (T < Last) do
    begin
      If Data^[T] = #10 then Dec(Left);
      Inc(T);
    end;

    PlusLine := T;
  End;

  Function    TBuffer.AtEnd:Boolean;
  Begin
    AtEnd := Current >= Last;
  End;


  Function    TBuffer.ThisChar : Char;
  Begin
    If Current <> Last then ThisChar := Data^[Current]
                       else ThisChar := #0;
  End;

  Function    TBuffer.ASCII(Where : TextPtr):Char;
  Begin
    If (Where >= 0) AND (Where < Last) then ASCII := Data^[Where]
                                       else ASCII := #0;
  End;

  Function    TBuffer.ThisCharP : Pointer;
  Begin
    If Current <> Last then ThisCharP := @Data^[Current]
                       else ThisCharP := nil;
  End;

  Procedure   TBuffer.Move(Amount : Longint);
  Var
    T : Longint;
  Begin
    T := Current + Amount;
    If (T >= 0) and (T <= Succ(Last) ) then
      Current := T
    else
      Error('Move out of range');
  End;

  Procedure   TBuffer.Delete(Amount : Longint);
  Var
    T,t2 : Longint;
  Begin
    T := Current + Amount;

    If (T < 0) OR (T > Size) then Error('Delete Too Big!')
    else
    begin
      if T < Current then
      begin
        t2 := t;
        t  := current;
        current := t2;
      end;
      t2 := t - current;
      If T2 <> 0 then
      begin
        System.Move(Data^[T],Data^[Current],Last - T);
        Dec(Last,T2);
      end;
      Modified := True;
    end;
  End;

  Procedure   TBuffer.Insert(Var B;
                                    BSize : Word);
  Begin
    If (Bsize + Last > Size) AND
       ( NOT Resize(Bsize + Last + Margin) ) then Error('Insert TOO BIG!')
    else
    begin
      System.Move(Data^[Current],Data^[Current+Bsize],Last-Current);
      System.Move(B,Data^[Current],Bsize);
      Inc(Current,Bsize);
      Inc(Last,   Bsize);
      Modified := True;
    end;
  End;

  Procedure   TBuffer.Show(Start,Stop : TextPtr);
  var
    i : TextPtr;
    c : char;
  begin
    if (Start >= 0) AND (Start < Stop) AND (Stop <= Last) then
    begin
      for i := start to pred(stop) do
      begin
        if current = i then ShowPointer;
        C := data^[i];
        case c of
          ESC   : Write('$');
        else
          Write(c);
        end;
      end;
      if current = stop then ShowPointer;
    end;
  end;

  Procedure   TBuffer.Dump;
  Var
    i : Word;
  Begin
    WriteLn('Memory Available        = ',MemAvail);
    WriteLn('Current Allocation Size = ',Size);
    WriteLn('Current Text Size       = ',Last);
    WriteLn('Current Text Pointer    = ',Current);
    If Last <> 0 then
    begin
      WriteLn('---------- Dump of contents ----------');
      If Current <> 0 then
        For i := 0 to Pred(Current) do
          Write(Data^[i]);
      ShowPointer;
      If Current <> Last then
        For i := Current to Pred(Last) do
          Write(Data^[i]);
      WriteLn;
      WriteLn('----------- End of Dump --------------');
    end;
    WriteLn;
  End;

    (*************************  Tbuf  stuff **************************)

  Constructor TBuf.Init(MaxSize : Word);
  Begin
    TBuffer.Init(maxsize);
    SrcName := '';
    DstName := '';
    TmpName := '';
    FillChar(src,sizeof(src),#0);
    FillChar(dst,sizeof(dst),#0);
    Offset  := 0;
  End;

  Constructor TBuf.Load(Name : PathStr);
  Begin
    Self.Init(MaxBlockSize);
    Self.AssignRead(Name);
  End;

  Destructor TBuf.Done;
  var
    f : file;
  begin
    WritePage;
    If ((FileRec(Src).Mode AND fmInput)  = fmInput) AND
       ((FileRec(Dst).Mode AND fmOutput) = fmOutput) then
    begin
      Repeat
        WritePage;
        ReadPage;
      Until Last = 0;
      Close(Dst);
      Close(Src);
    end;

    if ((FileRec(Src).Mode AND 3) <> 0) then Close(Src);
    if ((FileRec(Dst).Mode AND 3) <> 0) then Close(Dst);

    If (TmpName <> '') AND (DstName <> '') then
    begin
      Assign(F,DstName);
      {$I-} Reset(F,1); {$I+}
      If IOresult = 0 then
      begin
        Close(F);
        {$I-} Erase(F); {$I+}
        If IOresult <> 0 then
          Error('Error destroying old destination')
        else
          Rename(Dst,DstName);
      end;
    end;
    Self.Clear;
    FreeMem(Data,Size);
  end;

  Procedure TBuf.AssignRead(Name : PathStr);
  Begin
    If SrcName = '' then
    begin
      SrcName := Name;
      Assign(Src,SrcName);
      {$I-} Reset(Src,1); {$I+}
      If IOresult <> 0 then
        SrcName := '';
    end;
    If SrcName <> '' then readpage;
  End;

  Procedure TBuf.AssignWrite(Name : PathStr);
  Begin
    DstName := '';
    TmpName := '';

    Assign(Dst,Name);
    {$I-} Reset(Dst,1); {$I+}
    If IOresult <> 0 then              { Output did NOT exist }
    begin
      {$I-} ReWrite(Dst,1); {$I+}
      If IOresult <> 0 then
        Error('Error creating destination file')
      else
        DstName := Name;
    end
    else
    begin                              { Output did exist }
      Inc(TempNum);
      tmpname := 'TECO'+Numb(TempNum,4)+'.TMP';
      dstname := Name;
      assign(dst,tmpname);
      {$I-} rewrite(dst,1); {$I+}
      If IOresult <> 0 then
        Error('Error creating temporary file');
    end;
  End;

  Procedure Tbuf.ReadPage;
  Var
    I,J : Word;
    K   : Longint;
  Begin
    If ((FileRec(Src).Mode AND fmInput) = fmInput) Then
    begin
      If (Offset = 0) then
      begin
        k := FileSize(Src);
        if (k > size) then
        begin
          if k > MaxBlockSize then k := MaxBlockSize;
          if resize(k) then writeln('Resize OK');
        end;
      end;
      I := Size - Last;
      If (I > 2) AND (FileRec(Src).Mode = fmInOut) then
      begin
        BlockRead(Src,Data^[Last],I,J);
        Last := Last + J;
        Inc(Offset,J);
      end;
    end
    else
      Error('File not open for input!');
  End;

  Procedure Tbuf.WritePage;
  begin
    If (FileRec(Dst).Mode AND fmOutput) = fmOutput then
      BlockWrite(Dst,Data^,Last);
    Self.Clear;
  end;

Begin
  PointerChar := '�';
  TempNum     := 0;
  ErrorFlag   := 0;
End.