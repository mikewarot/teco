Program Teco;
Uses
  TextBuffers,
  DOS,CRT,
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
