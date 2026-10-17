{-----------------------------------------------------------------------------}
{  TUIMENU - menu bars and status bars, LCL names:                             }
{     TMainMenu TMenuItem  (Menus)   NewItem NewSubMenu NewLine               }
{     TStatusBar TStatusPanel  (ComCtrls)                                     }
{                                                                             }
{  Both work at two levels:                                                   }
{     screen  Application.Menu := MainMenu1;     top row of the screen        }
{             Application.StatusBar := StatusBar1;  bottom row (no Parent)    }
{     window  Form.Menu := MainMenu2;            row under the form's title  }
{             StatusBar2.Parent := Form;         last row of the form        }
{  Forms live in Application.DesktopRect, between the screen's bars.          }
{                                                                             }
{  Keys: F10 opens the active form's menu bar, or the screen's. Alt+letter    }
{  goes to the form's menu bar, then the form's controls, then the screen's   }
{  menu bar. ShortCut keys of menu items and status panels work whenever     }
{  their form is active (the screen's ones when no modal form runs).          }
{  In a menu: arrows, Enter, Esc (one level), Home/End, letters.              }
{  Mouse: click or drag along the bar and down the menus; release on an      }
{  item to run it.                                                            }
{                                                                             }
{  Status panel text: '~' switches the highlight on and off, Turbo Vision     }
{  style: '~F10~ Menu'. A panel can have OnClick and ShortCut. AutoHint shows }
{  Application.Hint (the menu item's or focused control's Hint) instead.     }
{-----------------------------------------------------------------------------}
unit TUIMenu;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl;

type
   TMenuItem = class(TComponent)
   private
      FCaption, FHint: string;
      FShortCut: TShortCut;
      FEnabled, FVisible, FChecked, FAutoCheck: boolean;
      FOnClick: TNotifyEvent;
      FItems: TFPList;
      FParentItem: TMenuItem;
      FAction: TAction;
      procedure SetAction(V: TAction);
      procedure ActionChanged(Sender: TObject);
      function  GetCount: integer;
      function  GetItem(I: integer): TMenuItem;
      procedure SetCaption(const V: string);
      procedure SetChecked(V: boolean);
      procedure SetEnabled(V: boolean);
      procedure SetVisible(V: boolean);
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Add(Item: TMenuItem); overload;
      procedure Add(const AItems: array of TMenuItem); overload;
      procedure Insert(Index: integer; Item: TMenuItem);
      procedure Delete(Index: integer);
      procedure Remove(Item: TMenuItem);
      procedure Clear;
      function  IndexOf(Item: TMenuItem): integer;
      function  IsLine: boolean;
      function  HasItems: boolean;              { visible sub items }
      function  EnabledAll: boolean;            { and its parents }
      procedure Click; virtual;
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
      { in an .lfm items sit inside their menu or their parent item }
      function  GetParentComponent: TComponent; override;
      function  HasParent: boolean; override;
      procedure SetParentComponent(Value: TComponent); override;
      { Caption, Hint, ShortCut, Enabled, Checked, Visible and the click }
      { come from the action                                            }
      property Items[I: integer]: TMenuItem read GetItem; default;
      property Parent: TMenuItem read FParentItem;
   published
      property Action: TAction read FAction write SetAction;
      property Count: integer read GetCount;
      property Caption: string read FCaption write SetCaption;
      property Hint: string read FHint write FHint;
      property ShortCut: TShortCut read FShortCut write FShortCut default 0;
      property Enabled: boolean read FEnabled write SetEnabled default true;
      property Visible: boolean read FVisible write SetVisible default true;
      property Checked: boolean read FChecked write SetChecked default false;
      property AutoCheck: boolean read FAutoCheck write FAutoCheck default false;
      property OnClick: TNotifyEvent read FOnClick write FOnClick;
   end;

   TMenuPopup = record
      Item: TMenuItem;          { the item whose sub items are shown }
      Sel: integer;             { index into Item's items, -1 none }
      R: TRect;                 { frame, screen coordinates }
   end;

   TMainMenu = class(TMenuBarBase)
   protected
      FNoBar: boolean;             { TPopupMenu: menus only, no bar }
   private
      FItems: TMenuItem;
      FOpen: boolean;
      FBarSel: integer;
      FPopups: array of TMenuPopup;
      FTracking: boolean;
      procedure InvalidateParts;
      procedure BarItemPos(I: integer; out X1, X2: integer);
      function  BarItemAt(X: integer): integer;
      function  NextBar(From, Dir: integer): integer;
      procedure OpenBar(I: integer; WithPopup: boolean);
      procedure PushPopup(Item: TMenuItem; X, Y: integer);
      procedure PopTo(Depth: integer);
      function  NextSel(const P: TMenuPopup; From, Dir: integer): integer;
      procedure SelectIn(Depth, Index: integer);
      procedure OpenSub(Depth: integer);
      procedure Execute(Item: TMenuItem);
      function  PopupHit(X, Y: integer; out Depth, Index: integer): boolean;
      procedure UpdateHint;
      function  FindShortCut(Item: TMenuItem; SC: TShortCut): TMenuItem;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      function  BarRect: TRect; override;
      procedure PaintBar; override;
      procedure PaintPopups; override;
      function  IsOpen: boolean; override;
      procedure Activate; override;
      procedure OpenAt(X: integer); override;
      function  AccelKey(Ch: char): boolean; override;
      function  ShortCutKey(SC: TShortCut): boolean; override;
      procedure CloseMenu; override;
      procedure MenuKey(Key: Word; Ch: char; Shift: TShiftState); override;
      procedure MenuMouse(Down, Up: boolean; X, Y: integer; Buttons: byte); override;
   published
      property Items: TMenuItem read FItems;
   end;

   { a menu that opens where it is needed: Control.PopupMenu := PopupMenu1 }
   { opens it with a right click or Shift+F10; Popup(X, Y) opens it by code }
   TPopupMenu = class(TMainMenu)
   private
      FOnPopup, FOnClose: TNotifyEvent;
   public
      constructor Create(AOwner: TComponent); override;
      function  BarRect: TRect; override;
      procedure PaintBar; override;
      procedure Popup(X, Y: integer); override;
      procedure CloseMenu; override;
   published
      property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
      property OnClose: TNotifyEvent read FOnClose write FOnClose;
   end;

   TStatusBar = class;

   TStatusPanel = class(TCollectionItem)
   private
      FText: string;
      FWidth: integer;
      FAlignment: TAlignment;
      FShortCut: TShortCut;
      FOnClick: TNotifyEvent;
      procedure SetText(const V: string);
      procedure SetWidth(V: integer);
   public
      constructor Create(ACollection: TCollection); override;
      { TUI: what a click on the panel (or its ShortCut) does }
   published
      property Text: string read FText write SetText;
      property Width: integer read FWidth write SetWidth default 0;  { 0 = fit the text }
      property Alignment: TAlignment read FAlignment write FAlignment default taLeftJustify;
   published
      property OnClick: TNotifyEvent read FOnClick write FOnClick;
      property ShortCut: TShortCut read FShortCut write FShortCut default 0;
   end;

   TStatusPanels = class(TCollection)
   private
      FBar: TStatusBar;
      function GetItem(I: integer): TStatusPanel;
   protected
      procedure Update(Item: TCollectionItem); override;
   public
      constructor Create(ABar: TStatusBar);
      function Add: TStatusPanel;
      property Items[I: integer]: TStatusPanel read GetItem; default;
   end;

   TStatusBar = class(TStatusBarBase)
   private
      FPanels: TStatusPanels;
      FSimplePanel: boolean;
      FSimpleText: string;
      FAutoHint: boolean;
      FDownPanel: integer;
      procedure SetSimplePanel(V: boolean);
      procedure SetPanels(V: TStatusPanels);
      procedure SetSimpleText(const V: string);
      procedure PanelPos(I: integer; out X1, X2: integer);
      function  PanelAt(X: integer): integer;
      function  ShowsHint: boolean;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Paint; override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      function  ShortCutKey(SC: TShortCut): boolean; override;
   published
      property Panels: TStatusPanels read FPanels write SetPanels;
      property SimplePanel: boolean read FSimplePanel write SetSimplePanel default false;
      property SimpleText: string read FSimpleText write SetSimpleText;
      property AutoHint: boolean read FAutoHint write FAutoHint default true;
   end;

{ the LCL's helpers for building menus in code }
function NewItem(const ACaption: string; AShortCut: TShortCut; AChecked, AEnabled: boolean;
                 AOnClick: TNotifyEvent; hCtx: integer; const AName: string): TMenuItem;
function NewSubMenu(const ACaption: string; hCtx: integer; const AName: string;
                    const AItems: array of TMenuItem; AEnabled: boolean = true): TMenuItem;
function NewLine: TMenuItem;

{ text with '~' highlight switches: the visible length / drawing }
function TildeLength(const S: string): integer;
procedure PutTilde(X, Y: integer; const S: string; Attr, HotAttr: byte);

implementation

procedure MenusChanged;
begin
   if Application <> nil then Application.InvalidateAll;
end;

function TildeLength(const S: string): integer;
var i: integer;
begin
   Result := 0;
   for i := 1 to Length(S) do
      if S[i] <> '~' then inc(Result);
end;

{ at most N visible characters of a '~' string }
function TildeCut(const S: string; N: integer): string;
var i, k: integer;
begin
   k := 0;
   Result := '';
   for i := 1 to Length(S) do
   begin
      if S[i] <> '~' then
      begin
         if k >= N then break;
         inc(k);
      end;
      Result := Result + S[i];
   end;
end;

procedure PutTilde(X, Y: integer; const S: string; Attr, HotAttr: byte);
var i: integer;
    hot: boolean;
begin
   hot := false;
   for i := 1 to Length(S) do
      if S[i] = '~' then hot := not hot
      else
      begin
         if hot then ScrPutChar(X, Y, S[i], HotAttr)
         else ScrPutChar(X, Y, S[i], Attr);
         inc(X);
      end;
end;

{=============================================================================}
{  TMenuItem                                                                  }
{=============================================================================}

constructor TMenuItem.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FItems := TFPList.Create;
   FEnabled := true;
   FVisible := true;
end;

destructor TMenuItem.Destroy;
begin
   SetAction(nil);
   { sub items go with their parent, as in the LCL }
   while FItems.Count > 0 do TMenuItem(FItems[FItems.Count - 1]).Free;
   if FParentItem <> nil then FParentItem.FItems.Remove(Self);
   FItems.Free;
   inherited Destroy;
end;

function TMenuItem.GetCount: integer;
begin
   Result := FItems.Count;
end;

function TMenuItem.GetItem(I: integer): TMenuItem;
begin
   Result := TMenuItem(FItems[I]);
end;

procedure TMenuItem.Add(Item: TMenuItem);
begin
   Insert(FItems.Count, Item);
end;

procedure TMenuItem.Add(const AItems: array of TMenuItem);
var i: integer;
begin
   for i := 0 to High(AItems) do Add(AItems[i]);
end;

procedure TMenuItem.Insert(Index: integer; Item: TMenuItem);
begin
   if Item.FParentItem <> nil then Item.FParentItem.Remove(Item);
   FItems.Insert(Index, Item);
   Item.FParentItem := Self;
   MenusChanged;
end;

procedure TMenuItem.Delete(Index: integer);
begin
   TMenuItem(FItems[Index]).FParentItem := nil;
   FItems.Delete(Index);
   MenusChanged;
end;

procedure TMenuItem.Remove(Item: TMenuItem);
var i: integer;
begin
   i := FItems.IndexOf(Item);
   if i >= 0 then Delete(i);
end;

procedure TMenuItem.Clear;
begin
   while FItems.Count > 0 do TMenuItem(FItems[FItems.Count - 1]).Free;
   MenusChanged;
end;

function TMenuItem.IndexOf(Item: TMenuItem): integer;
begin
   Result := FItems.IndexOf(Item);
end;

function TMenuItem.IsLine: boolean;
begin
   Result := FCaption = '-';
end;

function TMenuItem.HasItems: boolean;
var i: integer;
begin
   for i := 0 to FItems.Count - 1 do
      if TMenuItem(FItems[i]).FVisible then exit(true);
   Result := false;
end;

function TMenuItem.EnabledAll: boolean;
var m: TMenuItem;
begin
   m := Self;
   while m <> nil do
   begin
      if not m.FEnabled then exit(false);
      m := m.FParentItem;
   end;
   Result := true;
end;

procedure TMenuItem.SetCaption(const V: string);
begin
   if V = FCaption then exit;
   FCaption := V;
   MenusChanged;
end;

procedure TMenuItem.SetChecked(V: boolean);
begin
   if V = FChecked then exit;
   FChecked := V;
   MenusChanged;
end;

procedure TMenuItem.SetEnabled(V: boolean);
begin
   if V = FEnabled then exit;
   FEnabled := V;
   MenusChanged;
end;

procedure TMenuItem.SetVisible(V: boolean);
begin
   if V = FVisible then exit;
   FVisible := V;
   MenusChanged;
end;

procedure TMenuItem.Click;
begin
   if FAutoCheck then Checked := not Checked;
   if Assigned(FOnClick) then FOnClick(Self)
   else if FAction <> nil then FAction.Execute;
end;

function TMenuItem.GetParentComponent: TComponent;
begin
   Result := FParentItem;
   { the root item of a menu stands for the menu itself }
   if (Result <> nil) and (TMenuItem(Result).FParentItem = nil) and (Result.Owner is TMainMenu) then
      Result := Result.Owner;
end;

function TMenuItem.HasParent: boolean;
begin
   Result := FParentItem <> nil;
end;

procedure TMenuItem.SetParentComponent(Value: TComponent);
begin
   if Value is TMainMenu then TMainMenu(Value).Items.Add(Self)
   else if Value is TMenuItem then TMenuItem(Value).Add(Self);
end;

procedure TMenuItem.SetAction(V: TAction);
begin
   if V = FAction then exit;
   if FAction <> nil then
   begin
      FAction.UnRegisterChanges(Self);
      FAction.RemoveFreeNotification(Self);
   end;
   FAction := V;
   if V <> nil then
   begin
      V.FreeNotification(Self);
      V.RegisterChanges(Self, @ActionChanged);
      ActionChanged(V);
   end;
end;

procedure TMenuItem.ActionChanged(Sender: TObject);
var a: TAction;
begin
   a := TAction(Sender);
   if a.Caption <> '' then FCaption := a.Caption;
   if a.Hint <> '' then FHint := a.Hint;
   FShortCut := a.ShortCut;
   FEnabled := a.Enabled;
   FChecked := a.Checked;
   FVisible := a.Visible;
   MenusChanged;
end;

procedure TMenuItem.Notification(AComponent: TComponent; Operation: TOperation);
begin
   inherited Notification(AComponent, Operation);
   if (Operation = opRemove) and (AComponent = FAction) then FAction := nil;
end;

function NewItem(const ACaption: string; AShortCut: TShortCut; AChecked, AEnabled: boolean;
                 AOnClick: TNotifyEvent; hCtx: integer; const AName: string): TMenuItem;
begin
   Result := TMenuItem.Create(nil);
   Result.Caption := ACaption;
   Result.ShortCut := AShortCut;
   Result.Checked := AChecked;
   Result.Enabled := AEnabled;
   Result.OnClick := AOnClick;
   if AName <> '' then Result.Name := AName;
   if hCtx = 0 then;
end;

function NewSubMenu(const ACaption: string; hCtx: integer; const AName: string;
                    const AItems: array of TMenuItem; AEnabled: boolean): TMenuItem;
begin
   Result := NewItem(ACaption, 0, false, AEnabled, nil, hCtx, AName);
   Result.Add(AItems);
end;

function NewLine: TMenuItem;
begin
   Result := NewItem('-', 0, false, true, nil, 0, '');
end;

{=============================================================================}
{  TMainMenu                                                                  }
{=============================================================================}

constructor TMainMenu.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FItems := TMenuItem.Create(Self);
   FBarSel := -1;
end;

destructor TMainMenu.Destroy;
begin
   CloseMenu;
   if (Application <> nil) and (Application.Menu = Self) then Application.Menu := nil;
   if FForm <> nil then FForm.Menu := nil;
   inherited Destroy;      { frees FItems (owned) and with it every item }
end;

function TMainMenu.BarRect: TRect;
var fr: TRect;
    o: integer;
begin
   if FForm <> nil then
   begin
      fr := FForm.ScreenRect;
      if FForm.HasFrame then o := 1 else o := 0;
      Result := Rect(fr.Left + o, fr.Top + o, fr.Right - o, fr.Top + o + 1);
   end
   else
      Result := Rect(0, 0, ScrCols, 1);
end;

function TMainMenu.IsOpen: boolean;
begin
   Result := FOpen;
end;

{ screen columns of top level item I ([X1, X2) including its padding) }
procedure TMainMenu.BarItemPos(I: integer; out X1, X2: integer);
var j, x: integer;
    m: TMenuItem;
begin
   x := BarRect.Left + 1;
   X1 := x; X2 := x;
   for j := 0 to FItems.Count - 1 do
   begin
      m := FItems[j];
      if not m.Visible then continue;
      X1 := x;
      X2 := x + Length(StripAccel(m.Caption)) + 2;
      if j = I then exit;
      x := X2;
   end;
end;

function TMainMenu.BarItemAt(X: integer): integer;
var i, x1, x2: integer;
begin
   for i := 0 to FItems.Count - 1 do
      if FItems[i].Visible then
      begin
         BarItemPos(i, x1, x2);
         if (X >= x1) and (X < x2) then exit(i);
      end;
   Result := -1;
end;

function TMainMenu.NextBar(From, Dir: integer): integer;
var n, i: integer;
begin
   Result := -1;
   n := FItems.Count;
   if n = 0 then exit;
   i := From;
   repeat
      i := (i + Dir + n) mod n;
      if FItems[i].Visible then exit(i);
   until i = From;
   if (From >= 0) and (From < n) and FItems[From].Visible then Result := From;
end;

procedure TMainMenu.InvalidateParts;
var i: integer;
    r: TRect;
begin
   if Application = nil then exit;
   Application.InvalidateRect(BarRect);
   for i := 0 to High(FPopups) do
   begin
      r := FPopups[i].R;
      inc(r.Right, 2);
      inc(r.Bottom, 1);
      Application.InvalidateRect(r);
   end;
end;

procedure TMainMenu.UpdateHint;
var h: string;
    d: integer;
begin
   h := '';
   d := High(FPopups);
   if (d >= 0) and (FPopups[d].Sel >= 0) then h := FPopups[d].Item[FPopups[d].Sel].Hint
   else if (FBarSel >= 0) and (FBarSel < FItems.Count) then h := FItems[FBarSel].Hint;
   if Application <> nil then Application.MenuHint := h;
end;

function TMainMenu.NextSel(const P: TMenuPopup; From, Dir: integer): integer;
var n, i, k: integer;
    m: TMenuItem;
begin
   Result := -1;
   n := P.Item.Count;
   if n = 0 then exit;
   i := From;
   if i < 0 then
      if Dir > 0 then i := -1 else i := n;
   for k := 1 to n do
   begin
      i := i + Dir;
      if i >= n then i := 0;
      if i < 0 then i := n - 1;
      m := P.Item[i];
      if m.Visible and not m.IsLine then exit(i);
   end;
end;

procedure TMainMenu.PushPopup(Item: TMenuItem; X, Y: integer);
var p: TMenuPopup;
    i, w, h, capW, scW, n: integer;
    m: TMenuItem;
    sc: string;
begin
   { as in the LCL: an item with sub items gets OnClick when they open, }
   { so it can fill them (a window list)                               }
   if (Item <> FItems) and Assigned(Item.FOnClick) then Item.FOnClick(Item);
   capW := 0; scW := 0; h := 0;
   for i := 0 to Item.Count - 1 do
   begin
      m := Item[i];
      if not m.Visible then continue;
      inc(h);
      n := Length(StripAccel(m.Caption));
      if n > capW then capW := n;
      if m.HasItems then sc := chArrowRight else sc := ShortCutToText(m.ShortCut);
      if Length(sc) > scW then scW := Length(sc);
   end;
   if h = 0 then exit;
   { frame, ' ', check, ' ', caption, '  ' shortcut, ' ', frame }
   w := 2 + 3 + capW + 1;
   if scW > 0 then inc(w, 2 + scW);
   h := h + 2;
   if X + w > ScrCols then X := ScrCols - w;
   if Y + h > ScrRows then Y := ScrRows - h;
   if X < 0 then X := 0;
   if Y < 0 then Y := 0;
   p.Item := Item;
   p.R := Rect(X, Y, X + w, Y + h);
   p.Sel := -1;
   p.Sel := NextSel(p, -1, 1);
   SetLength(FPopups, Length(FPopups) + 1);
   FPopups[High(FPopups)] := p;
end;

procedure TMainMenu.PopTo(Depth: integer);
begin
   if Depth < 0 then Depth := 0;
   if Depth < Length(FPopups) then SetLength(FPopups, Depth);
end;

procedure TMainMenu.OpenBar(I: integer; WithPopup: boolean);
var x1, x2: integer;
begin
   InvalidateParts;
   PopTo(0);
   if not FOpen then
   begin
      FOpen := true;
      if Application <> nil then Application.MenuOpened(Self);
   end;
   FBarSel := I;
   if WithPopup and (I >= 0) and FItems[I].HasItems then
   begin
      BarItemPos(I, x1, x2);
      PushPopup(FItems[I], x1 - 1, BarRect.Top + 1);
   end;
   UpdateHint;
   InvalidateParts;
end;

procedure TMainMenu.SelectIn(Depth, Index: integer);
begin
   if (Depth < 0) or (Depth > High(FPopups)) then exit;
   InvalidateParts;
   PopTo(Depth + 1);
   FPopups[Depth].Sel := Index;
   UpdateHint;
   InvalidateParts;
end;

procedure TMainMenu.OpenSub(Depth: integer);
var p: TMenuPopup;
    m: TMenuItem;
    row, i: integer;
begin
   if (Depth < 0) or (Depth > High(FPopups)) then exit;
   p := FPopups[Depth];
   if p.Sel < 0 then exit;
   m := p.Item[p.Sel];
   if not (m.HasItems and m.EnabledAll) then exit;
   InvalidateParts;
   PopTo(Depth + 1);
   row := 0;
   for i := 0 to p.Sel - 1 do
      if p.Item[i].Visible then inc(row);
   PushPopup(m, p.R.Right - 1, p.R.Top + 1 + row);
   UpdateHint;
   InvalidateParts;
end;

procedure TMainMenu.Execute(Item: TMenuItem);
begin
   CloseMenu;
   if (Item <> nil) and Item.EnabledAll and not Item.IsLine then Item.Click;
end;

procedure TMainMenu.CloseMenu;
begin
   if not FOpen then exit;
   InvalidateParts;
   PopTo(0);
   FOpen := false;
   FTracking := false;
   FBarSel := -1;
   if Application <> nil then Application.MenuClosed(Self);
   InvalidateParts;
end;

procedure TMainMenu.Activate;
var i: integer;
begin
   i := NextBar(-1, 1);
   if i < 0 then exit;
   OpenBar(i, true);
end;

procedure TMainMenu.OpenAt(X: integer);
var i: integer;
begin
   i := BarItemAt(X);
   if i < 0 then exit;
   if FOpen and (i = FBarSel) and (Length(FPopups) > 0) then CloseMenu
   else
   begin
      OpenBar(i, true);
      FTracking := true;
   end;
end;

function TMainMenu.AccelKey(Ch: char): boolean;
var i: integer;
begin
   Ch := UpCase(Ch);
   for i := 0 to FItems.Count - 1 do
      if FItems[i].Visible and (AccelChar(FItems[i].Caption) = Ch) then
      begin
         if FItems[i].HasItems then OpenBar(i, true)
         else Execute(FItems[i]);
         exit(true);
      end;
   Result := false;
end;

function TMainMenu.FindShortCut(Item: TMenuItem; SC: TShortCut): TMenuItem;
var i: integer;
    m: TMenuItem;
begin
   Result := nil;
   for i := 0 to Item.Count - 1 do
   begin
      m := Item[i];
      if not (m.Visible and m.Enabled) then continue;
      if (m.ShortCut = SC) and not m.HasItems then exit(m);
      Result := FindShortCut(m, SC);
      if Result <> nil then exit;
   end;
end;

function TMainMenu.ShortCutKey(SC: TShortCut): boolean;
var m: TMenuItem;
begin
   Result := false;
   if SC = 0 then exit;
   m := FindShortCut(FItems, SC);
   if m = nil then exit;
   Execute(m);
   Result := true;
end;

procedure TMainMenu.MenuKey(Key: Word; Ch: char; Shift: TShiftState);
var d, i: integer;
    c: char;
    m: TMenuItem;
begin
   d := High(FPopups);                   { -1: only the bar }
   if FNoBar then
   begin
      { a pop-up menu: no bar to go back to }
      if (Key = VK_ESCAPE) and (d <= 0) then begin CloseMenu; exit; end;
      if (Key = VK_LEFT) and (d <= 0) then exit;
      if (Key = VK_RIGHT) and not ((d >= 0) and (FPopups[d].Sel >= 0) and
         FPopups[d].Item[FPopups[d].Sel].HasItems) then exit;
      if (Key = VK_F10) then begin CloseMenu; exit; end;
      if d < 0 then begin CloseMenu; exit; end;
   end;
   case Key of
      VK_ESCAPE:
         if d > 0 then
         begin
            InvalidateParts; PopTo(d); UpdateHint; InvalidateParts;
         end
         else if d = 0 then
         begin
            InvalidateParts; PopTo(0); UpdateHint; InvalidateParts;
         end
         else CloseMenu;
      VK_F10:
         CloseMenu;
      VK_LEFT:
         if d > 0 then
         begin
            InvalidateParts; PopTo(d); UpdateHint; InvalidateParts;
         end
         else OpenBar(NextBar(FBarSel, -1), d = 0);
      VK_RIGHT:
         begin
            if (d >= 0) and (FPopups[d].Sel >= 0) and FPopups[d].Item[FPopups[d].Sel].HasItems then
               OpenSub(d)
            else OpenBar(NextBar(FBarSel, 1), d >= 0);
         end;
      VK_DOWN, VK_UP:
         if d < 0 then OpenBar(FBarSel, true)
         else if Key = VK_DOWN then SelectIn(d, NextSel(FPopups[d], FPopups[d].Sel, 1))
         else SelectIn(d, NextSel(FPopups[d], FPopups[d].Sel, -1));
      VK_HOME:
         if d >= 0 then SelectIn(d, NextSel(FPopups[d], -1, 1));
      VK_END:
         if d >= 0 then SelectIn(d, NextSel(FPopups[d], -1, -1));
      VK_RETURN:
         if d < 0 then
         begin
            if (FBarSel >= 0) and FItems[FBarSel].HasItems then OpenBar(FBarSel, true)
            else if FBarSel >= 0 then Execute(FItems[FBarSel]);
         end
         else if FPopups[d].Sel >= 0 then
         begin
            m := FPopups[d].Item[FPopups[d].Sel];
            if m.HasItems then OpenSub(d) else Execute(m);
         end;
   else
      { a letter: the open menu's access key, or (Alt / bar only) the bar's }
      if Ch <> #0 then c := UpCase(Ch)
      else if (Key >= VK_A) and (Key <= VK_Z) or (Key >= VK_0) and (Key <= VK_9) then c := char(Key)
      else c := #0;
      if c = #0 then exit;
      if not FNoBar and ((d < 0) or (ssAlt in Shift)) then
      begin
         for i := 0 to FItems.Count - 1 do
            if FItems[i].Visible and (AccelChar(FItems[i].Caption) = c) then
            begin
               if FItems[i].HasItems then OpenBar(i, true)
               else Execute(FItems[i]);
               exit;
            end;
         exit;
      end;
      for i := 0 to FPopups[d].Item.Count - 1 do
      begin
         m := FPopups[d].Item[i];
         if m.Visible and not m.IsLine and (AccelChar(m.Caption) = c) then
         begin
            SelectIn(d, i);
            if m.HasItems then OpenSub(d) else Execute(m);
            exit;
         end;
      end;
   end;
end;

function TMainMenu.PopupHit(X, Y: integer; out Depth, Index: integer): boolean;
var d, i, row: integer;
    p: TMenuPopup;
begin
   Result := false;
   Index := -1;
   for d := High(FPopups) downto 0 do
   begin
      p := FPopups[d];
      if not PtInRectI(p.R, X, Y) then continue;
      Depth := d;
      Result := true;
      if (X <= p.R.Left) or (X >= p.R.Right - 1) then exit;
      row := Y - p.R.Top - 1;
      if row < 0 then exit;
      for i := 0 to p.Item.Count - 1 do
         if p.Item[i].Visible then
         begin
            if row = 0 then
            begin
               if not p.Item[i].IsLine then Index := i;
               exit;
            end;
            dec(row);
         end;
      exit;
   end;
   Depth := -1;
end;

procedure TMainMenu.MenuMouse(Down, Up: boolean; X, Y: integer; Buttons: byte);
var b, d, i: integer;
    onBar: boolean;
    m: TMenuItem;
begin
   onBar := PtInRectI(BarRect, X, Y);
   if Down then
   begin
      if onBar then
      begin
         b := BarItemAt(X);
         if b < 0 then exit;
         if (b = FBarSel) and (Length(FPopups) > 0) then CloseMenu
         else
         begin
            OpenBar(b, true);
            FTracking := true;
         end;
      end
      else if PopupHit(X, Y, d, i) then
      begin
         FTracking := true;
         if i >= 0 then
         begin
            SelectIn(d, i);
            if FPopups[d].Item[i].HasItems then OpenSub(d);
         end;
      end
      else
         CloseMenu;                       { a click outside closes the menu }
      exit;
   end;
   if Up then
   begin
      FTracking := false;
      if onBar then
      begin
         b := BarItemAt(X);
         if (b >= 0) and not FItems[b].HasItems then Execute(FItems[b]);
      end
      else if PopupHit(X, Y, d, i) and (i >= 0) then
      begin
         m := FPopups[d].Item[i];
         if not m.HasItems then Execute(m);
      end;
      exit;
   end;
   { a move: with the button held the bar follows; menus follow always }
   if onBar and FTracking and (Buttons and 1 <> 0) then
   begin
      b := BarItemAt(X);
      if (b >= 0) and (b <> FBarSel) then OpenBar(b, true);
   end
   else if PopupHit(X, Y, d, i) and (i >= 0) and (i <> FPopups[d].Sel) then
   begin
      SelectIn(d, i);
      if FPopups[d].Item[i].HasItems then OpenSub(d);
   end;
end;

procedure TMainMenu.PaintBar;
var r: TRect;
    i, x1, x2: integer;
    m: TMenuItem;
    a, hot: byte;
    sel: boolean;
begin
   r := BarRect;
   ScrFill(r, ' ', Theme.MenuBar);
   for i := 0 to FItems.Count - 1 do
   begin
      m := FItems[i];
      if not m.Visible then continue;
      BarItemPos(i, x1, x2);
      if x1 >= r.Right then break;
      sel := FOpen and (i = FBarSel);
      if not m.Enabled then
      begin
         if sel then a := Theme.MenuSelDisabled else a := Theme.MenuDisabled;
         hot := a;
      end
      else if sel then begin a := Theme.MenuSel; hot := Theme.MenuSelHot; end
      else begin a := Theme.MenuBar; hot := Theme.MenuHot; end;
      if x2 > r.Right then x2 := r.Right;
      ScrFill(Rect(x1, r.Top, x2, r.Top + 1), ' ', a);
      ScrPutAccel(x1 + 1, r.Top, m.Caption, a, hot);
   end;
end;

procedure TMainMenu.PaintPopups;
var d, i, y, w: integer;
    p: TMenuPopup;
    m: TMenuItem;
    a, hot: byte;
    sc: string;
    sel: boolean;
begin
   for d := 0 to High(FPopups) do
   begin
      p := FPopups[d];
      ScrFill(p.R, ' ', Theme.MenuBar);
      ScrBox(p.R, 1, Theme.MenuBar);
      if Theme.WindowShadow then ScrWindowShadow(p.R);
      w := p.R.Right - p.R.Left;
      y := p.R.Top + 1;
      for i := 0 to p.Item.Count - 1 do
      begin
         m := p.Item[i];
         if not m.Visible then continue;
         if m.IsLine then
         begin
            ScrPutChar(p.R.Left, y, #195, Theme.MenuBar);
            ScrHLine(p.R.Left + 1, p.R.Right - 1, y, #196, Theme.MenuBar);
            ScrPutChar(p.R.Right - 1, y, #180, Theme.MenuBar);
            inc(y);
            continue;
         end;
         sel := i = p.Sel;
         if not m.EnabledAll then
         begin
            if sel then a := Theme.MenuSelDisabled else a := Theme.MenuDisabled;
            hot := a;
         end
         else if sel then begin a := Theme.MenuSel; hot := Theme.MenuSelHot; end
         else begin a := Theme.MenuBar; hot := Theme.MenuHot; end;
         ScrFill(Rect(p.R.Left + 1, y, p.R.Right - 1, y + 1), ' ', a);
         if m.Checked then ScrPutChar(p.R.Left + 2, y, chCheck, a);
         ScrPutAccel(p.R.Left + 4, y, m.Caption, a, hot);
         if m.HasItems then sc := chArrowRight else sc := ShortCutToText(m.ShortCut);
         if sc <> '' then ScrPutStr(p.R.Left + w - 2 - Length(sc), y, sc, a);
         inc(y);
      end;
   end;
end;

{=============================================================================}
{  TPopupMenu                                                                 }
{=============================================================================}

constructor TPopupMenu.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FNoBar := true;
end;

function TPopupMenu.BarRect: TRect;
begin
   Result := Rect(0, 0, 0, 0);
end;

procedure TPopupMenu.PaintBar;
begin
end;

procedure TPopupMenu.Popup(X, Y: integer);
begin
   if FOpen then CloseMenu;
   if Assigned(FOnPopup) then FOnPopup(Self);
   if not FItems.HasItems then exit;
   FOpen := true;
   FBarSel := -1;
   if Application <> nil then Application.MenuOpened(Self);
   PushPopup(FItems, X, Y);
   UpdateHint;
   InvalidateParts;
end;

procedure TPopupMenu.CloseMenu;
var was: boolean;
begin
   was := FOpen;
   inherited CloseMenu;
   if was and Assigned(FOnClose) then FOnClose(Self);
end;

{=============================================================================}
{  TStatusPanel, TStatusPanels, TStatusBar                                    }
{=============================================================================}

constructor TStatusPanel.Create(ACollection: TCollection);
begin
   inherited Create(ACollection);
   FAlignment := taLeftJustify;
end;

procedure TStatusPanel.SetText(const V: string);
begin
   if V = FText then exit;
   FText := V;
   Changed(false);
end;

procedure TStatusPanel.SetWidth(V: integer);
begin
   if V = FWidth then exit;
   FWidth := V;
   Changed(false);
end;

constructor TStatusPanels.Create(ABar: TStatusBar);
begin
   inherited Create(TStatusPanel);
   FBar := ABar;
end;

function TStatusPanels.GetItem(I: integer): TStatusPanel;
begin
   Result := TStatusPanel(inherited GetItem(I));
end;

procedure TStatusPanels.Update(Item: TCollectionItem);
begin
   if FBar <> nil then FBar.Invalidate;
end;

function TStatusPanels.Add: TStatusPanel;
begin
   Result := TStatusPanel(inherited Add);
end;

constructor TStatusBar.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FPanels := TStatusPanels.Create(Self);
   FAutoHint := true;
   FHeight := 1;
   FWidth := 20;
   FDownPanel := -1;
   FAlign := alBottom;          { in a form: the last row }
end;

destructor TStatusBar.Destroy;
begin
   if (Application <> nil) and (TControl(Application.StatusBar) = Self) then
      Application.StatusBar := nil;
   FPanels.FBar := nil;
   FreeAndNil(FPanels);
   inherited Destroy;
end;

procedure TStatusBar.SetPanels(V: TStatusPanels);
begin
   FPanels.Assign(V);
end;

procedure TStatusBar.SetSimplePanel(V: boolean);
begin
   if V = FSimplePanel then exit;
   FSimplePanel := V;
   Invalidate;
end;

procedure TStatusBar.SetSimpleText(const V: string);
begin
   if V = FSimpleText then exit;
   FSimpleText := V;
   Invalidate;
end;

{ panel I's columns, relative to the bar }
procedure TStatusBar.PanelPos(I: integer; out X1, X2: integer);
var j, x, w: integer;
begin
   x := 1;
   X1 := x; X2 := x;
   for j := 0 to FPanels.Count - 1 do
   begin
      w := FPanels[j].Width;
      if w <= 0 then w := TildeLength(FPanels[j].Text);
      X1 := x;
      X2 := x + w;
      if j = I then exit;
      x := X2 + 2;
   end;
end;

function TStatusBar.PanelAt(X: integer): integer;
var i, x1, x2: integer;
begin
   if FSimplePanel then exit(-1);
   for i := 0 to FPanels.Count - 1 do
   begin
      PanelPos(i, x1, x2);
      if (X >= x1 - 1) and (X <= x2) then exit(i);
   end;
   Result := -1;
end;

{ which hint this bar shows: the menu's (replaces the panels) or the }
{ focused control's (after the panels). It goes to the active form's  }
{ own status bar if it has one, else to the screen's                  }
function TStatusBar.ShowsHint: boolean;
var f: TCustomForm;
    m: TMenuBarBase;
begin
   Result := false;
   if not FAutoHint or (Application = nil) or (Application.Hint = '') then exit;
   f := Application.ActiveForm;
   m := Application.OpenMenu;
   if m <> nil then
   begin
      if Parent = nil then
         Result := (m.Form = nil) or (m.Form.StatusBarControl = nil)
      else
         Result := (m.Form = GetParentForm);
   end
   else if Parent = nil then
      Result := (f = nil) or (f.StatusBarControl = nil)
   else
      Result := GetParentForm = f;
end;

procedure TStatusBar.Paint;
var o: TPoint;
    i, x1, x2, n, x, endX: integer;
    p: TStatusPanel;
    a, hot: byte;
    hintOn: boolean;
begin
   a := Theme.StatusBar;
   if (Color >= 0) and (Color <= 15) then a := MakeAttr(AttrFg(a), Color);
   hot := MakeAttr(AttrFg(Theme.StatusHot), AttrBg(a));
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   o := ScreenOrigin;
   hintOn := ShowsHint;
   { a menu item's hint takes the whole bar (Turbo Vision style) }
   if hintOn and (Application.OpenMenu <> nil) then
   begin
      Canvas.TextOut(1, 0, Application.Hint, a);
      exit;
   end;
   endX := 0;
   if FSimplePanel then
   begin
      PutTilde(o.X + 1, o.Y, FSimpleText, a, hot);
      endX := 1 + TildeLength(FSimpleText);
   end
   else
      for i := 0 to FPanels.Count - 1 do
      begin
         p := FPanels[i];
         PanelPos(i, x1, x2);
         if x1 >= Width then break;
         n := TildeLength(p.Text);
         case p.Alignment of
            taRightJustify: x := x2 - n;
            taCenter:       x := x1 + (x2 - x1 - n) div 2;
         else
            x := x1;
         end;
         { a panel with a Width keeps its text inside it }
         if p.Width > 0 then PutTilde(o.X + x, o.Y, TildeCut(p.Text, x2 - x), a, hot)
         else PutTilde(o.X + x, o.Y, p.Text, a, hot);
         endX := x2;
      end;
   { the focused control's hint after the panels }
   if hintOn then
   begin
      if endX > 0 then
      begin
         Canvas.PutChar(endX + 1, 0, #179, a);
         inc(endX, 3);
      end
      else endX := 1;
      Canvas.TextOut(endX, 0, Application.Hint, a);
   end;
end;

procedure TStatusBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   inherited MouseDown(Button, Shift, X, Y);
   if Button = mbLeft then FDownPanel := PanelAt(X) else FDownPanel := -1;
end;

procedure TStatusBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var i: integer;
begin
   i := PanelAt(X);
   inherited MouseUp(Button, Shift, X, Y);
   if (Button = mbLeft) and (i >= 0) and (i = FDownPanel) and Assigned(FPanels[i].OnClick) then
      FPanels[i].OnClick(FPanels[i]);
   FDownPanel := -1;
end;

function TStatusBar.ShortCutKey(SC: TShortCut): boolean;
var i: integer;
begin
   Result := false;
   if (SC = 0) or not Visible or not Enabled then exit;
   for i := 0 to FPanels.Count - 1 do
      if (FPanels[i].ShortCut = SC) and Assigned(FPanels[i].OnClick) then
      begin
         FPanels[i].OnClick(FPanels[i]);
         exit(true);
      end;
end;

initialization
   RegisterClasses([TMainMenu, TMenuItem, TPopupMenu, TStatusBar]);
end.
