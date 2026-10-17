{-----------------------------------------------------------------------------}
{  TUIGRID - grids, LCL names (Grids):  TDrawGrid, TStringGrid                 }
{                                                                             }
{  ColCount, RowCount, FixedCols, FixedRows, ColWidths[], DefaultColWidth,    }
{  Col, Row, TopRow, LeftCol, Options (goVertLine, goFixedVertLine,           }
{  goColSizing, goEditing, goTabs, goRowSelect, goAlwaysShowEditor),          }
{  OnSelectCell (veto), OnSelection, OnDrawCell, OnHeaderClick,               }
{  OnGetEditText, OnSetEditText; TStringGrid: Cells[], SortColRow,            }
{  SortOrder, DeleteColRow, Clean; TUI extra: ColAlignments[].                }
{                                                                             }
{  Rows are one text row high; a column's last cell is its vertical line      }
{  (goVertLine), so ColWidths include it.                                     }
{  Keys: arrows, Home/End (first/last column), Ctrl+Home/End, PgUp/PgDn,      }
{  Tab/Shift+Tab between cells with goTabs; with goEditing F2 or Enter edits, }
{  a typed character starts editing with it; in the editor Enter keeps the    }
{  text, Esc throws it away, Up/Down/Tab keep it and move.                   }
{  Mouse: click a cell, double click edits, click a header (OnHeaderClick),  }
{  drag a header's right edge (goColSizing), scroll bars.                    }
{-----------------------------------------------------------------------------}
unit TUIGrid;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, Math, TUIHW, TUIScrn, TUICtrl, TUIStd, TUIList;

type
   TGridOption = (goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine,
                  goRangeSelect, goDrawFocusSelected, goRowSizing, goColSizing,
                  goRowMoving, goColMoving, goEditing, goTabs, goRowSelect,
                  goAlwaysShowEditor, goThumbTracking);
   TGridOptions = set of TGridOption;
   TGridDrawStates = (gdSelected, gdFocused, gdFixed);
   TGridDrawState = set of TGridDrawStates;
   TSortOrder = (soAscending, soDescending);

   TOnDrawCell = procedure(Sender: TObject; aCol, aRow: integer; aRect: TRect;
                           aState: TGridDrawState) of object;
   TOnSelectCellEvent = procedure(Sender: TObject; aCol, aRow: integer;
                                  var CanSelect: boolean) of object;
   TOnSelectEvent = procedure(Sender: TObject; aCol, aRow: integer) of object;
   THdrEvent = procedure(Sender: TObject; IsColumn: boolean; Index: integer) of object;
   TGetEditEvent = procedure(Sender: TObject; ACol, ARow: integer; var Value: string) of object;
   TSetEditEvent = procedure(Sender: TObject; ACol, ARow: integer; const Value: string) of object;

   TCustomGrid = class(TWinControl)
   private
      FColCount, FRowCount, FFixedCols, FFixedRows: integer;
      FColWidths: array of integer;
      FAligns: array of TAlignment;
      FDefaultColWidth: integer;
      FCol, FRow, FTopRow, FLeftCol: integer;
      FOptions: TGridOptions;
      FVBar, FHBar: boolean;
      FEditor: TEdit;
      FEditing, FEndingEdit: boolean;
      FSizingCol: integer;           { -1 or the column being resized }
      FThumbV, FThumbH: boolean;
      FHoldV, FHoldH: TScrollHit;
      FOnDrawCell: TOnDrawCell;
      FOnSelectCell: TOnSelectCellEvent;
      FOnSelection: TOnSelectEvent;
      FOnHeaderClick: THdrEvent;
      FOnGetEditText: TGetEditEvent;
      FOnSetEditText: TSetEditEvent;
      procedure SetColCount(V: integer);
      procedure SetRowCount(V: integer);
      procedure SetFixedCols(V: integer);
      procedure SetFixedRows(V: integer);
      function  GetColWidth(I: integer): integer;
      procedure SetColWidth(I: integer; V: integer);
      function  GetColAlign(I: integer): TAlignment;
      procedure SetColAlign(I: integer; V: TAlignment);
      procedure SetDefaultColWidth(V: integer);
      procedure SetOptions(V: TGridOptions);
      procedure SetTopRow(V: integer);
      procedure SetLeftCol(V: integer);
      procedure SetCol(V: integer);
      procedure SetRow(V: integer);
      procedure Measure;
      function  ViewW: integer;
      function  ViewH: integer;
      function  FixedW: integer;
      function  ScrollRows: integer;      { rows that fit below the fixed ones }
      function  MaxTopRow: integer;
      function  MaxLeftCol: integer;
      procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
      procedure EditorExit(Sender: TObject);
      procedure HitV(H: TScrollHit);
      procedure HitH(H: TScrollHit);
   protected
      procedure SizeChanged(OldCols, OldRows: integer); virtual;
      procedure DrawCell(aCol, aRow: integer; aRect: TRect; aState: TGridDrawState); virtual;
      function  GetEditText(aCol, aRow: integer): string; virtual;
      procedure SetEditText(aCol, aRow: integer; const Value: string); virtual;
      function  CellText(aCol, aRow: integer): string; virtual;
      { draw Text in a cell, aligned, in the cell's colours (OnDrawCell can use it) }
      procedure DrawCellText(aCol, aRow: integer; const aRect: TRect; aState: TGridDrawState;
                             const AText: string);
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure KeyPress(var Key: char); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseHeld(X, Y: integer); override;
      function  MouseWheel(WheelDelta: integer): boolean; override;
      procedure DblClick; override;
      procedure SetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
      function  WantsChars: boolean; override;
      function  GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean; override;
      { the cell at X, Y (relative to the grid); false = none }
      function  MouseToCell(X, Y: integer; out ACol, ARow: integer): boolean;
      { the cell's rectangle relative to the grid; empty when not shown }
      function  CellRect(ACol, ARow: integer): TRect;
      { the column's left (relative to the grid), -1 when not shown }
      function  ColX(ACol: integer): integer;
      procedure MoveTo(ACol, ARow: integer);
      procedure MakeVisible(ACol, ARow: integer);
      procedure EditorShow(const Initial: string; SelectAll: boolean);
      procedure EditorHide(Keep: boolean);
      property ColWidths[I: integer]: integer read GetColWidth write SetColWidth;
      property ColAlignments[I: integer]: TAlignment read GetColAlign write SetColAlign;
   published
      property EditorMode: boolean read FEditing;
      property ColCount: integer read FColCount write SetColCount default 5;
      property RowCount: integer read FRowCount write SetRowCount default 5;
      property FixedCols: integer read FFixedCols write SetFixedCols default 1;
      property FixedRows: integer read FFixedRows write SetFixedRows default 1;
      property DefaultColWidth: integer read FDefaultColWidth write SetDefaultColWidth default 10;
      property Col: integer read FCol write SetCol;
      property Row: integer read FRow write SetRow;
      property TopRow: integer read FTopRow write SetTopRow;
      property LeftCol: integer read FLeftCol write SetLeftCol;
      property Options: TGridOptions read FOptions write SetOptions;
      property OnDrawCell: TOnDrawCell read FOnDrawCell write FOnDrawCell;
      property OnSelectCell: TOnSelectCellEvent read FOnSelectCell write FOnSelectCell;
      property OnSelection: TOnSelectEvent read FOnSelection write FOnSelection;
      property OnHeaderClick: THdrEvent read FOnHeaderClick write FOnHeaderClick;
      property OnGetEditText: TGetEditEvent read FOnGetEditText write FOnGetEditText;
      property OnSetEditText: TSetEditEvent read FOnSetEditText write FOnSetEditText;
   end;

   { cells drawn by OnDrawCell (Canvas is set to the grid; aRect in its   }
   { coordinates); without OnDrawCell the cells are empty                 }
   TDrawGrid = class(TCustomGrid);

   TStringGrid = class(TCustomGrid)
   private
      FCells: array of array of string;      { [col][row] }
      FSortOrder: TSortOrder;
      function  GetCell(C, R: integer): string;
      procedure SetCell(C, R: integer; const V: string);
   protected
      procedure SizeChanged(OldCols, OldRows: integer); override;
      function  CellText(aCol, aRow: integer): string; override;
      function  GetEditText(aCol, aRow: integer): string; override;
      procedure SetEditText(aCol, aRow: integer; const Value: string); override;
   public
      constructor Create(AOwner: TComponent); override;
      procedure Clean;
      { sort the rows by a column (IsColumn true) or the columns by a row; }
      { numbers compare as numbers                                        }
      procedure SortColRow(IsColumn: boolean; Index: integer);
      procedure DeleteColRow(IsColumn: boolean; Index: integer);
      property Cells[C, R: integer]: string read GetCell write SetCell; default;
   published
      property SortOrder: TSortOrder read FSortOrder write FSortOrder default soAscending;
   end;

{ text compare with numbers as numbers (used by the grid and list view) }
function CompareCellText(const A, B: string): integer;

implementation

function CompareCellText(const A, B: string): integer;
var x, y: double;
begin
   if TryStrToFloat(Trim(A), x) and TryStrToFloat(Trim(B), y) then
   begin
      if x < y then Result := -1 else if x > y then Result := 1 else Result := 0;
   end
   else
      Result := CompareText(A, B);
end;

{=============================================================================}
{  TCustomGrid                                                                }
{=============================================================================}

constructor TCustomGrid.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FDefaultColWidth := 10;
   FFixedCols := 1;
   FFixedRows := 1;
   FOptions := [goFixedVertLine, goVertLine, goRangeSelect, goDrawFocusSelected];
   FSizingCol := -1;
   FWidth := 40;
   FHeight := 10;
   SetColCount(5);
   SetRowCount(5);
   FCol := 1;
   FRow := 1;
   FTopRow := 1;
   FLeftCol := 1;
end;

procedure TCustomGrid.SizeChanged(OldCols, OldRows: integer);
begin
end;

procedure TCustomGrid.SetColCount(V: integer);
var old, i: integer;
begin
   if V < 0 then V := 0;
   old := FColCount;
   if V = old then exit;
   SetLength(FColWidths, V);
   SetLength(FAligns, V);
   for i := old to V - 1 do
   begin
      FColWidths[i] := FDefaultColWidth;
      FAligns[i] := taLeftJustify;
   end;
   FColCount := V;
   if FFixedCols > V then FFixedCols := V;
   SizeChanged(old, FRowCount);
   if FCol >= V then FCol := V - 1;
   if FCol < FFixedCols then FCol := FFixedCols;
   if FLeftCol < FFixedCols then FLeftCol := FFixedCols;
   Invalidate;
end;

procedure TCustomGrid.SetRowCount(V: integer);
var old: integer;
begin
   if V < 0 then V := 0;
   old := FRowCount;
   if V = old then exit;
   FRowCount := V;
   if FFixedRows > V then FFixedRows := V;
   SizeChanged(FColCount, old);
   if FRow >= V then FRow := V - 1;
   if FRow < FFixedRows then FRow := FFixedRows;
   if FTopRow < FFixedRows then FTopRow := FFixedRows;
   if FTopRow > MaxTopRow then FTopRow := MaxTopRow;
   Invalidate;
end;

procedure TCustomGrid.SetFixedCols(V: integer);
begin
   if V < 0 then V := 0;
   if V > FColCount then V := FColCount;
   FFixedCols := V;
   if FCol < V then FCol := V;
   FLeftCol := V;                     { the first column after the fixed ones }
   Invalidate;
end;

procedure TCustomGrid.SetFixedRows(V: integer);
begin
   if V < 0 then V := 0;
   if V > FRowCount then V := FRowCount;
   FFixedRows := V;
   if FRow < V then FRow := V;
   FTopRow := V;
   Invalidate;
end;

function TCustomGrid.GetColWidth(I: integer): integer;
begin
   if (I >= 0) and (I < FColCount) then Result := FColWidths[I] else Result := FDefaultColWidth;
end;

procedure TCustomGrid.SetColWidth(I: integer; V: integer);
begin
   if (I < 0) or (I >= FColCount) then exit;
   if V < 1 then V := 1;
   FColWidths[I] := V;
   Invalidate;
end;

function TCustomGrid.GetColAlign(I: integer): TAlignment;
begin
   if (I >= 0) and (I < FColCount) then Result := FAligns[I] else Result := taLeftJustify;
end;

procedure TCustomGrid.SetColAlign(I: integer; V: TAlignment);
begin
   if (I < 0) or (I >= FColCount) then exit;
   FAligns[I] := V;
   Invalidate;
end;

procedure TCustomGrid.SetDefaultColWidth(V: integer);
var i: integer;
begin
   if V < 1 then V := 1;
   FDefaultColWidth := V;
   for i := 0 to FColCount - 1 do FColWidths[i] := V;
   Invalidate;
end;

procedure TCustomGrid.SetOptions(V: TGridOptions);
begin
   FOptions := V;
   if not (goEditing in V) and FEditing then EditorHide(true);
   Invalidate;
end;

{-------------------------------------------------------------- geometry --}

function TCustomGrid.FixedW: integer;
var i: integer;
begin
   Result := 0;
   for i := 0 to FFixedCols - 1 do inc(Result, FColWidths[i]);
end;

procedure TCustomGrid.Measure;
var total, i: integer;
begin
   total := 0;
   for i := 0 to FColCount - 1 do inc(total, FColWidths[i]);
   FVBar := FRowCount > Height;
   FHBar := total > Width - ord(FVBar);
   if FHBar and not FVBar then FVBar := FRowCount > Height - 1;
end;

function TCustomGrid.ViewW: integer;
begin
   Result := Width - ord(FVBar);
   if Result < 0 then Result := 0;
end;

function TCustomGrid.ViewH: integer;
begin
   Result := Height - ord(FHBar);
   if Result < 0 then Result := 0;
end;

function TCustomGrid.ScrollRows: integer;
begin
   Result := ViewH - FFixedRows;
   if Result < 1 then Result := 1;
end;

function TCustomGrid.MaxTopRow: integer;
begin
   Result := FRowCount - ScrollRows;
   if Result < FFixedRows then Result := FFixedRows;
end;

{ the left column that shows the last columns as far right as they go }
function TCustomGrid.MaxLeftCol: integer;
var w: integer;
begin
   Result := FColCount - 1;
   if Result < FFixedCols then exit(FFixedCols);
   w := FColWidths[Result];
   while (Result > FFixedCols) and (w + FColWidths[Result - 1] <= ViewW - FixedW) do
   begin
      dec(Result);
      inc(w, FColWidths[Result]);
   end;
end;

function TCustomGrid.ColX(ACol: integer): integer;
var i, x: integer;
begin
   Result := -1;
   if (ACol < 0) or (ACol >= FColCount) then exit;
   if ACol < FFixedCols then
   begin
      x := 0;
      for i := 0 to ACol - 1 do inc(x, FColWidths[i]);
      exit(x);
   end;
   if ACol < FLeftCol then exit;
   x := FixedW;
   for i := FLeftCol to ACol - 1 do inc(x, FColWidths[i]);
   if x < ViewW then Result := x;
end;

function TCustomGrid.CellRect(ACol, ARow: integer): TRect;
var x, y: integer;
begin
   Result := Rect(0, 0, 0, 0);
   Measure;
   x := ColX(ACol);
   if x < 0 then exit;
   if ARow < FFixedRows then y := ARow
   else if (ARow >= FTopRow) and (ARow - FTopRow + FFixedRows < ViewH) then
      y := ARow - FTopRow + FFixedRows
   else exit;
   Result := Rect(x, y, x + FColWidths[ACol], y + 1);
   if Result.Right > ViewW then Result.Right := ViewW;
end;

function TCustomGrid.MouseToCell(X, Y: integer; out ACol, ARow: integer): boolean;
var c, cx: integer;
begin
   Result := false;
   ACol := -1;
   ARow := -1;
   Measure;
   if (X < 0) or (Y < 0) or (X >= ViewW) or (Y >= ViewH) then exit;
   if Y < FFixedRows then ARow := Y else ARow := FTopRow + Y - FFixedRows;
   if ARow >= FRowCount then exit;
   for c := 0 to FColCount - 1 do
   begin
      cx := ColX(c);
      if (cx >= 0) and (X >= cx) and (X < cx + FColWidths[c]) then
      begin
         ACol := c;
         exit(true);
      end;
   end;
end;

procedure TCustomGrid.SetTopRow(V: integer);
begin
   Measure;
   if V > MaxTopRow then V := MaxTopRow;
   if V < FFixedRows then V := FFixedRows;
   if V = FTopRow then exit;
   if FEditing then EditorHide(true);
   FTopRow := V;
   Invalidate;
end;

procedure TCustomGrid.SetLeftCol(V: integer);
begin
   Measure;
   if V > MaxLeftCol then V := MaxLeftCol;
   if V < FFixedCols then V := FFixedCols;
   if V = FLeftCol then exit;
   if FEditing then EditorHide(true);
   FLeftCol := V;
   Invalidate;
end;

procedure TCustomGrid.MakeVisible(ACol, ARow: integer);
var w, i: integer;
begin
   Measure;
   if ARow >= FFixedRows then
   begin
      if ARow < FTopRow then SetTopRow(ARow)
      else if ARow >= FTopRow + ScrollRows then SetTopRow(ARow - ScrollRows + 1);
   end;
   if ACol >= FFixedCols then
   begin
      if ACol < FLeftCol then SetLeftCol(ACol)
      else
      begin
         { scroll right until the whole column fits (or it is the first) }
         repeat
            w := FixedW;
            for i := FLeftCol to ACol do inc(w, FColWidths[i]);
            if (w <= ViewW) or (FLeftCol >= ACol) then break;
            SetLeftCol(FLeftCol + 1);
         until false;
      end;
   end;
end;

procedure TCustomGrid.MoveTo(ACol, ARow: integer);
var can: boolean;
begin
   if FColCount = 0 then exit;
   if ACol >= FColCount then ACol := FColCount - 1;
   if ACol < FFixedCols then ACol := FFixedCols;
   if ARow >= FRowCount then ARow := FRowCount - 1;
   if ARow < FFixedRows then ARow := FFixedRows;
   if (ACol = FCol) and (ARow = FRow) then
   begin
      MakeVisible(ACol, ARow);
      exit;
   end;
   can := true;
   if Assigned(FOnSelectCell) then FOnSelectCell(Self, ACol, ARow, can);
   if not can then exit;
   if FEditing then EditorHide(true);
   FCol := ACol;
   FRow := ARow;
   MakeVisible(ACol, ARow);
   Invalidate;
   if Assigned(FOnSelection) then FOnSelection(Self, FCol, FRow);
end;

procedure TCustomGrid.SetCol(V: integer);
begin
   MoveTo(V, FRow);
end;

procedure TCustomGrid.SetRow(V: integer);
begin
   MoveTo(FCol, V);
end;

procedure TCustomGrid.SetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
   inherited SetBounds(ALeft, ATop, AWidth, AHeight);
   if FEditing then EditorHide(true);
end;

{---------------------------------------------------------------- paint --}

function TCustomGrid.CellText(aCol, aRow: integer): string;
begin
   Result := '';
end;

procedure TCustomGrid.DrawCellText(aCol, aRow: integer; const aRect: TRect;
                                   aState: TGridDrawState; const AText: string);
var a: byte;
    w, x: integer;
    s: string;
begin
   if gdFixed in aState then a := Theme.MenuBar
   else if gdSelected in aState then
   begin
      if Focused or FEditing then a := Theme.ListFocusSel else a := Theme.ListSel;
   end
   else a := Theme.List;
   w := aRect.Right - aRect.Left - 1;           { the last cell: the line }
   if w < 1 then w := aRect.Right - aRect.Left;
   s := Copy(AText, 1, w);
   case GetColAlign(aCol) of
      taRightJustify: x := aRect.Left + w - Length(s);
      taCenter:       x := aRect.Left + (w - Length(s)) div 2;
   else
      x := aRect.Left;
   end;
   Canvas.TextOut(x, aRect.Top, s, a);
end;

procedure TCustomGrid.DrawCell(aCol, aRow: integer; aRect: TRect; aState: TGridDrawState);
begin
   DrawCellText(aCol, aRow, aRect, aState, CellText(aCol, aRow));
   if Assigned(FOnDrawCell) then FOnDrawCell(Self, aCol, aRow, aRect, aState);
end;

procedure TCustomGrid.Paint;
var r, c, y, x, x2: integer;
    a, la: byte;
    st: TGridDrawState;
    rc: TRect;
    o: TPoint;
    fixed, line: boolean;
begin
   Measure;
   if FTopRow > MaxTopRow then FTopRow := MaxTopRow;
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', Theme.List);
   { the fixed (title) rows are gray across the whole width, also past the }
   { last column and over the scroll bar's column                          }
   if FFixedRows > 0 then
      Canvas.Fill(Rect(0, 0, Width, Min(FFixedRows, ViewH)), ' ', Theme.MenuBar);
   for y := 0 to ViewH - 1 do
   begin
      if y < FFixedRows then r := y else r := FTopRow + y - FFixedRows;
      if r >= FRowCount then
      begin
         { below the last row: the fixed columns and the column lines go }
         { on to the bottom                                             }
         for c := 0 to FColCount - 1 do
         begin
            x := ColX(c);
            if x < 0 then continue;
            x2 := x + FColWidths[c];
            if x2 > ViewW then x2 := ViewW;
            fixed := c < FFixedCols;
            if fixed then
            begin
               Canvas.Fill(Rect(x, y, x2, y + 1), ' ', Theme.MenuBar);
               line := goFixedVertLine in FOptions;
               la := Theme.MenuBar;
            end
            else
            begin
               line := goVertLine in FOptions;
               la := MakeAttr(tcDarkGray, AttrBg(Theme.List));
            end;
            if line and (x + FColWidths[c] <= ViewW) and (FColWidths[c] > 1) then
               Canvas.PutChar(x + FColWidths[c] - 1, y, #179, la);
         end;
         continue;
      end;
      for c := 0 to FColCount - 1 do
      begin
         x := ColX(c);
         if x < 0 then continue;
         x2 := x + FColWidths[c];
         if x2 > ViewW then x2 := ViewW;
         rc := Rect(x, y, x2, y + 1);
         fixed := (r < FFixedRows) or (c < FFixedCols);
         st := [];
         if fixed then Include(st, gdFixed)
         else if (r = FRow) and ((c = FCol) or (goRowSelect in FOptions)) then
         begin
            Include(st, gdSelected);
            if (c = FCol) and Focused then Include(st, gdFocused);
         end;
         if gdFixed in st then a := Theme.MenuBar
         else if gdSelected in st then
         begin
            if Focused or FEditing then a := Theme.ListFocusSel else a := Theme.ListSel;
         end
         else a := Theme.List;
         Canvas.Fill(rc, ' ', a);
         DrawCell(c, r, rc, st);
         { the column's line }
         if fixed then line := goFixedVertLine in FOptions else line := goVertLine in FOptions;
         if line and (x + FColWidths[c] <= ViewW) and (FColWidths[c] > 1) then
         begin
            if fixed then la := Theme.MenuBar
            else la := MakeAttr(tcDarkGray, AttrBg(Theme.List));
            if (gdSelected in st) and (goRowSelect in FOptions) then la := MakeAttr(tcDarkGray, AttrBg(a));
            Canvas.PutChar(x + FColWidths[c] - 1, y, #179, la);
         end;
      end;
   end;
   o := ScreenOrigin;
   la := MakeAttr(AttrFg(Theme.ListScroll), AttrBg(Theme.List));
   if FVBar then DrawVScroll(o.X + ViewW, o.Y + FFixedRows, ViewH - FFixedRows,
                             FTopRow - FFixedRows, MaxTopRow - FFixedRows, la);
   if FHBar then DrawHScroll(o.X + FixedW, o.Y + ViewH, ViewW - FixedW,
                             FLeftCol - FFixedCols, MaxLeftCol - FFixedCols, la);
end;

{--------------------------------------------------------------- editor --}

function TCustomGrid.GetEditText(aCol, aRow: integer): string;
begin
   Result := CellText(aCol, aRow);
   if Assigned(FOnGetEditText) then FOnGetEditText(Self, aCol, aRow, Result);
end;

procedure TCustomGrid.SetEditText(aCol, aRow: integer; const Value: string);
begin
   if Assigned(FOnSetEditText) then FOnSetEditText(Self, aCol, aRow, Value);
end;

procedure TCustomGrid.EditorShow(const Initial: string; SelectAll: boolean);
var rc: TRect;
begin
   if not (goEditing in FOptions) or FEditing then exit;
   MakeVisible(FCol, FRow);
   rc := CellRect(FCol, FRow);
   if (rc.Right <= rc.Left) then exit;
   if FEditor = nil then
   begin
      FEditor := TEdit.Create(Self);
      FEditor.TabStop := false;
      FEditor.Visible := false;
      FEditor.Parent := Self;
      FEditor.OnKeyDown := @EditorKeyDown;
      FEditor.OnExit := @EditorExit;
   end;
   if rc.Right - rc.Left > 1 then dec(rc.Right);   { keep the line }
   FEditor.SetBounds(rc.Left, rc.Top, rc.Right - rc.Left, 1);
   FEditor.Text := Initial;
   FEditing := true;
   FEditor.Visible := true;
   { not FEditor.SetFocus: the editor is no Tab stop, so it cannot take }
   { the focus the usual way                                           }
   if GetParentForm <> nil then GetParentForm.ActiveControl := FEditor;
   if SelectAll then FEditor.SelectAll else FEditor.SelStart := Length(Initial);
   Invalidate;
end;

procedure TCustomGrid.EditorHide(Keep: boolean);
begin
   if not FEditing or FEndingEdit then exit;
   FEndingEdit := true;
   try
      if Keep then SetEditText(FCol, FRow, FEditor.Text);
      FEditing := false;
      if FEditor.Focused and CanFocus then SetFocus;
      FEditor.Visible := false;
   finally
      FEndingEdit := false;
   end;
   Invalidate;
end;

procedure TCustomGrid.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
   case Key of
      VK_RETURN: begin EditorHide(true); Key := 0; end;
      VK_ESCAPE: begin EditorHide(false); Key := 0; end;
      VK_UP, VK_DOWN:
         begin
            EditorHide(true);
            if Key = VK_UP then MoveTo(FCol, FRow - 1) else MoveTo(FCol, FRow + 1);
            Key := 0;
         end;
      VK_TAB:
         if goTabs in FOptions then
         begin
            EditorHide(true);
            KeyDown(Key, Shift);
            Key := 0;
         end
         else EditorHide(true);
   end;
end;

procedure TCustomGrid.EditorExit(Sender: TObject);
begin
   { the focus went elsewhere (a click): keep the text }
   if FEditing and not FEndingEdit then EditorHide(true);
end;

{----------------------------------------------------------------- keys --}

procedure TCustomGrid.KeyDown(var Key: Word; Shift: TShiftState);
var ctrl: boolean;
begin
   inherited KeyDown(Key, Shift);
   if (Key = 0) or (ssAlt in Shift) then exit;
   ctrl := ssCtrl in Shift;
   Measure;
   case Key of
      VK_LEFT:  MoveTo(FCol - 1, FRow);
      VK_RIGHT: MoveTo(FCol + 1, FRow);
      VK_UP:    MoveTo(FCol, FRow - 1);
      VK_DOWN:  MoveTo(FCol, FRow + 1);
      VK_PRIOR:
         begin
            SetTopRow(FTopRow - ScrollRows + 1);
            MoveTo(FCol, FRow - ScrollRows + 1);
         end;
      VK_NEXT:
         begin
            SetTopRow(FTopRow + ScrollRows - 1);
            MoveTo(FCol, FRow + ScrollRows - 1);
         end;
      VK_HOME:  if ctrl then MoveTo(FFixedCols, FFixedRows) else MoveTo(FFixedCols, FRow);
      VK_END:   if ctrl then MoveTo(FColCount - 1, FRowCount - 1) else MoveTo(FColCount - 1, FRow);
      VK_TAB:
         if (goTabs in FOptions) and not ctrl then
         begin
            if ssShift in Shift then
            begin
               if FCol > FFixedCols then MoveTo(FCol - 1, FRow)
               else if FRow > FFixedRows then MoveTo(FColCount - 1, FRow - 1);
            end
            else if FCol < FColCount - 1 then MoveTo(FCol + 1, FRow)
            else if FRow < FRowCount - 1 then MoveTo(FFixedCols, FRow + 1);
         end
         else exit;
      VK_F2, VK_RETURN:
         if (goEditing in FOptions) and (Shift = []) then EditorShow(GetEditText(FCol, FRow), false)
         else exit;
   else
      exit;
   end;
   Key := 0;
end;

procedure TCustomGrid.KeyPress(var Key: char);
begin
   inherited KeyPress(Key);
   if (Key > ' ') and (goEditing in FOptions) and not FEditing then
   begin
      { a typed character replaces the cell }
      EditorShow(Key, false);
      Key := #0;
   end;
end;

function TCustomGrid.WantsChars: boolean;
begin
   Result := goEditing in FOptions;
end;

function TCustomGrid.GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean;
begin
   X := 0; Y := 0; Shape := csHidden;
   Result := false;
end;

{---------------------------------------------------------------- mouse --}

procedure TCustomGrid.HitV(H: TScrollHit);
begin
   case H of
      shLineUp:   SetTopRow(FTopRow - 1);
      shLineDown: SetTopRow(FTopRow + 1);
      shPageUp:   SetTopRow(FTopRow - ScrollRows + 1);
      shPageDown: SetTopRow(FTopRow + ScrollRows - 1);
      shThumb:    FThumbV := true;
   end;
end;

procedure TCustomGrid.HitH(H: TScrollHit);
begin
   case H of
      shLineUp:   SetLeftCol(FLeftCol - 1);
      shLineDown: SetLeftCol(FLeftCol + 1);
      shPageUp:   SetLeftCol(FLeftCol - 3);
      shPageDown: SetLeftCol(FLeftCol + 3);
      shThumb:    FThumbH := true;
   end;
end;

procedure TCustomGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var c, r, x2: integer;
begin
   inherited MouseDown(Button, Shift, X, Y);
   FHoldV := shNone;
   FHoldH := shNone;
   if Button <> mbLeft then exit;
   if FEditing then EditorHide(true);
   Measure;
   if FVBar and (X = ViewW) and (Y >= FFixedRows) and (Y < ViewH) then
   begin
      FHoldV := ScrollHitAt(Y - FFixedRows, ViewH - FFixedRows, FTopRow - FFixedRows, MaxTopRow - FFixedRows);
      HitV(FHoldV);
      if FHoldV = shThumb then FHoldV := shNone;
      exit;
   end;
   if FHBar and (Y = ViewH) and (X >= FixedW) and (X < ViewW) then
   begin
      FHoldH := ScrollHitAt(X - FixedW, ViewW - FixedW, FLeftCol - FFixedCols, MaxLeftCol - FFixedCols);
      HitH(FHoldH);
      if FHoldH = shThumb then FHoldH := shNone;
      exit;
   end;
   if not MouseToCell(X, Y, c, r) then exit;
   if r < FFixedRows then
   begin
      { the right edge of a header cell: resize the column }
      x2 := ColX(c) + FColWidths[c] - 1;
      if (goColSizing in FOptions) and (X = x2) then
      begin
         FSizingCol := c;
         exit;
      end;
      if Assigned(FOnHeaderClick) then FOnHeaderClick(Self, true, c);
      exit;
   end;
   if c < FFixedCols then
   begin
      if Assigned(FOnHeaderClick) then FOnHeaderClick(Self, false, r);
      exit;
   end;
   MoveTo(c, r);
end;

procedure TCustomGrid.MouseMove(Shift: TShiftState; X, Y: integer);
var c, r: integer;
begin
   inherited MouseMove(Shift, X, Y);
   if not (ssLeft in Shift) then exit;
   if FSizingCol >= 0 then
      SetColWidth(FSizingCol, X - ColX(FSizingCol) + 1)
   else if FThumbV then
      SetTopRow(FFixedRows + ScrollPosAt(Y - FFixedRows, ViewH - FFixedRows, MaxTopRow - FFixedRows))
   else if FThumbH then
      SetLeftCol(FFixedCols + ScrollPosAt(X - FixedW, ViewW - FixedW, MaxLeftCol - FFixedCols))
   else if MouseToCell(X, Y, c, r) and (r >= FFixedRows) and (c >= FFixedCols) then
      MoveTo(c, r);
end;

procedure TCustomGrid.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FSizingCol := -1;
   FThumbV := false;
   FThumbH := false;
   FHoldV := shNone;
   FHoldH := shNone;
   inherited MouseUp(Button, Shift, X, Y);
end;

procedure TCustomGrid.MouseHeld(X, Y: integer);
begin
   if (FHoldV <> shNone) and (X = ViewW) and
      (ScrollHitAt(Y - FFixedRows, ViewH - FFixedRows, FTopRow - FFixedRows, MaxTopRow - FFixedRows) = FHoldV) then
      HitV(FHoldV);
   if (FHoldH <> shNone) and (Y = ViewH) and
      (ScrollHitAt(X - FixedW, ViewW - FixedW, FLeftCol - FFixedCols, MaxLeftCol - FFixedCols) = FHoldH) then
      HitH(FHoldH);
end;

procedure TCustomGrid.DblClick;
begin
   inherited DblClick;
   if (goEditing in FOptions) and not FEditing then EditorShow(GetEditText(FCol, FRow), true);
end;

{=============================================================================}
{  TStringGrid                                                                }
{=============================================================================}

constructor TStringGrid.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   SizeChanged(0, 0);
end;

procedure TStringGrid.SizeChanged(OldCols, OldRows: integer);
var c: integer;
begin
   SetLength(FCells, ColCount);
   for c := 0 to ColCount - 1 do SetLength(FCells[c], RowCount);
end;

function TStringGrid.GetCell(C, R: integer): string;
begin
   if (C >= 0) and (C < ColCount) and (R >= 0) and (R < RowCount) then Result := FCells[C][R]
   else Result := '';
end;

procedure TStringGrid.SetCell(C, R: integer; const V: string);
begin
   if (C < 0) or (C >= ColCount) or (R < 0) or (R >= RowCount) then exit;
   FCells[C][R] := V;
   Invalidate;
end;

function TStringGrid.CellText(aCol, aRow: integer): string;
begin
   Result := GetCell(aCol, aRow);
end;

function TStringGrid.GetEditText(aCol, aRow: integer): string;
begin
   Result := GetCell(aCol, aRow);
   if Assigned(OnGetEditText) then OnGetEditText(Self, aCol, aRow, Result);
end;

procedure TStringGrid.SetEditText(aCol, aRow: integer; const Value: string);
begin
   SetCell(aCol, aRow, Value);
   inherited SetEditText(aCol, aRow, Value);
end;

procedure TStringGrid.Clean;
var c, r: integer;
begin
   for c := 0 to ColCount - 1 do
      for r := 0 to RowCount - 1 do FCells[c][r] := '';
   Invalidate;
end;

procedure TStringGrid.SortColRow(IsColumn: boolean; Index: integer);
var i, j, k, n, d: integer;
    t: string;

   function Cmp(A, B: integer): integer;
   begin
      if IsColumn then Result := CompareCellText(FCells[Index][A], FCells[Index][B])
      else Result := CompareCellText(FCells[A][Index], FCells[B][Index]);
      if FSortOrder = soDescending then Result := -Result;
   end;

   procedure Swap(A, B: integer);
   var x: integer;
   begin
      if IsColumn then
         for x := 0 to ColCount - 1 do
         begin
            t := FCells[x][A]; FCells[x][A] := FCells[x][B]; FCells[x][B] := t;
         end
      else
         for x := 0 to RowCount - 1 do
         begin
            t := FCells[A][x]; FCells[A][x] := FCells[B][x]; FCells[B][x] := t;
         end;
   end;

begin
   { insertion sort: stable, and grids are small }
   if IsColumn then begin k := FixedRows; n := RowCount; end
   else begin k := FixedCols; n := ColCount; end;
   for i := k + 1 to n - 1 do
   begin
      j := i;
      while j > k do
      begin
         d := Cmp(j - 1, j);
         if d <= 0 then break;
         Swap(j - 1, j);
         dec(j);
      end;
   end;
   Invalidate;
end;

procedure TStringGrid.DeleteColRow(IsColumn: boolean; Index: integer);
var c, r: integer;
begin
   if IsColumn then
   begin
      if (Index < 0) or (Index >= ColCount) then exit;
      for c := Index to ColCount - 2 do
      begin
         FCells[c] := FCells[c + 1];
         ColWidths[c] := ColWidths[c + 1];
         ColAlignments[c] := ColAlignments[c + 1];
      end;
      FCells[ColCount - 1] := nil;
      ColCount := ColCount - 1;
   end
   else
   begin
      if (Index < 0) or (Index >= RowCount) then exit;
      for c := 0 to ColCount - 1 do
         for r := Index to RowCount - 2 do FCells[c][r] := FCells[c][r + 1];
      RowCount := RowCount - 1;
   end;
   Invalidate;
end;


function TCustomGrid.MouseWheel(WheelDelta: integer): boolean;
begin
   SetTopRow(FTopRow - (WheelDelta div 120) * 3);
   Result := true;
end;

initialization
   RegisterClasses([TStringGrid, TDrawGrid]);
end.
