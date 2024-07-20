Unit MyObj;
Interface
Type
  PBaseObject  = ^TBaseObject;
  TBaseObject  = Object
                   Constructor Init;
                   Destructor  Done;      VIRTUAL;
                 End;

Implementation

  Constructor TBaseObject.Init;
  Begin
  End;

  Destructor  TBaseObject.Done;
  Begin
  End;

Begin
End.
