{-----------------------------------------------------------------------------}
{  TUISTD - the standard controls for the text mode UI, LCL names:             }
{     TLabel TButton TEdit TCheckBox TRadioButton TGroupBox TPanel             }
{  and the LCL dialog functions ShowMessage, MessageDlg, InputQuery,          }
{  InputBox.                                                                  }
{                                                                             }
{  Looks follow Technojock's toolkit and Turbo Vision: green buttons with a   }
{  half block shadow, blue input lines, [X] check boxes, (*) radio buttons.   }
{  '&' in a caption marks the access key (Alt+letter, or the letter alone    }
{  when the focus is not in an edit field).                                   }
{-----------------------------------------------------------------------------}
unit TUIStd;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl;

type
   TLabel = class(TControl)
   protected
      FAlignment: TAlignment;
      FAutoSize: boolean;
      FFocusControl: TWinControl;
      FShowAccelChar: boolean;
      FLines: TStringList;
      procedure SetAlignment(V: TAlignment);
      procedure SetAutoSize(V: boolean);
      procedure SetFocusControl(V: TWinControl);
   protected
      procedure TextChanged; override;
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Paint; override;
      function  HasAccel: boolean; override;
      procedure DoAccel; override;
      procedure AdjustSize;
   published
      property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
      property AutoSize: boolean read FAutoSize write SetAutoSize default true;
      property FocusControl: TWinControl read FFocusControl write SetFocusControl;
      property ShowAccelChar: boolean read FShowAccelChar write FShowAccelChar default true;
   end;

   TButton = class(TWinControl)
   private
      FDefault, FCancel: boolean;
      FModalResult: TModalResult;
      FPressed: boolean;
      procedure SetDefault(V: boolean);
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure Click; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      function  HasAccel: boolean; override;
      procedure DoAccel; override;
      function  IsDefault: boolean; override;
      function  IsCancel: boolean; override;
   published
      property Default: boolean read FDefault write SetDefault default false;
      property Cancel: boolean read FCancel write FCancel default false;
      property ModalResult: TModalResult read FModalResult write FModalResult default mrNone;
   end;

   TEdit = class(TWinControl)
   protected
      FCaret, FFirst: integer;
      FMaxLength: integer;
      FReadOnly: boolean;
      FPasswordChar: char;
      FAutoSelect: boolean;
      FSelAll: boolean;
      FOnChange: TNotifyEvent;
      procedure ScrollIntoView;
      procedure SetCaret(V: integer);
      procedure DeleteSelection;
      function  GetSelStart: integer;
      function  GetSelLength: integer;
      procedure SetCaption(const V: string); override;
      procedure Change; virtual;
      { the columns the text uses (a combo box keeps one for its arrow) }
      function  EditWidth: integer; virtual;
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure KeyPress(var Key: char); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure DoEnter; override;
      procedure DoExit; override;
      function  WantsChars: boolean; override;
      function  GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean; override;
      procedure SelectAll;
      procedure Clear;
      { the clipboard: the whole text when it is selected (Ctrl+A, entering }
      { with Tab); paste inserts at the cursor (Ctrl+C/X/V, Ctrl+Ins, Shift+ }
      { Del, Shift+Ins)                                                     }
      procedure CopyToClipboard; virtual;
      procedure CutToClipboard; virtual;
      procedure PasteFromClipboard; virtual;
   published
      property SelStart: integer read GetSelStart write SetCaret;
      property SelLength: integer read GetSelLength;
      property MaxLength: integer read FMaxLength write FMaxLength default 0;
      property ReadOnly: boolean read FReadOnly write FReadOnly default false;
      property PasswordChar: char read FPasswordChar write FPasswordChar default #0;
      property AutoSelect: boolean read FAutoSelect write FAutoSelect default true;
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
   end;

   { [X] Caption }
   TCustomCheck = class(TWinControl)
   private
      FChecked: boolean;
      FAutoSize: boolean;
      FOnChange: TNotifyEvent;
   protected
      procedure SetChecked(V: boolean); virtual;
      procedure TextChanged; override;
      function  BoxText: string; virtual; abstract;
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      function  HasAccel: boolean; override;
      procedure DoAccel; override;
      function  GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean; override;
      procedure ActionChange(A: TAction); override;
   published
      property Checked: boolean read FChecked write SetChecked default false;
      property AutoSize: boolean read FAutoSize write FAutoSize default true;
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
   end;

   TCheckBox = class(TCustomCheck)
   protected
      function  BoxText: string; override;
   public
      procedure Click; override;
   end;

   { (*) Caption; checking one unchecks the radio buttons beside it }
   TRadioButton = class(TCustomCheck)
   protected
      procedure SetChecked(V: boolean); override;
      function  BoxText: string; override;
   public
      procedure Click; override;
   end;

   TGroupBox = class(TWinControl)
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      function  ClientOffset: TPoint; override;
      function  ClientWidthValue: integer; override;
      function  ClientHeightValue: integer; override;
   end;

   TPanelBorder = (pbNone, pbSingle, pbDouble);

   TPanel = class(TWinControl)
   private
      FBorder: TPanelBorder;
      FAlignment: TAlignment;
      procedure SetBorder(V: TPanelBorder);
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      function  ClientOffset: TPoint; override;
      function  ClientWidthValue: integer; override;
      function  ClientHeightValue: integer; override;
   published
      property Border: TPanelBorder read FBorder write SetBorder default pbNone;
      property Alignment: TAlignment read FAlignment write FAlignment default taCenter;
   end;

   TMsgDlgType = (mtWarning, mtError, mtInformation, mtConfirmation, mtCustom);
   TMsgDlgBtn = (mbYes, mbNo, mbOK, mbCancel, mbAbort, mbRetry, mbIgnore,
                 mbAll, mbNoToAll, mbYesToAll, mbHelp, mbClose);
   TMsgDlgButtons = set of TMsgDlgBtn;

const
   mbYesNo = [mbYes, mbNo];
   mbYesNoCancel = [mbYes, mbNo, mbCancel];
   mbOKCancel = [mbOK, mbCancel];
   mbAbortRetryIgnore = [mbAbort, mbRetry, mbIgnore];

procedure ShowMessage(const Msg: string);
function  MessageDlg(const Msg: string; DlgType: TMsgDlgType;
                     Buttons: TMsgDlgButtons; HelpCtx: longint): TModalResult; overload;
function  MessageDlg(const ACaption, Msg: string; DlgType: TMsgDlgType;
                     Buttons: TMsgDlgButtons; HelpCtx: longint): TModalResult; overload;
function  InputQuery(const ACaption, APrompt: string; var Value: string): boolean;
function  InputBox(const ACaption, APrompt, ADefault: string): string;

implementation

{ the lines of a caption (LineEnding, #13#10 or #10 separated) }
procedure SplitLines(const S: string; L: TStrings);
var i, start: integer;
    t: string;
begin
   L.Clear;
   start := 1;
   for i := 1 to Length(S) do
      if S[i] = #10 then
      begin
         t := Copy(S, start, i - start);
         if (t <> '') and (t[Length(t)] = #13) then SetLength(t, Length(t) - 1);
         L.Add(t);
         start := i + 1;
      end;
   t := Copy(S, start, MaxInt);
   if (t <> '') and (t[Length(t)] = #13) then SetLength(t, Length(t) - 1);
   L.Add(t);
end;

{=============================================================================}
{  TLabel                                                                     }
{=============================================================================}

constructor TLabel.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FLines := TStringList.Create;
   FAutoSize := true;
   FShowAccelChar := true;
   FAlignment := taLeftJustify;
   FHeight := 1;
   FWidth := 1;
end;

destructor TLabel.Destroy;
begin
   FLines.Free;
   inherited Destroy;
end;

procedure TLabel.Notification(AComponent: TComponent; Operation: TOperation);
begin
   inherited Notification(AComponent, Operation);
   if (Operation = opRemove) and (AComponent = FFocusControl) then FFocusControl := nil;
end;

procedure TLabel.SetFocusControl(V: TWinControl);
begin
   if V = FFocusControl then exit;
   if FFocusControl <> nil then FFocusControl.RemoveFreeNotification(Self);
   FFocusControl := V;
   if V <> nil then V.FreeNotification(Self);
end;

procedure TLabel.SetAlignment(V: TAlignment);
begin
   if V = FAlignment then exit;
   FAlignment := V;
   Invalidate;
end;

procedure TLabel.SetAutoSize(V: boolean);
begin
   FAutoSize := V;
   if V then AdjustSize;
end;

procedure TLabel.AdjustSize;
var i, w, n: integer;
begin
   if not FAutoSize then exit;
   w := 0;
   for i := 0 to FLines.Count - 1 do
   begin
      if FShowAccelChar then n := Length(StripAccel(FLines[i]))
      else n := Length(FLines[i]);
      if n > w then w := n;
   end;
   n := FLines.Count;
   if n < 1 then n := 1;
   SetBounds(Left, Top, w, n);
end;

procedure TLabel.TextChanged;
begin
   SplitLines(Caption, FLines);
   AdjustSize;
end;

procedure TLabel.Paint;
var bg, fg, a, hot: byte;
    i, x, n: integer;
    s: string;
begin
   bg := BackColor;
   if IsEnabledAll then fg := TextColor(Theme.LabelFg) else fg := Theme.DisabledFg;
   a := MakeAttr(fg, bg);
   hot := MakeAttr(Theme.LabelHotFg, bg);
   if not IsEnabledAll then hot := a;
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   for i := 0 to FLines.Count - 1 do
   begin
      if i >= Height then break;
      s := FLines[i];
      if FShowAccelChar then n := Length(StripAccel(s)) else n := Length(s);
      case FAlignment of
         taRightJustify: x := Width - n;
         taCenter:       x := (Width - n) div 2;
      else
         x := 0;
      end;
      if FShowAccelChar then Canvas.TextOutAccel(x, i, s, a, hot)
      else Canvas.TextOut(x, i, s, a);
   end;
end;

function TLabel.HasAccel: boolean;
begin
   Result := FShowAccelChar and (FFocusControl <> nil);
end;

procedure TLabel.DoAccel;
begin
   if (FFocusControl <> nil) and FFocusControl.CanFocus then FFocusControl.SetFocus;
end;

{=============================================================================}
{  TButton                                                                    }
{=============================================================================}

constructor TButton.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FWidth := 12;
   if Theme.ButtonShadow then FHeight := 2 else FHeight := 1;
end;

procedure TButton.SetDefault(V: boolean);
begin
   if V = FDefault then exit;
   FDefault := V;
   Invalidate;
end;

procedure TButton.Paint;
var pbg, face, hot, sha, mark: byte;
    shadow, marks: boolean;
    faceW, off, x, n: integer;
    f: TCustomForm;
begin
   if Parent <> nil then pbg := Parent.BackColor else pbg := AttrBg(Theme.FormBody);
   if not IsEnabledAll then face := Theme.ButtonDisabled
   else if Focused then face := Theme.ButtonFocus
   else face := Theme.ButtonFace;
   if (Color >= 0) and (Color <= 15) then face := MakeAttr(AttrFg(face), Color);
   face := MakeAttr(TextColor(AttrFg(face)), AttrBg(face));
   if IsEnabledAll then hot := MakeAttr(AttrFg(Theme.ButtonHot), AttrBg(face))
   else hot := face;
   sha := MakeAttr(Theme.ButtonShadowFg, pbg);
   shadow := Theme.ButtonShadow and (Height >= 2) and (Width >= 3);
   faceW := Width;
   if shadow then dec(faceW);
   if FPressed and shadow then off := 1 else off := 0;
   { the background around the face }
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', MakeAttr(0, pbg));
   if shadow and not FPressed then
   begin
      Canvas.PutChar(faceW, 0, chHalfDown, sha);
      Canvas.HLine(1, faceW + 1, 1, chHalfUp, sha);
   end;
   Canvas.Fill(Rect(off, 0, off + faceW, 1), ' ', face);
   n := Length(StripAccel(Caption));
   x := off + (faceW - n) div 2;
   if x < off then x := off;
   Canvas.TextOutAccel(x, 0, Caption, face, hot);
   { the default button and the focused one show markers (as TV does) }
   marks := Focused;
   if not marks and FDefault then
   begin
      f := GetParentForm;
      marks := (f = nil) or (f.ActiveControl = nil) or not (f.ActiveControl is TButton);
   end;
   if marks and (faceW >= n + 2) then
   begin
      mark := MakeAttr(Theme.ButtonDefaultMarkFg, AttrBg(face));
      Canvas.PutChar(off, 0, chArrowRight, mark);
      Canvas.PutChar(off + faceW - 1, 0, chArrowLeft, mark);
   end;
end;

procedure TButton.Click;
var f: TCustomForm;
begin
   if FModalResult <> mrNone then
   begin
      f := GetParentForm;
      if f <> nil then f.ModalResult := FModalResult;
   end;
   inherited Click;
end;

procedure TButton.KeyDown(var Key: Word; Shift: TShiftState);
begin
   inherited KeyDown(Key, Shift);
   if (Key = VK_RETURN) or (Key = VK_SPACE) then
   begin
      Key := 0;
      Click;
   end;
end;

procedure TButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   inherited MouseDown(Button, Shift, X, Y);
   if Button = mbLeft then
   begin
      FPressed := true;
      Invalidate;
   end;
end;

procedure TButton.MouseMove(Shift: TShiftState; X, Y: integer);
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

procedure TButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   if FPressed then
   begin
      FPressed := false;
      Invalidate;
   end;
   inherited MouseUp(Button, Shift, X, Y);
end;

function TButton.HasAccel: boolean;
begin
   Result := true;
end;

procedure TButton.DoAccel;
begin
   if CanFocus then SetFocus;
   Click;
end;

function TButton.IsDefault: boolean;
begin
   Result := FDefault;
end;

function TButton.IsCancel: boolean;
begin
   Result := FCancel;
end;

{=============================================================================}
{  TEdit                                                                      }
{=============================================================================}

constructor TEdit.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FWidth := 20;
   FHeight := 1;
   FAutoSelect := true;
end;

procedure TEdit.Change;
begin
   if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TEdit.SetCaption(const V: string);
var s: string;
begin
   s := V;
   if (FMaxLength > 0) and (Length(s) > FMaxLength) then SetLength(s, FMaxLength);
   if s = Caption then exit;
   inherited SetCaption(s);
   FSelAll := false;
   FCaret := Length(s);
   ScrollIntoView;
   Change;
end;

function TEdit.EditWidth: integer;
begin
   Result := Width;
end;

procedure TEdit.ScrollIntoView;
var w: integer;
begin
   w := EditWidth;
   if w < 1 then w := 1;
   if FCaret < 0 then FCaret := 0;
   if FCaret > Length(Caption) then FCaret := Length(Caption);
   if FCaret < FFirst then FFirst := FCaret;
   if FCaret >= FFirst + w then FFirst := FCaret - w + 1;
   if FFirst < 0 then FFirst := 0;
end;

procedure TEdit.SetCaret(V: integer);
begin
   FCaret := V;
   FSelAll := false;
   ScrollIntoView;
   Invalidate;
end;

function TEdit.GetSelStart: integer;
begin
   if FSelAll then Result := 0 else Result := FCaret;
end;

function TEdit.GetSelLength: integer;
begin
   if FSelAll then Result := Length(Caption) else Result := 0;
end;

procedure TEdit.SelectAll;
begin
   FSelAll := Caption <> '';
   FCaret := Length(Caption);
   ScrollIntoView;
   Invalidate;
end;

procedure TEdit.Clear;
begin
   Text := '';
end;

procedure TEdit.CopyToClipboard;
begin
   if FSelAll and (FPasswordChar = #0) then Clipboard.AsText := Caption;
end;

procedure TEdit.CutToClipboard;
begin
   if not FSelAll or FReadOnly then exit;
   CopyToClipboard;
   DeleteSelection;
   Invalidate;
end;

procedure TEdit.PasteFromClipboard;
var t, s: string;
    i: integer;
begin
   if FReadOnly or not Clipboard.HasText then exit;
   { the first line, no control characters }
   t := Clipboard.AsText;
   i := Pos(#13, t); if i > 0 then SetLength(t, i - 1);
   i := Pos(#10, t); if i > 0 then SetLength(t, i - 1);
   for i := 1 to Length(t) do if t[i] < ' ' then t[i] := ' ';
   if FSelAll then
   begin
      FSelAll := false;
      FFirst := 0;
      FCaret := 0;
      inherited SetCaption('');
   end;
   s := Caption;
   if (FMaxLength > 0) and (Length(s) + Length(t) > FMaxLength) then
      SetLength(t, FMaxLength - Length(s));
   if t = '' then exit;
   Insert(t, s, FCaret + 1);
   inc(FCaret, Length(t));
   inherited SetCaption(s);
   ScrollIntoView;
   Change;
   Invalidate;
end;

procedure TEdit.DeleteSelection;
begin
   FSelAll := false;
   FFirst := 0;
   inherited SetCaption('');
   FCaret := 0;
   Change;
end;

procedure TEdit.Paint;
var a, sel: byte;
    s: string;
    i, n: integer;
begin
   if Focused then a := Theme.EditFocus else a := Theme.Edit;
   if (Color >= 0) and (Color <= 15) then a := MakeAttr(AttrFg(a), Color);
   if not IsEnabledAll then a := MakeAttr(Theme.DisabledFg, AttrBg(a))
   else a := MakeAttr(TextColor(AttrFg(a)), AttrBg(a));
   s := Copy(Caption, FFirst + 1, EditWidth);
   if FPasswordChar <> #0 then
      for i := 1 to Length(s) do s[i] := FPasswordChar;
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   if FSelAll and Focused then
   begin
      sel := Theme.EditSelect;
      Canvas.TextOut(0, 0, s, sel);
   end
   else
      Canvas.TextOut(0, 0, s, a);
   n := Length(Caption) - FFirst;
   if n < 0 then n := 0;
end;

procedure TEdit.KeyDown(var Key: Word; Shift: TShiftState);
var s: string;
    p: integer;
begin
   inherited KeyDown(Key, Shift);
   if Key = 0 then exit;
   s := Caption;
   case Key of
      VK_LEFT:
         begin
            if ssCtrl in Shift then
            begin
               p := FCaret;
               while (p > 0) and (s[p] = ' ') do dec(p);
               while (p > 0) and (s[p] <> ' ') do dec(p);
               SetCaret(p);
            end
            else SetCaret(FCaret - 1);
            Key := 0;
         end;
      VK_RIGHT:
         begin
            if ssCtrl in Shift then
            begin
               p := FCaret + 1;
               while (p <= Length(s)) and (s[p] <> ' ') do inc(p);
               while (p <= Length(s)) and (s[p] = ' ') do inc(p);
               SetCaret(p - 1);
            end
            else SetCaret(FCaret + 1);
            Key := 0;
         end;
      VK_HOME:
         begin
            SetCaret(0);
            Key := 0;
         end;
      VK_END:
         begin
            SetCaret(Length(s));
            Key := 0;
         end;
      VK_BACK:
         begin
            if not FReadOnly then
            begin
               if FSelAll then DeleteSelection
               else if FCaret > 0 then
               begin
                  Delete(s, FCaret, 1);
                  dec(FCaret);
                  inherited SetCaption(s);
                  if FFirst > 0 then dec(FFirst);
                  ScrollIntoView;
                  Change;
               end;
               Invalidate;
            end;
            Key := 0;
         end;
      VK_DELETE:
         if ssShift in Shift then begin CutToClipboard; Key := 0; end
         else
         begin
            if not FReadOnly then
            begin
               if FSelAll then DeleteSelection
               else if FCaret < Length(s) then
               begin
                  Delete(s, FCaret + 1, 1);
                  inherited SetCaption(s);
                  ScrollIntoView;
                  Change;
               end;
               Invalidate;
            end;
            Key := 0;
         end;
      VK_INSERT:
         if Shift = [] then
         begin
            TUIInsertMode := not TUIInsertMode;
            Key := 0;
         end
         else if Shift = [ssCtrl] then begin CopyToClipboard; Key := 0; end
         else if Shift = [ssShift] then begin PasteFromClipboard; Key := 0; end;
      VK_A:
         if ssCtrl in Shift then
         begin
            SelectAll;
            Key := 0;
         end;
      ord('C'):
         if Shift = [ssCtrl] then begin CopyToClipboard; Key := 0; end;
      ord('X'):
         if Shift = [ssCtrl] then begin CutToClipboard; Key := 0; end;
      ord('V'):
         if Shift = [ssCtrl] then begin PasteFromClipboard; Key := 0; end;
      ord('Y'):
         if (ssCtrl in Shift) and not FReadOnly then     { WordStar: clear }
         begin
            DeleteSelection;
            Invalidate;
            Key := 0;
         end;
   end;
end;

procedure TEdit.KeyPress(var Key: char);
var s: string;
begin
   inherited KeyPress(Key);
   if (Key < ' ') or FReadOnly then exit;
   if FSelAll then
   begin
      FSelAll := false;
      FFirst := 0;
      FCaret := 0;
      inherited SetCaption('');
   end;
   s := Caption;
   if TUIInsertMode or (FCaret >= Length(s)) then
   begin
      if (FMaxLength > 0) and (Length(s) >= FMaxLength) then
      begin
         HWBeep;
         Key := #0;
         exit;
      end;
      Insert(Key, s, FCaret + 1);
   end
   else
      s[FCaret + 1] := Key;
   inc(FCaret);
   inherited SetCaption(s);
   ScrollIntoView;
   Change;
   Invalidate;
   Key := #0;
end;

procedure TEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   inherited MouseDown(Button, Shift, X, Y);
   if Button = mbLeft then SetCaret(FFirst + X);
end;

procedure TEdit.DoEnter;
begin
   if FAutoSelect then FSelAll := Caption <> '';
   FCaret := Length(Caption);
   ScrollIntoView;
   inherited DoEnter;
end;

procedure TEdit.DoExit;
begin
   FSelAll := false;
   FFirst := 0;
   inherited DoExit;
end;

function TEdit.WantsChars: boolean;
begin
   Result := true;
end;

function TEdit.GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean;
begin
   X := FCaret - FFirst;
   Y := 0;
   if FSelAll then Shape := csHidden
   else if TUIInsertMode then Shape := csLine
   else Shape := csBlock;
   Result := true;
end;

{=============================================================================}
{  TCustomCheck, TCheckBox, TRadioButton                                     }
{=============================================================================}

constructor TCustomCheck.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FAutoSize := true;
   FHeight := 1;
   FWidth := 4;
end;

procedure TCustomCheck.SetChecked(V: boolean);
begin
   if V = FChecked then exit;
   FChecked := V;
   Invalidate;
   if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TCustomCheck.TextChanged;
begin
   if FAutoSize then Width := Length(StripAccel(Caption)) + 4;
end;

procedure TCustomCheck.Paint;
var bg, fg, a, hot: byte;
begin
   bg := BackColor;
   if not IsEnabledAll then fg := Theme.DisabledFg
   else if Focused then fg := Theme.CheckFocusFg
   else fg := TextColor(Theme.CheckFg);
   a := MakeAttr(fg, bg);
   if IsEnabledAll then hot := MakeAttr(Theme.CheckHotFg, bg) else hot := a;
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   Canvas.TextOut(0, 0, BoxText, a);
   Canvas.TextOutAccel(4, 0, Caption, a, hot);
end;

procedure TCustomCheck.KeyDown(var Key: Word; Shift: TShiftState);
begin
   inherited KeyDown(Key, Shift);
   if Key = VK_SPACE then
   begin
      Key := 0;
      Click;
   end;
end;

function TCustomCheck.HasAccel: boolean;
begin
   Result := true;
end;

procedure TCustomCheck.DoAccel;
begin
   if CanFocus then SetFocus;
   Click;
end;

function TCustomCheck.GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean;
begin
   X := 1;
   Y := 0;
   Shape := csLine;
   Result := true;
end;

procedure TCustomCheck.ActionChange(A: TAction);
begin
   inherited ActionChange(A);
   Checked := A.Checked;
end;

function TCheckBox.BoxText: string;
begin
   if Checked then Result := '[X]' else Result := '[ ]';
end;

procedure TCheckBox.Click;
begin
   Checked := not Checked;
   inherited Click;
end;

procedure TRadioButton.SetChecked(V: boolean);
var i: integer;
    c: TControl;
begin
   if V and (Parent <> nil) then
      for i := 0 to Parent.ControlCount - 1 do
      begin
         c := Parent.Controls[i];
         if (c <> Self) and (c is TRadioButton) then TRadioButton(c).Checked := false;
      end;
   inherited SetChecked(V);
end;

function TRadioButton.BoxText: string;
begin
   if Checked then Result := '(' + chBullet + ')' else Result := '( )';
end;

procedure TRadioButton.Click;
begin
   Checked := true;
   inherited Click;
end;

{=============================================================================}
{  TGroupBox, TPanel                                                          }
{=============================================================================}

constructor TGroupBox.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   TabStop := false;
   FWidth := 20;
   FHeight := 6;
end;

procedure TGroupBox.Paint;
var bg: byte;
    s: string;
begin
   bg := BackColor;
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', MakeAttr(0, bg));
   Canvas.Frame(Rect(0, 0, Width, Height), 1, MakeAttr(Theme.GroupFrameFg, bg));
   if Caption <> '' then
   begin
      s := ' ' + Caption + ' ';
      Canvas.TextOutAccel(1, 0, s, MakeAttr(TextColor(Theme.GroupTitleFg), bg),
                          MakeAttr(Theme.LabelHotFg, bg));
   end;
end;

function TGroupBox.ClientOffset: TPoint;
begin
   Result := Point(1, 1);
end;

function TGroupBox.ClientWidthValue: integer;
begin
   Result := Width - 2;
   if Result < 0 then Result := 0;
end;

function TGroupBox.ClientHeightValue: integer;
begin
   Result := Height - 2;
   if Result < 0 then Result := 0;
end;

constructor TPanel.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   TabStop := false;
   FAlignment := taCenter;
   FWidth := 20;
   FHeight := 5;
end;

procedure TPanel.SetBorder(V: TPanelBorder);
begin
   if V = FBorder then exit;
   FBorder := V;
   Invalidate;
end;

procedure TPanel.Paint;
var bg, a: byte;
    n, x: integer;
begin
   bg := BackColor;
   a := MakeAttr(TextColor(AttrFg(Theme.FormBody)), bg);
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   case FBorder of
      pbSingle: Canvas.Frame(Rect(0, 0, Width, Height), 1, a);
      pbDouble: Canvas.Frame(Rect(0, 0, Width, Height), 2, a);
   end;
   if (Caption <> '') and (ControlCount = 0) then
   begin
      n := Length(Caption);
      case FAlignment of
         taLeftJustify:  x := ClientOffset.X;
         taRightJustify: x := Width - ClientOffset.X - n;
      else
         x := (Width - n) div 2;
      end;
      Canvas.TextOut(x, Height div 2, Caption, a);
   end;
end;

function TPanel.ClientOffset: TPoint;
begin
   if FBorder = pbNone then Result := Point(0, 0) else Result := Point(1, 1);
end;

function TPanel.ClientWidthValue: integer;
begin
   Result := Width - 2 * ClientOffset.X;
end;

function TPanel.ClientHeightValue: integer;
begin
   Result := Height - 2 * ClientOffset.Y;
end;

{=============================================================================}
{  dialogs                                                                    }
{=============================================================================}

const
   BtnCaption: array[TMsgDlgBtn] of string = ('&Yes', '&No', 'OK', 'Cancel',
      '&Abort', '&Retry', '&Ignore', '&All', 'N&o to all', 'Yes to a&ll',
      '&Help', '&Close');
   BtnResult: array[TMsgDlgBtn] of TModalResult = (mrYes, mrNo, mrOk, mrCancel,
      mrAbort, mrRetry, mrIgnore, mrAll, mrNoToAll, mrYesToAll, mrNone, mrClose);
   DlgCaption: array[TMsgDlgType] of string = ('Warning', 'Error',
      'Information', 'Confirm', '');

function MessageDlg(const ACaption, Msg: string; DlgType: TMsgDlgType;
                    Buttons: TMsgDlgButtons; HelpCtx: longint): TModalResult;
var f: TForm;
    lbl: TLabel;
    b: TMsgDlgBtn;
    btn: TButton;
    widths: array[TMsgDlgBtn] of integer;
    total, w, h, x, n, gap: integer;
    first: boolean;
    cancelBtn: TButton;
begin
   if Buttons = [] then Buttons := [mbOK];
   f := TForm.CreateNew(nil);
   try
      f.BorderStyle := bsDialog;
      f.Position := poScreenCenter;
      if ACaption <> '' then f.Caption := ACaption
      else if Application.Title <> '' then f.Caption := Application.Title
      else f.Caption := DlgCaption[DlgType];
      lbl := TLabel.Create(f);
      lbl.Parent := f;
      lbl.Caption := Msg;
      lbl.ShowAccelChar := false;
      lbl.AutoSize := true;
      { the buttons' row }
      gap := 2;
      total := 0;
      n := 0;
      for b := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
         if b in Buttons then
         begin
            widths[b] := Length(StripAccel(BtnCaption[b])) + 6;
            if widths[b] < 10 then widths[b] := 10;
            inc(total, widths[b]);
            inc(n);
         end;
      inc(total, gap * (n - 1));
      w := lbl.Width + 6;
      if total + 6 > w then w := total + 6;
      if w < 30 then w := 30;
      if w > ScrCols - 2 then w := ScrCols - 2;
      h := lbl.Height + 6;
      if not Theme.ButtonShadow then dec(h);
      if h > ScrRows - 1 then h := ScrRows - 1;
      f.SetBounds(0, 0, w, h);
      lbl.Left := (f.ClientWidth - lbl.Width) div 2;
      lbl.Top := 1;
      x := (f.ClientWidth - total) div 2;
      first := true;
      cancelBtn := nil;
      for b := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
         if b in Buttons then
         begin
            btn := TButton.Create(f);
            btn.Parent := f;
            btn.Caption := BtnCaption[b];
            if Theme.ButtonShadow then
               btn.SetBounds(x, lbl.Top + lbl.Height + 1, widths[b], 2)
            else
               btn.SetBounds(x, lbl.Top + lbl.Height + 1, widths[b], 1);
            btn.ModalResult := BtnResult[b];
            if first then btn.Default := true;
            first := false;
            if b in [mbCancel, mbClose] then cancelBtn := btn;
            inc(x, widths[b] + gap);
         end;
      if cancelBtn = nil then
         for n := f.ControlCount - 1 downto 0 do
            if (f.Controls[n] is TButton) and
               (TButton(f.Controls[n]).ModalResult in [mrNo, mrOk]) then
            begin
               cancelBtn := TButton(f.Controls[n]);
               break;
            end;
      if cancelBtn <> nil then cancelBtn.Cancel := true;
      Result := f.ShowModal;
   finally
      f.Free;
   end;
   if HelpCtx = 0 then;
end;

function MessageDlg(const Msg: string; DlgType: TMsgDlgType;
                    Buttons: TMsgDlgButtons; HelpCtx: longint): TModalResult;
begin
   Result := MessageDlg('', Msg, DlgType, Buttons, HelpCtx);
end;

procedure ShowMessage(const Msg: string);
begin
   MessageDlg('', Msg, mtInformation, [mbOK], 0);
end;

function InputQuery(const ACaption, APrompt: string; var Value: string): boolean;
var f: TForm;
    lbl: TLabel;
    ed: TEdit;
    ok, cancel: TButton;
    w, bh: integer;
begin
   f := TForm.CreateNew(nil);
   try
      f.BorderStyle := bsDialog;
      f.Position := poScreenCenter;
      f.Caption := ACaption;
      if Theme.ButtonShadow then bh := 2 else bh := 1;
      w := Length(APrompt) + 6;
      if w < 44 then w := 44;
      if w > ScrCols - 2 then w := ScrCols - 2;
      f.SetBounds(0, 0, w, 7 + bh);
      lbl := TLabel.Create(f);
      lbl.Parent := f;
      lbl.Caption := APrompt;
      lbl.SetBounds(2, 1, Length(StripAccel(APrompt)), 1);
      ed := TEdit.Create(f);
      ed.Parent := f;
      ed.SetBounds(2, 2, f.ClientWidth - 4, 1);
      ed.Text := Value;
      lbl.FocusControl := ed;
      ok := TButton.Create(f);
      ok.Parent := f;
      ok.Caption := 'OK';
      ok.Default := true;
      ok.ModalResult := mrOk;
      ok.SetBounds(f.ClientWidth div 2 - 13, 4, 12, bh);
      cancel := TButton.Create(f);
      cancel.Parent := f;
      cancel.Caption := 'Cancel';
      cancel.Cancel := true;
      cancel.ModalResult := mrCancel;
      cancel.SetBounds(f.ClientWidth div 2 + 1, 4, 12, bh);
      f.ActiveControl := ed;
      Result := f.ShowModal = mrOk;
      if Result then Value := ed.Text;
   finally
      f.Free;
   end;
end;

function InputBox(const ACaption, APrompt, ADefault: string): string;
begin
   Result := ADefault;
   InputQuery(ACaption, APrompt, Result);
end;

procedure ShowExceptionBox(E: Exception);
begin
   MessageDlg('Error', E.Message, mtError, [mbOK], 0);
end;

initialization
   RegisterClasses([TLabel, TButton, TEdit, TCheckBox, TRadioButton, TGroupBox, TPanel]);
   TUIShowExceptionProc := @ShowExceptionBox;

end.
