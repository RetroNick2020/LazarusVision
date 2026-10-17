unit LclForm;

{ A form written only with the LCL's unit names (the alias units in LCL\):
  the uses clause is the one Lazarus puts in a new form unit, plus the
  units of the controls used. Compile with -FuLCL. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, Menus, Grids, Spin, ActnList, LCLType;

type

  { TForm1 }

  TForm1 = class(TForm)
    Label1: TLabel;
    Edit1: TEdit;
    Button1: TButton;
    CheckBox1: TCheckBox;
    ListBox1: TListBox;
    ComboBox1: TComboBox;
    RadioGroup1: TRadioGroup;
    SpinEdit1: TSpinEdit;
    StringGrid1: TStringGrid;
    Panel1: TPanel;
    StatusBar1: TStatusBar;
    MainMenu1: TMainMenu;
    Timer1: TTimer;
    ActionList1: TActionList;
    actHello: TAction;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure actHelloExecute(Sender: TObject);
    procedure Edit1Change(Sender: TObject);
    procedure ListBox1SelectionChange(Sender: TObject; User: boolean);
    procedure Timer1Timer(Sender: TObject);
    procedure QuitClick(Sender: TObject);
  public
    Ticks, Hellos: integer;
    constructor Create(AOwner: TComponent); override;
  end;

var
  Form1: TForm1;

implementation

constructor TForm1.Create(AOwner: TComponent);
var c: TMenuItem;
begin
  inherited Create(AOwner);
  Caption := 'Form1 - LCL unit names';
  SetBounds(0, 0, 66, 21);
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  KeyPreview := true;
  OnCreate := @FormCreate;
  OnKeyDown := @FormKeyDown;

  ActionList1 := TActionList.Create(Self);
  actHello := TAction.Create(Self);
  actHello.ActionList := ActionList1;
  actHello.Caption := '&Hello';
  actHello.Hint := 'Say hello';
  actHello.ShortCut := ShortCut(VK_F2, []);
  actHello.OnExecute := @actHelloExecute;

  MainMenu1 := TMainMenu.Create(Self);
  c := TMenuItem.Create(Self);
  c.Caption := '&File';
  MainMenu1.Items.Add(c);
  c.Add(NewItem('&Hello', 0, false, true, nil, 0, ''));
  c.Items[0].Action := actHello;
  c.Add(NewLine);
  c.Add(NewItem('&Quit', ShortCut(Ord('Q'), [ssCtrl]), false, true, @QuitClick, 0, ''));
  Menu := MainMenu1;

  StatusBar1 := TStatusBar.Create(Self);
  StatusBar1.Parent := Self;
  StatusBar1.SimplePanel := true;

  Label1 := TLabel.Create(Self);
  Label1.Parent := Self;
  Label1.SetBounds(2, 1, 30, 1);
  Label1.Caption := '&Name:';
  Edit1 := TEdit.Create(Self);
  Edit1.Parent := Self;
  Edit1.SetBounds(10, 1, 30, 1);
  Edit1.Anchors := [akLeft, akTop, akRight];
  Edit1.OnChange := @Edit1Change;
  Label1.FocusControl := Edit1;
  Button1 := TButton.Create(Self);
  Button1.Parent := Self;
  Button1.SetBounds(44, 1, 16, 2);
  Button1.Anchors := [akTop, akRight];
  Button1.Action := actHello;
  Button1.Default := true;

  CheckBox1 := TCheckBox.Create(Self);
  CheckBox1.Parent := Self;
  CheckBox1.SetBounds(2, 3, 20, 1);
  CheckBox1.Caption := '&Loud';
  CheckBox1.Font.Color := clRed;

  ListBox1 := TListBox.Create(Self);
  ListBox1.Parent := Self;
  ListBox1.SetBounds(2, 5, 18, 6);
  ListBox1.Items.CommaText := 'One,Two,Three,Four,Five,Six,Seven,Eight';
  ListBox1.OnSelectionChange := @ListBox1SelectionChange;
  ComboBox1 := TComboBox.Create(Self);
  ComboBox1.Parent := Self;
  ComboBox1.SetBounds(22, 5, 16, 1);
  ComboBox1.Style := csDropDownList;
  ComboBox1.Items.CommaText := 'Red,Green,Blue';
  ComboBox1.ItemIndex := 0;
  RadioGroup1 := TRadioGroup.Create(Self);
  RadioGroup1.Parent := Self;
  RadioGroup1.SetBounds(40, 4, 20, 5);
  RadioGroup1.Caption := '&Size';
  RadioGroup1.Items.CommaText := 'Small,Medium,Large';
  RadioGroup1.ItemIndex := 1;
  SpinEdit1 := TSpinEdit.Create(Self);
  SpinEdit1.Parent := Self;
  SpinEdit1.SetBounds(22, 7, 8, 1);
  SpinEdit1.MaxValue := 10;
  SpinEdit1.Value := 5;

  Panel1 := TPanel.Create(Self);
  Panel1.Parent := Self;
  Panel1.SetBounds(2, 12, 58, 5);
  Panel1.Anchors := [akLeft, akTop, akRight, akBottom];
  StringGrid1 := TStringGrid.Create(Self);
  StringGrid1.Parent := Panel1;
  StringGrid1.Align := alClient;
  StringGrid1.ColCount := 3;
  StringGrid1.RowCount := 4;
  StringGrid1.Options := StringGrid1.Options + [goEditing];
  StringGrid1.Cells[1, 0] := 'A';
  StringGrid1.Cells[2, 0] := 'B';

  Timer1 := TTimer.Create(Self);
  Timer1.Interval := 200;
  Timer1.OnTimer := @Timer1Timer;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ActiveControl := Edit1;
  StatusBar1.SimpleText := 'Ready';
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    Key := 0;
    if MessageDlg('Quit?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then Close;
  end;
end;

procedure TForm1.actHelloExecute(Sender: TObject);
var s: string;
begin
  inc(Hellos);
  s := 'Hello, ' + Edit1.Text;
  if CheckBox1.Checked then s := UpperCase(s) + '!';
  ShowMessage(s);
end;

procedure TForm1.Edit1Change(Sender: TObject);
begin
  StatusBar1.SimpleText := 'Name: ' + Edit1.Text;
end;

procedure TForm1.ListBox1SelectionChange(Sender: TObject; User: boolean);
begin
  if User then StatusBar1.SimpleText := 'Picked ' + ListBox1.Items[ListBox1.ItemIndex];
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  inc(Ticks);
end;

procedure TForm1.QuitClick(Sender: TObject);
begin
  Close;
end;

end.
