unit DataFrm;

{ Stage 5 data views on three pages: a TStringGrid (editable, sortable by
  a click on a header, resizable columns), a TListView (report / list,
  check boxes, sorting by column) and a TTreeView (a node filled when it is
  opened) with two TTrackBars. Opened from Window|Data views (Ctrl+D);
  Esc closes it. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, TUIScrn, TUICtrl, TUIStd, TUIList, TUIMenu, TUIPages,
  TUIGrid, TUIViews;

type

  { TDataForm }

  TDataForm = class(TForm)
    Pages: TPageControl;
    GridSheet, ListSheet, TreeSheet: TTabSheet;
    Grid: TStringGrid;
    ListTop: TPanel;
    ReportCheck: TCheckBox;
    Files: TListView;
    Tree: TTreeView;
    TreeSplitter: TSplitter;
    TreePanel: TPanel;
    PathLabel, ZoomLabel, LevelLabel: TLabel;
    Zoom: TTrackBar;
    Level: TTrackBar;
    Status: TStatusBar;
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure GridHeaderClick(Sender: TObject; IsColumn: boolean; Index: integer);
    procedure GridSetEditText(Sender: TObject; ACol, ARow: integer; const Value: string);
    procedure GridSelection(Sender: TObject; aCol, aRow: integer);
    procedure ReportCheckChange(Sender: TObject);
    procedure FilesSelectItem(Sender: TObject; Item: TListItem; Selected: boolean);
    procedure FilesItemChecked(Sender: TObject; Item: TListItem);
    procedure FilesDblClick(Sender: TObject);
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure TreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: boolean);
    procedure ZoomChange(Sender: TObject);
  private
    procedure Say(const S: string);
    procedure Total(R: integer);
  public
    SortCol: integer;
    LazyFilled: integer;
    constructor Create(AOwner: TComponent); override;
  end;

var
  DataForm: TDataForm;

implementation

const
  Products: array[1..24] of string = ('Apples', 'Bread', 'Butter', 'Cheese',
    'Coffee', 'Eggs', 'Flour', 'Grapes', 'Honey', 'Jam', 'Lemons', 'Milk',
    'Nuts', 'Oats', 'Olives', 'Pasta', 'Pears', 'Rice', 'Salt', 'Sugar',
    'Tea', 'Tomatoes', 'Water', 'Yogurt');

constructor TDataForm.Create(AOwner: TComponent);
var i: integer;
    it: TListItem;
    c: TListColumn;
    root, cdrive, n: TTreeNode;

  function Col(const S: string; W: integer; A: TAlignment): TListColumn;
  begin
    Result := Files.Columns.Add;
    Result.Caption := S;
    Result.Width := W;
    Result.Alignment := A;
  end;

begin
  inherited Create(AOwner);
  Caption := 'Data views';
  SetBounds(0, 0, 78, 22);
  Position := poScreenCenter;
  Constraints.MinWidth := 50;
  Constraints.MinHeight := 14;
  KeyPreview := true;
  OnKeyDown := @FormKeyDown;

  Status := TStatusBar.Create(Self);
  Status.Parent := Self;
  Status.SimplePanel := true;

  Pages := TPageControl.Create(Self);
  Pages.Parent := Self;
  Pages.Align := alClient;

  { ---- the grid }
  GridSheet := Pages.AddTabSheet;
  GridSheet.Caption := '&Grid';
  Grid := TStringGrid.Create(Self);
  Grid.Parent := GridSheet;
  Grid.Align := alClient;
  Grid.ColCount := 5;
  Grid.RowCount := Length(Products) + 1;
  Grid.Options := Grid.Options + [goEditing, goColSizing];
  Grid.ColWidths[0] := 4;
  Grid.ColWidths[1] := 16;
  Grid.ColWidths[2] := 8;
  Grid.ColWidths[3] := 10;
  Grid.ColWidths[4] := 11;
  for i := 2 to 4 do Grid.ColAlignments[i] := taRightJustify;
  Grid.Cells[0, 0] := ' #';
  Grid.Cells[1, 0] := 'Product';
  Grid.Cells[2, 0] := 'Qty';
  Grid.Cells[3, 0] := 'Price';
  Grid.Cells[4, 0] := 'Total';
  for i := 1 to Length(Products) do
  begin
    Grid.Cells[0, i] := IntToStr(i);
    Grid.Cells[1, i] := Products[i];
    Grid.Cells[2, i] := IntToStr((i * 7) mod 13 + 1);
    Grid.Cells[3, i] := FormatFloat('0.00', 0.5 + (i * 37 mod 50) / 10);
    Total(i);
  end;
  Grid.Hint := 'Type or F2/Enter to edit; click a header to sort';
  Grid.OnHeaderClick := @GridHeaderClick;
  Grid.OnSetEditText := @GridSetEditText;
  Grid.OnSelection := @GridSelection;
  SortCol := -1;

  { ---- the list view }
  ListSheet := Pages.AddTabSheet;
  ListSheet.Caption := '&List view';
  ListTop := TPanel.Create(Self);
  ListTop.Parent := ListSheet;
  ListTop.Height := 1;
  ListTop.Align := alTop;
  ReportCheck := TCheckBox.Create(Self);
  ReportCheck.Parent := ListTop;
  ReportCheck.SetBounds(1, 0, 16, 1);
  ReportCheck.Caption := '&Report view';
  ReportCheck.Checked := true;
  ReportCheck.OnChange := @ReportCheckChange;
  Files := TListView.Create(Self);
  Files.Parent := ListSheet;
  Files.Align := alClient;
  Files.Checkboxes := true;
  Files.GridLines := true;
  Col('Name', 18, taLeftJustify);
  Col('Size', 9, taRightJustify);
  Col('Type', 7, taLeftJustify);
  c := Col('Modified', 12, taLeftJustify);
  for i := 1 to 30 do
  begin
    it := Files.Items.Add;
    it.Caption := Products[(i * 5) mod 24 + 1] + IntToStr(i) + '.' + Copy('TXTPASEXEDAT', 1 + (i mod 4) * 3, 3);
    it.SubItems.Add(IntToStr((i * 7919) mod 100000));
    it.SubItems.Add(Copy('TXTPASEXEDAT', 1 + (i mod 4) * 3, 3));
    it.SubItems.Add(Format('2026-%.2d-%.2d', [1 + i mod 12, 1 + i mod 28]));
  end;
  if c = nil then;
  Files.Hint := 'Space checks; click a header to sort; double click opens';
  Files.OnSelectItem := @FilesSelectItem;
  Files.OnItemChecked := @FilesItemChecked;
  Files.OnDblClick := @FilesDblClick;

  { ---- the tree, a splitter and a panel with track bars }
  TreeSheet := Pages.AddTabSheet;
  TreeSheet.Caption := '&Tree';
  Tree := TTreeView.Create(Self);
  Tree.Parent := TreeSheet;
  Tree.Width := 34;
  Tree.Align := alLeft;
  Tree.Hint := 'Right/Left open/close, +/-/*, a letter jumps';
  TreeSplitter := TSplitter.Create(Self);
  TreeSplitter.Parent := TreeSheet;
  TreeSplitter.Align := alLeft;
  TreePanel := TPanel.Create(Self);
  TreePanel.Parent := TreeSheet;
  TreePanel.Align := alClient;
  PathLabel := TLabel.Create(Self);
  PathLabel.Parent := TreePanel;
  PathLabel.AutoSize := false;
  PathLabel.SetBounds(1, 1, 36, 1);
  PathLabel.Anchors := [akLeft, akTop, akRight];
  Zoom := TTrackBar.Create(Self);
  Zoom.Parent := TreePanel;
  Zoom.SetBounds(9, 4, 21, 1);
  Zoom.Max := 10;
  Zoom.Position := 5;
  Zoom.OnChange := @ZoomChange;
  ZoomLabel := TLabel.Create(Self);
  ZoomLabel.Parent := TreePanel;
  ZoomLabel.SetBounds(1, 4, 6, 1);
  ZoomLabel.Caption := '&Zoom:';
  ZoomLabel.FocusControl := Zoom;
  Level := TTrackBar.Create(Self);
  Level.Parent := TreePanel;
  Level.Orientation := trVertical;
  Level.SetBounds(9, 7, 1, 6);
  Level.Max := 5;
  Level.Position := 2;
  Level.OnChange := @ZoomChange;
  LevelLabel := TLabel.Create(Self);
  LevelLabel.Parent := TreePanel;
  LevelLabel.SetBounds(1, 7, 7, 1);
  LevelLabel.Caption := 'L&evel:';
  LevelLabel.FocusControl := Level;

  Tree.Items.BeginUpdate;
  root := Tree.Items.Add(nil, 'Computer');
  cdrive := Tree.Items.AddChild(root, 'C:');
  n := Tree.Items.AddChild(cdrive, 'FPC');
  Tree.Items.AddChild(n, 'bin');
  Tree.Items.AddChild(n, 'units');
  Tree.Items.AddChild(n, 'source');
  Tree.Items.AddChild(cdrive, 'DOS');
  n := Tree.Items.AddChild(cdrive, 'GAMES');
  Tree.Items.AddChild(n, 'DIGGER');
  Tree.Items.AddChild(n, 'KEEN');
  Tree.Items.AddChild(n, 'SOKOBAN');
  n := Tree.Items.AddChild(root, 'D: (filled when opened)');
  n.HasChildren := true;
  Tree.Items.AddChild(root, 'Network');
  Tree.Items.Add(root, 'Recycle bin');
  root.Expanded := true;
  Tree.Items.EndUpdate;
  Tree.Selected := root;
  Tree.OnChange := @TreeChange;
  Tree.OnExpanding := @TreeExpanding;

  Pages.ActivePageIndex := 0;
  ActiveControl := Grid;
  Say('Ready');
end;

procedure TDataForm.Say(const S: string);
begin
  if Status <> nil then Status.SimpleText := S;
end;

procedure TDataForm.Total(R: integer);
var q, p: double;
begin
  if TryStrToFloat(Grid.Cells[2, R], q) and TryStrToFloat(Grid.Cells[3, R], p) then
    Grid.Cells[4, R] := FormatFloat('0.00', q * p)
  else
    Grid.Cells[4, R] := '?';
end;

procedure TDataForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) and not Grid.EditorMode then
  begin
    Key := 0;
    Hide;
  end;
end;

procedure TDataForm.GridHeaderClick(Sender: TObject; IsColumn: boolean; Index: integer);
begin
  if not IsColumn then exit;
  if Index = SortCol then
  begin
    if Grid.SortOrder = soAscending then Grid.SortOrder := soDescending
    else Grid.SortOrder := soAscending;
  end
  else
  begin
    SortCol := Index;
    Grid.SortOrder := soAscending;
  end;
  Grid.SortColRow(true, Index);
  if Grid.SortOrder = soAscending then Say('Sorted by ' + Grid.Cells[Index, 0] + ' up')
  else Say('Sorted by ' + Grid.Cells[Index, 0] + ' down');
end;

procedure TDataForm.GridSetEditText(Sender: TObject; ACol, ARow: integer; const Value: string);
begin
  if ACol in [2, 3] then Total(ARow);
  Say('Cell ' + IntToStr(ACol) + ',' + IntToStr(ARow) + ' = ' + Value);
end;

procedure TDataForm.GridSelection(Sender: TObject; aCol, aRow: integer);
begin
  Say(Grid.Cells[1, aRow] + ': ' + Grid.Cells[aCol, 0]);
end;

procedure TDataForm.ReportCheckChange(Sender: TObject);
begin
  if Files = nil then exit;
  if ReportCheck.Checked then Files.ViewStyle := vsReport else Files.ViewStyle := vsList;
end;

procedure TDataForm.FilesSelectItem(Sender: TObject; Item: TListItem; Selected: boolean);
begin
  if Selected then Say('Selected: ' + Item.Caption + ' (' + Item.SubItems[0] + ' bytes)');
end;

procedure TDataForm.FilesItemChecked(Sender: TObject; Item: TListItem);
begin
  Say(Item.Caption + BoolToStr(Item.Checked, ' checked', ' unchecked'));
end;

procedure TDataForm.FilesDblClick(Sender: TObject);
begin
  if Files.Selected <> nil then Say('Open ' + Files.Selected.Caption);
end;

procedure TDataForm.TreeChange(Sender: TObject; Node: TTreeNode);
begin
  if Node <> nil then PathLabel.Caption := Node.GetTextPath
  else PathLabel.Caption := '';
end;

procedure TDataForm.TreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: boolean);
var i: integer;
begin
  { the D: node gets its children only when it is opened the first time }
  if (Pos('D:', Node.Text) = 1) and (Node.Count = 0) then
  begin
    for i := 1 to 5 do Tree.Items.AddChild(Node, 'DATA' + IntToStr(i));
    inc(LazyFilled);
    Say('D: filled in OnExpanding');
  end;
end;

procedure TDataForm.ZoomChange(Sender: TObject);
begin
  Say('Zoom ' + IntToStr(Zoom.Position) + ', level ' + IntToStr(Level.Position));
end;

end.
