Program Teco;
Uses
  Stacks,
  TextBuffers,
  DOS,CRT,
  TecoSearch,
  TecoEngine;
Const
  ESC = #27;
  CrLf           : Array[0..1] of Char = #13#10;
  Version        = '1.08 alpha';
  ProgName       = 'TECO/2';

  DefaultSize    = 1000;

(******** Misc routines *******)
Type
  KeyStroke = Record
                ascii  : char;
                stroke : byte;
              End;
Const
  NullKey   : KeyStroke = (ascii:#0;stroke:0);

Function GetKey     : KeyStroke;
var
  x : KeyStroke;
begin
  x.ascii := ReadKey;
  if x.ascii = #0 then
    x.stroke := ord(ReadKey)
  else
    x.stroke := 0;
  GetKey := x;
end;

Function Qnum(X : Char):Byte;
Const
  Qxlat : Array[0..127] of Byte =
    ( 0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
      0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
      0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0,37, 0,
      1, 2, 3, 4,  5, 6, 7, 8,  9,10, 0, 0,  0, 0, 0, 0,
      0,11,12,13, 14,15,16,17, 18,19,20,21, 22,23,24,25,
     26,27,28,29, 30,31,32,33, 34,35,36, 0,  0, 0, 0, 0,
      0,11,12,13, 14,15,16,17, 18,19,20,21, 22,23,24,25,
     26,27,28,29, 30,31,32,33, 34,35,36, 0,  0, 0, 0, 0);

begin
  Qnum := Qxlat[Ord(X) AND $7f];
End;

(******** Global variables *********)
Var
  Stack,
  LoopStack  : LStack;

  QStack  : OStack;
  Done    : Boolean;
  Flags   : Array[0..37] of Longint;
  Qregs   : Array[0..37] of PTextFileBuffer;       { Q registers }
  Qnums   : Array[0..37] of Longint;    { Q registers, numeric part }

  function CmdChar(cmd : PTextFileBuffer):Char;
  var
    c : char;
  begin
    c := cmd^.ThisChar; cmd^.Move(+1);
    if c = '^' then
    begin
      c := cmd^.ThisChar; cmd^.Move(+1);
      c := Char(Lo(Ord(UpCase(C))-$40));
    end;
    CmdChar := C;
  end;

Function StringCompare(P1,P2 : Pointer):Longint;
Begin
  StringCompare := TecoSearch.StringCompare(
    PTextFileBuffer(P1),
    PTextFileBuffer(P2),
    (Flags[13] AND 1) <> 0
  );
End;




Function StringSearch(Pattern,Data : PTextFileBuffer):Longint;
Begin
  StringSearch := TecoSearch.StringSearch(
    Pattern,
    Data,
    (Flags[13] AND 1) <> 0
  );
End;

Procedure Compile_And_Execute(Var Cmd, Data : PTextFileBuffer);
Begin
End;



Procedure Execute(Var Cmd, Data : PTextFileBuffer);
Var
  Delim       : Char;        { #0 if '@' prefix used }
  ColonPrefix : Boolean;

  procedure ReInit;
  begin
    Stack.Clear;
    Delim := Esc;
  end;

(******** Numeric routines **********)

  Function GetConstant : Longint;
  Var
    T : Longint;
  Begin
    T := 0;
    Case UpCase(Cmd^.ThisChar) of
      'B'      : begin
                   Cmd^.move(+1);
                   t := 0;
                 end;
      'Z'      : begin
                   Cmd^.move(+1);
                   t := Data^.endptr;
                 end;
      '.'      : begin
                   Cmd^.move(+1);
                   T := Data^.WhereAt;
                 end;
      'H'      : begin
                   Cmd^.move(+1);
                   stack.push(0);
                   T := Data^.EndPtr;
                 end;
      '0'..'9' : While (Cmd^.ThisChar in ['0'..'9']) do
                 begin
                   t := t * 10 + (ord(Cmd^.ThisChar)-ord('0'));
                   Cmd^.Move(+1);
                 end;
    end;
    GetConstant := T;
  End;

  Function ValidNumber(Var B : PTextFileBuffer) : Boolean;
  var
    ok : boolean;
    t  : longint;
    c  : char;
    p  : textptr;
  begin
    Ok := True;
    t := 0;
    c := Cmd^.thischar;
    case c of
      '-'      : begin
                   cmd^.move(+1);
                   p := cmd^.WhereAt;
                   t := GetConstant;
                   if (p <> cmd^.WhereAt) then t := -t
                                         else t := -1;
                   if Not Stack.Empty then
                     t := Stack.Pop-t;
                 end;
      '+'      : begin
                   cmd^.move(+1);
                   t := GetConstant;
                   if Not Stack.Empty then
                     t := Stack.Pop+t;
                 end;
      '*'      : begin
                   cmd^.move(+1);
                   t := GetConstant;
                   if Not Stack.Empty then
                     t := Stack.Pop * t;
                 end;
      '/'      : begin
                   cmd^.move(+1);
                   t := GetConstant;
                   if t <> 0 then
                     if Not Stack.Empty then
                       t := Stack.Pop div t;
                 end;
      '&'      : begin
                   cmd^.move(+1);
                   t := GetConstant;
                   if Not Stack.Empty then
                     t := Stack.Pop AND t;
                 end;
      '#'      : begin
                   cmd^.move(+1);
                   t := GetConstant;
                   if Not Stack.Empty then
                     t := Stack.Pop OR t;
                 end;
    else
      p := cmd^.WhereAt;
      t := GetConstant;
      ok := p <> cmd^.WhereAt;            { If current moved, it's a vaild num }
    end;

    If Ok then Stack.Push(t);

    ValidNumber := Ok;
  end;

(******** String parameter routines **********)

  Function GetStringParam(Var B : PTextFileBuffer;
                          Var P : Pointer;
                          Var Size : NativeUint        ) : Boolean;
  Var
    Ok : Boolean;
  Begin
    If Delim = #0 then
    begin
      Delim := cmd^.ThisChar;
      cmd^.Move(+1);
    end;
    P     := cmd^.ThisCharP;    { Pointer to buffer }
    Size     := cmd^.WhereAt;      { Current char # }
    While (NOT Cmd^.AtEnd) AND (cmd^.ThisChar <> Delim) do
      cmd^.Move(+1);
    If cmd^.ThisChar = Delim then
    begin
      Size  := (cmd^.WhereAt - Size);
      Ok := True;
      cmd^.Move(+1);
    end
    else
      Ok := False;
    GetStringParam := Ok;
  End;

  procedure LineOriented(Var I,J : Longint);
  var
    k : longint;
  begin
    If Stack.Count >= 2 then
    begin
      j := stack.pop;
      i := stack.pop;
    end
    else
    begin
      if Stack.Empty then k := 1
                     else k := stack.pop;
      i := Data^.PlusLine(0);
      j := Data^.PlusLine(k);
    end;
  end; { LineOriented }

  procedure InsertMacro(Var Dest : PTextFileBuffer);
  var
    x : char;
    p1 : pointer;
    s1 : NativeUint;
  begin
    If ColonPrefix then                    { Append }
      Dest^.JumpTo(Dest^.EndPtr);
    If Stack.Empty then
    begin                                  { String insert }
      If GetStringParam(Cmd,P1,S1) then
        Dest^.Insert(P1^,S1);
    end
    else
    begin                                  { Insert ASCII }
      x := char(Stack.Pop);
      Dest^.Insert(X,1);
    end;
  end;

  function Qregister: PTextFileBuffer;
  var
    c : integer;
  begin
    c := Qnum(cmd^.ThisChar); cmd^.Move(+1);
    if qregs[c] = nil then qregs[c] := new(PTextFileBuffer,Init(DefaultSize));
    Qregister := Qregs[c];
  end;


  { scans forward for the end of a loop }
  procedure exitloop(xout : boolean);
  var
    lastchar : char;
  begin
    lastchar := #0;
    while (NOT cmd^.AtEnd) AND
          ((cmd^.thischar <> '>') OR (lastchar = 'F')) do
    begin
      lastchar := Upcase(cmd^.thischar);
      cmd^.move(+1);
    end;

    if cmd^.thischar <> '>' then
      ReportError('loop missing ending ">"!')
    else
      if xout then cmd^.move(+1);                    { Mod for skip to > }
  end;

  { returns true if inside a loop, else errors, and returns false }
  function  inloop:boolean;
  begin
    If LoopStack.Empty then
    begin
      ReportError('not in a loop!');
      inloop := false;
    end
    else
      inloop := true;
  end;

  procedure gotoelse;
  var
    lastchar : char;
  begin
    lastchar := #0;
    while (NOT cmd^.AtEnd) AND
          ( ((cmd^.thischar <> '|') AND (cmd^.thischar <> '''') )
            OR (lastchar = 'F')) do
    begin
      lastchar := Upcase(cmd^.thischar);
      cmd^.move(+1);
    end;

    if (cmd^.thischar <> '|') AND (cmd^.thischar <> '''') then
      ReportError('loop missing ending ">"!')
    else
      cmd^.move(+1);
  end;

  procedure gotoend;
  var
    lastchar : char;
  begin
    lastchar := #0;
    while (NOT cmd^.AtEnd) AND
          ((cmd^.thischar <> '''') OR (lastchar = 'F')) do
    begin
      lastchar := Upcase(cmd^.thischar);
      cmd^.move(+1);
    end;

    if cmd^.thischar <> '''' then
      ReportError('loop missing ending "''"!')
    else
      cmd^.move(+1);
  end;

Var
  C,X   : Char;
  I,J,K : Longint;
  P1,P2 : Pointer;
  S1,S2 : NativeUint;
  S     : String;
  Q     : PTextFileBuffer;
  kludge : integer;
begin
  cmd^.JumpTo(0);
  ReInit;

  While Not Cmd^.AtEnd do
  begin
    While ValidNumber(Cmd) do { nothing };
    ColonPrefix := False;
    Delim       := Esc;

    While cmd^.ThisChar in ['@',':'] do
    begin
      Case cmd^.ThisChar of
        '@'  : Delim := #0;
        ':'  : ColonPrefix := True;
      End;
      cmd^.Move(+1);
    end;

    C := CmdChar(Cmd);
    Case UpCase(C) of
{ Misc }
      #13,#10,
      ' ',','   : { Nothing };

      '='       : WriteLn(Stack.Pop);

{ Cursor Movement }
      'C'       : If Stack.Empty then Data^.Move(+1)
                                 else Data^.Move(Stack.Pop);

      'R'       : If Stack.Empty then Data^.Move(-1)
                                 else Data^.Move(-Stack.Pop);

      'J'       : If Not Stack.Empty then Data^.JumpTo(Stack.Pop);

      'L'       : If Not Stack.Empty then
                    Data^.JumpTo(Data^.PlusLine(Stack.Pop))
                  else
                    Data^.JumpTo(Data^.PlusLine(1));
{ Display }
      'T'       : begin
                    LineOriented(i,j);
                    If (i < j) then Data^.Show(i,j)
                               else Data^.Show(j,i);
                  end;

      'V'       : begin
                    if Stack.Empty then k := 1
                                   else k := Abs(Stack.Pop);
                    i := Data^.PlusLine(-k);
                    j := Data^.PlusLine( k);
                    Data^.Show(i,j);
                  end;
{ Insertion }
      'I'       : InsertMacro(Data);

{ Deletion }
      'D'       : If Stack.Empty then Data^.Delete(1)
                                 else Data^.Delete(Stack.Pop);
      'K'       : begin
                    LineOriented(i,j);
                    Data^.JumpTo(i);
                    Data^.Delete(j-i);
                  end;

{ Search and Replace }
      'N'       : begin
                    j := Data^.WhereAt;
                    if stack.Empty then k := 1
                                   else k := Stack.Pop;
                    If GetStringParam(Cmd,P1,S1) then
                    begin
                      QStack.Push(New(PTextBuffer,Cpy(P1,S1)));
                       Stack.Push( StringSearch(PTextFileBuffer(Qstack.Top),Data) );
                      Dispose(QStack.Pop,Done);
                    end;
                  end;

      'S'       : Begin
                    j := Data^.WhereAt;
                    if stack.Empty then k := 1
                                   else k := Stack.Pop;
                    If GetStringParam(Cmd,P1,S1) then
                    begin
                      QStack.Push(New(PTextBuffer,Cpy(P1,S1)));

                      While (k > 0) AND (Not Data^.AtEnd) do
                      begin
                        i := StringCompare(QStack.Top,Data);
                        if (i <> 0) then
                        begin
                          dec(k);
                          Data^.Move(PTextFileBuffer(QStack.Top)^.EndPtr); {AFTER match}
                        end
                        else
                          Data^.Move(+1);
                      end;

                      While (k < 0) AND (NOT Data^.AtEnd) do
                      begin
                        i := StringCompare(QStack.Top,Data);
                        if (i <> 0) then inc(k);
                        if k <> 0 then
                          Data^.Move(-1)
                        else
                          Data^.Move(PTextFileBuffer(QStack.Top)^.EndPtr); {AFTER match}
                      end;

                      Dispose(QStack.Pop,Done);
                    end;

                    If (k = 0) then
                      Stack.Push(i)
                    else
                    begin
                      Stack.Push( 0);
                      Data^.JumpTo(j);
                    end;
                  End;

{ FR must always TAKE the string parameter from the command line, even
  if it doesn't use it, otherwise the string becomes a TECO command, and
  disaster ensues.   Bug fixed 7/22/91 MAW

  7/23/91 Now returns size of text that would have been inserted,
          if no match preceded, for use with ; and :; commands
}
      'F'       : Begin
                    X := cmd^.ThisChar;
                    cmd^.Move(+1);
                    Case UpCase(X) of                      { Replace match }
                      'R'  : begin
                               If Stack.Empty then k := 0
                                              else k := Stack.Pop;
                               If GetStringParam(Cmd,P1,S1) then
                               begin
                                 if (k <> 0) then
                                 begin
                                   Data^.Delete(-k);
                                   Data^.Insert(P1^,S1);
                                 end
                                 else
                                   Stack.Push(S1);
                               end;
                             end;
                      '|'  : GotoElse;                     { Skip to | or ' }
                      '''' : GotoEnd;                      { Skip to ' }
                      '>'  : ExitLoop(False);              { Skip to > }
                    End;
                  End;

{ Extended commands }
      'E'       : Begin
                    X := cmd^.ThisChar;
                    cmd^.Move(+1);
                    Case UpCase(X) of
                      'B'  : if GetStringParam(Cmd,P1,S1) then
                             begin
                               s := '';
                               for kludge := 1 to S1 do
                                 s := s + char((P1+kludge-1)^);
//                               S[0] := Char(s1);
//                               System.Move(P1^,S[1],S1);
                               Data^.AssignRead(S);
                               Data^.AssignWrite(S);
                             end;
                      'C'  : begin     { close the current buffer }
                               Data^.Done;
                               Data := New(PTextFileBuffer,Init(DefaultSize));
                             end;

                      'Q'  : begin
                               q := Qregister;
                               if GetStringParam(Cmd,P1,S1) then
                               begin
                                 s := '';
                                 for kludge := 1 to S1 do
                                   s := s + char((P1+kludge-1)^);
//                                 S[0] := Char(s1);
//                                 System.Move(P1^,S[1],S1);
                                 Q^.AssignRead(S);
                               end;
                             end;

                      'R'  : if GetStringParam(Cmd,P1,S1) then
                             begin
                               s := '';
                               for kludge := 1 to S1 do
                                 s := s + char((P1+kludge-1)^);
//                               S[0] := Char(s1);
//                               System.Move(P1^,S[1],S1);
                               Data^.AssignRead(S);
                             end;
                      'T'  : Data^.Dump;
                      'W'  : if GetStringParam(Cmd,P1,S1) then
                             begin
                               s := '';
                               for kludge := 1 to S1 do
                                 s := s + char((P1+kludge-1)^);
//                               S[0] := Char(s1);
//                               System.Move(P1^,S[1],S1);
                               Data^.AssignWrite(S);
                             end;
                      'X'  : Done := True;
                      '!'  : Compile_And_Execute(Cmd,Data);
                    else
                      k := qnum(X);
                      if Stack.Empty then Stack.Push(Flags[k])
                                     else Flags[k] := Stack.Pop;
                    End;
                  End;


      'A'       : Data^.ReadPage;
      'P'       : Data^.WritePage;
      'Y'       : Begin
                    Data^.WritePage;
                    Data^.ReadPage;
                  End;

(******* Q-register commands... *******)
      ^U        : begin
                    q := Qregister;
                    if q <> nil then
                      InsertMacro(Q);
                  end;

      'G'       : begin
                    q := Qregister;
                    if q <> nil then
                      if ColonPrefix then
                        Q^.Show(0,Q^.EndPtr)
                      else
                      begin
                        k := Q^.WhereAt;
                        Q^.JumpTo(0);
                        Data^.Insert(Q^.ThisCharP^,Q^.EndPtr);
                        Q^.JumpTo(k);
                      end;
                  end;

      'Q'       : begin
                    q := Qregister;
                    if ColonPrefix then
                      Stack.Push(q^.EndPtr)
                    else
                    begin
                      if stack.empty then stack.Push(Q^.Number)
                      else
                      begin
                        k := stack.pop;
                        if (k < 0) or (k >= q^.EndPtr) then
                          Stack.push(-1)
                        else
                          Stack.Push(Longint(Q^.Ascii(k)));
                      end;
                    end;
                  end;
      'U'       : begin
                    q := Qregister;
                    k := Stack.Pop;
                    Q^.Number := k;
                  end;


      'X'       : begin
                    q := Qregister;
                    LineOriented(i,j);
                    If (i > j) then
                    begin
                      k := i;
                      i := j;
                      j := k;
                    end;
                    k := Data^.WhereAt;
                    Data^.JumpTo(i);
                    If Q <> nil then
                    begin
                      if ColonPrefix then q^.JumpTo(q^.EndPtr)
                                     else q^.Clear;
                      Q^.Insert(Data^.ThisCharP^,j-i);
                    end;
                    Data^.JumpTo(k);
                  end;

      'M'       : begin
                    q := Qregister;
                    if q <> nil then
                      Execute(Q,Data);
                  end;

(*************** Input, comment, and label commands *******************)

      ^A        : begin
                    Repeat
                      X := CmdChar(Cmd);
                      If X <> ^A then
                        Write(X);
                    Until (cmd^.AtEnd) OR (X = ^A);
                  end;

      ^T        : If Stack.Empty then
                  begin
                    k := Ord(GetKey.Ascii);
                    Stack.Push(Longint(k));
                    If (Flags[Qnum('T')] and $08) = 0 then
                      Write(Char(k));
                  end
                  else
                    Write(Char(Lo(Stack.Pop)));

      '!'       : repeat
                    X := CmdChar(Cmd);
                  until (cmd^.AtEnd) OR (X = '!');

  { 7/23/91 modified to support skipping the entire loop if n <= 0 }

      '<'       : begin
                    If Stack.Empty then i := maxint
                                   else i := Stack.Pop;
                    if i > 0 then
                    begin
                      LoopStack.Push(i);
                      LoopStack.Push(Cmd^.WhereAt);
                    end
                    else
                      ExitLoop(True);  { skip the iteration
                                         if the count is <= 0 }
                  end;

      '>'       : if InLoop then
                  begin
                    I := LoopStack.Pop;
                    J := LoopStack.Pop;
                    Dec(J);
                    If J > 0 then
                    begin
                      LoopStack.Push(J);
                      LoopStack.Push(I);
                      Cmd^.JumpTo(I);
                    end;
                  end;

  { added to allow for a big search and replace inside a loop }

      ';'       : if InLoop then
                  begin
                    if stack.empty then i := -1
                                   else i := stack.pop;
                    if ColonPrefix then i := -i -1;
                    if i >= 0 then
                      ExitLoop(True);
                  end;

      '"'       : begin
                    X := cmd^.ThisChar;
                    cmd^.Move(+1);
                    i := 0;
                    if Not Stack.Empty then i := Stack.Pop;

                    Case UpCase(X) of
      { Ascii    }    'A' : If NOT (Char(Lo(I)) In ['A'..'Z','a'..'z']) then
                              GotoElse;
      { Radix 50 }    'C' : WriteLn('Radix 50 NOT Supported!');
                      'D' : If NOT (Char(Lo(I)) In ['0'..'9']) then
                              GotoElse;
      { Equal    }    'E',
      { False    }    'F',
      { Unsuccessful} 'U' : If I <> 0 then
                              GotoElse;
      { Greater  }    'G' : If I <= 0 then
                              GotoElse;
      { Less     }    'L',
      { Success  }    'S',
      { True     }    'T' : If I >= 0 then
                              GotoElse;
      { Not Zero }    'N' : If I = 0 then
                              GotoElse;
                    else
                      ReportError('Undefined Conditional!');
                    End;
                  end;

      '|'       : gotoend;

      ''''      : begin
                    ReInit;
                  end;

      Esc       : begin
                    If cmd^.ThisChar = Esc then Exit
                                           else ReInit;
                  end;
    Else
      WriteLn('Undefined command <',C,'>');
    End;
  end;
end; { Execute() }

procedure GetCommand(var engine: TTecoEngine; var cmd : PTextFileBuffer);
var
  C,X,Last  : KeyStroke;
begin
  engine.Reset;

  c := GetKey;
  case C.ascii of
    Esc : Exit;
  else
    Cmd^.Clear;
    Write(C.ascii);
    Cmd^.Insert(C,1);
  end;

  Repeat
    Last := C;
    C := GetKey;
    Case C.ascii of
      #13       : Begin
                    WriteLn;
                    Cmd^.Insert(CrLf,2);
                  End;
      Esc       : Begin
                    Write('$');
                    Cmd^.Insert(C,1);
                  End;
      #8        : If Cmd^.WhereAt <> 0 then
                  Begin
                    Cmd^.Delete(-1);
                    Write(' ',#8,#8,' ',#8);
                  End;
    else
      Write(C.ascii);
      Cmd^.Insert(C,1);
    End; { Case C }
  Until (Last.ascii = Esc) and (C.ascii = Esc);
end;

Var
  C,X,Last  : KeyStroke;
  Current   : Integer;
  i         : integer;
  CommandP  : String;
  ExeName,
  IniName   : PathStr;
  Engine    : TTecoEngine;

  D: DirStr;
  N: NameStr;
  E: ExtStr;
Begin
  ExeName := ParamStr(0);
  IniName := 'TECO.INI';

  FSplit(ExeName, D, N, E);
  if N = '' then
    N:='TECO';
  E :='.INI';
  INIname := D + N + E;

  Engine := TTecoEngine.Create(DefaultSize);

//  CommandP := Ptr(PrefixSeg,$80);
  CommandP := '';
  For i := 1 to paramcount do
    if i <> 1 then
      CommandP := CommandP + ' ' + ParamStr(i)
    else
      CommandP := ParamStr(i);


  Current   := 0;

  Engine.Qregs[11] := PTextFileBuffer(New(PTextBuffer,Cpy(@CommandP[1],Length(CommandP)) ) );

  Engine.Qregs[37] := New(PTextFileBuffer,Load(INIname));
  Engine.Qregs[Current] := New(PTextFileBuffer,Init(DefaultSize));

  Engine.Done := False;

  Engine.Execute(Engine.Qregs[37],Engine.Qregs[Current]);
  While (Engine.Qregs[37] <> nil) AND (Engine.Qregs[current] <> nil) AND (Not Engine.Done) do
  begin
    WriteLn;
    If Engine.Qregs[36] <> nil then
      Engine.Execute(Engine.Qregs[36],Engine.Qregs[Current]);  { Z is now the "Prompt" macro }

    GetCommand(Engine, Engine.Qregs[37]);
    WriteLn;
    Engine.Execute(Engine.Qregs[37],Engine.Qregs[Current]);
  end;
  Engine.Free;
End.
