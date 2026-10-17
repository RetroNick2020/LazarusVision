unit LfmDemo;

{ A form whose controls come from LFMDEMO.LFM - the Lazarus way: the class
  lists the controls and the event handlers, the .lfm says where they are
  (in character cells) and how they are set up. No constructor is needed:
  TForm.Create finds LFMDEMO.LFM (the unit's name) and reads it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TUICtrl, TUIStd, TUIList, TUIMemo, TUIMenu, TUIExt,
  TUIPages, TUIGrid, TUIViews;

type

  { TLfmForm }

  TLfmForm = class(TForm)
    NameLabel: TLabel;
    NameEdit: TEdit;
    HelloButton: TButton;
    LoudCheck: TCheckBox;
    SizeGroup: TRadioGroup;
    FruitList: TListBox;
    CityCombo: TComboBox;
    QtySpin: TSpinEdit;
    Pages: TPageControl;
    GridSheet: TTabSheet;
    Grid: TStringGrid;
    NotesSheet: TTabSheet;
    Notes: TMemo;
    FilesSheet: TTabSheet;
    Files: TListView;
    StatusBar1: TStatusBar;
    MainMenu1: TMainMenu;
    FileItem: TMenuItem;
    HelloItem: TMenuItem;
    SepItem: TMenuItem;
    QuitItem: TMenuItem;
    ActionList1: TActionList;
    actHello: TAction;
    Timer1: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure NameEditChange(Sender: TObject);
    procedure SizeGroupClick(Sender: TObject);
    procedure actHelloExecute(Sender: TObject);
    procedure QuitItemClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  public
    Hellos, Ticks: integer;
    LastMessage: string;
  end;

var
  LfmForm: TLfmForm;

implementation

procedure TLfmForm.FormCreate(Sender: TObject);
begin
  Grid.Cells[0, 0] := 'Product';
  Grid.Cells[1, 0] := 'Qty';
  Grid.Cells[0, 1] := 'Apples';
  Grid.Cells[1, 1] := '2';
  with Files.Items.Add do
  begin
    Caption := 'LFMDEMO.LFM';
    SubItems.Add('4096');
  end;
end;

procedure TLfmForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    Key := 0;
    Close;
  end;
end;

procedure TLfmForm.NameEditChange(Sender: TObject);
begin
  StatusBar1.Panels[1].Text := 'Name: ' + NameEdit.Text;
end;

procedure TLfmForm.SizeGroupClick(Sender: TObject);
begin
  StatusBar1.Panels[1].Text := 'Size: ' + SizeGroup.Items[SizeGroup.ItemIndex];
end;

procedure TLfmForm.actHelloExecute(Sender: TObject);
var s: string;
begin
  inc(Hellos);
  s := 'Hello, ' + NameEdit.Text;
  if LoudCheck.Checked then s := UpperCase(s) + '!';
  LastMessage := s;
  ShowMessage(s);
end;

procedure TLfmForm.QuitItemClick(Sender: TObject);
begin
  Close;
end;

procedure TLfmForm.Timer1Timer(Sender: TObject);
begin
  inc(Ticks);
end;

end.
