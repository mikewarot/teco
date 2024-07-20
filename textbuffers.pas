Unit TextBuffers;
Interface
Uses
  MyObj,DOS;
Const
  MaxBlockSize = $1000;  { It's small while still in development, to force
                           out bugs that pop up around the limits on size }

  Margin       = $0100;  { Amount added to a re-size operation to keep it
                           from happening all the time. }

  Abort        = 0;
  Retry        = 1;
  Ignore       = 2;

  ESC          = #27;

  MaxAvail     = 1000000;  // a quick hack to get things started
  MemAvail     = 1000000;  // more of same

Type
  TextPtr      = NativeUint;

  Buffer       = Array[0..$fff0] of Char;
  PBuffer      = ^Buffer;

  PTextBuffer      = ^TTextBuffer;
  TTextBuffer      = Object(TBaseObject)
                   Number    : Longint;

                   Constructor Init( MaxSize : NativeUint);

                   Constructor Cpy( P : Pointer;
                                    S : NativeUint);

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
                                          BSize : NativeUint);      Virtual;

                   Procedure   Show(Start,Stop : TextPtr);          Virtual;
                   Procedure   Dump;                                Virtual;
                 private
                   Data     : PBuffer;
                   Size,               { How big is the allocation }
                   Current,            { Text pointer }
                   Last     : TextPtr; { End of text pointer }
                   Modified : Boolean; { True if insert or delete }
               { Methods }
                 End;

  PTextFileBuffer = ^TTextFileBuffer;
  TTextFileBuffer = Object(TTextBuffer)
                   Constructor Init( MaxSize : NativeUint);
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

  procedure ReportError(S : String);

Implementation

  procedure ReportError(S : String);
  begin
    WriteLn(s);
    ErrorFlag := 1;
  end;


Var
  TempNum : NativeUint;


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

  Constructor TTextBuffer.Init(MaxSize : NativeUint);
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

  Constructor TTextBuffer.Cpy(P : Pointer;
                          S : NativeUint);
  Begin
    If (S >  MaxBlockSize) or
       (S >= MaxAvail) then    Fail;
    Self.Init(S);
    Self.Insert(P^,S);
    Modified := False;
    Current  := 0;
  End;

  Destructor  TTextBuffer.Done;
  Begin
    Self.Clear;
    FreeMem(Data,Size);
  End;

  Function    TTextBuffer.Resize(NewSize : TextPtr):Boolean;
  var
    tmp : PBuffer;
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

  Procedure   TTextBuffer.Clear;
  Begin
    If (Current <> 0) OR (Last <> 0) then
    begin
      Current  := 0;
      Last     := 0;
      Modified := True;
    end;
  End;

  Procedure   TTextBuffer.JumpTo(Where : TextPtr);
  Begin
    If (Where >= 0) and (Where <= Succ(Last) ) then
      Current := Where
    else
      ReportError('Jump out of range');
  End;

  Function    TTextBuffer.WhereAt : TextPtr;
  Begin
    WhereAt := Current;
  End;

  Function    TTextBuffer.EndPtr  : TextPtr;
  Begin
    EndPtr  := Last;
  End;

  Function    TTextBuffer.PlusLine(Amount : Longint): TextPtr;
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

  Function    TTextBuffer.AtEnd:Boolean;
  Begin
    AtEnd := Current >= Last;
  End;


  Function    TTextBuffer.ThisChar : Char;
  Begin
    If Current <> Last then ThisChar := Data^[Current]
                       else ThisChar := #0;
  End;

  Function    TTextBuffer.ASCII(Where : TextPtr):Char;
  Begin
    If (Where >= 0) AND (Where < Last) then ASCII := Data^[Where]
                                       else ASCII := #0;
  End;

  Function    TTextBuffer.ThisCharP : Pointer;
  Begin
    If Current <> Last then ThisCharP := @Data^[Current]
                       else ThisCharP := nil;
  End;

  Procedure   TTextBuffer.Move(Amount : Longint);
  Var
    T : Longint;
  Begin
    T := Current + Amount;
    If (T >= 0) and (T <= Succ(Last) ) then
      Current := T
    else
      ReportError('Move out of range');
  End;

  Procedure   TTextBuffer.Delete(Amount : Longint);
  Var
    T,t2 : Longint;
  Begin
    T := Current + Amount;

    If (T < 0) OR (T > Size) then ReportError('Delete Too Big!')
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

  Procedure   TTextBuffer.Insert(Var B;
                                    BSize : NativeUint);
  Begin
    If (Bsize + Last > Size) AND
       ( NOT Resize(Bsize + Last + Margin) ) then ReportError('Insert TOO BIG!')
    else
    begin
      System.Move(Data^[Current],Data^[Current+Bsize],Last-Current);
      System.Move(B,Data^[Current],Bsize);
      Inc(Current,Bsize);
      Inc(Last,   Bsize);
      Modified := True;
    end;
  End;

  Procedure   TTextBuffer.Show(Start,Stop : TextPtr);
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

  Procedure   TTextBuffer.Dump;
  Var
    i : NativeUint;
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

    (*************************  TTextFileBuffer  stuff **************************)

  Constructor TTextFileBuffer.Init(MaxSize : NativeUint);
  Begin
    TTextBuffer.Init(maxsize);
    SrcName := '';
    DstName := '';
    TmpName := '';
    FillChar(src,sizeof(src),#0);
    FillChar(dst,sizeof(dst),#0);
    Offset  := 0;
  End;

  Constructor TTextFileBuffer.Load(Name : PathStr);
  Begin
    Self.Init(MaxBlockSize);
    Self.AssignRead(Name);
  End;

  Destructor TTextFileBuffer.Done;
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
          ReportError('Error destroying old destination')
        else
          Rename(Dst,DstName);
      end;
    end;
    Self.Clear;
    FreeMem(Data,Size);
  end;

  Procedure TTextFileBuffer.AssignRead(Name : PathStr);
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

  Procedure TTextFileBuffer.AssignWrite(Name : PathStr);
  Begin
    DstName := '';
    TmpName := '';

    Assign(Dst,Name);
    {$I-} Reset(Dst,1); {$I+}
    If IOresult <> 0 then              { Output did NOT exist }
    begin
      {$I-} ReWrite(Dst,1); {$I+}
      If IOresult <> 0 then
        ReportError('Error creating destination file')
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
        ReportError('Error creating temporary file');
    end;
  End;

  Procedure TTextFileBuffer.ReadPage;
  Var
    I,J : NativeUint;
    K   : Longint;
    RecordsRead : Int64;   // the file is actually a collection of 1 byte records
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
        BlockRead(Src,Data^[Last],I,RecordsRead);
        Last := Last + RecordsRead;
        Inc(Offset,RecordsRead);
      end;
    end
    else
      ReportError('File not open for input!');
  End;

  Procedure TTextFileBuffer.WritePage;
  begin
    If (FileRec(Dst).Mode AND fmOutput) = fmOutput then
      BlockWrite(Dst,Data^,Last);
    Self.Clear;
  end;

Begin
  PointerChar := '^';
  TempNum     := 0;
  ErrorFlag   := 0;
End.
