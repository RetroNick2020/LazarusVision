{-----------------------------------------------------------------------------}
{  TUIEXT - more controls, LCL names (the LCL units in brackets):              }
{     TTimer (ExtCtrls)        Interval, Enabled, OnTimer                     }
{     TScrollBar (StdCtrls)    Kind, Min, Max, Position, SmallChange,         }
{                              LargeChange, OnChange                          }
{     TCheckListBox (CheckLst) Checked[], OnClickCheck (+ TListBox)           }
{     TRadioGroup (ExtCtrls)   Items, ItemIndex, Columns, OnClick,            }
{                              OnSelectionChanged                             }
{     TSpinEdit (Spin)         Value, MinValue, MaxValue, Increment           }
{     TMaskEdit (MaskEdit)     EditMask, Text, EditText, ValidateEdit         }
{     TProgressBar (ComCtrls)  Min, Max, Position, Step, StepIt, StepBy,      }
{                              Orientation, BarShowText                       }
{     TStaticText (StdCtrls)   BorderStyle, Alignment (+ TLabel)              }
{     TBevel (ExtCtrls)        Shape, Style                                   }
{-----------------------------------------------------------------------------}
unit TUIExt;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUIStd, TUIList;

type
   { -------------------------------------------------------------- timer }
   { OnTimer every Interval ms (55 ms steps: the BIOS clock), from the     }
   { message loop: it runs between events, never in the middle of one     }
   TTimer = class(TTimerBase)
   private
      FInterval: longint;
      FEnabled: boolean;
      FLast: longint;
      FOnTimer: TNotifyEvent;
      procedure SetEnabled(V: boolean);
      procedure SetInterval(V: longint);
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Tick(Now: longint); override;
   published
      property Interval: longint read FInterval write SetInterval default 1000;
      property Enabled: boolean read FEnabled write SetEnabled default true;
      property OnTimer: TNotifyEvent read FOnTimer write FOnTimer;
   end;

   { --------------------------------------------------------- scroll bar }
   TScrollBarKind = (sbHorizontal, sbVertical);

   TScrollBar = class(TWinControl)
   private
      FKind: TScrollBarKind;
      FMin, FMax, FPosition, FSmallChange, FLargeChange: integer;
      FThumb: boolean;
      FHold: TScrollHit;
      FOnChange: TNotifyEvent;
      procedure SetKind(V: TScrollBarKind);
      procedure SetMin(V: integer);
      procedure SetMax(V: integer);
      procedure SetPosition(V: integer);
      function  Len: integer;
      procedure DoHit(H: TScrollHit);
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseHeld(X, Y: integer); override;
      function  MouseWheel(WheelDelta: integer): boolean; override;
      procedure SetParams(APosition, AMin, AMax: integer);
   published
      property Kind: TScrollBarKind read FKind write SetKind default sbHorizontal;
      property Min: integer read FMin write SetMin default 0;
      property Max: integer read FMax write SetMax default 100;
      property Position: integer read FPosition write SetPosition default 0;
      property SmallChange: integer read FSmallChange write FSmallChange default 1;
      property LargeChange: integer read FLargeChange write FLargeChange default 10;
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
   end;

   { ----------------------------------------------------- check list box }
   TCheckListBox = class(TListBox)
   private
      FOnClickCheck: TNotifyEvent;
      function  GetChecked(I: integer): boolean;
      procedure SetChecked(I: integer; V: boolean);
   protected
      function  ItemText(I: integer): string; override;
   public
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure Toggle(I: integer);
      procedure CheckAll(V: boolean);
      property Checked[I: integer]: boolean read GetChecked write SetChecked;
   published
      property OnClickCheck: TNotifyEvent read FOnClickCheck write FOnClickCheck;
   end;

   { -------------------------------------------------------- radio group }
   TRadioGroup = class(TGroupBox)
   private
      FItems: TStringList;
      FButtons: TFPList;
      FItemIndex, FColumns: integer;
      FOnSelectionChanged: TNotifyEvent;
      FBuilding: boolean;
      FLoadIndex: integer;
      procedure ItemsChanged(Sender: TObject);
      procedure SetItems(V: TStrings);
      function  GetItems: TStrings;
      procedure SetItemIndex(V: integer);
      procedure SetColumns(V: integer);
      procedure Rebuild;
      procedure Arrange;
      procedure UpdateTabStops;
      procedure ButtonClick(Sender: TObject);
      procedure ButtonKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Loaded; override;
      procedure SetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
      function  HasAccel: boolean; override;
      procedure DoAccel; override;
      function  Buttons(I: integer): TRadioButton;
   published
      property Items: TStrings read GetItems write SetItems;
      property ItemIndex: integer read FItemIndex write SetItemIndex default -1;
      property Columns: integer read FColumns write SetColumns default 1;
      property OnSelectionChanged: TNotifyEvent read FOnSelectionChanged write FOnSelectionChanged;
   end;

   { --------------------------------------------------------- spin edit }
   { a number field: Up/Down (PgUp/PgDn ten steps) or the ▲▼ arrows       }
   TSpinEdit = class(TEdit)
   private
      FMinValue, FMaxValue, FIncrement: integer;
      FHoldDir: integer;
      function  GetValue: integer;
      procedure SetValue(V: integer);
      procedure SetMinValue(V: integer);
      procedure SetMaxValue(V: integer);
   protected
      function  EditWidth: integer; override;
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure KeyPress(var Key: char); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseHeld(X, Y: integer); override;
      function  MouseWheel(WheelDelta: integer): boolean; override;
      procedure DoExit; override;
      procedure PasteFromClipboard; override;
   published
      property Value: integer read GetValue write SetValue;
      property MinValue: integer read FMinValue write SetMinValue default 0;
      property MaxValue: integer read FMaxValue write SetMaxValue default 100;
      property Increment: integer read FIncrement write FIncrement default 1;
   end;

   { --------------------------------------------------------- mask edit }
   { EditMask 'mask;save literals;blank', e.g. '99/99/9999;1;_'           }
   {   0 digit   9 digit or blank   # digit, + - or blank                 }
   {   L letter  l letter or blank  A letter/digit  a ... or blank        }
   {   C any     c any or blank     > upper case  < lower case  <> off    }
   {   \x the literal x;  anything else is a literal (/ : - ( ) . space)  }
   TMaskSlot = record
      Kind: char;          { #0 literal, else the mask character }
      Lit: char;           { the literal }
      CaseMode: char;      { ' ', '>' or '<' }
   end;

   TMaskEdit = class(TEdit)
   private
      FEditMask: string;
      FSlots: array of TMaskSlot;
      FSaveLiterals: boolean;
      FBlank: char;
      procedure SetEditMask(const V: string);
      function  GetMaskText: string;
      procedure SetMaskText(const V: string);
      function  NextSlot(P, Dir: integer): integer;
      function  Accepts(I: integer; var Ch: char): boolean;
      function  EmptyText: string;
   public
      constructor Create(AOwner: TComponent); override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure KeyPress(var Key: char); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure DoEnter; override;
      procedure PasteFromClipboard; override;
      function  IsMasked: boolean;
      { every required position is filled }
      function  ValidateEdit: boolean;
      { with the literals when the mask says so ('1'), blanks as spaces }
      { what is shown: literals and blank characters }
   published
      property EditMask: string read FEditMask write SetEditMask;
      property Text: string read GetMaskText write SetMaskText;
      property EditText: string read FCaption;
   end;

   { ------------------------------------------------------ progress bar }
   TProgressBarOrientation = (pbHorizontal, pbVertical, pbRightToLeft, pbTopDown);

   TProgressBar = class(TControl)
   private
      FMin, FMax, FPosition, FStep: integer;
      FOrientation: TProgressBarOrientation;
      FBarShowText: boolean;
      procedure SetPosition(V: integer);
      procedure SetMin(V: integer);
      procedure SetMax(V: integer);
      procedure SetBarShowText(V: boolean);
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure StepIt;
      procedure StepBy(Delta: integer);
      { the percentage in the middle of the bar }
   published
      property Min: integer read FMin write SetMin default 0;
      property Max: integer read FMax write SetMax default 100;
      property Position: integer read FPosition write SetPosition default 0;
      property Step: integer read FStep write FStep default 10;
      property Orientation: TProgressBarOrientation read FOrientation write FOrientation default pbHorizontal;
      property BarShowText: boolean read FBarShowText write SetBarShowText default false;
   end;

   { ------------------------------------------------- static text, bevel }
   TStaticBorderStyle = (sbsNone, sbsSingle, sbsSunken);

   TStaticText = class(TLabel)
   private
      FBorderStyle: TStaticBorderStyle;
      procedure SetBorderStyle(V: TStaticBorderStyle);
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
   published
      property BorderStyle: TStaticBorderStyle read FBorderStyle write SetBorderStyle default sbsNone;
   end;

   TBevelShape = (bsBox, bsFrame, bsTopLine, bsBottomLine, bsLeftLine, bsRightLine, bsSpacer);
   TBevelStyle = (bsLowered, bsRaised);

   TBevel = class(TControl)
   private
      FShape: TBevelShape;
      FStyle: TBevelStyle;
      procedure SetShape(V: TBevelShape);
      procedure SetStyle(V: TBevelStyle);
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
   published
      property Shape: TBevelShape read FShape write SetShape default bsBox;
      property Style: TBevelStyle read FStyle write SetStyle default bsLowered;
   end;

implementation

{=============================================================================}
{  TTimer                                                                     }
{=============================================================================}

constructor TTimer.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FInterval := 1000;
   FEnabled := true;
   FLast := HWTicks;
   if Application <> nil then Application.AddTimer(Self);
end;

destructor TTimer.Destroy;
begin
   if Application <> nil then Application.RemoveTimer(Self);
   inherited Destroy;
end;

procedure TTimer.SetEnabled(V: boolean);
begin
   if V and not FEnabled then FLast := HWTicks;
   FEnabled := V;
end;

procedure TTimer.SetInterval(V: longint);
begin
   FInterval := V;
   FLast := HWTicks;
end;

procedure TTimer.Tick(Now: longint);
begin
   if not FEnabled or (FInterval <= 0) or not Assigned(FOnTimer) then exit;
   if Now - FLast < FInterval then exit;
   FLast := Now;
   FOnTimer(Self);
end;

{=============================================================================}
{  TScrollBar                                                                 }
{=============================================================================}

constructor TScrollBar.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FMax := 100;
   FSmallChange := 1;
   FLargeChange := 10;
   FWidth := 20;
   FHeight := 1;
end;

procedure TScrollBar.SetKind(V: TScrollBarKind);
begin
   if V = FKind then exit;
   FKind := V;
   SetBounds(Left, Top, Height, Width);
end;

procedure TScrollBar.SetParams(APosition, AMin, AMax: integer);
begin
   if AMax < AMin then AMax := AMin;
   FMin := AMin;
   FMax := AMax;
   if APosition < FMin then APosition := FMin;
   if APosition > FMax then APosition := FMax;
   if APosition <> FPosition then
   begin
      FPosition := APosition;
      if Assigned(FOnChange) then FOnChange(Self);
   end;
   Invalidate;
end;

procedure TScrollBar.SetMin(V: integer);
begin
   SetParams(FPosition, V, FMax);
end;

procedure TScrollBar.SetMax(V: integer);
begin
   SetParams(FPosition, FMin, V);
end;

procedure TScrollBar.SetPosition(V: integer);
begin
   SetParams(V, FMin, FMax);
end;

function TScrollBar.Len: integer;
begin
   if FKind = sbHorizontal then Result := Width else Result := Height;
end;

procedure TScrollBar.Paint;
var o: TPoint;
    a: byte;
begin
   o := ScreenOrigin;
   a := Theme.ListScroll;
   if Focused then a := MakeAttr(tcWhite, AttrBg(a));
   if not IsEnabledAll then a := MakeAttr(Theme.DisabledFg, AttrBg(a));
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   if FKind = sbHorizontal then
      DrawHScroll(o.X, o.Y, Width, FPosition - FMin, FMax - FMin, a)
   else
      DrawVScroll(o.X, o.Y, Height, FPosition - FMin, FMax - FMin, a);
end;

procedure TScrollBar.DoHit(H: TScrollHit);
begin
   case H of
      shLineUp:   Position := FPosition - FSmallChange;
      shLineDown: Position := FPosition + FSmallChange;
      shPageUp:   Position := FPosition - FLargeChange;
      shPageDown: Position := FPosition + FLargeChange;
      shThumb:    FThumb := true;
   end;
end;

procedure TScrollBar.KeyDown(var Key: Word; Shift: TShiftState);
begin
   inherited KeyDown(Key, Shift);
   if (Key = 0) or (Shift * [ssAlt, ssCtrl] <> []) then exit;
   if ((FKind = sbHorizontal) and (Key = VK_LEFT)) or ((FKind = sbVertical) and (Key = VK_UP)) then
      DoHit(shLineUp)
   else if ((FKind = sbHorizontal) and (Key = VK_RIGHT)) or ((FKind = sbVertical) and (Key = VK_DOWN)) then
      DoHit(shLineDown)
   else if Key = VK_PRIOR then DoHit(shPageUp)
   else if Key = VK_NEXT then DoHit(shPageDown)
   else if Key = VK_HOME then Position := FMin
   else if Key = VK_END then Position := FMax
   else exit;
   Key := 0;
end;

procedure TScrollBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var d: integer;
begin
   inherited MouseDown(Button, Shift, X, Y);
   FHold := shNone;
   if Button <> mbLeft then exit;
   if FKind = sbHorizontal then d := X else d := Y;
   FHold := ScrollHitAt(d, Len, FPosition - FMin, FMax - FMin);
   DoHit(FHold);
   if FHold = shThumb then FHold := shNone;
end;

procedure TScrollBar.MouseMove(Shift: TShiftState; X, Y: integer);
var d: integer;
begin
   inherited MouseMove(Shift, X, Y);
   if not (FThumb and (ssLeft in Shift)) then exit;
   if FKind = sbHorizontal then d := X else d := Y;
   Position := FMin + ScrollPosAt(d, Len, FMax - FMin);
end;

procedure TScrollBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FThumb := false;
   FHold := shNone;
   inherited MouseUp(Button, Shift, X, Y);
end;

procedure TScrollBar.MouseHeld(X, Y: integer);
var d: integer;
begin
   if FHold = shNone then exit;
   if FKind = sbHorizontal then d := X else d := Y;
   if ScrollHitAt(d, Len, FPosition - FMin, FMax - FMin) = FHold then DoHit(FHold);
end;

{=============================================================================}
{  TCheckListBox                                                              }
{=============================================================================}

function TCheckListBox.GetChecked(I: integer): boolean;
begin
   Result := (I >= 0) and (I < FItems.Count) and (FItems.Objects[I] <> nil);
end;

procedure TCheckListBox.SetChecked(I: integer; V: boolean);
begin
   if (I < 0) or (I >= FItems.Count) or (GetChecked(I) = V) then exit;
   if V then FItems.Objects[I] := TObject(PtrInt(1)) else FItems.Objects[I] := nil;
   Invalidate;
end;

function TCheckListBox.ItemText(I: integer): string;
begin
   if GetChecked(I) then Result := '[X] ' else Result := '[ ] ';
   Result := Result + FItems[I];
end;

procedure TCheckListBox.Toggle(I: integer);
begin
   if (I < 0) or (I >= FItems.Count) or not IsEnabledAll then exit;
   SetChecked(I, not GetChecked(I));
   if Assigned(FOnClickCheck) then FOnClickCheck(Self);
end;

procedure TCheckListBox.CheckAll(V: boolean);
var i: integer;
begin
   for i := 0 to FItems.Count - 1 do SetChecked(i, V);
end;

procedure TCheckListBox.KeyDown(var Key: Word; Shift: TShiftState);
begin
   if (Key = VK_SPACE) and (Shift = []) then
   begin
      if FItemIndex < 0 then UserSelect(0) else Toggle(FItemIndex);
      Key := 0;
      exit;
   end;
   inherited KeyDown(Key, Shift);
end;

procedure TCheckListBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var i: integer;
    r: TRect;
begin
   inherited MouseDown(Button, Shift, X, Y);
   if Button <> mbLeft then exit;
   { a click on the [ ] box toggles it }
   r := ListRect;
   i := ItemAtPos(X, Y);
   if (i >= 0) and (X >= r.Left + 1) and (X <= r.Left + 3) then Toggle(i);
end;

{=============================================================================}
{  TRadioGroup                                                                }
{=============================================================================}

constructor TRadioGroup.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FItems := TStringList.Create;
   FItems.OnChange := @ItemsChanged;
   FButtons := TFPList.Create;
   FItemIndex := -1;
   FLoadIndex := -2;
   FColumns := 1;
end;

destructor TRadioGroup.Destroy;
begin
   FItems.OnChange := nil;
   FreeAndNil(FItems);
   FreeAndNil(FButtons);      { the buttons are owned by the group }
   inherited Destroy;
end;

function TRadioGroup.GetItems: TStrings;
begin
   Result := FItems;
end;

procedure TRadioGroup.SetItems(V: TStrings);
begin
   FItems.Assign(V);
end;

procedure TRadioGroup.ItemsChanged(Sender: TObject);
begin
   Rebuild;
end;

function TRadioGroup.Buttons(I: integer): TRadioButton;
begin
   Result := TRadioButton(FButtons[I]);
end;

procedure TRadioGroup.Rebuild;
var i: integer;
    b: TRadioButton;
begin
   if csDestroying in ComponentState then exit;
   FBuilding := true;
   try
      while FButtons.Count > FItems.Count do
      begin
         TObject(FButtons[FButtons.Count - 1]).Free;
         FButtons.Delete(FButtons.Count - 1);
      end;
      while FButtons.Count < FItems.Count do
      begin
         b := TRadioButton.Create(Self);
         b.AutoSize := false;
         b.Parent := Self;
         b.OnClick := @ButtonClick;
         b.OnKeyDown := @ButtonKeyDown;
         FButtons.Add(b);
      end;
      for i := 0 to FItems.Count - 1 do
         Buttons(i).Caption := FItems[i];
      if FItemIndex >= FItems.Count then FItemIndex := -1;
      for i := 0 to FButtons.Count - 1 do
         Buttons(i).Checked := i = FItemIndex;
   finally
      FBuilding := false;
   end;
   Arrange;
   UpdateTabStops;
   Invalidate;
end;

procedure TRadioGroup.Arrange;
var i, rows, cw: integer;
begin
   if (FButtons = nil) or (FButtons.Count = 0) then exit;
   rows := (FButtons.Count + FColumns - 1) div FColumns;
   cw := ClientWidthValue div FColumns;
   if cw < 4 then cw := 4;
   for i := 0 to FButtons.Count - 1 do
      Buttons(i).SetBounds((i div rows) * cw, i mod rows, cw, 1);
end;

{ like the LCL: only the checked button (or the first) is a Tab stop; the }
{ arrows move between the buttons                                        }
procedure TRadioGroup.UpdateTabStops;
var i, t: integer;
begin
   t := FItemIndex;
   if t < 0 then t := 0;
   for i := 0 to FButtons.Count - 1 do Buttons(i).TabStop := i = t;
end;

procedure TRadioGroup.SetBounds(ALeft, ATop, AWidth, AHeight: integer);
begin
   inherited SetBounds(ALeft, ATop, AWidth, AHeight);
   Arrange;
end;

procedure TRadioGroup.SetColumns(V: integer);
begin
   if V < 1 then V := 1;
   if V = FColumns then exit;
   FColumns := V;
   Arrange;
   Invalidate;
end;

procedure TRadioGroup.Loaded;
begin
   inherited Loaded;
   if FLoadIndex <> -2 then SetItemIndex(FLoadIndex);
   FLoadIndex := -2;
end;

procedure TRadioGroup.SetItemIndex(V: integer);
var i: integer;
begin
   if csLoading in ComponentState then
   begin
      FLoadIndex := V;
      exit;
   end;
   if (V < -1) or (V >= FItems.Count) then V := -1;
   if V = FItemIndex then exit;
   FItemIndex := V;
   FBuilding := true;
   try
      for i := 0 to FButtons.Count - 1 do Buttons(i).Checked := i = V;
   finally
      FBuilding := false;
   end;
   UpdateTabStops;
   if Assigned(FOnSelectionChanged) then FOnSelectionChanged(Self);
end;

procedure TRadioGroup.ButtonClick(Sender: TObject);
var i: integer;
begin
   if FBuilding then exit;
   i := FButtons.IndexOf(Sender);
   if i < 0 then exit;
   if i <> FItemIndex then
   begin
      FItemIndex := i;
      UpdateTabStops;
      if Assigned(FOnSelectionChanged) then FOnSelectionChanged(Self);
   end;
   if Assigned(OnClick) then OnClick(Self);
end;

procedure TRadioGroup.ButtonKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var i, n: integer;
begin
   if Shift <> [] then exit;
   n := FButtons.Count;
   if n = 0 then exit;
   i := FButtons.IndexOf(Sender);
   case Key of
      VK_UP, VK_LEFT:    i := (i - 1 + n) mod n;
      VK_DOWN, VK_RIGHT: i := (i + 1) mod n;
   else
      exit;
   end;
   Key := 0;
   Buttons(i).TabStop := true;
   Buttons(i).SetFocus;
   Buttons(i).Click;
end;

function TRadioGroup.HasAccel: boolean;
begin
   Result := AccelChar(Caption) <> #0;
end;

procedure TRadioGroup.DoAccel;
var i: integer;
begin
   i := FItemIndex;
   if i < 0 then i := 0;
   if i < FButtons.Count then Buttons(i).SetFocus;
end;

{=============================================================================}
{  TSpinEdit                                                                  }
{=============================================================================}

constructor TSpinEdit.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FMaxValue := 100;
   FIncrement := 1;
   FWidth := 10;
   inherited SetCaption('0');
end;

function TSpinEdit.EditWidth: integer;
begin
   Result := Width - 2;
   if Result < 1 then Result := 1;
end;

function TSpinEdit.GetValue: integer;
begin
   Result := StrToIntDef(Trim(Caption), FMinValue);
   if Result < FMinValue then Result := FMinValue;
   if Result > FMaxValue then Result := FMaxValue;
end;

procedure TSpinEdit.SetValue(V: integer);
begin
   if V < FMinValue then V := FMinValue;
   if V > FMaxValue then V := FMaxValue;
   Text := IntToStr(V);
   if Focused then FSelAll := false;
end;

procedure TSpinEdit.SetMinValue(V: integer);
begin
   FMinValue := V;
   if FMaxValue < V then FMaxValue := V;
   SetValue(GetValue);
end;

procedure TSpinEdit.SetMaxValue(V: integer);
begin
   FMaxValue := V;
   if FMinValue > V then FMinValue := V;
   SetValue(GetValue);
end;

procedure TSpinEdit.Paint;
var b: byte;
begin
   inherited Paint;
   if Focused then b := Theme.ButtonFocus else b := Theme.ComboButton;
   if not IsEnabledAll then b := Theme.ButtonDisabled;
   Canvas.PutChar(Width - 2, 0, chArrowUp, b);
   Canvas.PutChar(Width - 1, 0, chArrowDown, b);
end;

procedure TSpinEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
   if Shift * [ssAlt, ssCtrl] = [] then
      case Key of
         VK_UP:    begin Value := Value + FIncrement; Key := 0; exit; end;
         VK_DOWN:  begin Value := Value - FIncrement; Key := 0; exit; end;
         VK_PRIOR: begin Value := Value + FIncrement * 10; Key := 0; exit; end;
         VK_NEXT:  begin Value := Value - FIncrement * 10; Key := 0; exit; end;
      end;
   inherited KeyDown(Key, Shift);
end;

procedure TSpinEdit.KeyPress(var Key: char);
begin
   if (Key >= ' ') and not (Key in ['0'..'9']) and
      not ((Key = '-') and (FMinValue < 0) and ((FCaret = 0) or FSelAll)) then
   begin
      HWBeep;
      Key := #0;
      exit;
   end;
   inherited KeyPress(Key);
end;

procedure TSpinEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FHoldDir := 0;
   if (Button = mbLeft) and (X >= Width - 2) then
   begin
      if X = Width - 2 then FHoldDir := 1 else FHoldDir := -1;
      Value := Value + FHoldDir * FIncrement;
      exit;
   end;
   inherited MouseDown(Button, Shift, X, Y);
end;

procedure TSpinEdit.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FHoldDir := 0;
   inherited MouseUp(Button, Shift, X, Y);
end;

procedure TSpinEdit.MouseHeld(X, Y: integer);
begin
   if (FHoldDir = 1) and (X = Width - 2) and (Y = 0) then Value := Value + FIncrement
   else if (FHoldDir = -1) and (X = Width - 1) and (Y = 0) then Value := Value - FIncrement;
end;

procedure TSpinEdit.DoExit;
begin
   { leave a valid number behind }
   if Caption <> IntToStr(GetValue) then Value := GetValue;
   inherited DoExit;
end;

procedure TSpinEdit.PasteFromClipboard;
begin
   if Clipboard.HasText and (StrToIntDef(Trim(Clipboard.AsText), MaxInt) <> MaxInt) then
      Value := StrToInt(Trim(Clipboard.AsText))
   else
      HWBeep;
end;

{=============================================================================}
{  TMaskEdit                                                                  }
{=============================================================================}

constructor TMaskEdit.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FBlank := '_';
   FSaveLiterals := true;
   FAutoSelect := false;
end;

function TMaskEdit.IsMasked: boolean;
begin
   Result := Length(FSlots) > 0;
end;

procedure TMaskEdit.SetEditMask(const V: string);
var i, n, p: integer;
    m, rest: string;
    cm: char;
begin
   FEditMask := V;
   { 'mask;1;_' }
   m := V;
   FSaveLiterals := true;
   FBlank := '_';
   p := 0;
   for i := Length(m) downto 1 do
      if (m[i] = ';') and ((i = 1) or (m[i - 1] <> '\')) then begin p := i; break; end;
   if p > 0 then
   begin
      rest := Copy(m, p + 1, MaxInt);
      m := Copy(m, 1, p - 1);
      if rest <> '' then FBlank := rest[1];
      p := 0;
      for i := Length(m) downto 1 do
         if (m[i] = ';') and ((i = 1) or (m[i - 1] <> '\')) then begin p := i; break; end;
      if p > 0 then
      begin
         FSaveLiterals := Copy(m, p + 1, 1) <> '0';
         m := Copy(m, 1, p - 1);
      end;
   end;
   SetLength(FSlots, Length(m));
   n := 0;
   cm := ' ';
   i := 1;
   while i <= Length(m) do
   begin
      case m[i] of
         '>': begin
                 if (i < Length(m)) and (m[i + 1] = '<') then begin cm := ' '; inc(i); end
                 else cm := '>';
              end;
         '<': cm := '<';
         '!': ;
         '\': if i < Length(m) then
              begin
                 inc(i);
                 FSlots[n].Kind := #0; FSlots[n].Lit := m[i]; FSlots[n].CaseMode := ' ';
                 inc(n);
              end;
         '0', '9', '#', 'L', 'l', 'A', 'a', 'C', 'c':
              begin
                 FSlots[n].Kind := m[i]; FSlots[n].Lit := #0; FSlots[n].CaseMode := cm;
                 inc(n);
              end;
      else
         FSlots[n].Kind := #0; FSlots[n].Lit := m[i]; FSlots[n].CaseMode := ' ';
         inc(n);
      end;
      inc(i);
   end;
   SetLength(FSlots, n);
   if n > 0 then MaxLength := n else MaxLength := 0;
   inherited SetCaption(EmptyText);
   FCaret := NextSlot(-1, 1);
   Invalidate;
end;

function TMaskEdit.EmptyText: string;
var i: integer;
begin
   SetLength(Result, Length(FSlots));
   for i := 0 to High(FSlots) do
      if FSlots[i].Kind = #0 then Result[i + 1] := FSlots[i].Lit
      else Result[i + 1] := FBlank;
end;

{ the next input position after (Dir 1) / before (Dir -1) P; at the end: }
{ Length (after the last), at the start: the first input                 }
function TMaskEdit.NextSlot(P, Dir: integer): integer;
var i: integer;
begin
   i := P + Dir;
   while (i >= 0) and (i <= High(FSlots)) and (FSlots[i].Kind = #0) do inc(i, Dir);
   if i < 0 then
   begin
      i := 0;
      while (i <= High(FSlots)) and (FSlots[i].Kind = #0) do inc(i);
   end;
   if i > Length(FSlots) then i := Length(FSlots);
   Result := i;
end;

function TMaskEdit.Accepts(I: integer; var Ch: char): boolean;
begin
   case FSlots[I].CaseMode of
      '>': Ch := UpCase(Ch);
      '<': if Ch in ['A'..'Z'] then Ch := char(Ord(Ch) + 32);
   end;
   case FSlots[I].Kind of
      '0', '9': Result := Ch in ['0'..'9'];
      '#':      Result := Ch in ['0'..'9', '+', '-'];
      'L', 'l': Result := Ch in ['A'..'Z', 'a'..'z'];
      'A', 'a': Result := Ch in ['A'..'Z', 'a'..'z', '0'..'9'];
      'C', 'c': Result := Ch >= ' ';
   else
      Result := false;
   end;
end;

function TMaskEdit.GetMaskText: string;
var i: integer;
begin
   if not IsMasked then exit(FCaption);
   Result := '';
   for i := 0 to High(FSlots) do
      if FSlots[i].Kind = #0 then
      begin
         if FSaveLiterals then Result := Result + FSlots[i].Lit;
      end
      else if FCaption[i + 1] = FBlank then Result := Result + ' '
      else Result := Result + FCaption[i + 1];
end;

procedure TMaskEdit.SetMaskText(const V: string);
var s: string;
    i, j: integer;
    c: char;
begin
   if not IsMasked then
   begin
      inherited Text := V;
      exit;
   end;
   s := EmptyText;
   if Length(V) = Length(FSlots) then
   begin
      { position by position (the literals are in V too) }
      for i := 0 to High(FSlots) do
         if FSlots[i].Kind <> #0 then
         begin
            c := V[i + 1];
            if (c <> ' ') and Accepts(i, c) then s[i + 1] := c;
         end;
   end
   else
   begin
      { only the input characters, in order }
      j := 1;
      for i := 0 to High(FSlots) do
         if (FSlots[i].Kind <> #0) and (j <= Length(V)) then
         begin
            c := V[j];
            inc(j);
            if (c <> ' ') and Accepts(i, c) then s[i + 1] := c;
         end;
   end;
   inherited SetCaption(s);
   FCaret := NextSlot(-1, 1);
   ScrollIntoView;
end;

function TMaskEdit.ValidateEdit: boolean;
var i: integer;
begin
   Result := true;
   for i := 0 to High(FSlots) do
      if (FSlots[i].Kind in ['0', 'L', 'A', 'C']) and (FCaption[i + 1] = FBlank) then
         exit(false);
end;

procedure TMaskEdit.KeyDown(var Key: Word; Shift: TShiftState);
var s: string;
    p: integer;
begin
   if not IsMasked then
   begin
      inherited KeyDown(Key, Shift);
      exit;
   end;
   if Shift * [ssAlt] <> [] then exit;
   s := FCaption;
   case Key of
      VK_LEFT:  begin SetCaret(NextSlot(FCaret, -1)); Key := 0; end;
      VK_RIGHT: begin SetCaret(NextSlot(FCaret, 1)); Key := 0; end;
      VK_HOME:  begin SetCaret(NextSlot(-1, 1)); Key := 0; end;
      VK_END:   begin SetCaret(Length(FSlots)); Key := 0; end;
      VK_BACK:
         begin
            if not FReadOnly then
            begin
               p := FCaret - 1;
               while (p >= 0) and (FSlots[p].Kind = #0) do dec(p);
               if p >= 0 then
               begin
                  s[p + 1] := FBlank;
                  inherited SetCaption(s);
                  FCaret := p;
                  Change;
               end;
            end;
            Key := 0;
         end;
      VK_DELETE:
         begin
            if not FReadOnly and (FCaret < Length(FSlots)) and (FSlots[FCaret].Kind <> #0) then
            begin
               s[FCaret + 1] := FBlank;
               inherited SetCaption(s);
               Change;
            end;
            Key := 0;
         end;
      VK_INSERT:
         if Shift = [ssShift] then begin PasteFromClipboard; Key := 0; end
         else if Shift = [ssCtrl] then begin Clipboard.AsText := Text; Key := 0; end
         else Key := 0;                     { always overwrite }
   else
      if (ssCtrl in Shift) and (Key = Ord('Y')) and not FReadOnly then
      begin
         inherited SetCaption(EmptyText);
         FCaret := NextSlot(-1, 1);
         Change;
         Key := 0;
      end
      else if (ssCtrl in Shift) and (Key = Ord('C')) then
      begin
         Clipboard.AsText := Text;
         Key := 0;
      end
      else if (ssCtrl in Shift) and (Key = Ord('V')) then
      begin
         PasteFromClipboard;
         Key := 0;
      end
      else if ssCtrl in Shift then Key := 0;
   end;
   Invalidate;
end;

procedure TMaskEdit.KeyPress(var Key: char);
var s: string;
    p: integer;
    c: char;
begin
   if not IsMasked then
   begin
      inherited KeyPress(Key);
      exit;
   end;
   if (Key < ' ') then exit;
   if FReadOnly then begin Key := #0; exit; end;
   p := FCaret;
   while (p < Length(FSlots)) and (FSlots[p].Kind = #0) do
   begin
      { typing the literal itself just steps over it }
      if FSlots[p].Lit = Key then
      begin
         SetCaret(NextSlot(p, 1));
         Key := #0;
         exit;
      end;
      inc(p);
   end;
   c := Key;
   Key := #0;
   if (p >= Length(FSlots)) or not Accepts(p, c) then
   begin
      HWBeep;
      exit;
   end;
   s := FCaption;
   s[p + 1] := c;
   inherited SetCaption(s);
   FCaret := NextSlot(p, 1);
   ScrollIntoView;
   Change;
   Invalidate;
end;

procedure TMaskEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   inherited MouseDown(Button, Shift, X, Y);
   if IsMasked and (FCaret < Length(FSlots)) and (FSlots[FCaret].Kind = #0) then
      SetCaret(NextSlot(FCaret, 1));
end;

procedure TMaskEdit.DoEnter;
begin
   inherited DoEnter;
   if IsMasked then
   begin
      FSelAll := false;
      FCaret := NextSlot(-1, 1);
      ScrollIntoView;
   end;
end;

procedure TMaskEdit.PasteFromClipboard;
var t: string;
    i: integer;
    k: char;
begin
   if not IsMasked then
   begin
      inherited PasteFromClipboard;
      exit;
   end;
   t := Clipboard.AsText;
   for i := 1 to Length(t) do
   begin
      if t[i] < ' ' then break;
      k := t[i];
      KeyPress(k);
   end;
end;

{=============================================================================}
{  TProgressBar                                                               }
{=============================================================================}

constructor TProgressBar.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FMax := 100;
   FStep := 10;
   FWidth := 20;
   FHeight := 1;
end;

procedure TProgressBar.SetPosition(V: integer);
begin
   if V < FMin then V := FMin;
   if V > FMax then V := FMax;
   if V = FPosition then exit;
   FPosition := V;
   Invalidate;
end;

procedure TProgressBar.SetMin(V: integer);
begin
   FMin := V;
   if FMax < V then FMax := V;
   SetPosition(FPosition);
   Invalidate;
end;

procedure TProgressBar.SetMax(V: integer);
begin
   FMax := V;
   if FMin > V then FMin := V;
   SetPosition(FPosition);
   Invalidate;
end;

procedure TProgressBar.SetBarShowText(V: boolean);
begin
   FBarShowText := V;
   Invalidate;
end;

procedure TProgressBar.StepIt;
begin
   if FPosition >= FMax then Position := FMin
   else Position := FPosition + FStep;
end;

procedure TProgressBar.StepBy(Delta: integer);
begin
   Position := FPosition + Delta;
end;

procedure TProgressBar.Paint;
var len, done, pct, i, x: integer;
    s: string;
    horiz: boolean;
    a: byte;
    o: TPoint;
    w: word;
begin
   horiz := FOrientation in [pbHorizontal, pbRightToLeft];
   if horiz then len := Width else len := Height;
   if FMax > FMin then
   begin
      done := ((FPosition - FMin) * len + (FMax - FMin) div 2) div (FMax - FMin);
      pct := ((FPosition - FMin) * 100) div (FMax - FMin);
   end
   else
   begin
      done := 0;
      pct := 0;
   end;
   Canvas.Fill(Rect(0, 0, Width, Height), chShadeLight, Theme.Progress);
   case FOrientation of
      pbHorizontal:  Canvas.Fill(Rect(0, 0, done, Height), ' ', Theme.ProgressDone);
      pbRightToLeft: Canvas.Fill(Rect(Width - done, 0, Width, Height), ' ', Theme.ProgressDone);
      pbVertical:    Canvas.Fill(Rect(0, Height - done, Width, Height), ' ', Theme.ProgressDone);
      pbTopDown:     Canvas.Fill(Rect(0, 0, Width, done), ' ', Theme.ProgressDone);
   end;
   if FBarShowText and horiz then
   begin
      { the percentage over the bar, each character in its cell's colours }
      s := IntToStr(pct) + '%';
      x := (Width - Length(s)) div 2;
      o := ScreenOrigin;
      for i := 1 to Length(s) do
      begin
         w := ScrGetCell(o.X + x + i - 1, o.Y + Height div 2);
         a := w shr 8;
         if (w and $FF) = byte(chShadeLight) then a := MakeAttr(tcBlack, AttrBg(a));
         Canvas.PutChar(x + i - 1, Height div 2, s[i], a);
      end;
   end;
end;

{=============================================================================}
{  TStaticText, TBevel                                                        }
{=============================================================================}

constructor TStaticText.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FAutoSize := false;
   FWidth := 20;
   FHeight := 1;
end;

procedure TStaticText.SetBorderStyle(V: TStaticBorderStyle);
begin
   if V = FBorderStyle then exit;
   FBorderStyle := V;
   Invalidate;
end;

procedure TStaticText.Paint;
var bg, fg, a, hot: byte;
    i, x, n, off, w: integer;
    s: string;
begin
   bg := BackColor;
   if IsEnabledAll then fg := TextColor(Theme.LabelFg) else fg := Theme.DisabledFg;
   a := MakeAttr(fg, bg);
   hot := MakeAttr(Theme.LabelHotFg, bg);
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   off := 0;
   case FBorderStyle of
      sbsSingle: begin Canvas.Frame(Rect(0, 0, Width, Height), 1, a); off := 1; end;
      sbsSunken: begin Canvas.Frame(Rect(0, 0, Width, Height), 5, a); off := 1; end;
   end;
   w := Width - 2 * off;
   for i := 0 to FLines.Count - 1 do
   begin
      if i >= Height - 2 * off then break;
      s := FLines[i];
      if FShowAccelChar then n := Length(StripAccel(s)) else n := Length(s);
      case FAlignment of
         taRightJustify: x := off + w - n;
         taCenter:       x := off + (w - n) div 2;
      else
         x := off;
      end;
      if FShowAccelChar then Canvas.TextOutAccel(x, off + i, s, a, hot)
      else Canvas.TextOut(x, off + i, s, a);
   end;
end;

constructor TBevel.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FWidth := 20;
   FHeight := 3;
end;

procedure TBevel.SetShape(V: TBevelShape);
begin
   FShape := V;
   Invalidate;
end;

procedure TBevel.SetStyle(V: TBevelStyle);
begin
   FStyle := V;
   Invalidate;
end;

procedure TBevel.Paint;
var a: byte;
    h, v: char;
    st: integer;
begin
   a := MakeAttr(TextColor(Theme.GroupFrameFg), BackColor);
   if FStyle = bsRaised then begin h := #205; v := #186; st := 2; end
   else begin h := #196; v := #179; st := 1; end;
   case FShape of
      bsBox, bsFrame: Canvas.Frame(Rect(0, 0, Width, Height), st, a);
      bsTopLine:      Canvas.HLine(0, Width, 0, h, a);
      bsBottomLine:   Canvas.HLine(0, Width, Height - 1, h, a);
      bsLeftLine:     Canvas.VLine(0, 0, Height, v, a);
      bsRightLine:    Canvas.VLine(Width - 1, 0, Height, v, a);
   end;
end;


function TScrollBar.MouseWheel(WheelDelta: integer): boolean;
begin
   Position := FPosition - (WheelDelta div 120) * FSmallChange * 3;
   Result := true;
end;

{ the wheel: up adds, down takes away }
function TSpinEdit.MouseWheel(WheelDelta: integer): boolean;
begin
   Value := Value + (WheelDelta div 120) * FIncrement;
   Result := true;
end;

initialization
   RegisterClasses([TTimer, TScrollBar, TCheckListBox, TRadioGroup, TSpinEdit, TMaskEdit,
                    TProgressBar, TStaticText, TBevel]);
end.
