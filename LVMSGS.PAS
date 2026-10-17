{-----------------------------------------------------------------------------}
{  LVMSGS - the compiler's messages: reading fpc's output, and the Messages   }
{  window. Enter or a double click on a message with a place (file, line,     }
{  column) goes there; Alt+F8 / Alt+F7 (Compile menu) take the next / the     }
{  previous one.                                                             }
{                                                                             }
{  fpc writes   C:\WORK\HELLO.PAS(5,11) Error: Identifier not found "x"       }
{               hello.pas(12) Warning: ...      Fatal: Compilation aborted    }
{-----------------------------------------------------------------------------}
unit LVMsgs;

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, TUICtrl, TUIStd, TUIList;

type
   TLVMsgKind = (mkInfo, mkHint, mkNote, mkWarning, mkError, mkFatal);

   TLVMessage = class
   public
      Kind: TLVMsgKind;
      FileName: string;            { '' when the message has no place }
      Line, Col: integer;
      Text: string;                { what follows "Error: " }
      Raw: string;                 { the line as fpc wrote it }
      function HasPlace: boolean;
      function Display: string;
   end;

   TLVGotoEvent = procedure(Sender: TObject; Msg: TLVMessage) of object;

   TMessagesForm = class(TForm)
   private
      FList: TListBox;
      FMessages: TList;
      FOnGoto: TLVGotoEvent;
      procedure ListDblClick(Sender: TObject);
      procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
   public
      Errors, Warnings, Notes, Hints: integer;
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Clear;
      { fpc's output, line by line }
      procedure LoadOutput(Lines: TStrings);
      procedure AddText(const S: string);
      function  Count: integer;
      function  Messages(I: integer): TLVMessage;
      { the selected message (nil: none) }
      function  Current: TLVMessage;
      { the next / previous message with a place, from the selected one; it }
      { becomes the selected one; nil: none                                }
      function  NextPlace(Backward: boolean): TLVMessage;
      function  FirstError: TLVMessage;
      procedure Select(M: TLVMessage);
      procedure GotoCurrent;
      property List: TListBox read FList;
      property OnGoto: TLVGotoEvent read FOnGoto write FOnGoto;
   end;

{ one line of fpc's output; false: not a message (nil) }
function ParseMessage(const S: string): TLVMessage;

implementation

const
   KindWords: array[TLVMsgKind] of string = ('Info', 'Hint', 'Note', 'Warning', 'Error', 'Fatal');

function TLVMessage.HasPlace: boolean;
begin
   Result := (FileName <> '') and (Line > 0);
end;

function TLVMessage.Display: string;
begin
   if HasPlace then
      Result := Format('%-8s %s(%d,%d): %s', [KindWords[Kind], ExtractFileName(FileName), Line, Col, Text])
   else if Kind = mkInfo then Result := Raw
   else Result := Format('%-8s %s', [KindWords[Kind], Text]);
end;

function ParseMessage(const S: string): TLVMessage;
var k: TLVMsgKind;
    p, q, i: integer;
    w, place, nums: string;
    found: boolean;
begin
   Result := TLVMessage.Create;
   Result.Raw := S;
   Result.Kind := mkInfo;
   Result.Text := S;
   Result.Line := 0;
   Result.Col := 0;
   if Trim(S) = '' then
   begin
      FreeAndNil(Result);
      exit;
   end;
   { "... Kind: text": the kind word after a ") " or at the start }
   found := false;
   for k := mkHint to mkFatal do
   begin
      w := KindWords[k] + ': ';
      p := Pos(w, S);
      if (p = 1) or ((p > 2) and (S[p - 1] = ' ') and (S[p - 2] = ')')) then
      begin
         Result.Kind := k;
         Result.Text := Copy(S, p + Length(w), MaxInt);
         place := Trim(Copy(S, 1, p - 1));
         found := true;
         break;
      end;
   end;
   if not found then exit;
   { the place: name(line,col) or name(line) }
   if (place <> '') and (place[Length(place)] = ')') then
   begin
      q := Length(place);
      p := q;
      while (p > 1) and (place[p] <> '(') do dec(p);
      if place[p] = '(' then
      begin
         nums := Copy(place, p + 1, q - p - 1);
         i := Pos(',', nums);
         if i > 0 then
         begin
            Result.Line := StrToIntDef(Copy(nums, 1, i - 1), 0);
            Result.Col := StrToIntDef(Copy(nums, i + 1, MaxInt), 0);
         end
         else Result.Line := StrToIntDef(nums, 0);
         if Result.Line > 0 then Result.FileName := Copy(place, 1, p - 1);
      end;
   end;
end;

{ ------------------------------------------------------------- the window }

constructor TMessagesForm.Create(AOwner: TComponent);
var d: TRect;
begin
   CreateNew(AOwner);
   Caption := 'Compiler messages';
   d := Application.DesktopRect;
   SetBounds(d.Left, d.Bottom - 8, d.Right - d.Left, 8);
   Constraints.MinHeight := 4;
   Constraints.MinWidth := 30;
   FMessages := TList.Create;
   FList := TListBox.Create(Self);
   FList.Parent := Self;
   FList.Align := alClient;
   FList.OnDblClick := @ListDblClick;
   FList.OnKeyDown := @ListKeyDown;
   ActiveControl := FList;
end;

destructor TMessagesForm.Destroy;
begin
   Clear;
   FMessages.Free;
   inherited Destroy;
end;

procedure TMessagesForm.Clear;
var i: integer;
begin
   for i := 0 to FMessages.Count - 1 do TLVMessage(FMessages[i]).Free;
   FMessages.Clear;
   if FList <> nil then FList.Items.Clear;
   Errors := 0; Warnings := 0; Notes := 0; Hints := 0;
end;

procedure TMessagesForm.AddText(const S: string);
var m: TLVMessage;
begin
   m := TLVMessage.Create;
   m.Kind := mkInfo;
   m.Raw := S;
   m.Text := S;
   FMessages.Add(m);
   FList.Items.Add(S);
end;

procedure TMessagesForm.LoadOutput(Lines: TStrings);
var i, fatals: integer;
    m: TLVMessage;
begin
   fatals := 0;
   FList.Items.BeginUpdate;
   try
      for i := 0 to Lines.Count - 1 do
      begin
         m := ParseMessage(Lines[i]);
         if m = nil then continue;
         case m.Kind of
            mkError: inc(Errors);
            mkFatal: inc(fatals);
            mkWarning: inc(Warnings);
            mkNote: inc(Notes);
            mkHint: inc(Hints);
         end;
         FMessages.Add(m);
         FList.Items.Add(m.Display);
      end;
   finally
      FList.Items.EndUpdate;
   end;
   { "Fatal: There were 2 errors" repeats the errors; alone it is one }
   if Errors = 0 then Errors := fatals;
end;

function TMessagesForm.Count: integer;
begin
   Result := FMessages.Count;
end;

function TMessagesForm.Messages(I: integer): TLVMessage;
begin
   Result := TLVMessage(FMessages[I]);
end;

function TMessagesForm.Current: TLVMessage;
begin
   if (FList.ItemIndex >= 0) and (FList.ItemIndex < FMessages.Count) then
      Result := TLVMessage(FMessages[FList.ItemIndex])
   else Result := nil;
end;

procedure TMessagesForm.Select(M: TLVMessage);
begin
   FList.ItemIndex := FMessages.IndexOf(M);
end;

function TMessagesForm.NextPlace(Backward: boolean): TLVMessage;
var i: integer;
begin
   Result := nil;
   i := FList.ItemIndex;
   repeat
      if Backward then dec(i) else inc(i);
      if (i < 0) or (i >= FMessages.Count) then exit;
   until TLVMessage(FMessages[i]).HasPlace;
   FList.ItemIndex := i;
   Result := TLVMessage(FMessages[i]);
end;

function TMessagesForm.FirstError: TLVMessage;
var i: integer;
begin
   Result := nil;
   for i := 0 to FMessages.Count - 1 do
      with TLVMessage(FMessages[i]) do
         if HasPlace and (Kind in [mkError, mkFatal]) then
         begin
            Result := TLVMessage(FMessages[i]);
            FList.ItemIndex := i;
            exit;
         end;
end;

procedure TMessagesForm.GotoCurrent;
var m: TLVMessage;
begin
   m := Current;
   if (m <> nil) and m.HasPlace and Assigned(FOnGoto) then FOnGoto(Self, m);
end;

procedure TMessagesForm.ListDblClick(Sender: TObject);
begin
   GotoCurrent;
end;

procedure TMessagesForm.ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
   if (Key = VK_RETURN) and (Shift = []) then
   begin
      GotoCurrent;
      Key := 0;
   end;
end;

end.
