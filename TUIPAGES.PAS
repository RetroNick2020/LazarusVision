{-----------------------------------------------------------------------------}
{  TUIPAGES - containers, LCL names (the LCL units in brackets):               }
{     TPageControl, TTabSheet (ComCtrls)                                      }
{        the tabs sit on the frame's top line: ┌ General ─[Options]─ Notes ┐  }
{        Ctrl+Tab / Ctrl+Shift+Tab, Ctrl+PgDn/PgUp switch pages from inside; }
{        on the tab row (the page control focused) Left/Right; Alt+letter    }
{        picks a tab while the focus is inside; a click on a tab.            }
{     TScrollBox (Forms)                                                      }
{        children placed on a larger area; scroll bars when they do not fit; }
{        the focused control is scrolled into view; PgUp/PgDn scroll.        }
{     TSplitter (ExtCtrls)                                                    }
{        between aligned controls: drag it to resize its neighbour.          }
{     TSpeedButton (Buttons), TToolBar, TToolButton (ComCtrls)                }
{        buttons for the mouse (no focus): GroupIndex/Down/AllowAllUp; the   }
{        tool bar lays them out left to right, tbsSeparator, tbsCheck.       }
{-----------------------------------------------------------------------------}
unit TUIPages;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUIList;

type
   TPageControl = class;

   TTabSheet = class(TWinControl)
   private
      FPageControl: TPageControl;
      FTabVisible: boolean;
      procedure SetPageControl(V: TPageControl);
      procedure SetTabVisible(V: boolean);
      function  GetPageIndex: integer;
   protected
      procedure SetCaption(const V: string); override;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Paint; override;
      { in an .lfm a tab sheet sits inside its page control }
      procedure SetParentComponent(Value: TComponent); override;
   published
      property PageControl: TPageControl read FPageControl write SetPageControl;
      property PageIndex: integer read GetPageIndex;
      property TabVisible: boolean read FTabVisible write SetTabVisible default true;
   end;

   TTabChangingEvent = procedure(Sender: TObject; var AllowChange: boolean) of object;

   TPageControl = class(TWinControl)
   private
      FPages: TFPList;
      FActivePage: TTabSheet;
      FOnChange: TNotifyEvent;
      FOnChanging: TTabChangingEvent;
      function  GetPage(I: integer): TTabSheet;
      function  GetPageCount: integer;
      function  GetActivePageIndex: integer;
      procedure SetActivePageIndex(V: integer);
      procedure SetActivePage(V: TTabSheet);
      procedure InsertPage(P: TTabSheet);
      procedure RemovePage(P: TTabSheet);
      procedure TabPos(I: integer; out X1, X2: integer);
      function  TabAt(X: integer): integer;
      function  NextTab(Dir: integer): integer;
      function  ChangePage(P: TTabSheet): boolean;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure DialogKey(var Key: Word; Shift: TShiftState); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      function  ClientOffset: TPoint; override;
      function  ClientWidthValue: integer; override;
      function  ClientHeightValue: integer; override;
      function  GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean; override;
      function  AddTabSheet: TTabSheet;
      procedure SelectNextPage(GoForward: boolean);
      function  IndexOf(P: TTabSheet): integer;
      property Pages[I: integer]: TTabSheet read GetPage;
   published
      property PageCount: integer read GetPageCount;
      property ActivePage: TTabSheet read FActivePage write SetActivePage;
      property ActivePageIndex: integer read GetActivePageIndex write SetActivePageIndex;
      property TabIndex: integer read GetActivePageIndex write SetActivePageIndex;
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
      property OnChanging: TTabChangingEvent read FOnChanging write FOnChanging;
   end;

   TScrollBox = class(TWinControl)
   private
      FScrollX, FScrollY: integer;
      FVBar, FHBar: boolean;
      FExtW, FExtH: integer;
      FThumbV, FThumbH: boolean;
      FHoldV, FHoldH: TScrollHit;
      FBorder: boolean;
      procedure Measure;
      function  ViewW: integer;
      function  ViewH: integer;
      function  MaxX: integer;
      function  MaxY: integer;
      procedure HitV(H: TScrollHit);
      procedure HitH(H: TScrollHit);
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure Invalidate; override;
      function  ClientOffset: TPoint; override;
      function  ClientWidthValue: integer; override;
      function  ClientHeightValue: integer; override;
      function  ScrollOffset: TPoint; override;
      procedure ChildFocused(C: TControl); override;
      procedure DialogKey(var Key: Word; Shift: TShiftState); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseHeld(X, Y: integer); override;
      function  MouseWheel(WheelDelta: integer): boolean; override;
      procedure ScrollBy(DX, DY: integer);
      procedure ScrollInView(C: TControl);
      { a single line frame (takes a row and column each side) }
   published
      property HorzPosition: integer read FScrollX;
      property VertPosition: integer read FScrollY;
      property Border: boolean read FBorder write FBorder default false;
   end;

   TSplitter = class(TControl)
   private
      FMinSize: integer;
      FDragging: boolean;
      FOnMoved: TNotifyEvent;
      function  Neighbour: TControl;
      function  Vertical: boolean;
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      { the control that gets resized (before the splitter, same Align) }
   published
      property ResizeControl: TControl read Neighbour;
      property MinSize: integer read FMinSize write FMinSize default 3;
      property OnMoved: TNotifyEvent read FOnMoved write FOnMoved;
   end;

   TSpeedButton = class(TControl)
   private
      FDown, FPressed, FAllowAllUp, FAutoSize: boolean;
      FGroupIndex: integer;
      procedure SetDown(V: boolean);
   protected
      procedure TextChanged; override;
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure Click; override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure ActionChange(A: TAction); override;
      { GroupIndex > 0: a click keeps it down and lets the others of the   }
      { group (same parent) up; AllowAllUp: a click on the down one: up    }
   published
      property GroupIndex: integer read FGroupIndex write FGroupIndex default 0;
      property Down: boolean read FDown write SetDown default false;
      property AllowAllUp: boolean read FAllowAllUp write FAllowAllUp default false;
      property AutoSize: boolean read FAutoSize write FAutoSize default true;
   end;

   TToolButtonStyle = (tbsButton, tbsCheck, tbsDropDown, tbsSeparator, tbsDivider);

   TToolButton = class(TSpeedButton)
   private
      FStyle: TToolButtonStyle;
      procedure SetStyle(V: TToolButtonStyle);
   public
      procedure Paint; override;
      procedure Click; override;
   published
      property Style: TToolButtonStyle read FStyle write SetStyle default tbsButton;
   end;

   { a row of buttons; Align alTop; the children are laid out left to   }
   { right in creation order (1 column apart)                           }
   TToolBar = class(TWinControl)
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure AlignControls; override;
   end;

implementation

{=============================================================================}
{  TTabSheet                                                                  }
{=============================================================================}

constructor TTabSheet.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   TabStop := false;
   FTabVisible := true;
   FVisible := false;
end;

destructor TTabSheet.Destroy;
begin
   SetPageControl(nil);
   inherited Destroy;
end;

procedure TTabSheet.SetPageControl(V: TPageControl);
begin
   if V = FPageControl then exit;
   if FPageControl <> nil then FPageControl.RemovePage(Self);
   FPageControl := V;
   if V <> nil then V.InsertPage(Self);
end;

procedure TTabSheet.SetParentComponent(Value: TComponent);
begin
   if Value is TPageControl then PageControl := TPageControl(Value)
   else inherited SetParentComponent(Value);
end;

procedure TTabSheet.SetTabVisible(V: boolean);
begin
   if V = FTabVisible then exit;
   FTabVisible := V;
   if FPageControl <> nil then
   begin
      if not V and (FPageControl.FActivePage = Self) then FPageControl.SelectNextPage(true);
      FPageControl.Invalidate;
   end;
end;

function TTabSheet.GetPageIndex: integer;
begin
   if FPageControl = nil then Result := -1 else Result := FPageControl.IndexOf(Self);
end;

procedure TTabSheet.SetCaption(const V: string);
begin
   inherited SetCaption(V);
   if FPageControl <> nil then FPageControl.Invalidate;
end;

procedure TTabSheet.Paint;
begin
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', MakeAttr(AttrFg(Theme.FormBody), BackColor));
end;

{=============================================================================}
{  TPageControl                                                               }
{=============================================================================}

constructor TPageControl.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FPages := TFPList.Create;
   FWidth := 40;
   FHeight := 12;
end;

destructor TPageControl.Destroy;
begin
   while FPages.Count > 0 do TTabSheet(FPages[FPages.Count - 1]).PageControl := nil;
   FreeAndNil(FPages);
   inherited Destroy;
end;

function TPageControl.GetPage(I: integer): TTabSheet;
begin
   Result := TTabSheet(FPages[I]);
end;

function TPageControl.GetPageCount: integer;
begin
   Result := FPages.Count;
end;

function TPageControl.IndexOf(P: TTabSheet): integer;
begin
   Result := FPages.IndexOf(P);
end;

procedure TPageControl.InsertPage(P: TTabSheet);
begin
   FPages.Add(P);
   P.Parent := Self;
   P.Align := alClient;
   if FActivePage = nil then SetActivePage(P) else P.Visible := false;
   Invalidate;
end;

procedure TPageControl.RemovePage(P: TTabSheet);
begin
   if FPages = nil then exit;
   if FActivePage = P then
   begin
      FActivePage := nil;
      if FPages.Count > 1 then
         if FPages.IndexOf(P) = 0 then SetActivePage(GetPage(1))
         else SetActivePage(GetPage(FPages.IndexOf(P) - 1));
   end;
   FPages.Remove(P);
   if not (csDestroying in P.ComponentState) then P.Parent := nil;
   Invalidate;
end;

function TPageControl.AddTabSheet: TTabSheet;
begin
   Result := TTabSheet.Create(Owner);
   Result.PageControl := Self;
end;

{ the switch: OnChanging may refuse it; the focus inside the old page goes }
{ to the page control (its tab row)                                       }
function TPageControl.ChangePage(P: TTabSheet): boolean;
var allow: boolean;
    f: TCustomForm;
    a: TControl;
    old: TTabSheet;
begin
   Result := false;
   if P = FActivePage then exit;
   allow := true;
   if Assigned(FOnChanging) and (FActivePage <> nil) then FOnChanging(Self, allow);
   if not allow then exit;
   old := FActivePage;
   f := GetParentForm;
   if (old <> nil) and (f <> nil) and (f.ActiveControl <> nil) then
   begin
      a := f.ActiveControl;
      while (a <> nil) and (a <> old) do a := a.Parent;
      if (a = old) and CanFocus then SetFocus;
   end;
   FActivePage := P;
   if P <> nil then P.Visible := true;
   if old <> nil then old.Visible := false;
   Invalidate;
   if Assigned(FOnChange) then FOnChange(Self);
   Result := true;
end;

procedure TPageControl.SetActivePage(V: TTabSheet);
begin
   if (V <> nil) and (V.FPageControl <> Self) then exit;
   ChangePage(V);
end;

function TPageControl.GetActivePageIndex: integer;
begin
   if FActivePage = nil then Result := -1 else Result := FPages.IndexOf(FActivePage);
end;

procedure TPageControl.SetActivePageIndex(V: integer);
begin
   if (V >= 0) and (V < FPages.Count) then SetActivePage(GetPage(V))
   else SetActivePage(nil);
end;

function TPageControl.NextTab(Dir: integer): integer;
var i, n, k: integer;
begin
   Result := -1;
   n := FPages.Count;
   if n = 0 then exit;
   i := GetActivePageIndex;
   for k := 1 to n do
   begin
      i := (i + Dir + n) mod n;
      if GetPage(i).FTabVisible then exit(i);
   end;
end;

procedure TPageControl.SelectNextPage(GoForward: boolean);
var i: integer;
begin
   if GoForward then i := NextTab(1) else i := NextTab(-1);
   if i >= 0 then SetActivePageIndex(i);
end;

function TPageControl.ClientOffset: TPoint;
begin
   Result := Point(1, 1);
end;

function TPageControl.ClientWidthValue: integer;
begin
   Result := Width - 2;
   if Result < 0 then Result := 0;
end;

function TPageControl.ClientHeightValue: integer;
begin
   Result := Height - 2;
   if Result < 0 then Result := 0;
end;

procedure TPageControl.TabPos(I: integer; out X1, X2: integer);
var j, x: integer;
begin
   x := 1;
   X1 := x; X2 := x;
   for j := 0 to FPages.Count - 1 do
   begin
      if not GetPage(j).FTabVisible then continue;
      X1 := x;
      X2 := x + Length(StripAccel(GetPage(j).Caption)) + 2;
      if j = I then exit;
      x := X2 + 1;
   end;
end;

function TPageControl.TabAt(X: integer): integer;
var i, x1, x2: integer;
begin
   for i := 0 to FPages.Count - 1 do
      if GetPage(i).FTabVisible then
      begin
         TabPos(i, x1, x2);
         if (X >= x1) and (X < x2) then exit(i);
      end;
   Result := -1;
end;

procedure TPageControl.Paint;
var bg, fa, a, hot: byte;
    i, x1, x2: integer;
begin
   bg := BackColor;
   fa := MakeAttr(Theme.GroupFrameFg, bg);
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', MakeAttr(0, bg));
   Canvas.Frame(Rect(0, 0, Width, Height), 1, fa);
   for i := 0 to FPages.Count - 1 do
   begin
      if not GetPage(i).FTabVisible then continue;
      TabPos(i, x1, x2);
      if x1 >= Width - 1 then break;
      if GetPage(i) = FActivePage then
      begin
         if Focused then a := Theme.ListFocusSel else a := Theme.ListSel;
         hot := MakeAttr(tcYellow, AttrBg(a));
      end
      else
      begin
         a := MakeAttr(Theme.GroupTitleFg, bg);
         hot := MakeAttr(Theme.LabelHotFg, bg);
      end;
      if not IsEnabledAll then begin a := MakeAttr(Theme.DisabledFg, bg); hot := a; end;
      Canvas.Fill(Rect(x1, 0, x2, 1), ' ', a);
      Canvas.TextOutAccel(x1 + 1, 0, GetPage(i).Caption, a, hot);
   end;
end;

function TPageControl.GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean;
var x2: integer;
begin
   { the text cursor on the active tab }
   TabPos(GetActivePageIndex, X, x2);
   inc(X);
   Y := 0;
   Shape := csLine;
   Result := FActivePage <> nil;
end;

procedure TPageControl.KeyDown(var Key: Word; Shift: TShiftState);
begin
   inherited KeyDown(Key, Shift);
   if Key = 0 then exit;
   if Shift = [] then
      case Key of
         VK_LEFT:  begin SelectNextPage(false); Key := 0; exit; end;
         VK_RIGHT: begin SelectNextPage(true); Key := 0; exit; end;
      end;
   DialogKey(Key, Shift);
end;

procedure TPageControl.DialogKey(var Key: Word; Shift: TShiftState);
var i: integer;
begin
   if (Key = VK_TAB) and (ssCtrl in Shift) then
   begin
      SelectNextPage(not (ssShift in Shift));
      Key := 0;
   end
   else if (Key = VK_NEXT) and (Shift = [ssCtrl]) then
   begin
      SelectNextPage(true);
      Key := 0;
   end
   else if (Key = VK_PRIOR) and (Shift = [ssCtrl]) then
   begin
      SelectNextPage(false);
      Key := 0;
   end
   else if (ssAlt in Shift) and (((Key >= VK_A) and (Key <= VK_Z)) or ((Key >= VK_0) and (Key <= VK_9))) then
      { Alt+letter: a tab with that access key }
      for i := 0 to FPages.Count - 1 do
         if GetPage(i).FTabVisible and (AccelChar(GetPage(i).Caption) = char(Key)) then
         begin
            SetActivePageIndex(i);
            if CanFocus then SetFocus;
            Key := 0;
            exit;
         end;
end;

procedure TPageControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var i: integer;
begin
   inherited MouseDown(Button, Shift, X, Y);
   if (Button = mbLeft) and (Y = 0) then
   begin
      i := TabAt(X);
      if i >= 0 then SetActivePageIndex(i);
   end;
end;

{=============================================================================}
{  TScrollBox                                                                 }
{=============================================================================}

constructor TScrollBox.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   TabStop := false;
   FWidth := 30;
   FHeight := 10;
end;

{ the size of the area the children use, and which scroll bars that needs }
procedure TScrollBox.Measure;
var i, b: integer;
    c: TControl;
begin
   FExtW := 0;
   FExtH := 0;
   for i := 0 to ControlCount - 1 do
   begin
      c := Controls[i];
      if not c.Visible then continue;
      if c.Left + c.Width > FExtW then FExtW := c.Left + c.Width;
      if c.Top + c.Height > FExtH then FExtH := c.Top + c.Height;
   end;
   b := 2 * ord(FBorder);
   FVBar := FExtH > Height - b;
   FHBar := FExtW > Width - b - ord(FVBar);
   if FHBar and not FVBar then FVBar := FExtH > Height - b - 1;
   if FScrollX > MaxX then FScrollX := MaxX;
   if FScrollY > MaxY then FScrollY := MaxY;
   if FScrollX < 0 then FScrollX := 0;
   if FScrollY < 0 then FScrollY := 0;
end;

function TScrollBox.ViewW: integer;
begin
   Result := Width - 2 * ord(FBorder) - ord(FVBar);
   if Result < 0 then Result := 0;
end;

function TScrollBox.ViewH: integer;
begin
   Result := Height - 2 * ord(FBorder) - ord(FHBar);
   if Result < 0 then Result := 0;
end;

function TScrollBox.MaxX: integer;
begin
   Result := FExtW - ViewW;
   if Result < 0 then Result := 0;
end;

function TScrollBox.MaxY: integer;
begin
   Result := FExtH - ViewH;
   if Result < 0 then Result := 0;
end;

function TScrollBox.ClientOffset: TPoint;
begin
   Result := Point(ord(FBorder), ord(FBorder));
end;

function TScrollBox.ClientWidthValue: integer;
begin
   Measure;
   Result := ViewW;
end;

function TScrollBox.ClientHeightValue: integer;
begin
   Measure;
   Result := ViewH;
end;

function TScrollBox.ScrollOffset: TPoint;
begin
   Result := Point(FScrollX, FScrollY);
end;

procedure TScrollBox.Invalidate;
begin
   { scrolling moves every child: repaint the whole box }
   inherited Invalidate;
end;

procedure TScrollBox.ScrollBy(DX, DY: integer);
var ox, oy: integer;
begin
   Measure;
   ox := FScrollX;
   oy := FScrollY;
   FScrollX := FScrollX + DX;
   FScrollY := FScrollY + DY;
   if FScrollX > MaxX then FScrollX := MaxX;
   if FScrollY > MaxY then FScrollY := MaxY;
   if FScrollX < 0 then FScrollX := 0;
   if FScrollY < 0 then FScrollY := 0;
   if (ox <> FScrollX) or (oy <> FScrollY) then Invalidate;
end;

{ C is a child (or deeper): scroll so that it is inside the view }
procedure TScrollBox.ScrollInView(C: TControl);
var r: TRect;
    dx, dy: integer;
    o: TPoint;
begin
   Measure;
   while (C <> nil) and (C.Parent <> Self) do C := C.Parent;
   if C = nil then exit;
   o := ClientScreenRect.TopLeft;
   r := C.ScreenRect;
   dx := 0;
   dy := 0;
   if r.Right > o.X + ViewW then dx := r.Right - (o.X + ViewW);
   if r.Left - dx < o.X then dx := r.Left - o.X;
   if r.Bottom > o.Y + ViewH then dy := r.Bottom - (o.Y + ViewH);
   if r.Top - dy < o.Y then dy := r.Top - o.Y;
   if (dx <> 0) or (dy <> 0) then ScrollBy(dx, dy);
end;

procedure TScrollBox.ChildFocused(C: TControl);
begin
   ScrollInView(C);
end;

procedure TScrollBox.DialogKey(var Key: Word; Shift: TShiftState);
begin
   if Shift <> [] then exit;
   case Key of
      VK_PRIOR: begin ScrollBy(0, -(ViewH - 1)); Key := 0; end;
      VK_NEXT:  begin ScrollBy(0, ViewH - 1); Key := 0; end;
   end;
end;

procedure TScrollBox.Paint;
var o: TPoint;
    bg, a, sa: byte;
    b: integer;
begin
   Measure;
   bg := BackColor;
   a := MakeAttr(Theme.GroupFrameFg, bg);
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', MakeAttr(0, bg));
   if FBorder then Canvas.Frame(Rect(0, 0, Width, Height), 1, a);
   o := ScreenOrigin;
   b := ord(FBorder);
   sa := MakeAttr(AttrFg(Theme.ListScroll), bg);
   if FVBar then DrawVScroll(o.X + b + ViewW, o.Y + b, ViewH, FScrollY, MaxY, sa);
   if FHBar then DrawHScroll(o.X + b, o.Y + b + ViewH, ViewW, FScrollX, MaxX, sa);
end;

procedure TScrollBox.HitV(H: TScrollHit);
begin
   case H of
      shLineUp:   ScrollBy(0, -1);
      shLineDown: ScrollBy(0, 1);
      shPageUp:   ScrollBy(0, -(ViewH - 1));
      shPageDown: ScrollBy(0, ViewH - 1);
      shThumb:    FThumbV := true;
   end;
end;

procedure TScrollBox.HitH(H: TScrollHit);
begin
   case H of
      shLineUp:   ScrollBy(-1, 0);
      shLineDown: ScrollBy(1, 0);
      shPageUp:   ScrollBy(-(ViewW - 1), 0);
      shPageDown: ScrollBy(ViewW - 1, 0);
      shThumb:    FThumbH := true;
   end;
end;

procedure TScrollBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var b: integer;
begin
   inherited MouseDown(Button, Shift, X, Y);
   FHoldV := shNone;
   FHoldH := shNone;
   if Button <> mbLeft then exit;
   Measure;
   b := ord(FBorder);
   if FVBar and (X = b + ViewW) and (Y >= b) and (Y < b + ViewH) then
   begin
      FHoldV := ScrollHitAt(Y - b, ViewH, FScrollY, MaxY);
      HitV(FHoldV);
      if FHoldV = shThumb then FHoldV := shNone;
   end
   else if FHBar and (Y = b + ViewH) and (X >= b) and (X < b + ViewW) then
   begin
      FHoldH := ScrollHitAt(X - b, ViewW, FScrollX, MaxX);
      HitH(FHoldH);
      if FHoldH = shThumb then FHoldH := shNone;
   end;
end;

procedure TScrollBox.MouseMove(Shift: TShiftState; X, Y: integer);
var b: integer;
begin
   inherited MouseMove(Shift, X, Y);
   if not (ssLeft in Shift) then exit;
   b := ord(FBorder);
   if FThumbV then ScrollBy(0, ScrollPosAt(Y - b, ViewH, MaxY) - FScrollY)
   else if FThumbH then ScrollBy(ScrollPosAt(X - b, ViewW, MaxX) - FScrollX, 0);
end;

procedure TScrollBox.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FThumbV := false;
   FThumbH := false;
   FHoldV := shNone;
   FHoldH := shNone;
   inherited MouseUp(Button, Shift, X, Y);
end;

procedure TScrollBox.MouseHeld(X, Y: integer);
var b: integer;
begin
   b := ord(FBorder);
   if (FHoldV <> shNone) and (X = b + ViewW) and
      (ScrollHitAt(Y - b, ViewH, FScrollY, MaxY) = FHoldV) then HitV(FHoldV);
   if (FHoldH <> shNone) and (Y = b + ViewH) and
      (ScrollHitAt(X - b, ViewW, FScrollX, MaxX) = FHoldH) then HitH(FHoldH);
end;

{=============================================================================}
{  TSplitter                                                                  }
{=============================================================================}

constructor TSplitter.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FMinSize := 3;
   FAlign := alLeft;
   FWidth := 1;
   FHeight := 1;
end;

function TSplitter.Vertical: boolean;
begin
   Result := FAlign in [alLeft, alRight];
end;

{ the aligned control the splitter is attached to: same Align, touching }
function TSplitter.Neighbour: TControl;
var i: integer;
    c: TControl;
begin
   Result := nil;
   if Parent = nil then exit;
   for i := 0 to Parent.ControlCount - 1 do
   begin
      c := Parent.Controls[i];
      if (c = Self) or (c.Align <> FAlign) or not c.Visible then continue;
      case FAlign of
         alLeft:   if c.Left + c.Width = Left then exit(c);
         alRight:  if c.Left = Left + Width then exit(c);
         alTop:    if c.Top + c.Height = Top then exit(c);
         alBottom: if c.Top = Top + Height then exit(c);
      end;
   end;
end;

procedure TSplitter.Paint;
var a: byte;
begin
   if FDragging then a := MakeAttr(Theme.CloseBoxFg, BackColor)
   else a := MakeAttr(Theme.GroupFrameFg, BackColor);
   if Vertical then Canvas.Fill(Rect(0, 0, Width, Height), #179, a)
   else Canvas.Fill(Rect(0, 0, Width, Height), #196, a);
end;

procedure TSplitter.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   inherited MouseDown(Button, Shift, X, Y);
   if (Button = mbLeft) and (Neighbour <> nil) then
   begin
      FDragging := true;
      Invalidate;
   end;
end;

procedure TSplitter.MouseMove(Shift: TShiftState; X, Y: integer);
var n: TControl;
    d, size, room: integer;
begin
   inherited MouseMove(Shift, X, Y);
   if not FDragging then exit;
   n := Neighbour;
   if n = nil then exit;
   if Vertical then d := X else d := Y;
   if d = 0 then exit;
   if FAlign in [alRight, alBottom] then d := -d;
   if Vertical then size := n.Width + d else size := n.Height + d;
   if Vertical then room := Parent.ClientWidthValue else room := Parent.ClientHeightValue;
   { keep at least MinSize on both sides }
   if size < FMinSize then size := FMinSize;
   if size > room - Width - FMinSize then size := room - Width - FMinSize;
   if Vertical then n.Width := size else n.Height := size;
   Parent.AlignControls;
   Parent.Invalidate;
end;

procedure TSplitter.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   if FDragging then
   begin
      FDragging := false;
      Invalidate;
      if Assigned(FOnMoved) then FOnMoved(Self);
   end;
   inherited MouseUp(Button, Shift, X, Y);
end;

{=============================================================================}
{  TSpeedButton, TToolButton, TToolBar                                        }
{=============================================================================}

constructor TSpeedButton.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FAutoSize := true;
   FWidth := 6;
   FHeight := 1;
end;

procedure TSpeedButton.TextChanged;
begin
   if FAutoSize then Width := Length(StripAccel(Caption)) + 2;
   if Parent is TToolBar then Parent.AlignControls;
end;

procedure TSpeedButton.SetDown(V: boolean);
var i: integer;
    c: TControl;
begin
   if V = FDown then exit;
   FDown := V;
   { only one down in a group }
   if V and (FGroupIndex > 0) and (Parent <> nil) then
      for i := 0 to Parent.ControlCount - 1 do
      begin
         c := Parent.Controls[i];
         if (c <> Self) and (c is TSpeedButton) and (TSpeedButton(c).FGroupIndex = FGroupIndex) then
            TSpeedButton(c).Down := false;
      end;
   Invalidate;
end;

procedure TSpeedButton.Click;
begin
   if FGroupIndex > 0 then
   begin
      if FDown and FAllowAllUp then Down := false
      else Down := true;
   end;
   inherited Click;
end;

procedure TSpeedButton.Paint;
var a, hot: byte;
begin
   if not IsEnabledAll then a := Theme.MenuDisabled
   else if FDown or FPressed then a := Theme.MenuSel
   else a := Theme.MenuBar;
   if (Color >= 0) and (Color <= 15) and not (FDown or FPressed) then
      a := MakeAttr(AttrFg(a), Color);
   if IsEnabledAll then hot := MakeAttr(AttrFg(Theme.MenuHot), AttrBg(a)) else hot := a;
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   Canvas.TextOutAccel((Width - Length(StripAccel(Caption))) div 2, Height div 2, Caption, a, hot);
end;

procedure TSpeedButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   inherited MouseDown(Button, Shift, X, Y);
   if Button = mbLeft then
   begin
      FPressed := true;
      Invalidate;
   end;
end;

procedure TSpeedButton.MouseMove(Shift: TShiftState; X, Y: integer);
var inside: boolean;
begin
   inherited MouseMove(Shift, X, Y);
   if not (ssLeft in Shift) then exit;
   inside := (X >= 0) and (Y >= 0) and (X < Width) and (Y < Height);
   if inside <> FPressed then
   begin
      FPressed := inside;
      Invalidate;
   end;
end;

procedure TSpeedButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   if FPressed then
   begin
      FPressed := false;
      Invalidate;
   end;
   inherited MouseUp(Button, Shift, X, Y);
end;

procedure TSpeedButton.ActionChange(A: TAction);
begin
   inherited ActionChange(A);
   if (FGroupIndex > 0) or ((Self is TToolButton) and (TToolButton(Self).Style = tbsCheck)) then
      Down := A.Checked;
end;

procedure TToolButton.SetStyle(V: TToolButtonStyle);
begin
   FStyle := V;
   if V in [tbsSeparator, tbsDivider] then
   begin
      FAutoSize := false;
      Width := 1;
   end;
   Invalidate;
end;

procedure TToolButton.Paint;
begin
   if FStyle in [tbsSeparator, tbsDivider] then
      Canvas.Fill(Rect(0, 0, Width, Height), #179, Theme.MenuBar)
   else
      inherited Paint;
end;

procedure TToolButton.Click;
begin
   if FStyle in [tbsSeparator, tbsDivider] then exit;
   if (FStyle = tbsCheck) and (FGroupIndex = 0) then Down := not Down;
   inherited Click;
end;

constructor TToolBar.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   TabStop := false;
   FAlign := alTop;
   FHeight := 1;
   FWidth := 40;
end;

procedure TToolBar.Paint;
begin
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', Theme.MenuBar);
end;

procedure TToolBar.AlignControls;
var i, x: integer;
    c: TControl;
begin
   inherited AlignControls;
   x := 1;
   for i := 0 to ControlCount - 1 do
   begin
      c := Controls[i];
      if not c.Visible or (c.Align <> alNone) then continue;
      if (c.Left <> x) or (c.Top <> 0) or (c.Height <> Height) then
         c.SetBounds(x, 0, c.Width, Height);
      x := x + c.Width + 1;
   end;
end;


function TScrollBox.MouseWheel(WheelDelta: integer): boolean;
begin
   Measure;
   ScrollBy(0, -(WheelDelta div 120) * 3);
   Result := FVBar;
end;

initialization
   RegisterClasses([TPageControl, TTabSheet, TScrollBox, TSplitter, TSpeedButton, TToolBar,
                    TToolButton]);
end.
