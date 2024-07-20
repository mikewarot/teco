Unit Stacks;
Interface
Uses
  MyObj;
Const
  StackLimit = 10;
Type
  LStack     = Object
                 constructor init;
                 destructor  done;               virtual;
                 function  pop    : longint;     virtual;
                 procedure push(x : longint);    virtual;
                 function  empty  : boolean;     virtual;
                 function  count  : longint;     virtual;
                 procedure clear;                virtual;
               private
                 Top   : Word;
                 Data  : Array[0..StackLimit] of Longint;
               End;

  OStack     = Object
                 constructor init;
                 destructor  done;                 virtual;
                 function  top    : PBaseObject;   virtual;
                 function  pop    : PBaseObject;   virtual;
                 procedure push(x : PBaseObject);  virtual;
                 function  empty  : boolean;       virtual;
                 function  count  : longint;       virtual;
                 procedure clear;                  virtual;
               private
                 TopP  : Word;
                 Data  : Array[0..StackLimit] of PBaseObject;
               End;

Implementation
  constructor LStack.Init;
  begin
    Top := 0;
    Data[0] := 0;
  end;

  function LStack.Pop : Longint;
  begin
    Pop := Data[Top];
    If Top > 0 then Dec(Top);
  end;

  procedure LStack.Push(x : longint);
  begin
    If Top < StackLimit then inc(Top);
    Data[Top] := x;
  end;

  function LStack.Empty : Boolean;
  begin
    Empty := Top = 0;
  end;

  function LStack.Count : Longint;
  begin
    Count := Top;
  end;

  procedure LStack.Clear;
  begin
    Top := 0;
  end;

  destructor LStack.Done;
  begin
    Self.Clear;
  end;


  constructor OStack.init;
  begin
    fillchar(Data,SizeOf(Data),#0);
    TopP := 0;
  end;

  destructor  OStack.done;
  begin
    self.clear;
  end;

  function    OStack.top    : PBaseObject;
  begin
    If TopP <> 0 then Top := Data[TopP]
                 else Top := Nil;
  end;

  function    OStack.pop    : PBaseObject;
  begin
    If TopP <> 0 then
    begin
      pop := Data[TopP];
      Dec(TopP);
    end
    else
      pop := Nil;
  end;

  procedure   OStack.push(x : PBaseObject);
  begin
    If TopP < StackLimit then
    begin
      Inc(TopP);
      Data[TopP] := X;
    end;
  end;

  function    OStack.empty  : boolean;
  begin
    empty := TopP = 0;
  end;

  function    OStack.count  : longint;
  begin
    Count := TopP;
  end;

  procedure   OStack.clear;
  begin
    while topp > 0 do
    begin
      If Data[TopP] <> nil then
        Data[TopP]^.Done;
      Dec(TopP);
    end;
  end;


begin
end.
