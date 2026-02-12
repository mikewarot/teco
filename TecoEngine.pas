unit TecoEngine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, CRT, Stacks, TextBuffers, TecoSearch;

type
  TTecoEngine = class
  public
    Stack: LStack;
    LoopStack: LStack;
    QStack: OStack;
    Flags: array[0..37] of Longint;
    Qregs: array[0..37] of PTextFileBuffer;       { Q registers }
    Done: Boolean;
    constructor Create(ADefaultSize: Longint = 1000);
    destructor Destroy; override;
    procedure Reset;
    procedure Execute(var Cmd, Data: PTextFileBuffer);
  private
    DefaultSize: Longint;
    Esc: Char;

    function CmdChar(cmd: PTextFileBuffer): Char;
    function Qnum(X: Char): Byte;
  end;

implementation

constructor TTecoEngine.Create(ADefaultSize: Longint);
begin
  inherited Create;
  DefaultSize := ADefaultSize;
  Esc := #27;
  FillChar(Flags, SizeOf(Flags), #0);
  FillChar(Qregs, SizeOf(Qregs), #0);
  Stack.Init;
  LoopStack.Init;
  QStack.Init;
  Done := False;
end;

destructor TTecoEngine.Destroy;
var
  i: Integer;
begin
  for i := 0 to 37 do
    if Qregs[i] <> nil then
      Qregs[i]^.Done;
  Stack.Done;
  LoopStack.Done;
  QStack.Done;
  inherited Destroy;
end;

procedure TTecoEngine.Reset;
begin
  Stack.Clear;
  LoopStack.Clear;
  QStack.Clear;
end;

function TTecoEngine.CmdChar(cmd: PTextFileBuffer): Char;
var
  c: Char;
begin
  c := cmd^.ThisChar; cmd^.Move(+1);
  if c = '^' then
  begin
    c := cmd^.ThisChar; cmd^.Move(+1);
    c := Char(Lo(Ord(UpCase(c)) - $40));
  end;
  CmdChar := c;
end;

function TTecoEngine.Qnum(X: Char): Byte;
const
  Qxlat: array[0..127] of Byte =
    ( 0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
      0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,
      0, 0, 0, 0,  0, 0, 0, 0,  0, 0, 0, 0,  0, 0,37, 0,
      1, 2, 3, 4,  5, 6, 7, 8,  9,10, 0, 0,  0, 0, 0, 0,
      0,11,12,13, 14,15,16,17, 18,19,20,21, 22,23,24,25,
     26,27,28,29, 30,31,32,33, 34,35,36, 0,  0, 0, 0, 0,
      0,11,12,13, 14,15,16,17, 18,19,20,21, 22,23,24,25,
     26,27,28,29, 30,31,32,33, 34,35,36, 0,  0, 0, 0, 0);
begin
  Qnum := Qxlat[Ord(X) and $7f];
end;

procedure TTecoEngine.Execute(var Cmd, Data: PTextFileBuffer);
var
  Delim: Char;        { #0 if '@' prefix used }
  ColonPrefix: Boolean;

  procedure ReInit;
  begin
    Stack.Clear;
    Delim := Esc;
  end;

  function GetConstant: Longint;
  var
    T: Longint;
  begin
    T := 0;
    case UpCase(Cmd^.ThisChar) of
      'B': begin
             Cmd^.move(+1);
             t := 0;
           end;
      'Z': begin
             Cmd^.move(+1);
             t := Data^.endptr;
           end;
      '.': begin
             Cmd^.move(+1);
             T := Data^.WhereAt;
           end;
      'H': begin
             Cmd^.move(+1);
             stack.push(0);
             T := Data^.EndPtr;
           end;
      '0'..'9': while (Cmd^.ThisChar in ['0'..'9']) do
                 begin
                   t := t * 10 + (ord(Cmd^.ThisChar)-ord('0'));
                   Cmd^.Move(+1);
                 end;
    end;
    GetConstant := T;
  end;

  function ValidNumber(var B: PTextFileBuffer): Boolean;
  var
    ok: boolean;
    t: longint;
    c: char;
    p: textptr;
  begin
    Ok := True;
    t := 0;
    c := Cmd^.thischar;
    case c of
      '-': begin
             cmd^.move(+1);
             p := cmd^.WhereAt;
             t := GetConstant;
             if (p <> cmd^.WhereAt) then t := -t else t := -1;
             if Not Stack.Empty then t := Stack.Pop-t;
           end;
      '+': begin
             cmd^.move(+1);
             t := GetConstant;
             if Not Stack.Empty then t := Stack.Pop+t;
           end;
      '*': begin
             cmd^.move(+1);
             t := GetConstant;
             if Not Stack.Empty then t := Stack.Pop * t;
           end;
      '/': begin
             cmd^.move(+1);
             t := GetConstant;
             if t <> 0 then
               if Not Stack.Empty then t := Stack.Pop div t;
           end;
      '&': begin
             cmd^.move(+1);
             t := GetConstant;
             if Not Stack.Empty then t := Stack.Pop AND t;
           end;
      '#': begin
             cmd^.move(+1);
             t := GetConstant;
             if Not Stack.Empty then t := Stack.Pop OR t;
           end;
    else
      p := cmd^.WhereAt;
      t := GetConstant;
      ok := p <> cmd^.WhereAt;            { If current moved, it's a valid num }
    end;

    If Ok then Stack.Push(t);

    ValidNumber := Ok;
  end;

  function GetStringParam(var B: PTextFileBuffer; var P: Pointer; var Size: NativeUint): Boolean;
  var
    Ok: Boolean;
  begin
    if Delim = #0 then
    begin
      Delim := cmd^.ThisChar;
      cmd^.Move(+1);
    end;
    P := cmd^.ThisCharP;    { Pointer to buffer }
    Size := cmd^.WhereAt;   { Current char # }
    while (NOT Cmd^.AtEnd) AND (cmd^.ThisChar <> Delim) do
      cmd^.Move(+1);
    if cmd^.ThisChar = Delim then
    begin
      Size := (cmd^.WhereAt - Size);
      Ok := True;
      cmd^.Move(+1);
    end
    else
      Ok := False;
    GetStringParam := Ok;
  end;

  procedure LineOriented(var I,J: Longint);
  var
    k: longint;
  begin
    if Stack.Count >= 2 then
    begin
      j := stack.pop;
      i := stack.pop;
    end
    else
    begin
      if Stack.Empty then k := 1 else k := stack.pop;
      i := Data^.PlusLine(0);
      j := Data^.PlusLine(k);
    end;
  end; { LineOriented }

  procedure InsertMacro(var Dest: PTextFileBuffer);
  var
    x: char;
    p1: pointer;
    s1: NativeUint;
  begin
    if ColonPrefix then                    { Append }
      Dest^.JumpTo(Dest^.EndPtr);
    if Stack.Empty then
    begin                                  { String insert }
      if GetStringParam(Cmd,P1,S1) then
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
    c: integer;
  begin
    c := Qnum(cmd^.ThisChar); cmd^.Move(+1);
    if Qregs[c] = nil then Qregs[c] := new(PTextFileBuffer,Init(DefaultSize));
    Qregister := Qregs[c];
  end;

  procedure exitloop(xout: boolean);
  var
    lastchar: char;
  begin
    lastchar := #0;
    while (NOT cmd^.AtEnd) AND ((cmd^.thischar <> '>') OR (lastchar = 'F')) do
    begin
      lastchar := Upcase(cmd^.thischar);
      cmd^.move(+1);
    end;

    if cmd^.thischar <> '>' then
      ReportError('loop missing ending ">"!')
    else
      if xout then cmd^.move(+1);                    { Mod for skip to > }
  end;

  function inloop: boolean;
  begin
    if LoopStack.Empty then
    begin
      ReportError('not in a loop!');
      inloop := false;
    end
    else
      inloop := true;
  end;

  procedure gotoelse;
  var
    lastchar: char;
  begin
    lastchar := #0;
    while (NOT cmd^.AtEnd) AND
          ( ((cmd^.thischar <> '|') AND (cmd^.thischar <> '''')) OR (lastchar = 'F')) do
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
    lastchar: char;
  begin
    lastchar := #0;
    while (NOT cmd^.AtEnd) AND ((cmd^.thischar <> '''') OR (lastchar = 'F')) do
    begin
      lastchar := Upcase(cmd^.thischar);
      cmd^.move(+1);
    end;

    if cmd^.thischar <> '''' then
      ReportError('loop missing ending "' + '''' + '"!')
    else
      cmd^.move(+1);
  end;

var
  C,X: Char;
  I,J,K: Longint;
  P1,P2: Pointer;
  S1,S2: NativeUint;
  S: String;
  Q: PTextFileBuffer;
  kludge: integer;
begin
  cmd^.JumpTo(0);
  ReInit;

  while Not Cmd^.AtEnd do
  begin
    while ValidNumber(Cmd) do { nothing };
    ColonPrefix := False;
    Delim       := Esc;

    while cmd^.ThisChar in ['@',':'] do
    begin
      case cmd^.ThisChar of
        '@'  : Delim := #0;
        ':'  : ColonPrefix := True;
      end;
      cmd^.Move(+1);
    end;

    C := CmdChar(Cmd);
    case UpCase(C) of
{ Misc }
      #13,#10,
      ' ',','   : { Nothing };

      '='       : WriteLn(Stack.Pop);

{ Cursor Movement }
      'C'       : if Stack.Empty then Data^.Move(+1)
                                 else Data^.Move(Stack.Pop);

      'R'       : if Stack.Empty then Data^.Move(-1)
                                 else Data^.Move(-Stack.Pop);

      'J'       : if Not Stack.Empty then Data^.JumpTo(Stack.Pop);

      'L'       : if Not Stack.Empty then
                    Data^.JumpTo(Data^.PlusLine(Stack.Pop))
                  else
                    Data^.JumpTo(Data^.PlusLine(1));
{ Display }
      'T'       : begin
                    LineOriented(i,j);
                    if (i < j) then Data^.Show(i,j)
                               else Data^.Show(j,i);
                  end;

      'V'       : begin
                    if Stack.Empty then k := 1 else k := Abs(Stack.Pop);
                    i := Data^.PlusLine(-k);
                    j := Data^.PlusLine( k);
                    Data^.Show(i,j);
                  end;
{ Insertion }
      'I'       : InsertMacro(Data);

{ Deletion }
      'D'       : if Stack.Empty then Data^.Delete(1)
                                 else Data^.Delete(Stack.Pop);
      'K'       : begin
                    LineOriented(i,j);
                    Data^.JumpTo(i);
                    Data^.Delete(j-i);
                  end;

{ Search and Replace }
      'N'       : begin
                    j := Data^.WhereAt;
                    if stack.Empty then k := 1 else k := Stack.Pop;
                    if GetStringParam(Cmd,P1,S1) then
                    begin
                      QStack.Push(New(PTextBuffer,Cpy(P1,S1)));
                      Stack.Push( TecoSearch.StringSearch(PTextFileBuffer(Qstack.Top), Data, (Flags[13] and 1) <> 0) );
                      Dispose(QStack.Pop,Done);
                    end;
                  end;

      'S'       : begin
                    j := Data^.WhereAt;
                    if stack.Empty then k := 1 else k := Stack.Pop;
                    if GetStringParam(Cmd,P1,S1) then
                    begin
                      QStack.Push(New(PTextBuffer,Cpy(P1,S1)));

                      while (k > 0) AND (Not Data^.AtEnd) do
                      begin
                        i := TecoSearch.StringCompare(PTextFileBuffer(QStack.Top),Data,(Flags[13] and 1) <> 0);
                        if (i <> 0) then
                        begin
                          dec(k);
                          Data^.Move(PTextFileBuffer(QStack.Top)^.EndPtr); {AFTER match}
                        end
                        else
                          Data^.Move(+1);
                      end;

                      while (k < 0) AND (NOT Data^.AtEnd) do
                      begin
                        i := TecoSearch.StringCompare(PTextFileBuffer(QStack.Top),Data,(Flags[13] and 1) <> 0);
                        if (i <> 0) then inc(k);
                        if k <> 0 then
                          Data^.Move(-1)
                        else
                          Data^.Move(PTextFileBuffer(QStack.Top)^.EndPtr); {AFTER match}
                      end;

                      Dispose(QStack.Pop,Done);
                    end;

                    if (k = 0) then
                      Stack.Push(i)
                    else
                    begin
                      Stack.Push(0);
                      Data^.JumpTo(j);
                    end;
                  end;

      'F'       : begin
                    X := cmd^.ThisChar;
                    cmd^.Move(+1);
                    case UpCase(X) of                      { Replace match }
                      'R'  : begin
                               if Stack.Empty then k := 0 else k := Stack.Pop;
                               if GetStringParam(Cmd,P1,S1) then
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
                    end;
                  end;

{ Extended commands }
      'E'       : begin
                    X := cmd^.ThisChar;
                    cmd^.Move(+1);
                    case UpCase(X) of
                      'B'  : if GetStringParam(Cmd,P1,S1) then
                             begin
                               s := '';
                               for kludge := 1 to S1 do
                                 s := s + char((P1+kludge-1)^);
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
                                 Q^.AssignRead(S);
                               end;
                             end;

                      'R'  : if GetStringParam(Cmd,P1,S1) then
                             begin
                               s := '';
                               for kludge := 1 to S1 do
                                 s := s + char((P1+kludge-1)^);
                               Data^.AssignRead(S);
                             end;
                      'T'  : Data^.Dump;
                      'W'  : if GetStringParam(Cmd,P1,S1) then
                             begin
                               s := '';
                               for kludge := 1 to S1 do
                                 s := s + char((P1+kludge-1)^);
                               Data^.AssignWrite(S);
                             end;
                      'X'  : Done := True;
                    else
                      k := qnum(X);
                      if Stack.Empty then Stack.Push(Flags[k])
                                     else Flags[k] := Stack.Pop;
                    end;
                  end;


      'A'       : Data^.ReadPage;
      'P'       : Data^.WritePage;
      'Y'       : begin
                    Data^.WritePage;
                    Data^.ReadPage;
                  end;

{******* Q-register commands... *******}
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
                    if (i > j) then
                    begin
                      k := i;
                      i := j;
                      j := k;
                    end;
                    k := Data^.WhereAt;
                    Data^.JumpTo(i);
                    if Q <> nil then
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

{*************** Input, comment, and label commands *******************}

      ^A        : begin
                    repeat
                      X := CmdChar(Cmd);
                      if X <> ^A then
                        Write(X);
                    until (cmd^.AtEnd) OR (X = ^A);
                  end;

      ^T        : if Stack.Empty then
                  begin
                    k := Ord(ReadKey);
                    Stack.Push(Longint(k));
                    if (Flags[Qnum('T')] and $08) = 0 then
                      Write(Char(k));
                  end
                  else
                    Write(Char(Lo(Stack.Pop)));

      '!'       : repeat
                    X := CmdChar(Cmd);
                  until (cmd^.AtEnd) OR (X = '!');

      '<'       : begin
                    if Stack.Empty then i := maxint else i := Stack.Pop;
                    if i > 0 then
                    begin
                      LoopStack.Push(i);
                      LoopStack.Push(Cmd^.WhereAt);
                    end
                    else
                      ExitLoop(True);
                  end;

      '>'       : if InLoop then
                  begin
                    I := LoopStack.Pop;
                    J := LoopStack.Pop;
                    Dec(J);
                    if J > 0 then
                    begin
                      LoopStack.Push(J);
                      LoopStack.Push(I);
                      Cmd^.JumpTo(I);
                    end;
                  end;

      ';'       : if InLoop then
                  begin
                    if stack.empty then i := -1 else i := stack.pop;
                    if ColonPrefix then i := -i -1;
                    if i >= 0 then
                      ExitLoop(True);
                  end;

      '"'      : begin
                    X := cmd^.ThisChar;
                    cmd^.Move(+1);
                    i := 0;
                    if Not Stack.Empty then i := Stack.Pop;

                    case UpCase(X) of
                      'A' : if NOT (Char(Lo(I)) In ['A'..'Z','a'..'z']) then GotoElse;
                      'C' : WriteLn('Radix 50 NOT Supported!');
                      'D' : if NOT (Char(Lo(I)) In ['0'..'9']) then GotoElse;
                      'E', 'F', 'U' : if I <> 0 then GotoElse;
                      'G' : if I <= 0 then GotoElse;
                      'L', 'S', 'T' : if I >= 0 then GotoElse;
                      'N' : if I = 0 then GotoElse;
                    else
                      ReportError('Undefined Conditional!');
                    end;
                  end;

      '|'       : gotoend;

      ''''      : begin
                    ReInit;
                  end;

      #27       : begin
                    if cmd^.ThisChar = Esc then Exit else ReInit;
                  end;
    else
      WriteLn('Undefined command <',C,'>');
    end;
  end;
end; { Execute() }

end.
