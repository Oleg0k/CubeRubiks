unit uMath;

interface
uses OpenGL;

type TGLPoint=record X,Y,Z : GLDouble; end;
     PTGLPoint=^TGLPoint;

{procedure VectorOffset( pIn, pOffset, pOut :PTGLpoint);
procedure VectorGetNormal(a, b, pOut :PTGLpoint);
function VectorNormalize(pIn, pOut :PTGLpoint):Boolean;}
function  ComputeFaceNormal(var p1, p2, p3, pOut :TGLpoint) :Boolean;


implementation


// Offset pIn by pOffset into pOut
procedure VectorOffset(var pIn, pOffset, pOut :TGLpoint);
begin
	pOut.x := pIn.x - pOffset.x;
	pOut.y := pIn.y - pOffset.y;
	pOut.z := pIn.z - pOffset.z;
end;


// Compute the cross product a X b into pOut
procedure VectorGetNormal(var a, b, pOut :TGLpoint);
begin
	pOut.x := a.y * b.z - a.z * b.y;
	pOut.y := a.z * b.x - a.x * b.z;
	pOut.z := a.x * b.y - a.y * b.x;
end;


// Normalize pIn vector into pOut
function VectorNormalize (var pIn, pOut :TGLpoint):Boolean;
var len: GLDouble;
begin
	len := (sqrt(sqr(pIn.x) + sqr(pIn.y) + sqr(pIn.z)));
	if (len<>0) then
	begin
		pOut.x := pIn.x / len;
		pOut.y := pIn.y / len;
		pOut.z := pIn.z / len;
		Result := true;
	end;
	Result := false;
end;


// Compute p1,p2,p3 face normal into pOut
function ComputeFaceNormal(var p1, p2, p3, pOut :TGLpoint):Boolean;
var a, b, pn  :TGLpoint;
begin
	VectorOffset(p3, p2, a);
	VectorOffset(p1, p2, b);
	// Compute the cross product a X b to get the face normal
	VectorGetNormal(a, b, pn);
	// Return a normalized vector
	Result := VectorNormalize(pn, pOut);
end;
end.
