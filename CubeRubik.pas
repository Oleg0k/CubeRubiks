unit CubeRubik;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  OpenGL, ExtCtrls, StdCtrls, ComCtrls;

const

  SMALLCUBE = 1;

  MaxCubeSize=10;
  BevelAccuracy=12;

  KeyInRegistry='\Software\CubeOfRubik\';
  DefaultColors:array[1..6]of integer=(clRed, clGreen, clBlue, clWhite, clYellow, clFuchsia);

type
  TfrmGLScene = class(TForm)
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseWheel(Sender: TObject; Shift: TShiftState;
      WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    procedure Timer1Timer(Sender: TObject);
  private
    procedure AppException(Sender: TObject; E: Exception);
    procedure SetDCPixelFormat;
    procedure IdleHandler(Sender: TObject; var Done: Boolean);
    procedure RestoreSettings;
  protected
//    procedure WMTimer(var Msg: TMessage); message WM_Timer;
  public
  end;


var
    frmGLScene: TfrmGLScene;

implementation

uses Registry,Math, uSettings, uSmallCube, uMath, uConsts;

type TMovement=record
                 Axis,Layer,Direction:integer;
               end;

     TBigCube=Array[1..MaxCubeSize,1..MaxCubeSize,1..MaxCubeSize] of TSmallCube;

//     TGLPoint=record X,Y,Z : GLDouble; end;
{$R *.DFM}

var  BigCube: TBigCube;
    Track:Array[0..100] of TMovement;
    ColorsOfSides:array[1..6]of TColor;

    Xprev, Yprev:integer;
    glPatchOneSide, glEmptySide, glListText:GLuint;
    TimerFlag, CounterFrames:integer;

    DC: HDC;
    hrc: HGLRC;
    Palette: HPALETTE;
    Xmax,Ymax: GLDouble;
    CurrentAngle:glDouble=0;

    CubePos, CubeAngle, TextPos: TGLPoint;

    MaxQuantitySteps, CubeSize, AssembleFlag, Axis, Layer, Direction, CurrentStep :integer;
    Delta : Double = 5.0;
    Bevel : Double = 0.16;
    startTick : Int64;
    TimeStart:TTime;
    FPS:Double=0;
    FPS_Counter:integer=0;
    GLSceneFullScreen:Boolean=True;

procedure GenerateRandomColors;
var i, R,G,B :integer;

begin
  Randomize;
  for i:=1 to 6 do
  begin
    R:=Trunc(Random(256));
    G:=Trunc(Random(256));
    B:=Trunc(Random(256));
    ColorsOfSides[i]:=RGB(R,G,B);
  end
end;

procedure CreateBigCube;
var i,j,k:integer;
begin
  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
      for k:=1 to CubeSize do
        if (i=1) or (i=CubeSize) or (j=1) or (j=CubeSize) or (k=1) or (k=CubeSize) then
          BigCube[i,j,k]:=TSmallCube.Create;
end;

procedure DestroyBigCube;
var i,j,k:integer;
begin
  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
      for k:=1 to CubeSize do
        if (i=1) or (i=CubeSize) or (j=1) or (j=CubeSize) or (k=1) or (k=CubeSize) then
          BigCube[i,j,k].Free
end;


Procedure InitializeBigCube;
var i,j:integer;
begin

  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
    if BigCube[1,i,j]<>nil then
     BigCube[1,i,j].Side[1,0]:=ColorsOfSides[1]; // Top

  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
    if BigCube[CubeSize,i,j]<>nil then
      BigCube[CubeSize,i,j].Side[1,1]:=ColorsOfSides[2]; // Bottom

  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
    if BigCube[i,1,j]<>nil then
      BigCube[i,1,j].Side[2,0]:=ColorsOfSides[3]; // Front

  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
    if BigCube[i,CubeSize,j]<>nil then
      BigCube[i,CubeSize,j].Side[2,1]:=ColorsOfSides[4]; // Back

  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
    if BigCube[i,j,1]<>nil then
      BigCube[i,j,1].Side[3,0]:=ColorsOfSides[5]; // Left

  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
    if BigCube[i,j,CubeSize]<>nil then
      BigCube[i,j,CubeSize][3,1]:=ColorsOfSides[6]; // Right
end;

procedure SetLight;
const
  mat_specular : Array[0..3] of glFloat = (0.8, 0.8, 0.8, 1.0); // Цвет блика
  mat_shininess : Array[0..0] of glFloat   = (50.0); // Размер блика (обратная пропорция)
  light_position : Array[0..3] of glFloat = (8.0, 1.0, 2.0, 0.0); // Расположение источника
  white_light : Array[0..3] of glFloat = (0.90, 0.90, 0.90, 2.0); // Цвет и интенсивность освещения, генерируемого источником
  lmodel_ambient : Array[0..3] of glFloat = (0.5, 0.5, 0.5, 1.0); // Параметры фонового освещения
begin
  glClearColor(0.0, 0.0, 0.0, 1.0);
  glShadeModel(GL_SMOOTH);

  glMaterialfv(GL_FRONT, GL_SPECULAR, @mat_specular);
  glMaterialfv(GL_FRONT, GL_SHININESS, @mat_shininess);

  glLightfv(GL_LIGHT0, GL_POSITION, @light_position);
  glLightfv(GL_LIGHT0, GL_DIFFUSE, @white_light);
  glLightfv(GL_LIGHT0, GL_SPECULAR, @white_light);
  glLightModelfv(GL_LIGHT_MODEL_AMBIENT, @lmodel_ambient);

  glEnable(GL_LIGHTING);
  glEnable(GL_LIGHT0);
  glEnable(GL_DEPTH_TEST);
end;

function Vertex(X, Y, Z:GLDouble): TGLPoint;
begin
  Result.X:=X;
  Result.Y:=Y;
  Result.Z:=Z
end;

procedure EmptySide;
begin
  glEmptySide:=glGenLists(1);
  glNewList(glEmptySide, GL_COMPILE);
  glBegin(GL_QUADS);
      glNormal3d(0.0, 0.0, 1.0); // Z
      glVertex3d(1.0-Bevel, 1.0-Bevel, 1.0);   // 1
      glVertex3d(-1.0+Bevel, 1.0-Bevel, 1.0);  // 2
      glVertex3d(-1.0+Bevel, -1.0+Bevel, 1.0);  // 3
      glVertex3d(1.0-Bevel, -1.0+Bevel, 1.0);  // 4
  glEnd;
  glEndList();
end;


procedure BuildOneSide;
const BevelPrecision=10;
var lBevel, BevP, H, x1,y1,x2,y2,CoeffMult:double;
    P1, P2, P3, PRes : TGLPoint;
    Points:Array[0..BevelPrecision]of array[0..20]of TGLPoint;
    i,j:integer;
begin
  H:=0.1;
  BevP:=Bevel - H/2;
  lBevel:=Bevel+H;

  glPatchOneSide:=glGenLists(1);
  glNewList(glPatchOneSide, GL_COMPILE);

  x1:=BevP*COS(PI/8); y1:=BevP*SIN(PI/8);
  x2:=BevP*SIN(PI/4); y2:=x2;

  Points[0][0]:= Vertex(1.0-lBevel, 1.0-(lBevel+BevP), 1.0+H);   // 1
  Points[0][1]:= Vertex(1.0-(lBevel+BevP)+x1, 1.0-(lBevel+BevP)+y1, 1.0+H);   // bw 1 and 2
  Points[0][2]:= Vertex(1.0-(lBevel+BevP)+x2, 1.0-(lBevel+BevP)+y2, 1.0+H);   // bw 1 and 2
  Points[0][3]:= Vertex(1.0-(lBevel+BevP)+y1, 1.0-(lBevel+BevP)+x1, 1.0+H);   // bw 1 and 2 !!
  Points[0][4]:= Vertex(1.0-(lBevel+BevP), 1.0-lBevel, 1.0+H);   // 2
  Points[0][5]:= Vertex(-1.0+(lBevel+BevP), 1.0-lBevel, 1.0+H);  // 3
  Points[0][6]:= Vertex(-1.0+(lBevel+BevP)-y1, 1.0-(lBevel+BevP)+x1, 1.0+H);   // bw 3 and 4
  Points[0][7]:= Vertex(-1.0+(lBevel+BevP)-x2, 1.0-(lBevel+BevP)+y2, 1.0+H);   // bw 3 and 4
  Points[0][8]:= Vertex(-1.0+(lBevel+BevP)-x1, 1.0-(lBevel+BevP)+y1, 1.0+H);   // bw 3 and 4
  Points[0][9]:= Vertex(-1.0+lBevel, 1.0-(lBevel+BevP), 1.0+H);  // 4
  Points[0][10]:= Vertex(-1.0+lBevel, -1.0+(lBevel+BevP), 1.0+H); // 5
  Points[0][11]:= Vertex(-1.0+(lBevel+BevP)-x1, -1.0+(lBevel+BevP)-y1, 1.0+H);   // bw 5 and 6
  Points[0][12]:= Vertex(-1.0+(lBevel+BevP)-x2, -1.0+(lBevel+BevP)-y2, 1.0+H);   // bw 5 and 6
  Points[0][13]:= Vertex(-1.0+(lBevel+BevP)-y1, -1.0+(lBevel+BevP)-x1, 1.0+H);   // bw 5 and 6
  Points[0][14]:= Vertex(-1.0+(lBevel+BevP), -1.0+lBevel, 1.0+H); // 6
  Points[0][15]:= Vertex(1.0-(lBevel+BevP), -1.0+lBevel, 1.0+H);   // 7
  Points[0][16]:= Vertex(1.0-(lBevel+BevP)+y1, -1.0+(lBevel+BevP)-x1, 1.0+H);   // bw 7 and 8
  Points[0][17]:= Vertex(1.0-(lBevel+BevP)+x2, -1.0+(lBevel+BevP)-y2, 1.0+H);   // bw 7 and 8
  Points[0][18]:= Vertex(1.0-(lBevel+BevP)+x1, -1.0+(lBevel+BevP)-y1, 1.0+H);   // bw 7 and 8
  Points[0][19]:= Vertex(1.0-lBevel, -1.0+(lBevel+BevP), 1.0+H);  // 8
  Points[0][20]:= Points[0][0];   // 1 - опять нулевая

  glBegin(GL_POLYGON);
  glNormal3d(0.0, 0.0, 1.0); // Z
  for i:=0 to 19 do
      glVertex3dv(@Points[0][i]);   // 1
  glEnd;

  for j:=1 to BevelPrecision do
  begin
    CoeffMult:=(Points[0][0].X + H*SIN(PI/2*j/BevelPrecision))/Points[0][0].X;
    for i:=0 to 20 do
    begin
    Points[j][i].X:=Points[0][i].X * CoeffMult;
    Points[j][i].Y:=Points[0][i].Y * CoeffMult;
    Points[j][i].Z:= 1 + H *(COS(PI/2*j/BevelPrecision));
    end;
  end;

  glFrontFace(GL_CW);

  glBegin(GL_QUAD_STRIP);
  for j:=1 to BevelPrecision do
  begin
    P1:=Points[j-1][19];
    P2:=Points[j][19];

    for i:=0 to 20  do
    begin
      P3:=Points[j-1][i];
      ComputeFaceNormal(P1, P2, P3, PRes);

      glNormal3dv(@PRes); // Нормаль
      glVertex3dv(@Points[j][i]);
      glVertex3dv(@Points[j-1][i]);

      P1:=P3;
      P2:=Points[j][i];
    end;

  end;
    glEnd;
  glFrontFace(GL_CCW);

  glEndList();
end;


procedure BuildFont;								// Build Our Bitmap Font
var	font:HFONT;										// Windows Font ID
begin
  glColor3ub(255,255,255);
	glListText := glGenLists(96);								// Storage For 96 Characters
	font := CreateFont(	-16,							// Height Of Font
						0,								// Width Of Font
						0,								// Angle Of Escapement
						0,								// Orientation Angle
						FW_BOLD,						// Font Weight
						0,							// Italic
						0,							// Underline
						0,							// Strikeout
						ANSI_CHARSET,					// Character Set Identifier
						OUT_TT_PRECIS,					// Output Precision
						CLIP_DEFAULT_PRECIS,			// Clipping Precision
						ANTIALIASED_QUALITY,			// Output Quality
						FF_DONTCARE And DEFAULT_PITCH,		// Family And Pitch
						'Courier New');					// Font Name
	SelectObject(DC, font);							// Selects The Font We Want
	wglUseFontBitmaps(DC, 32, 96, glListText);				// Builds 96 Characters Starting At Character 32

	DeleteObject(font);									// Delete The Font

end;

procedure InitGL;
const
  glfLightAmbient : Array[0..3] of GLDouble = (1.0, 1.0, 1.0, 1.0);
  glfLightDiffuse : Array[0..3] of GLDouble = (0.1, 0.1, 0.1, 1.0);
  glfLightSpecular: Array[0..3] of GLDouble = (-0.9, 0.0, 0.1, 1.0);
  glfLightPosition: Array[0..3] of GLDouble = (-1,-5, 1.0, 1.0);

var
  gldAspect : GLdouble;
begin
  glEnable(GL_DEPTH_TEST);
  glEnable(GL_CULL_FACE);
  glEnable(GL_POLYGON_SMOOTH);
  glCullFace (GL_BACK);
  glEnable (GL_CULL_FACE);
  glBlendFunc (GL_SRC_ALPHA_SATURATE, GL_ONE);

{	glClearDepth(1.0);							// Enables Clearing Of The Depth Buffer
	glShadeModel(GL_SMOOTH);					// Enables Smooth Color Shading
 }
  glPolygonMode(GL_FRONT,GL_FILL);

  SetLight;
  // Redefine the viewing volume and viewport when the window size changes.
  gldAspect := frmGLScene.Width / frmGLScene.Height;
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity;
  gluPerspective(45.0,           // Field-of-view angle
                 gldAspect,      // Aspect ratio of viewing volume
                 1,            // Distance to near clipping plane
                 220.0);         // Distance to far clipping plane
  glViewport(0, 0, frmGLScene.Width, frmGLScene.Height);
  glFrontFace(GL_CCW);
  glDepthFunc(GL_LESS);
//  glClearColor(0.4, 0.4, 0.4, 0);
  glListBase(1);
//  box1:=GLgenlists(1);
//  GlNewList(box1,Gl_Compile);
  BuildOneSide;
  EmptySide;
  BuildFont;
end;

procedure TfrmGLScene.AppException(Sender: TObject; E: Exception);
begin
  Application.ShowException(E);
  Screen.Cursor := crDefault;
end;

procedure TfrmGLScene.FormCreate(Sender: TObject);
begin
  Application.OnException := AppException;
  RestoreSettings;
  AssembleFlag:=1;
  CubePos.Z:=-5*CubeSize;
  CubeAngle.X:=0;
  CubeAngle.Y:=0;
  CubeAngle.Z:=0;

  Xmax:=32;
  Ymax:=24;
  CurrentStep:=-1;
  // Create a rendering context.

  if GLSceneFullScreen then
  begin
    frmGLScene.BorderStyle:= bsNone;
    Width:=GetSystemMetrics(SM_CXSCREEN);
    Height:=GetSystemMetrics(SM_CYSCREEN);
  end;

  SetDCPixelFormat;
  hrc := wglCreateContext(DC);
  wglMakeCurrent(DC, hrc);

  CreateBigCube;
  InitializeBigCube;


  TextPos.X:=-0.55;
  TextPos.Y:=0.404;
  Cursor:=crNone;

  InitGL;
  TimeStart:=Time;
  startTick := GetTickCount;
//  Timer1.Enabled := True;
  Application.OnIdle:=IdleHandler
end;

procedure glPrint(S:ShortString);					// Custom GL "Print" Routine
begin
	glPushAttrib(GL_LIST_BIT);							// Pushes The Display List Bits
	glListBase(glListText-32);								// Sets The Base Character to 32
	glCallLists(byte(S[0]), GL_UNSIGNED_BYTE, @S[1]);	// Draws The Display List Text
	glPopAttrib();										// Pops The Display List Bits
end;


procedure RotateLayer(Axis,Layer,Direction:integer);
type TLayer=Array[1..MaxCubeSize,1..MaxCubeSize] of TSmallCube;
var i,j:integer;
    Tmp:TLayer;
begin
  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
    begin
      if (i=1) or (i=CubeSize) or (j=1) or (j=CubeSize) or (Layer=1) or (Layer=CubeSize) then
      case Axis of
        1: if Direction=1 then
             begin
               if BigCube[Layer,j,CubeSize+1-i]<>nil then
                 BigCube[Layer,j,CubeSize+1-i].Rotate(Axis,Direction);
               Tmp[i,j]:=BigCube[Layer,j,CubeSize+1-i];
             end
            else
             begin
               if BigCube[Layer,CubeSize+1-j,i]<>nil then
                 BigCube[Layer,CubeSize+1-j,i].Rotate(Axis,Direction);
               Tmp[i,j]:=BigCube[Layer,CubeSize+1-j,i];
             end;
        2: if Direction=-1 then  // ПОЧЕМУ МИНУС ????
             begin
               if BigCube[j,Layer,CubeSize+1-i]<>nil then
                 BigCube[j,Layer,CubeSize+1-i].Rotate(Axis,Direction);
               Tmp[i,j]:=BigCube[j,Layer,CubeSize+1-i];
             end
            else
             begin
               if BigCube[CubeSize+1-j,Layer,i]<>nil then
                 BigCube[CubeSize+1-j,Layer,i].Rotate(Axis,Direction);
               Tmp[i,j]:=BigCube[CubeSize+1-j,Layer,i];
             end;
        3: if Direction=1 then
             begin
               if BigCube[j,CubeSize+1-i,Layer]<>nil then
                 BigCube[j,CubeSize+1-i,Layer].Rotate(Axis,Direction);
               Tmp[i,j]:=BigCube[j,CubeSize+1-i,Layer];
             end
            else
             begin
               if BigCube[CubeSize+1-j,i,Layer]<>nil then
                 BigCube[CubeSize+1-j,i,Layer].Rotate(Axis,Direction);
               Tmp[i,j]:=BigCube[CubeSize+1-j,i,Layer];
             end;
      end;
    end;
  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
    begin
      if (i=1) or (i=CubeSize) or (j=1) or (j=CubeSize) or (Layer=1) or (Layer=CubeSize) then
      case Axis of
        1:BigCube[Layer,i,j]:=Tmp[i,j];
        2:BigCube[i,Layer,j]:=Tmp[i,j];
        3:BigCube[i,j,Layer]:=Tmp[i,j];
      end;
    end
end;

procedure InitializeTrack;
label 1;
var i:integer;
begin
  Track[0].Axis:=3;
  Track[0].Layer:=CubeSize;
  Track[0].Direction:=-1;
  Track[MaxQuantitySteps+1].Axis:=0;
  Track[MaxQuantitySteps+1].Layer:=0;
  Track[MaxQuantitySteps+1].Direction:=0;
  Randomize;
  for i:=1 to MaxQuantitySteps do
  begin
   1: Track[i].Axis:=Trunc(Random(3)+1);
      Track[i].Layer:=Trunc(Random(CubeSize)+1);
      Track[i].Direction:=Trunc(Random(2))*2-1;
      if (Track[i].Axis=Track[i-1].Axis)
         and(Track[i].Layer=Track[i-1].Layer)
         and(Track[i].Direction=-Track[i-1].Direction) then goto 1
  end;
  CurrentStep:=0;
  Axis:=Track[0].Axis;
  Layer:=Track[0].Layer;
  Direction:=Track[0].Direction;
  AssembleFlag:=1;
end;

procedure TfrmGLScene.SetDCPixelFormat;
var
  nPixelFormat: Integer;
  pfd: TPixelFormatDescriptor;

begin
  DC := GetDC(Handle);
  FillChar(pfd, SizeOf(pfd), 0);
  with pfd do begin
    nSize     := sizeof(pfd);                               // Size of this structure
    nVersion  := 1;                                         // Version number
    dwFlags   := PFD_DRAW_TO_WINDOW or
                 PFD_SUPPORT_OPENGL or
                 PFD_DOUBLEBUFFER or
                 PFD_GENERIC_ACCELERATED or
                 PFD_GENERIC_FORMAT ;                       // Flags
    iPixelType:= PFD_TYPE_RGBA;                             // RGBA pixel values
    cColorBits:= 24;                                        // 24-bit color
    cDepthBits:= 32;                                        // 32-bit depth buffer
    iLayerType:= PFD_MAIN_PLANE;                            // Layer type
  end;

  nPixelFormat := ChoosePixelFormat(DC, @pfd);
  SetPixelFormat(DC, nPixelFormat, @pfd);

  DescribePixelFormat(DC, nPixelFormat, sizeof(TPixelFormatDescriptor), pfd);

end;


// --------------------- DRAW SCENE ----------------------------
procedure DrawScene;
var
  i,j,k:integer;

  procedure SmallCube(cube:TSmallCube);
  var quad:GLUquadricObj;

    procedure Bevels;
    begin
    // Фаски вдоль оси Z :
    glPushMatrix;
    glTranslate(-1+Bevel, 1-Bevel, -1+Bevel);
    gluCylinder(quad, Bevel, Bevel, 2.0-2*Bevel, BevelAccuracy, 1);
    glPopMatrix();

    glPushMatrix;
    glTranslate(-1+Bevel, -1+Bevel, -1+Bevel);
    gluCylinder(quad, Bevel, Bevel, 2.0-2*Bevel, BevelAccuracy, 1);
    glPopMatrix();

    glPushMatrix;
    glTranslate(1-Bevel, 1-Bevel, -1+Bevel);
    gluCylinder(quad, Bevel, Bevel, 2.0-2*Bevel, BevelAccuracy, 1);
    glPopMatrix();

    glPushMatrix;
    glTranslate(1-Bevel, -1+Bevel, -1+Bevel);
    gluCylinder(quad, Bevel, Bevel, 2.0-2*Bevel, BevelAccuracy, 1);
    glPopMatrix();
    end;

  begin
    glEnable(GL_COLOR_MATERIAL);
    glColorMaterial(GL_FRONT, GL_AMBIENT_AND_DIFFUSE);
    //
    // Draw the six faces of the cube.

    glColor3ub(GetRValue(cube[3,1]),GetGValue(cube[3,1]),GetBValue(cube[3,1]));
    if GetRValue(cube[3,1])=DefCubeColor then
      glCallList(glEmptySide)
    else
      glCallList(glPatchOneSide);

    glPushMatrix;
    glColor3ub(GetRValue(cube[3,0]),GetGValue(cube[3,0]),GetBValue(cube[3,0]));
    glRotate(180, 0.0, 1.0, 0.0);
    if GetRValue(cube[3,0])=DefCubeColor then
      glCallList(glEmptySide)
    else
      glCallList(glPatchOneSide);
    glPopMatrix;

    glPushMatrix;
    glColor3ub(GetRValue(cube[1,1]),GetGValue(cube[1,1]),GetBValue(cube[1,1]));
    glRotate(90, 0.0, 1.0, 0.0);
    if GetRValue(cube[1,1])=DefCubeColor then
      glCallList(glEmptySide)
    else
      glCallList(glPatchOneSide);
    glPopMatrix;

    glPushMatrix;
    glColor3ub(GetRValue(cube[1,0]),GetGValue(cube[1,0]),GetBValue(cube[1,0]));
    glRotate(-90, 0.0, 1.0, 0.0);
    if GetRValue(cube[1,0])=DefCubeColor then
      glCallList(glEmptySide)
    else
      glCallList(glPatchOneSide);
    glPopMatrix;

    glPushMatrix;
    glColor3ub(GetRValue(cube[2,1]),GetGValue(cube[2,1]),GetBValue(cube[2,1]));
    glRotate(-90, 1.0, 0.0, 0.0);
    if GetRValue(cube[2,1])=DefCubeColor then
      glCallList(glEmptySide)
    else
      glCallList(glPatchOneSide);
    glPopMatrix;

    glPushMatrix;
    glColor3ub(GetRValue(cube[2,0]),GetGValue(cube[2,0]),GetBValue(cube[2,0]));
    glRotate(90, 1.0, 0.0, 0.0);
    if GetRValue(cube[2,0])=DefCubeColor then
      glCallList(glEmptySide)
    else
      glCallList(glPatchOneSide);
    glPopMatrix;

  glColor3ub(DefCubeColor,DefCubeColor,DefCubeColor);
  quad:=gluNewQuadric();
	gluQuadricNormals(quad, GLU_SMOOTH);

  Bevels; // - Фаски вдоль оси Z

  glPushMatrix;
  glRotate(90, 0.0, 1.0, 0.0);
  Bevels; // - Фаски вдоль оси X
  glPopMatrix;

  glPushMatrix;
  glRotate(90, 1.0, 0.0, 0.0);
  Bevels; // - Фаски вдоль оси Y
  glPopMatrix;

// Углы :
  glPushMatrix;
  glTranslate(1-Bevel, 1-Bevel, 1-Bevel);
  gluSphere(quad,Bevel,BevelAccuracy,BevelAccuracy);
  glPopMatrix;

  glPushMatrix;
  glTranslate(-1+Bevel, 1-Bevel, 1-Bevel);
  gluSphere(quad,Bevel,BevelAccuracy,BevelAccuracy);
  glPopMatrix;

  glPushMatrix;
  glTranslate(1-Bevel, -1+Bevel, 1-Bevel);
  gluSphere(quad,Bevel,BevelAccuracy,BevelAccuracy);
  glPopMatrix;

  glPushMatrix;
  glTranslate(-1+Bevel, -1+Bevel, 1-Bevel);
  gluSphere(quad,Bevel,BevelAccuracy,BevelAccuracy);
  glPopMatrix;

//--
  glPushMatrix;
  glTranslate(1-Bevel, 1-Bevel, -1+Bevel);
  gluSphere(quad,Bevel,BevelAccuracy,BevelAccuracy);
  glPopMatrix;

  glPushMatrix;
  glTranslate(-1+Bevel, 1-Bevel, -1+Bevel);
  gluSphere(quad,Bevel,BevelAccuracy,BevelAccuracy);
  glPopMatrix;

  glPushMatrix;
  glTranslate(1-Bevel, -1+Bevel, -1+Bevel);
  gluSphere(quad,Bevel,BevelAccuracy,BevelAccuracy);
  glPopMatrix;

  glPushMatrix;
  glTranslate(-1+Bevel, -1+Bevel, -1+Bevel);
  gluSphere(quad,Bevel,BevelAccuracy,BevelAccuracy);
  glPopMatrix;

  end;

  procedure DrawSmallCube(i,j,k:integer);
  var x, y, z: GLdouble;
  begin
    if BigCube[i,j,k]=nil then exit;
          glPushMatrix;
          x:=(i-(CubeSize+1)/2)*2.01;
          y:=(j-(CubeSize+1)/2)*2.01;
          z:=(k-(CubeSize+1)/2)*2.01;
          glTranslatef(x, y, z);
          SmallCube(BigCube[i,j,k]);
          glPopMatrix;
  end;
begin
  // Clear the color and depth buffers.
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  // Define the modelview transformation.
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity;

  glTranslate(CubePos.X, CubePos.Y, CubePos.Z);

  glRotate(CubeAngle.X, 1.0, 0.0, 0.0);
  glRotate(CubeAngle.Y, 0.0, 1.0, 0.0);
  glRotate(CubeAngle.Z, 0.0, 0.0, 1.0);

  // Рисуем вращающийся слой:
  glPushMatrix;
  case Axis of
    1: glRotate(CurrentAngle*Direction, 1.0, 0.0, 0.0);
    2: glRotate(CurrentAngle*Direction, 0.0, 1.0, 0.0);
    3: glRotate(CurrentAngle*Direction, 0.0, 0.0, 1.0);
  end;
  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
      for k:=1 to CubeSize do
          case Axis of
            1:if i=Layer then
                if (j=1) or (j=CubeSize) or (k=1) or (k=CubeSize) or (Layer=1) or (Layer=CubeSize) then
                  DrawSmallCube(i,j,k);
            2:if j=Layer then
                if (i=1) or (i=CubeSize) or (k=1) or (k=CubeSize) or (Layer=1) or (Layer=CubeSize) then
                  DrawSmallCube(i,j,k);
            3:if k=Layer then
                if (i=1) or (i=CubeSize) or (j=1) or (j=CubeSize) or (Layer=1) or (Layer=CubeSize) then
                  DrawSmallCube(i,j,k)
          end;

  glPopMatrix;

  // Рисуем неподвижную часть :
  for i:=1 to CubeSize do
    for j:=1 to CubeSize do
      for k:=1 to CubeSize do
        begin
          case Axis of
            1:if i=Layer then continue;
            2:if j=Layer then continue;
            3:if k=Layer then continue
          end;
          if (i=1) or (i=CubeSize) or (j=1) or (j=CubeSize) or (k=1) or (k=CubeSize) then
          DrawSmallCube(i,j,k);
        end;
  inc(CounterFrames);
	glLoadIdentity;									// Reset The Current Modelview Matrix
	glTranslatef(0,0,-1);						// Move One Unit Into The Screen

  glColor3ub(255, 255, 255);

	glRasterPos2f(TextPos.X, TextPos.Y);
 	glPrint('X:'+FloatToStr(RoundTo(CubePos.X,-3)));

	glRasterPos2f(TextPos.X, TextPos.Y-0.011);
 	glPrint('Y:'+FloatToStr(RoundTo(CubePos.Y,-3)));

	glRasterPos2f(TextPos.X, TextPos.Y-0.022);
 	glPrint('Z:'+FloatToStr(CubePos.Z));

	glRasterPos2f(TextPos.X, TextPos.Y-0.033);
 	glPrint('Step:'+IntToStr(CurrentStep));

 	glRasterPos2f(TextPos.X, TextPos.Y-0.044);
 	glPrint('FPS:'+FloatToStr(FPS));

 	glRasterPos2f(TextPos.X, TextPos.Y-0.055);
 	glPrint('Dir:'+IntToStr(Direction));

 	glRasterPos2f(TextPos.X, TextPos.Y-0.066);
 	glPrint('Axis:'+IntToStr(Track[CurrentStep].Axis));

 	glRasterPos2f(TextPos.X, TextPos.Y-0.077);
 	glPrint('PosX:'+FloatToStr(TextPos.X));

 	glRasterPos2f(TextPos.X, TextPos.Y-0.088);
 	glPrint('PosY:'+FloatToStr(TextPos.Y));

 	glRasterPos2f(TextPos.X, TextPos.Y-0.099);
 	glPrint('Bevel:'+FloatToStr(Bevel));


  if GetTickCount-startTick >=5000 then
  begin
    startTick:=GetTickCount;
    FPS:=FPS_Counter/5;
    FPS_Counter:=0;
  end;
  inc(FPS_Counter);
  SwapBuffers(DC);
end;

procedure TfrmGLScene.RestoreSettings;
var Reg:TRegistry;
    ColorType, i:integer;
begin
  Reg:=TRegistry.Create;
  with Reg do
  try
    OpenKey(KeyInRegistry, False);
    ColorType:=ReadInteger('ColorType');
    case ColorType of
    0: ReadBinaryData('Colors', ColorsOfSides,SizeOf(ColorsOfSides));
    1: GenerateRandomColors;
    2: for i:=1 to 6 do ColorsOfSides[i]:=RGB(128,148,64)
    end;
    CubeSize:=ReadInteger('Size');
    MaxQuantitySteps:=ReadInteger('Steps');
    GLSceneFullScreen:=ReadBool('FullScreen');

  except on ERegistryException do
    begin
      CubeSize:=5;
      for i:=1 to 6 do ColorsOfSides[i]:=DefaultColors[i];
      MaxQuantitySteps:=20;
      GLSceneFullScreen:=True;
    end;
  end;
  Reg.Free;
//  SetLength(Track, MaxQuantitySteps+1);
end;

procedure TfrmGLScene.IdleHandler(Sender: TObject; var Done: Boolean);
begin
  Timer1Timer(Self);
  Done:=False;
end;

procedure TfrmGLScene.FormDestroy(Sender: TObject);
begin
  // Clean up and terminate.
  DestroyBigCube;
  wglMakeCurrent(0, 0);
  wglDeleteContext(hrc);
  ReleaseDC(Handle, DC);
	glDeleteLists(glListText, 96);
  if (Palette <> 0) then DeleteObject(Palette);

//  KillTimer(Handle,1)
end;

procedure TfrmGLScene.FormKeyDown(Sender: TObject;var Key: Word;Shift: TShiftState);
begin
 if Key=VK_ESCAPE then Close;
 if Key=VK_UP then CubePos.Z:=CubePos.Z-1;
 if Key=VK_DOWN then CubePos.Z:=CubePos.Z+1;
 if Key=VK_PAUSE then if Delta>0 then Delta:=0 else Delta:=5;
 if Key=82 then begin GenerateRandomColors; InitializeBigCube; InitializeTrack; end
end;

procedure TfrmGLScene.Timer1Timer(Sender: TObject);
begin
{  if TimerFlag < 5 then
  begin
    inc(TimerFlag); DrawScene; Exit;
  end;}
  CurrentAngle:=CurrentAngle + Delta;
  if CurrentAngle=90 then
  begin
    RotateLayer(Axis,Layer,Direction);
    CurrentStep:=CurrentStep+AssembleFlag;
    Axis:=Track[CurrentStep].Axis;
    Layer:=Track[CurrentStep].Layer;
    Direction:=AssembleFlag*Track[CurrentStep].Direction;
    CurrentAngle:=0;
    TimerFlag:=0;
  end;
  if CurrentStep=-1 then InitializeTrack;
  if CurrentStep=MaxQuantitySteps+1 then AssembleFlag:=-1;

  DrawScene

end;

procedure TfrmGLScene.FormMouseMove(Sender: TObject;Shift: TShiftState; X, Y: Integer);
begin
  if ssRight in Shift then
  begin
   CubeAngle.X:=CubeAngle.X + (Y - Yprev)/20;
   CubeAngle.Y:=CubeAngle.Y + (X - Xprev)/20;
  end;

  if ssLeft in Shift then
  begin
   CubePos.X:=CubePos.X + (X - Xprev)/500;
   CubePos.Y:=CubePos.Y + (Yprev - Y)/500;
  end;

  if (ssLeft in Shift) and  (ssCtrl in Shift) then
  begin
   TextPos.X:=TextPos.X + (X - Xprev)/2000;
   TextPos.Y:=TextPos.Y + (Yprev - Y)/2000;
  end;

end;

procedure TfrmGLScene.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
    Xprev:=X;
    Yprev:=Y
end;

procedure TfrmGLScene.FormMouseWheel(Sender: TObject; Shift: TShiftState;
  WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin
  CubeAngle.Z:=CubeAngle.Z + WheelDelta/40;
  if (CubeAngle.Z = 360.0) then CubeAngle.Z := 0.0;

end;

initialization
begin
end;

end.

