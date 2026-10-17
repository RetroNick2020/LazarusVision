{-----------------------------------------------------------------------------}
{  TUISYN - syntax highlighters for code editors (stage 1 of the editor).     }
{                                                                             }
{  Names follow Lazarus's SynEdit:                                            }
{     TSynCustomHighlighter   the base: scans one line into tokens            }
{     TSynPasSyn              Pascal (TP / FPC objfpc / Delphi)               }
{     TSynQBasicSyn           QBasic / QuickBASIC 4.5                         }
{     TSynAnySyn              table driven: keywords, comment markers and     }
{                             string quotes as properties (asm, batch, C...)  }
{     TSynLineStates          the start state of every line of a TStrings,    }
{                             kept up to date with as little scanning as      }
{                             possible                                        }
{                                                                             }
{  How a highlighter is used (TSynEdit, stage 2, does this for the lines it   }
{  shows):                                                                    }
{     HL.SetLine(LineText, StartState);                                       }
{     while not HL.GetEol do                                                  }
{     begin                                                                   }
{        draw Copy(LineText, HL.TokenStart, HL.TokenLength) in               }
{             HL.TokenAttri.Foreground;                                      }
{        HL.Next;                                                             }
{     end;                                                                    }
{     NextLineState := HL.EndState;                                           }
{                                                                             }
{  A state is what a line hands on to the next one: inside a brace comment, }
{  inside an asm block and so on. Every line starts in the state the line    }
{  before ended in; the first line in 0.                                     }
{-----------------------------------------------------------------------------}
unit TUISyn;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, TUICtrl;

type
   TTokenKind = (tkNull, tkSpace, tkIdentifier, tkKeyword, tkNumber, tkString,
                 tkComment, tkDirective, tkSymbol, tkAsm, tkLabel);

   { the colours of one kind of token; clDefault = the editor's colour }
   THighlightAttr = class(TPersistent)
   private
      FName: string;
      FForeground, FBackground: TColor;
      FOnChange: TNotifyEvent;
      procedure SetForeground(V: TColor);
      procedure SetBackground(V: TColor);
   public
      constructor Create(const AName: string; AForeground: TColor);
      procedure Assign(Source: TPersistent); override;
      property Name: string read FName;
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
   published
      property Foreground: TColor read FForeground write SetForeground default clDefault;
      property Background: TColor read FBackground write SetBackground default clDefault;
   end;

   TSynCustomHighlighter = class(TComponent)
   private
      FAttrs: array[TTokenKind] of THighlightAttr;
      FOnChange: TNotifyEvent;
      FHooks: array of TNotifyEvent;
      procedure AttrChanged(Sender: TObject);
      function  GetAttr(Index: integer): THighlightAttr;
      procedure SetAttr(Index: integer; V: THighlightAttr);
   protected
      FLine: string;
      FLen, FRun, FTokStart: integer;      { 1 based }
      FKind: TTokenKind;
      FState: integer;                     { while scanning: the current state }
      { scan the token at FRun: set FTokStart, FKind, move FRun past it }
      procedure ScanToken; virtual; abstract;
      procedure SetDefaultColors; virtual;
      procedure Changed;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      { start a line in State and find its first token }
      procedure SetLine(const S: string; State: integer);
      function  GetEol: boolean;
      procedure Next;
      function  TokenKind: TTokenKind;
      function  TokenStart: integer;       { 1 based, in the line }
      function  TokenLength: integer;
      function  GetToken: string;
      function  TokenAttri: THighlightAttr;
      { the state after the last token (call at the end of the line) }
      function  EndState: integer;
      { scan a whole line: the state it hands on }
      function  LineEndState(const S: string; State: integer): integer;
      function  AttriFor(Kind: TTokenKind): THighlightAttr;
      function  LanguageName: string; virtual;
      { for file dialogs: 'Pascal files|*.pas;*.pp;*.inc' }
      function  DefaultFilter: string; virtual;
      { a keyword of this language (case as the language wants) }
      function  IsKeyword(const S: string): boolean; virtual;
      { editors that use this highlighter are told about changes (colours) }
      procedure HookChange(Event: TNotifyEvent);
      procedure UnhookChange(Event: TNotifyEvent);
      { any attribute changed: editors repaint }
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
   published
      property SpaceAttri: THighlightAttr index ord(tkSpace) read GetAttr write SetAttr;
      property IdentifierAttri: THighlightAttr index ord(tkIdentifier) read GetAttr write SetAttr;
      property KeywordAttri: THighlightAttr index ord(tkKeyword) read GetAttr write SetAttr;
      property NumberAttri: THighlightAttr index ord(tkNumber) read GetAttr write SetAttr;
      property StringAttri: THighlightAttr index ord(tkString) read GetAttr write SetAttr;
      property CommentAttri: THighlightAttr index ord(tkComment) read GetAttr write SetAttr;
      property DirectiveAttri: THighlightAttr index ord(tkDirective) read GetAttr write SetAttr;
      property SymbolAttri: THighlightAttr index ord(tkSymbol) read GetAttr write SetAttr;
      property AsmAttri: THighlightAttr index ord(tkAsm) read GetAttr write SetAttr;
      property LabelAttri: THighlightAttr index ord(tkLabel) read GetAttr write SetAttr;
   end;

   TSynHighlighterClass = class of TSynCustomHighlighter;

   { ------------------------------------------------------------------ Pascal }
   { states: 0 code, 1 in a brace comment, 2 in a paren-star comment, 3 in a }
   { compiler directive; +4 inside an asm block                              }
   TSynPasSyn = class(TSynCustomHighlighter)
   private
      FAsmBlocks: boolean;
      procedure ScanBraceComment;
      procedure ScanParenComment;
   protected
      procedure ScanToken; override;
   public
      constructor Create(AOwner: TComponent); override;
      function  LanguageName: string; override;
      function  DefaultFilter: string; override;
      function  IsKeyword(const S: string): boolean; override;
   published
      { asm ... end in AsmAttri (else as ordinary code) }
      property AsmBlocks: boolean read FAsmBlocks write FAsmBlocks default true;
   end;

   { ------------------------------------------------------------------ QBasic }
   { no state crosses lines; line numbers and labels at the line start are   }
   { tkLabel; '$INCLUDE: and REM $DYNAMIC are tkDirective                     }
   TSynQBasicSyn = class(TSynCustomHighlighter)
   private
      FFirst: boolean;                     { no token yet on this line }
   protected
      procedure ScanToken; override;
   public
      function  LanguageName: string; override;
      function  DefaultFilter: string; override;
      function  IsKeyword(const S: string): boolean; override;
   end;

   { ------------------------------------------------------------ table driven }
   { state 1: inside a block comment                                          }
   TSynAnySyn = class(TSynCustomHighlighter)
   private
      FKeywords: TStringList;
      FLineComments: TStringList;
      FBlockStart, FBlockEnd: string;
      FQuotes: string;
      FDirectiveChar: char;
      FCaseSensitive: boolean;
      FLanguage, FFilter: string;
      procedure SetKeywords(V: TStrings);
      function  GetKeywords: TStrings;
      procedure SetLineComments(V: TStrings);
      function  GetLineComments: TStrings;
      function  At(const S: string): boolean;
   protected
      procedure ScanToken; override;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      function  LanguageName: string; override;
      function  DefaultFilter: string; override;
      function  IsKeyword(const S: string): boolean; override;
   published
      property Keywords: TStrings read GetKeywords write SetKeywords;
      { what starts a comment to the end of the line: ';', '//', 'REM ' }
      property LineComments: TStrings read GetLineComments write SetLineComments;
      property BlockCommentStart: string read FBlockStart write FBlockStart;
      property BlockCommentEnd: string read FBlockEnd write FBlockEnd;
      { the characters that start and end a string: '"''' }
      property Quotes: string read FQuotes write FQuotes;
      { a line starting with this character is a directive ('#' for C) }
      property DirectiveChar: char read FDirectiveChar write FDirectiveChar default #0;
      property CaseSensitive: boolean read FCaseSensitive write FCaseSensitive default false;
      property Language: string read FLanguage write FLanguage;
      property Filter: string read FFilter write FFilter;
   end;

   { ------------------------------------------------------------ line states }
   { The start state of each line of Lines. After an edit tell it which line  }
   { changed (or which lines came or went); StartState scans forward only as  }
   { far as it must: when a re-scanned line ends in the state the next line   }
   { already had, everything after it is still right.                        }
   TSynLineStates = class
   private
      FHighlighter: TSynCustomHighlighter;
      FLines: TStrings;
      FStates: array of integer;           { the start state of each line }
      FValid: integer;                     { lines 0..FValid-1 are right }
      FKnown: integer;                     { lines 0..FKnown-1 were scanned once }
      FScanned: longint;
      procedure Grow(N: integer);
      procedure SetHighlighter(V: TSynCustomHighlighter);
   public
      constructor Create(ALines: TStrings; AHighlighter: TSynCustomHighlighter);
      function  StartState(Line: integer): integer;
      { a line's text changed }
      procedure LineChanged(Line: integer);
      { Count lines were inserted before / deleted from Line }
      procedure LinesInserted(Line, Count: integer);
      procedure LinesDeleted(Line, Count: integer);
      { forget everything (new text, new highlighter) }
      procedure Reset;
      property Lines: TStrings read FLines write FLines;
      property Highlighter: TSynCustomHighlighter read FHighlighter write SetHighlighter;
      { lines scanned so far (tests, speed checks) }
      property Scanned: longint read FScanned write FScanned;
   end;

const
   TokenKindNames: array[TTokenKind] of string = ('null', 'space', 'ident', 'key',
      'num', 'str', 'comment', 'dir', 'sym', 'asm', 'label');

{ the highlighter for a file name by its extension (nil: plain text) }
function HighlighterClassForFile(const FileName: string): TSynHighlighterClass;

implementation

{=============================================================================}
{  keyword tables: sorted upper case, binary search without allocations       }
{=============================================================================}

const
   PasKeywords: array[0..93] of string = (
      'ABSOLUTE', 'ABSTRACT', 'AND', 'ARRAY', 'AS', 'ASM', 'ASSEMBLER', 'BEGIN',
      'CASE', 'CDECL', 'CLASS', 'CONST', 'CONSTRUCTOR', 'DEPRECATED', 'DESTRUCTOR',
      'DISPINTERFACE', 'DIV', 'DO', 'DOWNTO', 'DYNAMIC', 'ELSE', 'END', 'EXCEPT',
      'EXPERIMENTAL', 'EXPORT', 'EXPORTS', 'EXTERNAL', 'FAR', 'FILE', 'FINALIZATION',
      'FINALLY', 'FOR', 'FORWARD', 'FUNCTION', 'GENERIC', 'GOTO', 'IF',
      'IMPLEMENTATION', 'IN', 'INHERITED', 'INITIALIZATION', 'INLINE', 'INTERFACE',
      'INTERRUPT', 'IS', 'LABEL', 'LIBRARY', 'MOD', 'NEAR', 'NIL', 'NOT', 'OBJECT',
      'OF', 'ON', 'OPERATOR', 'OR', 'OUT', 'OVERLOAD', 'OVERRIDE', 'PACKED',
      'PLATFORM', 'PRIVATE', 'PROCEDURE', 'PROGRAM', 'PROPERTY', 'PROTECTED', 'PUBLIC',
      'PUBLISHED', 'RAISE', 'RECORD', 'REINTRODUCE', 'REPEAT', 'RESOURCESTRING', 'SET',
      'SHL', 'SHR', 'SPECIALIZE', 'STATIC', 'STDCALL', 'STRICT', 'STRING', 'THEN',
      'THREADVAR', 'TO', 'TRY', 'TYPE', 'UNIT', 'UNTIL', 'USES', 'VAR', 'VIRTUAL',
      'WHILE', 'WITH', 'XOR');

   QBKeywords: array[0..221] of string = (
      'ABS', 'ABSOLUTE', 'ACCESS', 'ALIAS', 'AND', 'ANY', 'APPEND', 'AS', 'ASC', 'ATN',
      'BASE', 'BEEP', 'BINARY', 'BLOAD', 'BSAVE', 'BYVAL', 'CALL', 'CALLS', 'CASE',
      'CDBL', 'CDECL', 'CHAIN', 'CHDIR', 'CHR$', 'CINT', 'CIRCLE', 'CLEAR', 'CLNG',
      'CLOSE', 'CLS', 'COLOR', 'COM', 'COMMAND$', 'COMMON', 'CONST', 'COS', 'CSNG',
      'CSRLIN', 'CVD', 'CVDMBF', 'CVI', 'CVL', 'CVS', 'CVSMBF', 'DATA', 'DATE$',
      'DECLARE', 'DEF', 'DEFDBL', 'DEFINT', 'DEFLNG', 'DEFSNG', 'DEFSTR', 'DIM', 'DO',
      'DOUBLE', 'DRAW', 'ELSE', 'ELSEIF', 'END', 'ENVIRON', 'ENVIRON$', 'EOF', 'EQV',
      'ERASE', 'ERDEV', 'ERDEV$', 'ERL', 'ERR', 'ERROR', 'EXIT', 'EXP', 'FIELD',
      'FILEATTR', 'FILES', 'FIX', 'FOR', 'FRE', 'FREEFILE', 'FUNCTION', 'GET', 'GOSUB',
      'GOTO', 'HEX$', 'IF', 'IMP', 'INKEY$', 'INP', 'INPUT', 'INPUT$', 'INSTR', 'INT',
      'INTEGER', 'INTERRUPT', 'INTERRUPTX', 'IOCTL', 'IOCTL$', 'IS', 'KEY', 'KILL',
      'LBOUND', 'LCASE$', 'LEFT$', 'LEN', 'LET', 'LINE', 'LIST', 'LOC', 'LOCATE',
      'LOCK', 'LOF', 'LOG', 'LONG', 'LOOP', 'LPOS', 'LPRINT', 'LSET', 'LTRIM$', 'MID$',
      'MKD$', 'MKDIR', 'MKDMBF$', 'MKI$', 'MKL$', 'MKS$', 'MKSMBF$', 'MOD', 'NAME',
      'NEXT', 'NOT', 'OCT$', 'OFF', 'ON', 'OPEN', 'OPTION', 'OR', 'OUT', 'OUTPUT',
      'PAINT', 'PALETTE', 'PCOPY', 'PEEK', 'PEN', 'PLAY', 'PMAP', 'POINT', 'POKE',
      'POS', 'PRESET', 'PRINT', 'PSET', 'PUT', 'RANDOM', 'RANDOMIZE', 'READ', 'REDIM',
      'REM', 'RESET', 'RESTORE', 'RESUME', 'RETURN', 'RIGHT$', 'RMDIR', 'RND', 'RSET',
      'RTRIM$', 'RUN', 'SADD', 'SCREEN', 'SEEK', 'SEG', 'SELECT', 'SETMEM', 'SGN',
      'SHARED', 'SHELL', 'SIGNAL', 'SIN', 'SINGLE', 'SLEEP', 'SOUND', 'SPACE$', 'SPC',
      'SQR', 'STATIC', 'STEP', 'STICK', 'STOP', 'STR$', 'STRIG', 'STRING', 'STRING$',
      'SUB', 'SWAP', 'SYSTEM', 'TAB', 'TAN', 'THEN', 'TIME$', 'TIMER', 'TO', 'TROFF',
      'TRON', 'TYPE', 'UBOUND', 'UCASE$', 'UEVENT', 'UNLOCK', 'UNTIL', 'USING', 'VAL',
      'VARPTR', 'VARPTR$', 'VARSEG', 'VIEW', 'WAIT', 'WEND', 'WHILE', 'WIDTH',
      'WINDOW', 'WRITE', 'XOR');

type
   TKeywordTable = class
      Words: array of string;
      procedure AddAll(const A: array of string);
      procedure Sort;
      { the text S[P .. P+N-1], upper cased while comparing }
      function  Has(const S: string; P, N: integer): boolean;
   end;

var
   PasTable, QBTable: TKeywordTable;

procedure TKeywordTable.AddAll(const A: array of string);
var i, n: integer;
begin
   for i := 0 to High(A) do
   begin
      n := Length(Words);
      SetLength(Words, n + 1);
      Words[n] := UpperCase(A[i]);
   end;
end;

procedure TKeywordTable.Sort;
var i, j: integer;
    t: string;
    w: array of string;
begin
   { insertion sort, then drop doubles }
   for i := 1 to High(Words) do
   begin
      t := Words[i];
      j := i;
      while (j > 0) and (Words[j - 1] > t) do
      begin
         Words[j] := Words[j - 1];
         dec(j);
      end;
      Words[j] := t;
   end;
   SetLength(w, 0);
   for i := 0 to High(Words) do
      if (i = 0) or (Words[i] <> Words[i - 1]) then
      begin
         SetLength(w, Length(w) + 1);
         w[High(w)] := Words[i];
      end;
   Words := w;
end;

function TKeywordTable.Has(const S: string; P, N: integer): boolean;
var lo, hi, mid, i, c: integer;
    w: string;
    a, b: char;
begin
   lo := 0;
   hi := High(Words);
   while lo <= hi do
   begin
      mid := (lo + hi) div 2;
      w := Words[mid];
      c := 0;
      i := 1;
      while (c = 0) and (i <= N) and (i <= Length(w)) do
      begin
         a := UpCase(S[P + i - 1]);
         b := w[i];
         if a < b then c := -1 else if a > b then c := 1;
         inc(i);
      end;
      if c = 0 then
         if N < Length(w) then c := -1
         else if N > Length(w) then c := 1;
      if c = 0 then exit(true);
      if c < 0 then hi := mid - 1 else lo := mid + 1;
   end;
   Result := false;
end;

function IsIdentStart(C: char): boolean; inline;
begin
   Result := C in ['A'..'Z', 'a'..'z', '_'];
end;

function IsIdentChar(C: char): boolean; inline;
begin
   Result := C in ['A'..'Z', 'a'..'z', '_', '0'..'9'];
end;

{=============================================================================}
{  THighlightAttr                                                             }
{=============================================================================}

constructor THighlightAttr.Create(const AName: string; AForeground: TColor);
begin
   inherited Create;
   FName := AName;
   FForeground := AForeground;
   FBackground := clDefault;
end;

procedure THighlightAttr.SetForeground(V: TColor);
begin
   if V = FForeground then exit;
   FForeground := V;
   if Assigned(FOnChange) then FOnChange(Self);
end;

procedure THighlightAttr.SetBackground(V: TColor);
begin
   if V = FBackground then exit;
   FBackground := V;
   if Assigned(FOnChange) then FOnChange(Self);
end;

procedure THighlightAttr.Assign(Source: TPersistent);
begin
   if Source is THighlightAttr then
   begin
      FForeground := THighlightAttr(Source).FForeground;
      FBackground := THighlightAttr(Source).FBackground;
      if Assigned(FOnChange) then FOnChange(Self);
   end
   else inherited Assign(Source);
end;

{=============================================================================}
{  TSynCustomHighlighter                                                      }
{=============================================================================}

constructor TSynCustomHighlighter.Create(AOwner: TComponent);
var k: TTokenKind;
begin
   inherited Create(AOwner);
   for k := Low(TTokenKind) to High(TTokenKind) do
   begin
      FAttrs[k] := THighlightAttr.Create(TokenKindNames[k], clDefault);
      FAttrs[k].OnChange := @AttrChanged;
   end;
   SetDefaultColors;
end;

destructor TSynCustomHighlighter.Destroy;
var k: TTokenKind;
begin
   for k := Low(TTokenKind) to High(TTokenKind) do FAttrs[k].Free;
   inherited Destroy;
end;

{ the colours on the editor's blue: Turbo Pascal 7 like }
procedure TSynCustomHighlighter.SetDefaultColors;
begin
   FAttrs[tkKeyword].FForeground := clWhite;
   FAttrs[tkNumber].FForeground := clLightCyan;
   FAttrs[tkString].FForeground := clLightCyan;
   FAttrs[tkComment].FForeground := clLightGray;
   FAttrs[tkDirective].FForeground := clLightGreen;
   FAttrs[tkAsm].FForeground := clLightGreen;
   FAttrs[tkLabel].FForeground := clLightRed;
end;

procedure TSynCustomHighlighter.AttrChanged(Sender: TObject);
begin
   Changed;
end;

procedure TSynCustomHighlighter.Changed;
var i: integer;
begin
   if Assigned(FOnChange) then FOnChange(Self);
   for i := 0 to High(FHooks) do FHooks[i](Self);
end;

procedure TSynCustomHighlighter.HookChange(Event: TNotifyEvent);
begin
   SetLength(FHooks, Length(FHooks) + 1);
   FHooks[High(FHooks)] := Event;
end;

procedure TSynCustomHighlighter.UnhookChange(Event: TNotifyEvent);
var i, j: integer;
begin
   for i := High(FHooks) downto 0 do
      if (TMethod(FHooks[i]).Code = TMethod(Event).Code) and
         (TMethod(FHooks[i]).Data = TMethod(Event).Data) then
      begin
         for j := i to High(FHooks) - 1 do FHooks[j] := FHooks[j + 1];
         SetLength(FHooks, Length(FHooks) - 1);
      end;
end;

function TSynCustomHighlighter.GetAttr(Index: integer): THighlightAttr;
begin
   Result := FAttrs[TTokenKind(Index)];
end;

procedure TSynCustomHighlighter.SetAttr(Index: integer; V: THighlightAttr);
begin
   FAttrs[TTokenKind(Index)].Assign(V);
end;

function TSynCustomHighlighter.AttriFor(Kind: TTokenKind): THighlightAttr;
begin
   Result := FAttrs[Kind];
end;

procedure TSynCustomHighlighter.SetLine(const S: string; State: integer);
begin
   FLine := S;
   FLen := Length(S);
   FRun := 1;
   FState := State;
   FKind := tkNull;
   Next;
end;

function TSynCustomHighlighter.GetEol: boolean;
begin
   Result := FKind = tkNull;
end;

procedure TSynCustomHighlighter.Next;
begin
   if FRun > FLen then
   begin
      FTokStart := FRun;
      FKind := tkNull;
      exit;
   end;
   FTokStart := FRun;
   ScanToken;
   if FRun <= FTokStart then FRun := FTokStart + 1;   { never stand still }
end;

function TSynCustomHighlighter.TokenKind: TTokenKind;
begin
   Result := FKind;
end;

function TSynCustomHighlighter.TokenStart: integer;
begin
   Result := FTokStart;
end;

function TSynCustomHighlighter.TokenLength: integer;
begin
   Result := FRun - FTokStart;
end;

function TSynCustomHighlighter.GetToken: string;
begin
   Result := Copy(FLine, FTokStart, FRun - FTokStart);
end;

function TSynCustomHighlighter.TokenAttri: THighlightAttr;
begin
   Result := FAttrs[FKind];
end;

function TSynCustomHighlighter.EndState: integer;
begin
   while not GetEol do Next;
   Result := FState;
end;

function TSynCustomHighlighter.LineEndState(const S: string; State: integer): integer;
begin
   SetLine(S, State);
   Result := EndState;
end;

function TSynCustomHighlighter.LanguageName: string;
begin
   Result := 'Text';
end;

function TSynCustomHighlighter.DefaultFilter: string;
begin
   Result := 'All files|*.*';
end;

function TSynCustomHighlighter.IsKeyword(const S: string): boolean;
begin
   Result := false;
end;

{=============================================================================}
{  TSynPasSyn                                                                 }
{=============================================================================}

const
   psCode = 0; psBrace = 1; psParen = 2; psDirective = 3; psAsm = 4;

constructor TSynPasSyn.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FAsmBlocks := true;
end;

function TSynPasSyn.LanguageName: string;
begin
   Result := 'Pascal';
end;

function TSynPasSyn.DefaultFilter: string;
begin
   Result := 'Pascal files|*.pas;*.pp;*.inc;*.lpr;*.dpr';
end;

function TSynPasSyn.IsKeyword(const S: string): boolean;
begin
   Result := (S <> '') and PasTable.Has(S, 1, Length(S));
end;

(* { ... } or {$ ... }: to the } or the end of the line (then the state says so) *)
procedure TSynPasSyn.ScanBraceComment;
begin
   while (FRun <= FLen) and (FLine[FRun] <> '}') do inc(FRun);
   if FRun <= FLen then
   begin
      inc(FRun);
      FState := FState and psAsm;
   end;
end;

procedure TSynPasSyn.ScanParenComment;
begin
   while (FRun < FLen) and not ((FLine[FRun] = '*') and (FLine[FRun + 1] = ')')) do inc(FRun);
   if FRun < FLen then
   begin
      inc(FRun, 2);
      FState := FState and psAsm;
   end
   else FRun := FLen + 1;
end;

procedure TSynPasSyn.ScanToken;
var c: char;
    inAsm: boolean;
    p: integer;
begin
   inAsm := FState and psAsm <> 0;
   { inside a comment from the line before }
   case FState and 3 of
      psBrace:     begin FKind := tkComment; ScanBraceComment; exit; end;
      psDirective: begin FKind := tkDirective; ScanBraceComment; exit; end;
      psParen:     begin FKind := tkComment; ScanParenComment; exit; end;
   end;
   c := FLine[FRun];
   case c of
      ' ', #9:
         begin
            FKind := tkSpace;
            while (FRun <= FLen) and (FLine[FRun] in [' ', #9]) do inc(FRun);
         end;
      '{':
         begin
            if (FRun < FLen) and (FLine[FRun + 1] = '$') then
            begin
               FKind := tkDirective;
               FState := (FState and psAsm) or psDirective;
            end
            else
            begin
               FKind := tkComment;
               FState := (FState and psAsm) or psBrace;
            end;
            inc(FRun);
            ScanBraceComment;
         end;
      '(':
         if (FRun < FLen) and (FLine[FRun + 1] = '*') then
         begin
            FKind := tkComment;
            FState := (FState and psAsm) or psParen;
            inc(FRun, 2);
            ScanParenComment;
         end
         else
         begin
            FKind := tkSymbol;
            inc(FRun);
         end;
      '/':
         if (FRun < FLen) and (FLine[FRun + 1] = '/') then
         begin
            FKind := tkComment;
            FRun := FLen + 1;
         end
         else
         begin
            FKind := tkSymbol;
            inc(FRun);
         end;
      '''':
         begin
            { 'it''s': a doubled quote stays in the string }
            FKind := tkString;
            inc(FRun);
            while FRun <= FLen do
            begin
               if FLine[FRun] = '''' then
               begin
                  if (FRun < FLen) and (FLine[FRun + 1] = '''') then inc(FRun, 2)
                  else
                  begin
                     inc(FRun);
                     break;
                  end;
               end
               else inc(FRun);
            end;
            if inAsm then FKind := tkAsm;
         end;
      '#':
         begin
            { #13, #$0D: a character constant }
            FKind := tkString;
            inc(FRun);
            if (FRun <= FLen) and (FLine[FRun] = '$') then
            begin
               inc(FRun);
               while (FRun <= FLen) and (FLine[FRun] in ['0'..'9', 'A'..'F', 'a'..'f']) do inc(FRun);
            end
            else
               while (FRun <= FLen) and (FLine[FRun] in ['0'..'9']) do inc(FRun);
            if inAsm then FKind := tkAsm;
         end;
      '0'..'9':
         begin
            FKind := tkNumber;
            while (FRun <= FLen) and (FLine[FRun] in ['0'..'9']) do inc(FRun);
            { a fraction, but not the .. of a range }
            if (FRun < FLen) and (FLine[FRun] = '.') and (FLine[FRun + 1] in ['0'..'9']) then
            begin
               inc(FRun);
               while (FRun <= FLen) and (FLine[FRun] in ['0'..'9']) do inc(FRun);
            end;
            if (FRun <= FLen) and (FLine[FRun] in ['e', 'E']) then
            begin
               p := FRun + 1;
               if (p <= FLen) and (FLine[p] in ['+', '-']) then inc(p);
               if (p <= FLen) and (FLine[p] in ['0'..'9']) then
               begin
                  FRun := p;
                  while (FRun <= FLen) and (FLine[FRun] in ['0'..'9']) do inc(FRun);
               end;
            end;
            if inAsm then FKind := tkAsm;
         end;
      '$':
         begin
            FKind := tkNumber;
            inc(FRun);
            while (FRun <= FLen) and (FLine[FRun] in ['0'..'9', 'A'..'F', 'a'..'f']) do inc(FRun);
            if FRun = FTokStart + 1 then FKind := tkSymbol;
            if inAsm then FKind := tkAsm;
         end;
      '%':
         begin
            FKind := tkNumber;
            inc(FRun);
            while (FRun <= FLen) and (FLine[FRun] in ['0', '1']) do inc(FRun);
            if FRun = FTokStart + 1 then FKind := tkSymbol;
            if inAsm then FKind := tkAsm;
         end;
      '&':
         begin
            inc(FRun);
            if (FRun <= FLen) and (FLine[FRun] in ['0'..'7']) then
            begin
               FKind := tkNumber;
               while (FRun <= FLen) and (FLine[FRun] in ['0'..'7']) do inc(FRun);
            end
            else if (FRun <= FLen) and IsIdentStart(FLine[FRun]) then
            begin
               { &begin: an identifier that is spelled like a keyword }
               FKind := tkIdentifier;
               while (FRun <= FLen) and IsIdentChar(FLine[FRun]) do inc(FRun);
            end
            else FKind := tkSymbol;
            if inAsm then FKind := tkAsm;
         end;
      'A'..'Z', 'a'..'z', '_':
         begin
            while (FRun <= FLen) and IsIdentChar(FLine[FRun]) do inc(FRun);
            if PasTable.Has(FLine, FTokStart, FRun - FTokStart) then
            begin
               FKind := tkKeyword;
               if FAsmBlocks then
               begin
                  if not inAsm and (FRun - FTokStart = 3) and
                     (UpperCase(Copy(FLine, FTokStart, 3)) = 'ASM') then
                     FState := FState or psAsm
                  else if inAsm then
                  begin
                     { in asm only "end" is a keyword: it ends the block }
                     if (FRun - FTokStart = 3) and (UpperCase(Copy(FLine, FTokStart, 3)) = 'END') then
                        FState := FState and not psAsm
                     else FKind := tkAsm;
                  end;
               end;
            end
            else if inAsm then FKind := tkAsm
            else FKind := tkIdentifier;
         end;
   else
      FKind := tkSymbol;
      inc(FRun);
      if inAsm then FKind := tkAsm;
   end;
end;

{=============================================================================}
{  TSynQBasicSyn                                                              }
{=============================================================================}

function TSynQBasicSyn.LanguageName: string;
begin
   Result := 'QBasic';
end;

function TSynQBasicSyn.DefaultFilter: string;
begin
   Result := 'BASIC files|*.bas;*.bi;*.bm';
end;

function TSynQBasicSyn.IsKeyword(const S: string): boolean;
begin
   Result := (S <> '') and QBTable.Has(S, 1, Length(S));
end;

{ a comment that starts with $: a metacommand ('$INCLUDE:, REM $DYNAMIC) }
function IsMeta(const S: string; From: integer): boolean;
begin
   while (From <= Length(S)) and (S[From] = ' ') do inc(From);
   Result := (From <= Length(S)) and (S[From] = '$');
end;

procedure TSynQBasicSyn.ScanToken;
var c: char;
    p: integer;
    first: boolean;
begin
   if FTokStart = 1 then FFirst := true;
   first := FFirst;
   c := FLine[FRun];
   if not (c in [' ', #9]) then FFirst := false;
   case c of
      ' ', #9:
         begin
            FKind := tkSpace;
            while (FRun <= FLen) and (FLine[FRun] in [' ', #9]) do inc(FRun);
         end;
      '''':
         begin
            if IsMeta(FLine, FRun + 1) then FKind := tkDirective else FKind := tkComment;
            FRun := FLen + 1;
         end;
      '"':
         begin
            FKind := tkString;
            inc(FRun);
            while (FRun <= FLen) and (FLine[FRun] <> '"') do inc(FRun);
            if FRun <= FLen then inc(FRun);
         end;
      '0'..'9', '.':
         begin
            if (c = '.') and not ((FRun < FLen) and (FLine[FRun + 1] in ['0'..'9'])) then
            begin
               FKind := tkSymbol;
               inc(FRun);
               exit;
            end;
            while (FRun <= FLen) and (FLine[FRun] in ['0'..'9']) do inc(FRun);
            { a line number at the start of the line }
            if first and (c <> '.') and ((FRun > FLen) or (FLine[FRun] in [' ', #9, ':'])) then
            begin
               FKind := tkLabel;
               exit;
            end;
            FKind := tkNumber;
            if (FRun <= FLen) and (FLine[FRun] = '.') then
            begin
               inc(FRun);
               while (FRun <= FLen) and (FLine[FRun] in ['0'..'9']) do inc(FRun);
            end;
            if (FRun <= FLen) and (FLine[FRun] in ['e', 'E', 'd', 'D']) then
            begin
               p := FRun + 1;
               if (p <= FLen) and (FLine[p] in ['+', '-']) then inc(p);
               if (p <= FLen) and (FLine[p] in ['0'..'9']) then
               begin
                  FRun := p;
                  while (FRun <= FLen) and (FLine[FRun] in ['0'..'9']) do inc(FRun);
               end;
            end;
            { the type suffix: 10%, 3.5!, 1E10#, 70000& }
            if (FRun <= FLen) and (FLine[FRun] in ['%', '&', '!', '#']) then inc(FRun);
         end;
      '&':
         begin
            inc(FRun);
            if (FRun <= FLen) and (FLine[FRun] in ['H', 'h']) then
            begin
               FKind := tkNumber;
               inc(FRun);
               while (FRun <= FLen) and (FLine[FRun] in ['0'..'9', 'A'..'F', 'a'..'f']) do inc(FRun);
               if (FRun <= FLen) and (FLine[FRun] in ['%', '&']) then inc(FRun);
            end
            else if (FRun <= FLen) and (FLine[FRun] in ['O', 'o', '0'..'7']) then
            begin
               FKind := tkNumber;
               if FLine[FRun] in ['O', 'o'] then inc(FRun);
               while (FRun <= FLen) and (FLine[FRun] in ['0'..'7']) do inc(FRun);
               if (FRun <= FLen) and (FLine[FRun] in ['%', '&']) then inc(FRun);
            end
            else FKind := tkSymbol;
         end;
      'A'..'Z', 'a'..'z':
         begin
            while (FRun <= FLen) and (FLine[FRun] in ['A'..'Z', 'a'..'z', '0'..'9', '.', '_']) do inc(FRun);
            { the type sigil: name$, count%, total#, big&, x! }
            if (FRun <= FLen) and (FLine[FRun] in ['$', '%', '&', '!', '#']) then inc(FRun);
            if (FRun - FTokStart = 3) and (UpperCase(Copy(FLine, FTokStart, 3)) = 'REM') then
            begin
               { REM: the rest of the line is a comment }
               if IsMeta(FLine, FRun) then FKind := tkDirective else FKind := tkComment;
               FRun := FLen + 1;
            end
            else if QBTable.Has(FLine, FTokStart, FRun - FTokStart) then FKind := tkKeyword
            else
            begin
               FKind := tkIdentifier;
               { a label: the first thing on the line, followed by a colon }
               if first and (FRun <= FLen) and (FLine[FRun] = ':') then
               begin
                  inc(FRun);
                  FKind := tkLabel;
               end;
            end;
         end;
   else
      FKind := tkSymbol;
      inc(FRun);
   end;
end;

{=============================================================================}
{  TSynAnySyn                                                                 }
{=============================================================================}

constructor TSynAnySyn.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FKeywords := TStringList.Create;
   FKeywords.Sorted := true;
   FKeywords.Duplicates := dupIgnore;
   FLineComments := TStringList.Create;
   FQuotes := '"''';
   FLanguage := 'Text';
   FFilter := 'All files|*.*';
end;

destructor TSynAnySyn.Destroy;
begin
   FKeywords.Free;
   FLineComments.Free;
   inherited Destroy;
end;

function TSynAnySyn.GetKeywords: TStrings;
begin
   Result := FKeywords;
end;

procedure TSynAnySyn.SetKeywords(V: TStrings);
begin
   FKeywords.Assign(V);
end;

function TSynAnySyn.GetLineComments: TStrings;
begin
   Result := FLineComments;
end;

procedure TSynAnySyn.SetLineComments(V: TStrings);
begin
   FLineComments.Assign(V);
end;

function TSynAnySyn.LanguageName: string;
begin
   Result := FLanguage;
end;

function TSynAnySyn.DefaultFilter: string;
begin
   Result := FFilter;
end;

function TSynAnySyn.IsKeyword(const S: string): boolean;
var i: integer;
begin
   FKeywords.CaseSensitive := FCaseSensitive;
   Result := FKeywords.Find(S, i);
end;

{ does S start at FRun (case as CaseSensitive says)? }
function TSynAnySyn.At(const S: string): boolean;
begin
   Result := (S <> '') and (FRun + Length(S) - 1 <= FLen);
   if not Result then exit;
   if FCaseSensitive then Result := Copy(FLine, FRun, Length(S)) = S
   else Result := CompareText(Copy(FLine, FRun, Length(S)), S) = 0;
end;

procedure TSynAnySyn.ScanToken;
var c, q: char;
    i, p: integer;
begin
   if FState = 1 then
   begin
      FKind := tkComment;
      while (FRun <= FLen) and not At(FBlockEnd) do inc(FRun);
      if FRun <= FLen then
      begin
         inc(FRun, Length(FBlockEnd));
         FState := 0;
      end;
      exit;
   end;
   c := FLine[FRun];
   if c in [' ', #9] then
   begin
      FKind := tkSpace;
      while (FRun <= FLen) and (FLine[FRun] in [' ', #9]) do inc(FRun);
      exit;
   end;
   { a directive line: the first non-blank is DirectiveChar }
   if (FDirectiveChar <> #0) and (c = FDirectiveChar) and (Trim(Copy(FLine, 1, FRun - 1)) = '') then
   begin
      FKind := tkDirective;
      FRun := FLen + 1;
      exit;
   end;
   for i := 0 to FLineComments.Count - 1 do
      if At(FLineComments[i]) then
      begin
         FKind := tkComment;
         FRun := FLen + 1;
         exit;
      end;
   if At(FBlockStart) and (FBlockEnd <> '') then
   begin
      FKind := tkComment;
      inc(FRun, Length(FBlockStart));
      FState := 1;
      while (FRun <= FLen) and not At(FBlockEnd) do inc(FRun);
      if FRun <= FLen then
      begin
         inc(FRun, Length(FBlockEnd));
         FState := 0;
      end;
      exit;
   end;
   if Pos(c, FQuotes) > 0 then
   begin
      q := c;
      FKind := tkString;
      inc(FRun);
      while (FRun <= FLen) and (FLine[FRun] <> q) do
      begin
         if (FLine[FRun] = '\') and (FRun < FLen) then inc(FRun);
         inc(FRun);
      end;
      if FRun <= FLen then inc(FRun);
      exit;
   end;
   if c in ['0'..'9'] then
   begin
      FKind := tkNumber;
      if (c = '0') and (FRun < FLen) and (FLine[FRun + 1] in ['x', 'X']) then
      begin
         inc(FRun, 2);
         while (FRun <= FLen) and (FLine[FRun] in ['0'..'9', 'A'..'F', 'a'..'f']) do inc(FRun);
      end
      else
         while (FRun <= FLen) and (FLine[FRun] in ['0'..'9', '.', 'A'..'F', 'a'..'f', 'h', 'H']) do inc(FRun);
      exit;
   end;
   if IsIdentStart(c) then
   begin
      p := FRun;
      while (FRun <= FLen) and IsIdentChar(FLine[FRun]) do inc(FRun);
      if IsKeyword(Copy(FLine, p, FRun - p)) then FKind := tkKeyword else FKind := tkIdentifier;
      exit;
   end;
   FKind := tkSymbol;
   inc(FRun);
end;

{=============================================================================}
{  TSynLineStates                                                             }
{=============================================================================}

constructor TSynLineStates.Create(ALines: TStrings; AHighlighter: TSynCustomHighlighter);
begin
   inherited Create;
   FLines := ALines;
   FHighlighter := AHighlighter;
   Reset;
end;

procedure TSynLineStates.Reset;
begin
   SetLength(FStates, 1);
   FStates[0] := 0;
   FValid := 1;
   FKnown := 1;
end;

procedure TSynLineStates.SetHighlighter(V: TSynCustomHighlighter);
begin
   FHighlighter := V;
   Reset;
end;

procedure TSynLineStates.Grow(N: integer);
begin
   if N > Length(FStates) then SetLength(FStates, N + N div 2 + 16);
end;

function TSynLineStates.StartState(Line: integer): integer;
var e, j: integer;
begin
   if (FHighlighter = nil) or (Line <= 0) then exit(0);
   if Line > FLines.Count then Line := FLines.Count;
   Grow(Line + 1);
   while FValid <= Line do
   begin
      { the state line FValid starts in: where line FValid-1 ends }
      e := FHighlighter.LineEndState(FLines[FValid - 1], FStates[FValid - 1]);
      inc(FScanned);
      if (FValid < FKnown) and (FStates[FValid] = e) then
      begin
         { the same as before the edit: the lines after it hold until the }
         { next one an edit marked unknown (-1)                           }
         j := FValid + 1;
         while (j < FKnown) and (FStates[j] <> -1) do inc(j);
         FValid := j;
      end
      else
      begin
         FStates[FValid] := e;
         inc(FValid);
         if FValid > FKnown then FKnown := FValid;
      end;
   end;
   Result := FStates[Line];
end;

{ a line's text changed: its own start state still holds, the next line's }
{ is unknown                                                              }
procedure TSynLineStates.LineChanged(Line: integer);
begin
   if Line < 0 then Line := 0;
   if Line + 1 < FKnown then FStates[Line + 1] := -1;
   if Line + 1 < FValid then FValid := Line + 1;
   if FValid < 1 then FValid := 1;
end;

procedure TSynLineStates.LinesInserted(Line, Count: integer);
var i: integer;
begin
   if Count <= 0 then exit;
   if Line < FKnown then
   begin
      Grow(FKnown + Count + 1);
      for i := FKnown - 1 downto Line do FStates[i + Count] := FStates[i];
      { line Line still starts where line Line-1 ends; the new lines and }
      { the line pushed down after them are unknown                       }
      for i := Line + 1 to Line + Count do FStates[i] := -1;
      inc(FKnown, Count);
   end;
   if Line + 1 < FValid then FValid := Line + 1;
   if FValid < 1 then FValid := 1;
end;

procedure TSynLineStates.LinesDeleted(Line, Count: integer);
var i, keep: integer;
begin
   if Count <= 0 then exit;
   if Line < FKnown then
   begin
      keep := FStates[Line];
      for i := Line + Count to FKnown - 1 do FStates[i - Count] := FStates[i];
      FStates[Line] := keep;
      dec(FKnown, Count);
      if FKnown < Line + 1 then FKnown := Line + 1;
      if Line + 1 < FKnown then FStates[Line + 1] := -1;
   end;
   if Line + 1 < FValid then FValid := Line + 1;
   if FValid < 1 then FValid := 1;
end;

{=============================================================================}

function HighlighterClassForFile(const FileName: string): TSynHighlighterClass;
var e: string;
begin
   e := LowerCase(ExtractFileExt(FileName));
   if (e = '.pas') or (e = '.pp') or (e = '.inc') or (e = '.lpr') or (e = '.dpr') then
      Result := TSynPasSyn
   else if (e = '.bas') or (e = '.bi') or (e = '.bm') then
      Result := TSynQBasicSyn
   else
      Result := nil;
end;

initialization
   PasTable := TKeywordTable.Create;
   PasTable.AddAll(PasKeywords);
   PasTable.Sort;
   QBTable := TKeywordTable.Create;
   QBTable.AddAll(QBKeywords);
   QBTable.Sort;
   RegisterClasses([TSynPasSyn, TSynQBasicSyn, TSynAnySyn]);
finalization
   PasTable.Free;
   QBTable.Free;
end.
