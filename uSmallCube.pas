unit uSmallCube;

interface
uses Classes;
type TColor = -$7FFFFFFF-1..$7FFFFFFF;
type TSmallCube=class(TObject)
      private
        fSides:Array[1..3]of Array[0..1]of TColor;
        function GetSide(a,f:Shortint): TColor;
        procedure SetSide(a,f:Shortint; cl:TColor);
      public
        constructor Create;
        property Side[a, f: Shortint] : TColor read GetSide write SetSide; default;
        procedure Rotate(Axis, Direction:Shortint);
     end;

implementation

uses uConsts;



constructor TSmallCube.Create;
begin
  inherited;
  FillChar(fSides, SizeOf(fSides), DefCubeColor);
end;

function TSmallCube.GetSide(a,f:Shortint):TColor ;
begin
  Result:=fSides[a, f];
end;

procedure TSmallCube.SetSide(a,f:Shortint; cl:TColor);
begin
  fSides[a, f]:=cl
end;


procedure TSmallCube.Rotate(Axis, Direction: Shortint );
var Axis1,Axis2,d1,d2:Shortint;
    tmp:TColor;
begin
  Axis1:=Pred(axis);
  Axis2:=Succ(axis);
  if Axis1=0 then Axis1:=3;
  if Axis2=4 then Axis2:=1;
  d1:=Trunc((-direction+1)/2);
  d2:=Trunc((direction+1)/2);

  tmp:=fSides[Axis1][0];
  fSides[Axis1][0]:=fSides[Axis2][d1];
  fSides[Axis2][d1]:=fSides[Axis1][1];
  fSides[Axis1][1]:=fSides[Axis2][d2];
  fSides[Axis2][d2]:=tmp;
end;

end.
