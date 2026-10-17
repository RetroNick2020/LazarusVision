unit ListFrm;

{ The list controls (and a resizable form with anchored controls): a list box with a scroll bar, a pick-only combo box
  (csDropDownList) and a combo box you can also type into (csDropDown).
  Opened from the screen menu: Window|Lists (Ctrl+L). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TUICtrl, TUIStd, TUIList;

type

  { TListForm }

  TListForm = class(TForm)
    CountryLabel: TLabel;
    CountryList: TListBox;
    SizeLabel: TLabel;
    SizeCombo: TComboBox;
    FruitLabel: TLabel;
    FruitCombo: TComboBox;
    ItemLabel: TLabel;
    NewEdit: TEdit;
    AddButton: TButton;
    DeleteButton: TButton;
    InfoLabel: TLabel;
    OkButton: TButton;
    procedure CountryListSelectionChange(Sender: TObject; User: boolean);
    procedure CountryListDblClick(Sender: TObject);
    procedure SizeComboSelect(Sender: TObject);
    procedure FruitComboChange(Sender: TObject);
    procedure AddButtonClick(Sender: TObject);
    procedure DeleteButtonClick(Sender: TObject);
    procedure OkButtonClick(Sender: TObject);
  private
    procedure Info(const S: string);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  ListForm: TListForm;

implementation

constructor TListForm.Create(AOwner: TComponent);

  function NewLabel(X, Y: integer; const S: string; F: TWinControl): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Self;
    Result.Left := X;
    Result.Top := Y;
    Result.Caption := S;
    Result.FocusControl := F;
  end;

begin
  inherited Create(AOwner);
  Caption := 'Lists';
  SetBounds(0, 0, 52, 19);
  Position := poScreenCenter;
  { resizable (BorderStyle bsSizeable, the default): no smaller than this }
  Constraints.MinWidth := 52;
  Constraints.MinHeight := 19;

  CountryList := TListBox.Create(Self);
  CountryList.Parent := Self;
  CountryList.SetBounds(2, 2, 22, 10);
  CountryList.Sorted := true;
  CountryList.Anchors := [akLeft, akTop, akRight, akBottom];   { grows }
  CountryList.Items.CommaText := 'Canada,France,Germany,Greece,Italy,Japan,Mexico,' +
    'Brazil,Spain,Sweden,Norway,Egypt,India,Chile,Peru,Kenya,Ireland,Portugal';
  CountryList.Hint := 'Double click or Enter on OK';
  CountryList.OnSelectionChange := @CountryListSelectionChange;
  CountryList.OnDblClick := @CountryListDblClick;
  CountryLabel := NewLabel(2, 1, '&Countries:', CountryList);

  SizeCombo := TComboBox.Create(Self);
  SizeCombo.Parent := Self;
  SizeCombo.SetBounds(27, 2, 20, 1);
  SizeCombo.Style := csDropDownList;
  SizeCombo.Anchors := [akTop, akRight];                       { moves right }
  SizeCombo.Items.Add('Small');
  SizeCombo.Items.Add('Medium');
  SizeCombo.Items.Add('Large');
  SizeCombo.Items.Add('Extra large');
  SizeCombo.ItemIndex := 0;
  SizeCombo.Hint := 'Alt+Down or F4 opens the list';
  SizeCombo.OnSelect := @SizeComboSelect;
  SizeLabel := NewLabel(27, 1, '&Size:', SizeCombo);
  SizeLabel.Anchors := [akTop, akRight];

  FruitCombo := TComboBox.Create(Self);
  FruitCombo.Parent := Self;
  FruitCombo.SetBounds(27, 5, 20, 1);
  FruitCombo.Items.CommaText := 'Apple,Banana,Cherry,Grape,Lemon,Mango,Orange,' +
    'Peach,Pear,Plum,Strawberry';
  FruitCombo.DropDownCount := 6;
  FruitCombo.Anchors := [akTop, akRight];
  FruitCombo.Hint := 'Type a fruit or pick one';
  FruitCombo.OnChange := @FruitComboChange;
  FruitLabel := NewLabel(27, 4, '&Fruit:', FruitCombo);
  FruitLabel.Anchors := [akTop, akRight];

  NewEdit := TEdit.Create(Self);
  NewEdit.Parent := Self;
  NewEdit.SetBounds(27, 8, 20, 1);
  NewEdit.Hint := 'A country to add to the list';
  NewEdit.Anchors := [akTop, akRight];
  ItemLabel := NewLabel(27, 7, 'New &item:', NewEdit);
  ItemLabel.Anchors := [akTop, akRight];

  AddButton := TButton.Create(Self);
  AddButton.Parent := Self;
  AddButton.SetBounds(27, 10, 9, 2);
  AddButton.Caption := '&Add';
  AddButton.Anchors := [akTop, akRight];
  AddButton.OnClick := @AddButtonClick;

  DeleteButton := TButton.Create(Self);
  DeleteButton.Parent := Self;
  DeleteButton.SetBounds(38, 10, 9, 2);
  DeleteButton.Caption := '&Delete';
  DeleteButton.Anchors := [akTop, akRight];
  DeleteButton.OnClick := @DeleteButtonClick;

  InfoLabel := TLabel.Create(Self);
  InfoLabel.Parent := Self;
  InfoLabel.AutoSize := false;
  InfoLabel.SetBounds(2, 13, 46, 1);
  InfoLabel.Font.Color := clBlue;
  InfoLabel.Anchors := [akLeft, akRight, akBottom];

  OkButton := TButton.Create(Self);
  OkButton.Parent := Self;
  OkButton.SetBounds(19, 15, 12, 2);
  OkButton.Caption := 'OK';
  OkButton.Anchors := [akBottom];
  OkButton.Default := true;
  OkButton.Cancel := true;
  OkButton.OnClick := @OkButtonClick;

  ActiveControl := CountryList;
end;

procedure TListForm.Info(const S: string);
begin
  if InfoLabel <> nil then InfoLabel.Caption := S;
end;

procedure TListForm.CountryListSelectionChange(Sender: TObject; User: boolean);
begin
  if CountryList.ItemIndex >= 0 then
    Info('Country: ' + CountryList.Items[CountryList.ItemIndex] +
         ' (' + IntToStr(CountryList.ItemIndex + 1) + ' of ' +
         IntToStr(CountryList.Count) + ')');
end;

procedure TListForm.CountryListDblClick(Sender: TObject);
begin
  if CountryList.ItemIndex >= 0 then
    ShowMessage('You picked ' + CountryList.Items[CountryList.ItemIndex]);
end;

procedure TListForm.SizeComboSelect(Sender: TObject);
begin
  Info('Size: ' + SizeCombo.Text);
end;

procedure TListForm.FruitComboChange(Sender: TObject);
begin
  if FruitCombo.ItemIndex >= 0 then
    Info('Fruit: ' + FruitCombo.Text + ' (item ' + IntToStr(FruitCombo.ItemIndex) + ')')
  else
    Info('Fruit: ' + FruitCombo.Text + ' (not in the list)');
end;

procedure TListForm.AddButtonClick(Sender: TObject);
var s: string;
begin
  s := Trim(NewEdit.Text);
  if s = '' then exit;
  if CountryList.Items.IndexOf(s) < 0 then CountryList.Items.Add(s);
  CountryList.ItemIndex := CountryList.Items.IndexOf(s);
  NewEdit.Text := '';
  Info('Added ' + s);
end;

procedure TListForm.DeleteButtonClick(Sender: TObject);
var i: integer;
begin
  i := CountryList.ItemIndex;
  if i < 0 then exit;
  Info('Deleted ' + CountryList.Items[i]);
  CountryList.Items.Delete(i);
  if i >= CountryList.Count then i := CountryList.Count - 1;
  CountryList.ItemIndex := i;
end;

procedure TListForm.OkButtonClick(Sender: TObject);
begin
  Hide;
end;

end.
