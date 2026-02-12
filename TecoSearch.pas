unit TecoSearch;

{ Minimal extraction of search primitives from TECO.PAS.
  Provides StringCompare and StringSearch independent of TECO globals. }

interface

uses
  TextBuffers;

function StringCompare(Pattern, Data: PTextFileBuffer; CaseSensitive: Boolean): Longint;
function StringSearch(Pattern, Data: PTextFileBuffer; CaseSensitive: Boolean): Longint;

implementation

function CmdChar(cmd: PTextFileBuffer): Char;
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

function StringCompare(Pattern, Data: PTextFileBuffer; CaseSensitive: Boolean): Longint;
{ Checks for pattern p1 in p2 }
var
  Old1, Old2: TextPtr;
  c: Char;
  Match: Boolean;
  Size: Longint;
begin
  Match := True;
  Old1  := Pattern^.WhereAt;
  Old2  := Data^.WhereAt;
  while (not Pattern^.AtEnd) and Match do
    if (not Data^.AtEnd) then
    begin
      c := CmdChar(Pattern);
      case c of
        ^X: Data^.Move(+1);           { Match ANYTHING }
      else
        if CaseSensitive then
        begin
          if c = Data^.ThisChar then Data^.Move(+1)
                                else Match := False;
        end
        else
        begin
          if UpCase(c) = UpCase(Data^.ThisChar) then Data^.Move(+1)
                                                else Match := False;
        end;
      end;
    end
    else
      Match := False;

  if Match then Size := Data^.WhereAt - Old2
           else Size := 0;

  Pattern^.JumpTo(Old1);       { Put the pointers back }
  Data^.JumpTo(Old2);
  StringCompare := Size;
end;

function StringSearch(Pattern, Data: PTextFileBuffer; CaseSensitive: Boolean): Longint;
{ Bit-parallel search; limited by word size (31 bits here). }
var
  EndMask: Longint;
  X: Longint;

  BitMask: array[0..255] of Longint;

  procedure do_add;
  var
    c: Char;

    procedure add_char(ch: Char);
    var
      j: Byte;
      y: Longint;
      ext: Char;
    begin
      case ch of
        ^Q: begin                                { literal next char }
              ext := Pattern^.ThisChar;
              Pattern^.Move(+1);
              BitMask[Ord(ext)] := BitMask[Ord(ext)] or X;
            end;
        ^X: for j := 0 to 255 do                 { any character }
              BitMask[j] := BitMask[j] or X;
        ^S: begin                                { separators    }
              for j :=   0 to  47 do BitMask[j] := BitMask[j] or X;
              for j :=  58 to  64 do BitMask[j] := BitMask[j] or X;
              for j :=  91 to  96 do BitMask[j] := BitMask[j] or X;
              for j := 123 to 255 do BitMask[j] := BitMask[j] or X;
            end;
        ^N: begin                                { NOT anything }
              y := X;
              do_add;
              for j := 0 to 255 do
                BitMask[j] := BitMask[j] xor y;
            end;
        ^E: begin
              ext := CmdChar(Pattern);
              case UpCase(ext) of
                'A': begin                              { Alpha }
                       for j :=  65 to  90 do BitMask[j] := BitMask[j] or X;
                       for j :=  97 to 122 do BitMask[j] := BitMask[j] or X;
                     end;
                'B': begin                              { separators }
                       for j :=   0 to  47 do BitMask[j] := BitMask[j] or X;
                       for j :=  58 to  64 do BitMask[j] := BitMask[j] or X;
                       for j :=  91 to  96 do BitMask[j] := BitMask[j] or X;
                       for j := 123 to 255 do BitMask[j] := BitMask[j] or X;
                     end;
                'D': for j := 48 to 57 do               { Digits }
                       BitMask[j] := BitMask[j] or X;
                'R': begin                               { Digits+Alpha }
                       for j := 48 to 57 do BitMask[j] := BitMask[j] or X;
                       for j :=  65 to  90 do BitMask[j] := BitMask[j] or X;
                       for j :=  97 to 122 do BitMask[j] := BitMask[j] or X;
                     end;
                '[': begin
                       ext := CmdChar(Pattern);
                       while (ext <> ']') and (not Pattern^.AtEnd) do
                       begin
                         BitMask[Ord(ext)] := BitMask[Ord(ext)] or X;
                         ext := CmdChar(Pattern);
                       end;
                     end;
              end; { case }
            end; { ^E }

        'A'..'Z', 'a'..'z': begin
          BitMask[Ord(ch)] := BitMask[Ord(ch)] or X;
          if not CaseSensitive then
            BitMask[Ord(ch) xor $20] := BitMask[Ord(ch) xor $20] or X;
        end;

      else
        BitMask[Ord(ch)] := BitMask[Ord(ch)] or X;
      end; { case }
    end;

  begin
    c := CmdChar(Pattern);
    add_char(c);
  end;

var
  I: Byte;
  Count: Byte;
  OldData: TextPtr;
  Left: Longint;
begin
  FillChar(BitMask, SizeOf(BitMask), #0);
  EndMask := -1;
  OldData := Data^.WhereAt;
  I := 0;
  X := 1;
  Count := 0;
  while (not Pattern^.AtEnd) and (I < 31) do
  begin
    do_add;
    X := X shl 1;
    EndMask := EndMask shl 1;
    Inc(Count);
  end;

  X := 0;
  Left := Data^.EndPtr - Data^.WhereAt;
  if Left > 0 then
  repeat
    X := X or 1;
    X := (X and BitMask[Ord(Data^.ThisChar)]) shl 1;
    Data^.Move(+1);
    Dec(Left);
  until (Left <= 0) or ((X and EndMask) <> 0);

  if (X and EndMask) <> 0 then
  begin
    StringSearch := Count;
  end
  else
  begin
    Data^.JumpTo(OldData);
    StringSearch := 0;
  end;
end;

end.
