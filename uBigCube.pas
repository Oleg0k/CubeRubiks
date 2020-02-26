unit uBigCube;

interface

uses Classes, uSmallCube;

const MaxCubeSize=10;

type TBigCube=class(TObject)
      private
        fBigCube:Array[1..MaxCubeSize,1..MaxCubeSize,1..MaxCubeSize] of TSmallCube;
        
      public
        constructor Create;

        procedure RotateLayer(Axis,Layer,Direction:Shortint);
     end;

implementation

constructor TBigCube.Create;
begin
  inherited;

end;

procedure TBigCube.RotateLayer(Axis,Layer,Direction:Shortint);
begin

end;

end.
 