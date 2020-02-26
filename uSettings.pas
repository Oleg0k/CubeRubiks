unit uSettings;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls, Spin, ComCtrls, Buttons;

type
  TfrmSettings = class(TForm)
    ColorDialog1: TColorDialog;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    SpinEditSize: TSpinEdit;
    RadioGroup1: TRadioGroup;
    Panel1: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel5: TPanel;
    Panel6: TPanel;
    Panel2: TPanel;
    SpinEditSteps: TSpinEdit;
    Label8: TLabel;
    TrackBarBevel: TTrackBar;
    Label9: TLabel;
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    cbFullScreen: TCheckBox;
    procedure Panel1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
  private
    { Private declarations }
    procedure SaveSettings;
    procedure LoadSettings;
  public
    { Public declarations }
  end;

var
  frmSettings: TfrmSettings;

implementation

uses Registry ;

const KeyInRegistry='\Software\CubeOfRubik\';

{$R *.DFM}

procedure TfrmSettings.Panel1Click(Sender: TObject);
begin
   if ColorDialog1.Execute then
    (Sender as TPanel).Color:=ColorDialog1.Color;
end;

procedure TfrmSettings.FormCreate(Sender: TObject);
begin
  LoadSettings
end;

procedure TfrmSettings.LoadSettings;
var Reg:TRegistry;
    ColorsOfSides:array[1..6]of TColor;
    i:integer;
begin
  Reg:=TRegistry.Create;
  with Reg do
    try
      OpenKey(KeyInRegistry, True);
      ReadBinaryData('Colors', ColorsOfSides,SizeOf(ColorsOfSides));
      SpinEditSize.Value:=ReadInteger('Size');
      SpinEditSteps.Value:=ReadInteger('Steps');
      TrackBarBevel.Position:=ReadInteger('Bevel');
      RadioGroup1.ItemIndex:=Integer(ReadInteger('ColorType'));
      cbFullScreen.Checked:=ReadBool('FullScreen');      
      for i:=0 to ComponentCount-1 do
        if Components[i] is TPanel then
         (Components[i] as TPanel).Color:=ColorsOfSides[Components[i].Tag] ;
     except on ERegistryException do
    end;
  Reg.Free;

end;

procedure TfrmSettings.SaveSettings;
var Reg:TRegistry;
    ColorsOfSides:array[1..6]of TColor;
    i:integer;
begin
  for i:=0 to ComponentCount-1 do
    if Components[i] is TPanel then
      ColorsOfSides[Components[i].Tag]:=(Components[i] as TPanel).Color ;
  Reg:=TRegistry.Create;
  with Reg do
    begin
      OpenKey(KeyInRegistry, True);
      WriteBinaryData('Colors', ColorsOfSides,SizeOf(ColorsOfSides));
      WriteInteger('Size', SpinEditSize.Value);
      WriteInteger('Steps', SpinEditSteps.Value);
      WriteInteger('Bevel', TrackBarBevel.Position);
      WriteInteger('ColorType', RadioGroup1.ItemIndex);
      WriteBool('FullScreen', cbFullScreen.Checked);
      Reg.Free
    end
end;

procedure TfrmSettings.BitBtn1Click(Sender: TObject);
begin
  SaveSettings;
  Close
end;

procedure TfrmSettings.BitBtn2Click(Sender: TObject);
begin
  Close
end;

end.
