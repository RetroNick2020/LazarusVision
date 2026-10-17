unit InfoFrm;

{ A second, non-modal form with its own menu bar and status bar (window
  level): Menu := CounterMenu puts the bar under the title, and a status bar
  with Parent := Self takes the form's last row (Align = alBottom).
  It can be moved by its title bar (mouse) and comes to the front when
  clicked; Hide puts it away again. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TUICtrl, TUIStd, TUIMenu;

type

  { TInfoForm }

  TInfoForm = class(TForm)
    CountLabel: TLabel;
    CountButton: TButton;
    HideButton: TButton;
    CounterMenu: TMainMenu;
    CounterStatus: TStatusBar;
    CountPanel: TStatusPanel;
    procedure CountButtonClick(Sender: TObject);
    procedure AddTenClick(Sender: TObject);
    procedure ResetClick(Sender: TObject);
    procedure HideButtonClick(Sender: TObject);
    procedure ColourClick(Sender: TObject);
  private
    FCount: integer;
    procedure ShowCount;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  InfoForm: TInfoForm;

implementation

constructor TInfoForm.Create(AOwner: TComponent);
var p: TStatusPanel;
begin
  inherited Create(AOwner);
  Caption := 'Counter';
  BorderStyle := bsSingle;
  SetBounds(48, 3, 30, 11);
  Color := clCyan;

  { the window's menu bar }
  CounterMenu := TMainMenu.Create(Self);
  CounterMenu.Items.Add(NewSubMenu('&Counter', 0, '', [
    NewItem('&Add one', ShortCut(VK_F5, []), false, true, @CountButtonClick, 0, ''),
    NewItem('Add &ten', ShortCut(Ord('T'), [ssCtrl]), false, true, @AddTenClick, 0, ''),
    NewItem('&Reset', ShortCut(Ord('R'), [ssCtrl]), false, true, @ResetClick, 0, ''),
    NewLine,
    NewItem('&Hide', 0, false, true, @HideButtonClick, 0, '')]));
  CounterMenu.Items.Add(NewSubMenu('&Look', 0, '', [
    NewItem('&Cyan', 0, true, true, @ColourClick, 0, ''),
    NewItem('&Gray', 0, false, true, @ColourClick, 0, '')]));
  Menu := CounterMenu;

  CountLabel := TLabel.Create(Self);
  CountLabel.Parent := Self;
  CountLabel.AutoSize := false;
  CountLabel.SetBounds(1, 1, 26, 1);
  CountLabel.Alignment := taCenter;

  CountButton := TButton.Create(Self);
  CountButton.Parent := Self;
  CountButton.SetBounds(1, 3, 12, 2);
  CountButton.Caption := 'C&ount';
  CountButton.Hint := 'Add one (F5)';
  CountButton.OnClick := @CountButtonClick;

  HideButton := TButton.Create(Self);
  HideButton.Parent := Self;
  HideButton.SetBounds(15, 3, 12, 2);
  HideButton.Caption := '&Hide';
  HideButton.Hint := 'Put the window away (Esc)';
  HideButton.Cancel := true;
  HideButton.OnClick := @HideButtonClick;

  { the window's status bar: its last row }
  CounterStatus := TStatusBar.Create(Self);
  CounterStatus.Parent := Self;
  p := CounterStatus.Panels.Add;
  p.Text := '~^R~ Reset';
  p.OnClick := @ResetClick;
  CountPanel := CounterStatus.Panels.Add;
  CountPanel.Width := 12;
  CountPanel.Alignment := taRightJustify;

  ShowCount;
end;

procedure TInfoForm.ShowCount;
begin
  CountLabel.Caption := 'Clicked ' + IntToStr(FCount) + ' times';
  CountPanel.Text := 'Count: ' + IntToStr(FCount);
end;

procedure TInfoForm.CountButtonClick(Sender: TObject);
begin
  inc(FCount);
  ShowCount;
end;

procedure TInfoForm.AddTenClick(Sender: TObject);
begin
  inc(FCount, 10);
  ShowCount;
end;

procedure TInfoForm.ResetClick(Sender: TObject);
begin
  FCount := 0;
  ShowCount;
end;

procedure TInfoForm.HideButtonClick(Sender: TObject);
begin
  Hide;
end;

procedure TInfoForm.ColourClick(Sender: TObject);
var look: TMenuItem;
begin
  look := TMenuItem(Sender).Parent;
  look[0].Checked := Sender = look[0];
  look[1].Checked := Sender = look[1];
  if look[0].Checked then Color := clCyan else Color := clLightGray;
end;

end.
