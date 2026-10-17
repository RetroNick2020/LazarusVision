{-----------------------------------------------------------------------------}
{  TUILIST - list controls for the text mode UI, LCL names:                    }
{     TListBox    Items, ItemIndex, TopIndex, Sorted, Frame,                   }
{                 OnClick, OnSelectionChange, OnDblClick                      }
{     TComboBox   Style csDropDown (type or pick) / csDropDownList (pick       }
{                 only), Items, ItemIndex, Text, DropDownCount, Sorted,       }
{                 DroppedDown, OnChange, OnSelect, OnDropDown, OnCloseUp       }
{                                                                             }
{  List box keys: Up/Down, PgUp/PgDn, Home/End, a letter jumps to the next     }
{  item starting with it. Mouse: click, drag, double click, the scroll bar    }
{  (arrows, track, dragging the thumb).                                       }
{  Combo box: Up/Down change the item without opening; Alt+Down or F4 opens   }
{  the list (also a click on the arrow, or anywhere for csDropDownList);      }
{  in the list Enter picks, Esc closes without a change.                      }
{                                                                             }
{  The scroll bar appears when there are more items than rows (TOT style:    }
{  arrows, a shaded track and a thumb).                                       }
{-----------------------------------------------------------------------------}
unit TUIList;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUIStd;

type
   TSelectionChangeEvent = procedure(Sender: TObject; User: boolean) of object;

   TScrollHit = (shNone, shLineUp, shLineDown, shPageUp, shPageDown, shThumb);

   TListBox = class(TWinControl)
   protected
      FItems: TStringList;
      FItemIndex, FTopIndex: integer;
      FFrame: boolean;
      FOnSelectionChange: TSelectionChangeEvent;
      FThumbDrag: boolean;
      FSelDrag: boolean;
      FDownOnItem: boolean;      { the last press was on an item (not the scroll bar) }
      FHoldHit: TScrollHit;      { held on the scroll bar: auto repeat }
      FLoadIndex: integer;       { ItemIndex read from an .lfm before the items }
      function  GetSorted: boolean;
      procedure SetSorted(V: boolean);
      procedure SetItems(V: TStrings);
      function  GetItems: TStrings;
      procedure SetItemIndex(V: integer);
      procedure SetTopIndex(V: integer);
      procedure SetFrame(V: boolean);
      procedure ItemsChanged(Sender: TObject);
      function  ListRect: TRect;
      function  Rows: integer;
      function  HasScrollBar: boolean;
      function  MaxTop: integer;
      procedure UserSelect(I: integer);
      procedure ThumbTo(Y: integer);
      { the text drawn for item I (TCheckListBox adds its box) }
      function  ItemText(I: integer): string; virtual;
      procedure DoScrollHit(H: TScrollHit);
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Loaded; override;
      procedure Paint; override;
      procedure MouseHeld(X, Y: integer); override;
      function  MouseWheel(WheelDelta: integer): boolean; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure KeyPress(var Key: char); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure DblClick; override;
      procedure SetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
      function  WantsChars: boolean; override;
      { the item at X, Y (relative to the list box), -1 = none }
      function  ItemAtPos(X, Y: integer): integer;
      procedure MakeCurrentVisible;
      procedure Clear;
      function  Count: integer;
      { a single line frame around the list (takes a row/column each side) }
   published
      property Items: TStrings read GetItems write SetItems;
      property ItemIndex: integer read FItemIndex write SetItemIndex default -1;
      property TopIndex: integer read FTopIndex write SetTopIndex;
      property Sorted: boolean read GetSorted write SetSorted default false;
      property Frame: boolean read FFrame write SetFrame default false;
      property OnSelectionChange: TSelectionChangeEvent read FOnSelectionChange write FOnSelectionChange;
   end;

   TComboBoxStyle = (csDropDown, csSimple, csDropDownList);

   TComboBox = class;

   { the drop-down list of a combo box, drawn over everything }
   TComboDropDown = class(TOverlayBase)
   private
      FCombo: TComboBox;
      FRect: TRect;           { frame, screen coordinates }
      FSel, FTop, FRows: integer;
      FThumbDrag: boolean;
      FIgnoreUp: boolean;     { the release of the click that opened it }
      procedure InvalidateIt;
      function  ItemAt(X, Y: integer): integer;
      procedure SetSel(I: integer);
      procedure Pick(I: integer);
   public
      procedure Open;
      procedure PaintPopups; override;
      procedure CloseMenu; override;
      procedure MenuKey(Key: Word; Ch: char; Shift: TShiftState); override;
      procedure MenuMouse(Down, Up: boolean; X, Y: integer; Buttons: byte); override;
   end;

   { an edit field with a list: TEdit underneath, so typing, the caret and }
   { selection work the same way                                          }
   TComboBox = class(TEdit)
   private
      FStyle: TComboBoxStyle;
      FItems: TStringList;
      FItemIndex: integer;
      FDropDownCount: integer;
      FDrop: TComboDropDown;
      FInSet: boolean;
      FLoadIndex: integer;
      FOnSelect, FOnDropDown, FOnCloseUp: TNotifyEvent;
      procedure SetStyle(V: TComboBoxStyle);
      procedure SetItems(V: TStrings);
      function  GetItems: TStrings;
      procedure SetItemIndex(V: integer);
      function  GetSorted: boolean;
      procedure SetSorted(V: boolean);
      function  GetDroppedDown: boolean;
      procedure SetDroppedDown(V: boolean);
      procedure ItemsChanged(Sender: TObject);
      procedure UserSelect(I: integer);
   protected
      procedure Change; override;
      function  EditWidth: integer; override;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure KeyPress(var Key: char); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure DoEnter; override;
      procedure Loaded; override;
      function  GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean; override;
      procedure DropDown;
      procedure CloseUp;
      procedure Clear;
   published
      property Style: TComboBoxStyle read FStyle write SetStyle default csDropDown;
      property Items: TStrings read GetItems write SetItems;
      property ItemIndex: integer read FItemIndex write SetItemIndex default -1;
      property Sorted: boolean read GetSorted write SetSorted default false;
      property DropDownCount: integer read FDropDownCount write FDropDownCount default 8;
      property DroppedDown: boolean read GetDroppedDown write SetDroppedDown;
      property OnSelect: TNotifyEvent read FOnSelect write FOnSelect;
      property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
      property OnCloseUp: TNotifyEvent read FOnCloseUp write FOnCloseUp;
   end;

{ a vertical scroll bar, screen coordinates: X, rows Y1..Y1+H-1 }
procedure DrawVScroll(X, Y1, H, Pos, MaxPos: integer; Attr: byte);
{ a horizontal one: row Y, columns X1..X1+W-1 }
procedure DrawHScroll(X1, Y, W, Pos, MaxPos: integer; Attr: byte);
{ thumb position (1..H-2) back to a scroll position }
function  ScrollPosAt(DY, H, MaxPos: integer): integer;
function  ScrollThumb(H, Pos, MaxPos: integer): integer;     { row of the thumb }
function  ScrollHitAt(DY, H, Pos, MaxPos: integer): TScrollHit;
{ the next item (after From, wrapping) starting with Ch; -1 = none }
function  FindByLetter(L: TStrings; From: integer; Ch: char): integer;

implementation

{=============================================================================}
{  scroll bar and search helpers                                              }
{=============================================================================}

function ScrollThumb(H, Pos, MaxPos: integer): integer;
var track: integer;
begin
   track := H - 2;
   if (track <= 1) or (MaxPos <= 0) then exit(1);
   if Pos < 0 then Pos := 0;
   if Pos > MaxPos then Pos := MaxPos;
   Result := 1 + (Pos * (track - 1) + MaxPos div 2) div MaxPos;
end;

procedure DrawVScroll(X, Y1, H, Pos, MaxPos: integer; Attr: byte);
var t: integer;
begin
   if H < 2 then exit;
   ScrPutChar(X, Y1, chArrowUp, Attr);
   ScrPutChar(X, Y1 + H - 1, chArrowDown, Attr);
   if H > 2 then
   begin
      ScrVLine(X, Y1 + 1, Y1 + H - 1, chShadeMedium, Attr);
      t := ScrollThumb(H, Pos, MaxPos);
      ScrPutChar(X, Y1 + t, chBlock, Attr);
   end;
end;

procedure DrawHScroll(X1, Y, W, Pos, MaxPos: integer; Attr: byte);
var t: integer;
begin
   if W < 2 then exit;
   ScrPutChar(X1, Y, chArrowLeft, Attr);
   ScrPutChar(X1 + W - 1, Y, chArrowRight, Attr);
   if W > 2 then
   begin
      ScrHLine(X1 + 1, X1 + W - 1, Y, chShadeMedium, Attr);
      t := ScrollThumb(W, Pos, MaxPos);
      ScrPutChar(X1 + t, Y, chBlock, Attr);
   end;
end;

function ScrollPosAt(DY, H, MaxPos: integer): integer;
var track: integer;
begin
   track := H - 2;
   if (track <= 1) or (MaxPos <= 0) then exit(0);
   Result := ((DY - 1) * MaxPos + (track - 1) div 2) div (track - 1);
   if Result < 0 then Result := 0;
   if Result > MaxPos then Result := MaxPos;
end;

function ScrollHitAt(DY, H, Pos, MaxPos: integer): TScrollHit;
var t: integer;
begin
   if (DY < 0) or (DY >= H) then exit(shNone);
   if DY = 0 then exit(shLineUp);
   if DY = H - 1 then exit(shLineDown);
   t := ScrollThumb(H, Pos, MaxPos);
   if DY < t then Result := shPageUp
   else if DY > t then Result := shPageDown
   else Result := shThumb;
end;

function FindByLetter(L: TStrings; From: integer; Ch: char): integer;
var i, k, n: integer;
    s: string;
begin
   Result := -1;
   n := L.Count;
   if n = 0 then exit;
   Ch := UpCase(Ch);
   i := From;
   for k := 1 to n do
   begin
      i := (i + 1) mod n;
      if i < 0 then i := 0;
      s := TrimLeft(L[i]);
      if (s <> '') and (UpCase(s[1]) = Ch) then exit(i);
   end;
end;

{=============================================================================}
{  TListBox                                                                   }
{=============================================================================}

constructor TListBox.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FItems := TStringList.Create;
   FItems.OnChange := @ItemsChanged;
   FItemIndex := -1;
   FLoadIndex := -2;
   FWidth := 20;
   FHeight := 6;
end;

destructor TListBox.Destroy;
begin
   FItems.OnChange := nil;
   FreeAndNil(FItems);
   inherited Destroy;
end;

function TListBox.GetItems: TStrings;
begin
   Result := FItems;
end;

procedure TListBox.SetItems(V: TStrings);
begin
   FItems.Assign(V);
end;

function TListBox.GetSorted: boolean;
begin
   Result := FItems.Sorted;
end;

procedure TListBox.SetSorted(V: boolean);
begin
   FItems.Sorted := V;
end;

function TListBox.Count: integer;
begin
   Result := FItems.Count;
end;

procedure TListBox.Clear;
begin
   FItems.Clear;
end;

procedure TListBox.SetFrame(V: boolean);
begin
   if V = FFrame then exit;
   FFrame := V;
   MakeCurrentVisible;
   Invalidate;
end;

{ the rows the items use, relative to the control (scroll bar excluded) }
function TListBox.ListRect: TRect;
begin
   Result := Rect(0, 0, Width, Height);
   if FFrame then
   begin
      inc(Result.Left); inc(Result.Top); dec(Result.Right); dec(Result.Bottom);
   end;
   if HasScrollBar then dec(Result.Right);
end;

function TListBox.Rows: integer;
begin
   Result := Height;
   if FFrame then dec(Result, 2);
   if Result < 1 then Result := 1;
end;

function TListBox.HasScrollBar: boolean;
begin
   Result := FItems.Count > Rows;
end;

function TListBox.MaxTop: integer;
begin
   Result := FItems.Count - Rows;
   if Result < 0 then Result := 0;
end;

procedure TListBox.ItemsChanged(Sender: TObject);
begin
   if FItemIndex >= FItems.Count then FItemIndex := FItems.Count - 1;
   if FTopIndex > MaxTop then FTopIndex := MaxTop;
   Invalidate;
end;

procedure TListBox.SetTopIndex(V: integer);
begin
   if V > MaxTop then V := MaxTop;
   if V < 0 then V := 0;
   if V = FTopIndex then exit;
   FTopIndex := V;
   Invalidate;
end;

procedure TListBox.MakeCurrentVisible;
begin
   if FItemIndex < 0 then exit;
   if FItemIndex < FTopIndex then SetTopIndex(FItemIndex)
   else if FItemIndex >= FTopIndex + Rows then SetTopIndex(FItemIndex - Rows + 1);
end;

procedure TListBox.Loaded;
begin
   inherited Loaded;
   if FLoadIndex <> -2 then SetItemIndex(FLoadIndex);
   FLoadIndex := -2;
end;

procedure TListBox.SetItemIndex(V: integer);
begin
   { (an .lfm may give ItemIndex before Items: keep it until Loaded) }
   if csLoading in ComponentState then
   begin
      FLoadIndex := V;
      exit;
   end;
   if V >= FItems.Count then V := FItems.Count - 1;
   if V < -1 then V := -1;
   if V = FItemIndex then exit;
   FItemIndex := V;
   MakeCurrentVisible;
   Invalidate;
   if Assigned(FOnSelectionChange) then FOnSelectionChange(Self, false);
end;

{ a change made by the user: OnSelectionChange(User) and OnClick, as LCL }
procedure TListBox.UserSelect(I: integer);
begin
   if FItems.Count = 0 then exit;
   if I >= FItems.Count then I := FItems.Count - 1;
   if I < 0 then I := 0;
   if I = FItemIndex then
   begin
      MakeCurrentVisible;
      exit;
   end;
   FItemIndex := I;
   MakeCurrentVisible;
   Invalidate;
   if Assigned(FOnSelectionChange) then FOnSelectionChange(Self, true);
   if Assigned(OnClick) then OnClick(Self);
end;

procedure TListBox.SetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
   inherited SetBounds(ALeft, ATop, AWidth, AHeight);
   if FItems <> nil then
   begin
      if FTopIndex > MaxTop then FTopIndex := MaxTop;
      MakeCurrentVisible;
   end;
end;

procedure TListBox.Paint;
var r: TRect;
    a, sel, fa: byte;
    i, y, w: integer;
    o: TPoint;
begin
   a := Theme.List;
   if (Color >= 0) and (Color <= 15) then a := MakeAttr(AttrFg(a), Color);
   if not IsEnabledAll then a := MakeAttr(Theme.DisabledFg, AttrBg(a))
   else a := MakeAttr(TextColor(AttrFg(a)), AttrBg(a));
   if Focused then sel := Theme.ListFocusSel else sel := Theme.ListSel;
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   if FFrame then
   begin
      if Focused then fa := MakeAttr(tcWhite, AttrBg(a)) else fa := a;
      Canvas.Frame(Rect(0, 0, Width, Height), 1, fa);
   end;
   r := ListRect;
   w := r.Right - r.Left;
   for i := 0 to Rows - 1 do
   begin
      if FTopIndex + i >= FItems.Count then break;
      y := r.Top + i;
      if FTopIndex + i = FItemIndex then
      begin
         Canvas.Fill(Rect(r.Left, y, r.Right, y + 1), ' ', sel);
         Canvas.TextOut(r.Left + 1, y, Copy(ItemText(FTopIndex + i), 1, w - 1), sel);
      end
      else
         Canvas.TextOut(r.Left + 1, y, Copy(ItemText(FTopIndex + i), 1, w - 1), a);
   end;
   if HasScrollBar then
   begin
      o := ScreenOrigin;
      DrawVScroll(o.X + r.Right, o.Y + r.Top, Rows, FTopIndex, MaxTop,
                  MakeAttr(AttrFg(Theme.ListScroll), AttrBg(a)));
   end;
end;

procedure TListBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
   inherited KeyDown(Key, Shift);
   if (Key = 0) or (Shift * [ssAlt, ssCtrl] <> []) then exit;
   case Key of
      VK_UP:    begin UserSelect(FItemIndex - 1); Key := 0; end;
      VK_DOWN:  begin UserSelect(FItemIndex + 1); Key := 0; end;
      VK_PRIOR: begin UserSelect(FItemIndex - (Rows - 1)); Key := 0; end;
      VK_NEXT:
         begin
            if FItemIndex < 0 then UserSelect(Rows - 1)
            else UserSelect(FItemIndex + (Rows - 1));
            Key := 0;
         end;
      VK_HOME:  begin UserSelect(0); Key := 0; end;
      VK_END:   begin UserSelect(FItems.Count - 1); Key := 0; end;
   end;
end;

procedure TListBox.KeyPress(var Key: char);
var i: integer;
begin
   inherited KeyPress(Key);
   if Key <= ' ' then exit;
   i := FindByLetter(FItems, FItemIndex, Key);
   if i >= 0 then UserSelect(i);
   Key := #0;
end;

function TListBox.WantsChars: boolean;
begin
   Result := true;          { letters search the list, not the access keys }
end;

function TListBox.ItemAtPos(X, Y: integer): integer;
var r: TRect;
begin
   r := ListRect;
   if not PtInRectI(r, X, Y) then exit(-1);
   Result := FTopIndex + Y - r.Top;
   if Result >= FItems.Count then Result := -1;
end;

procedure TListBox.ThumbTo(Y: integer);
var r: TRect;
    track: integer;
begin
   r := ListRect;
   track := Rows - 2;
   if track <= 1 then exit;
   SetTopIndex(((Y - r.Top - 1) * MaxTop + (track - 1) div 2) div (track - 1));
end;

procedure TListBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var r: TRect;
    i: integer;
begin
   inherited MouseDown(Button, Shift, X, Y);
   FDownOnItem := false;
   if Button <> mbLeft then exit;
   r := ListRect;
   FHoldHit := shNone;
   if HasScrollBar and (X = r.Right) and (Y >= r.Top) and (Y < r.Bottom) then
   begin
      FHoldHit := ScrollHitAt(Y - r.Top, Rows, FTopIndex, MaxTop);
      DoScrollHit(FHoldHit);
      if FHoldHit = shThumb then FHoldHit := shNone;
      exit;
   end;
   i := ItemAtPos(X, Y);
   if i >= 0 then
   begin
      UserSelect(i);
      FSelDrag := true;
      FDownOnItem := true;
   end;
end;

{ only a double click on an item counts (not on the scroll bar, the frame }
{ or the empty rows below the last item)                                 }
procedure TListBox.DblClick;
begin
   if FDownOnItem then inherited DblClick;
end;

function TListBox.ItemText(I: integer): string;
begin
   Result := FItems[I];
end;

procedure TListBox.DoScrollHit(H: TScrollHit);
begin
   case H of
      shLineUp:   SetTopIndex(FTopIndex - 1);
      shLineDown: SetTopIndex(FTopIndex + 1);
      shPageUp:   SetTopIndex(FTopIndex - (Rows - 1));
      shPageDown: SetTopIndex(FTopIndex + (Rows - 1));
      shThumb:    FThumbDrag := true;
   end;
end;

{ holding the button on an arrow or the track keeps scrolling }
procedure TListBox.MouseHeld(X, Y: integer);
var r: TRect;
    h: TScrollHit;
begin
   if FHoldHit = shNone then exit;
   r := ListRect;
   if (X <> r.Right) or (Y < r.Top) or (Y >= r.Bottom) then exit;
   h := ScrollHitAt(Y - r.Top, Rows, FTopIndex, MaxTop);
   if h = FHoldHit then DoScrollHit(h);
end;

procedure TListBox.MouseMove(Shift: TShiftState; X, Y: integer);
var r: TRect;
begin
   inherited MouseMove(Shift, X, Y);
   if not (ssLeft in Shift) then exit;
   if FThumbDrag then ThumbTo(Y)
   else if FSelDrag then
   begin
      { dragging past the ends scrolls }
      r := ListRect;
      if Y < r.Top then UserSelect(FTopIndex - 1)
      else if Y >= r.Bottom then UserSelect(FTopIndex + Rows)
      else UserSelect(FTopIndex + Y - r.Top);
   end;
end;

procedure TListBox.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FThumbDrag := false;
   FHoldHit := shNone;
   FSelDrag := false;
   { not inherited: OnClick comes from the selection change, as in the LCL }
   if Assigned(OnMouseUp) then OnMouseUp(Self, Button, Shift, X, Y);
end;

{=============================================================================}
{  TComboDropDown                                                             }
{=============================================================================}

procedure TComboDropDown.InvalidateIt;
var r: TRect;
begin
   r := FRect;
   inc(r.Right, 2);
   inc(r.Bottom, 1);
   if Application <> nil then Application.InvalidateRect(r);
   FCombo.Invalidate;
end;

procedure TComboDropDown.Open;
var cr: TRect;
    h, w: integer;
begin
   cr := FCombo.ScreenRect;
   FRows := FCombo.FItems.Count;
   if FRows > FCombo.FDropDownCount then FRows := FCombo.FDropDownCount;
   if FRows < 1 then FRows := 1;
   h := FRows + 2;
   w := cr.Right - cr.Left;
   if w < 8 then w := 8;
   { below the field, or above it when there is no room }
   if cr.Bottom + h <= ScrRows then FRect := Rect(cr.Left, cr.Bottom, cr.Left + w, cr.Bottom + h)
   else if cr.Top - h >= 0 then FRect := Rect(cr.Left, cr.Top - h, cr.Left + w, cr.Top)
   else
   begin
      FRows := ScrRows - cr.Bottom - 2;
      if FRows < 1 then FRows := 1;
      FRect := Rect(cr.Left, cr.Bottom, cr.Left + w, cr.Bottom + FRows + 2);
   end;
   if FRect.Right > ScrCols then OffsetRect(FRect, ScrCols - FRect.Right, 0);
   FSel := FCombo.FItemIndex;
   FTop := 0;
   SetSel(FSel);
   FThumbDrag := false;
   Application.MenuOpened(Self);
   InvalidateIt;
end;

procedure TComboDropDown.CloseMenu;
begin
   if (Application = nil) or (Application.OpenOverlay <> Self) then exit;
   InvalidateIt;
   Application.MenuClosed(Self);
   if Assigned(FCombo.FOnCloseUp) then FCombo.FOnCloseUp(FCombo);
end;

procedure TComboDropDown.SetSel(I: integer);
var n: integer;
begin
   n := FCombo.FItems.Count;
   if n = 0 then begin FSel := -1; exit; end;
   if I >= n then I := n - 1;
   if I < -1 then I := -1;
   FSel := I;
   if FSel >= 0 then
   begin
      if FSel < FTop then FTop := FSel;
      if FSel >= FTop + FRows then FTop := FSel - FRows + 1;
   end;
   if FTop > n - FRows then FTop := n - FRows;
   if FTop < 0 then FTop := 0;
   InvalidateIt;
end;

procedure TComboDropDown.Pick(I: integer);
begin
   CloseMenu;
   if I >= 0 then FCombo.UserSelect(I);
end;

function TComboDropDown.ItemAt(X, Y: integer): integer;
var w: integer;
begin
   w := FRect.Right - 1;
   if FCombo.FItems.Count > FRows then dec(w);
   if (X <= FRect.Left) or (X >= w) or (Y <= FRect.Top) or (Y >= FRect.Bottom - 1) then exit(-1);
   Result := FTop + Y - FRect.Top - 1;
   if Result >= FCombo.FItems.Count then Result := -1;
end;

procedure TComboDropDown.PaintPopups;
var i, y, w, n, maxTop: integer;
    a: byte;
begin
   ScrFill(FRect, ' ', Theme.List);
   ScrBox(FRect, 1, Theme.List);
   if Theme.WindowShadow then ScrWindowShadow(FRect);
   n := FCombo.FItems.Count;
   w := FRect.Right - FRect.Left - 2;
   if n > FRows then dec(w);
   for i := 0 to FRows - 1 do
   begin
      if FTop + i >= n then break;
      y := FRect.Top + 1 + i;
      if FTop + i = FSel then a := Theme.ListFocusSel else a := Theme.List;
      ScrFill(Rect(FRect.Left + 1, y, FRect.Left + 1 + w, y + 1), ' ', a);
      ScrPutStr(FRect.Left + 2, y, Copy(FCombo.FItems[FTop + i], 1, w - 1), a);
   end;
   if n > FRows then
   begin
      maxTop := n - FRows;
      DrawVScroll(FRect.Right - 2, FRect.Top + 1, FRows, FTop, maxTop, Theme.ListScroll);
   end;
end;

procedure TComboDropDown.MenuKey(Key: Word; Ch: char; Shift: TShiftState);
var i: integer;
begin
   case Key of
      VK_ESCAPE, VK_F4: CloseMenu;
      VK_UP:
         if ssAlt in Shift then Pick(FSel) else SetSel(FSel - 1);
      VK_DOWN:
         if FSel < 0 then SetSel(0) else SetSel(FSel + 1);
      VK_PRIOR: SetSel(FSel - (FRows - 1));
      VK_NEXT:  SetSel(FSel + (FRows - 1));
      VK_HOME:  SetSel(0);
      VK_END:   SetSel(FCombo.FItems.Count - 1);
      VK_RETURN, VK_TAB: Pick(FSel);
   else
      if Ch > ' ' then
      begin
         i := FindByLetter(FCombo.FItems, FSel, Ch);
         if i >= 0 then SetSel(i);
      end;
   end;
end;

procedure TComboDropDown.MenuMouse(Down, Up: boolean; X, Y: integer; Buttons: byte);
var i, n, sx, track: integer;
begin
   n := FCombo.FItems.Count;
   sx := FRect.Right - 2;
   if Down then
   begin
      FIgnoreUp := false;
      if not PtInRectI(FRect, X, Y) then
      begin
         CloseMenu;                     { a click outside closes the list }
         exit;
      end;
      if (n > FRows) and (X = sx) and (Y > FRect.Top) and (Y < FRect.Bottom - 1) then
      begin
         case ScrollHitAt(Y - FRect.Top - 1, FRows, FTop, n - FRows) of
            shLineUp:   begin FTop := FTop - 1; SetSel(FSel); end;
            shLineDown: begin FTop := FTop + 1; if FTop > n - FRows then FTop := n - FRows; InvalidateIt; end;
            shPageUp:   begin FTop := FTop - (FRows - 1); SetSel(FSel); end;
            shPageDown: begin FTop := FTop + (FRows - 1); if FTop > n - FRows then FTop := n - FRows; InvalidateIt; end;
            shThumb:    FThumbDrag := true;
         end;
         if FTop < 0 then FTop := 0;
         exit;
      end;
      i := ItemAt(X, Y);
      if i >= 0 then SetSel(i);
      exit;
   end;
   if Up then
   begin
      FThumbDrag := false;
      if FIgnoreUp then
      begin
         { the release of the click on the combo box that opened the list }
         FIgnoreUp := false;
         i := ItemAt(X, Y);
         if i >= 0 then Pick(i);
         exit;
      end;
      i := ItemAt(X, Y);
      if i >= 0 then Pick(i);
      exit;
   end;
   { a move }
   if FThumbDrag and (Buttons and 1 <> 0) then
   begin
      track := FRows - 2;
      if (track > 1) and (n > FRows) then
      begin
         FTop := ((Y - FRect.Top - 2) * (n - FRows) + (track - 1) div 2) div (track - 1);
         if FTop < 0 then FTop := 0;
         if FTop > n - FRows then FTop := n - FRows;
         InvalidateIt;
      end;
   end
   else
   begin
      i := ItemAt(X, Y);
      if (i >= 0) and (i <> FSel) then SetSel(i);
   end;
end;

{=============================================================================}
{  TComboBox                                                                  }
{=============================================================================}

constructor TComboBox.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FItems := TStringList.Create;
   FItems.OnChange := @ItemsChanged;
   FItemIndex := -1;
   FLoadIndex := -2;
   FDropDownCount := 8;
   FDrop := TComboDropDown.Create(nil);
   FDrop.FCombo := Self;
   FWidth := 20;
   FHeight := 1;
end;

destructor TComboBox.Destroy;
begin
   if FDrop <> nil then FDrop.CloseMenu;
   FreeAndNil(FDrop);
   FItems.OnChange := nil;
   FreeAndNil(FItems);
   inherited Destroy;
end;

function TComboBox.GetItems: TStrings;
begin
   Result := FItems;
end;

procedure TComboBox.SetItems(V: TStrings);
begin
   FItems.Assign(V);
end;

function TComboBox.GetSorted: boolean;
begin
   Result := FItems.Sorted;
end;

procedure TComboBox.SetSorted(V: boolean);
begin
   FItems.Sorted := V;
end;

procedure TComboBox.Clear;
begin
   FItems.Clear;
   Text := '';
end;

procedure TComboBox.SetStyle(V: TComboBoxStyle);
begin
   if V = FStyle then exit;
   FStyle := V;
   FReadOnly := V = csDropDownList;
   if (V = csDropDownList) and (FItemIndex < 0) then inherited SetCaption('');
   Invalidate;
end;

function TComboBox.EditWidth: integer;
begin
   Result := Width - 1;
   if Result < 1 then Result := 1;
end;

procedure TComboBox.ItemsChanged(Sender: TObject);
begin
   if FItemIndex >= FItems.Count then FItemIndex := -1;
   Invalidate;
end;

procedure TComboBox.Loaded;
begin
   inherited Loaded;
   if FLoadIndex <> -2 then SetItemIndex(FLoadIndex);
   FLoadIndex := -2;
end;

procedure TComboBox.SetItemIndex(V: integer);
begin
   if csLoading in ComponentState then
   begin
      FLoadIndex := V;
      exit;
   end;
   if (V < -1) or (V >= FItems.Count) then V := -1;
   FItemIndex := V;
   FInSet := true;
   try
      if V >= 0 then Text := FItems[V] else Text := '';
   finally
      FInSet := false;
   end;
   Invalidate;
end;

{ a pick by the user (arrows, letters, the list): OnSelect }
procedure TComboBox.UserSelect(I: integer);
begin
   if FItems.Count = 0 then exit;
   if I < 0 then I := 0;
   if I >= FItems.Count then I := FItems.Count - 1;
   if I = FItemIndex then exit;
   SetItemIndex(I);
   FSelAll := (FStyle <> csDropDownList) and Focused;
   if Assigned(FOnSelect) then FOnSelect(Self);
end;

procedure TComboBox.Change;
var i: integer;
begin
   { typed text that matches an item selects it, as in the LCL }
   if not FInSet then
   begin
      FItemIndex := -1;
      for i := 0 to FItems.Count - 1 do
         if CompareText(FItems[i], Text) = 0 then
         begin
            FItemIndex := i;
            break;
         end;
   end;
   inherited Change;
end;

function TComboBox.GetDroppedDown: boolean;
begin
   Result := (Application <> nil) and (Application.OpenOverlay = FDrop);
end;

procedure TComboBox.SetDroppedDown(V: boolean);
begin
   if V then DropDown else CloseUp;
end;

procedure TComboBox.DropDown;
begin
   if DroppedDown or not IsEnabledAll then exit;
   if CanFocus and not Focused then SetFocus;
   if Assigned(FOnDropDown) then FOnDropDown(Self);
   FDrop.Open;
end;

procedure TComboBox.CloseUp;
begin
   if DroppedDown then FDrop.CloseMenu;
end;

procedure TComboBox.Paint;
var a, b: byte;
    s: string;
begin
   if FStyle = csDropDownList then
   begin
      if Focused then a := Theme.ListFocusSel else a := Theme.Edit;
      if not IsEnabledAll then a := MakeAttr(Theme.DisabledFg, AttrBg(Theme.Edit));
      s := Copy(Text, 1, EditWidth - 1);
      Canvas.Fill(Rect(0, 0, EditWidth, Height), ' ', a);
      Canvas.TextOut(1, 0, s, a);
   end
   else
      inherited Paint;
   if Focused then b := Theme.ButtonFocus else b := Theme.ComboButton;
   if not IsEnabledAll then b := Theme.ButtonDisabled;
   Canvas.PutChar(Width - 1, 0, chArrowDown, b);
end;

procedure TComboBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
   if ((Key = VK_DOWN) and (ssAlt in Shift)) or ((Key = VK_F4) and (Shift = [])) then
   begin
      Key := 0;
      DropDown;
      exit;
   end;
   if Shift * [ssAlt, ssCtrl] = [] then
      case Key of
         VK_UP:
            begin
               Key := 0;
               if FItemIndex < 0 then UserSelect(0) else UserSelect(FItemIndex - 1);
               exit;
            end;
         VK_DOWN:
            begin
               Key := 0;
               UserSelect(FItemIndex + 1);
               exit;
            end;
         VK_HOME, VK_END:
            if FStyle = csDropDownList then
            begin
               if Key = VK_HOME then UserSelect(0) else UserSelect(FItems.Count - 1);
               Key := 0;
               exit;
            end;
      end;
   inherited KeyDown(Key, Shift);
end;

procedure TComboBox.KeyPress(var Key: char);
var i: integer;
begin
   if (FStyle = csDropDownList) and (Key > ' ') then
   begin
      i := FindByLetter(FItems, FItemIndex, Key);
      if i >= 0 then UserSelect(i);
      Key := #0;
      exit;
   end;
   inherited KeyPress(Key);
end;

procedure TComboBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   if (Button = mbLeft) and ((FStyle = csDropDownList) or (X >= Width - 1)) then
   begin
      if DroppedDown then CloseUp
      else
      begin
         DropDown;
         FDrop.FIgnoreUp := true;
      end;
      exit;
   end;
   inherited MouseDown(Button, Shift, X, Y);
end;

procedure TComboBox.DoEnter;
begin
   inherited DoEnter;
   if FStyle = csDropDownList then FSelAll := false;
end;

function TComboBox.GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean;
begin
   if FStyle = csDropDownList then
   begin
      X := 0; Y := 0; Shape := csHidden;
      Result := false;
   end
   else
      Result := inherited GetCaretPos(X, Y, Shape);
end;


{ the wheel scrolls three rows a notch }
function TListBox.MouseWheel(WheelDelta: integer): boolean;
begin
   SetTopIndex(FTopIndex - (WheelDelta div 120) * 3);
   Result := true;
end;

initialization
   RegisterClasses([TListBox, TComboBox]);
end.
