{-----------------------------------------------------------------------------}
{  TUICTRL - an LCL style control library for DOS text mode (go32v2).          }
{                                                                             }
{  The same pattern as FPTEGL's DUICTRL (and the LCL): TControl, TWinControl, }
{  TCustomForm/TForm and a global Application with CreateForm and Run.        }
{  Controls are made in code exactly as in Lazarus:                           }
{                                                                             }
{     Button1 := TButton.Create(Self);                                        }
{     Button1.Parent := Self;                                                 }
{     Button1.SetBounds(2, 5, 12, 2);                                         }
{     Button1.Caption := '&OK';                                               }
{     Button1.OnClick := @Button1Click;                                       }
{                                                                             }
{  Units are character cells: Left/Top/Width/Height count columns and rows.  }
{  A form's Left/Top are screen cells and Width/Height include its frame;    }
{  a control's Left/Top are relative to its parent's client area (inside the }
{  frame), as in the LCL. TColor is a text colour 0..15 (clBlack..clWhite).  }
{                                                                             }
{  Painting: Invalidate collects one dirty rectangle; once per loop the      }
{  desktop and the forms over it are repainted into TUISCRN's buffer, clipped }
{  to that rectangle, and ScrFlush sends only the cells that changed.         }
{-----------------------------------------------------------------------------}
unit TUICtrl;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, TUIHW, TUIScrn;

const
   VK_BACK = 8; VK_TAB = 9; VK_RETURN = 13; VK_ESCAPE = 27; VK_SPACE = 32;
   VK_PRIOR = 33; VK_NEXT = 34; VK_END = 35; VK_HOME = 36; VK_LEFT = 37;
   VK_UP = 38; VK_RIGHT = 39; VK_DOWN = 40; VK_INSERT = 45; VK_DELETE = 46;
   VK_0 = 48; VK_9 = 57; VK_A = 65; VK_Z = 90;
   VK_F1 = 112; VK_F2 = 113; VK_F3 = 114; VK_F4 = 115; VK_F5 = 116;
   VK_F6 = 117; VK_F7 = 118; VK_F8 = 119; VK_F9 = 120; VK_F10 = 121;
   VK_F11 = 122; VK_F12 = 123;

type
   { a text colour 0..15, or clDefault (the theme decides) }
   TColor = type longint;      { its own type: an .lfm may say clRed }

const
   { the LCL colour names on the 16 text colours }
   clBlack = 0;   clNavy = 1;  clGreen = 2;   clTeal = 3;    clMaroon = 4;
   clPurple = 5;  clOlive = 6; clSilver = 7;  clGray = 8;    clBlue = 9;
   clLime = 10;   clAqua = 11; clRed = 12;    clFuchsia = 13; clYellow = 14;
   clWhite = 15;
   { the text mode names too }
   clCyan = 3; clBrown = 6; clLightGray = 7; clDarkGray = 8; clLightBlue = 9;
   clLightGreen = 10; clLightCyan = 11; clLightRed = 12; clLightMagenta = 13;
   clMagenta = 5;
   clNone    = TColor($1FFFFFFF);
   clDefault = TColor($20000000);

type
   TMouseButton = (mbLeft, mbRight, mbMiddle);
   TModalResult = type integer; { an .lfm may say mrOk }
   TAlignment = (taLeftJustify, taRightJustify, taCenter);
   TFormBorderStyle = (bsNone, bsSingle, bsSizeable, bsDialog, bsToolWindow, bsSizeToolWin);
   TPosition = (poDesigned, poDefault, poDefaultPosOnly, poDefaultSizeOnly,
                poScreenCenter, poDesktopCenter, poMainFormCenter, poOwnerFormCenter);
   TCloseAction = (caNone, caHide, caFree, caMinimize);
   TBorderIcon = (biSystemMenu, biMinimize, biMaximize, biHelp);
   TBorderIcons = set of TBorderIcon;
   TAlign = (alNone, alTop, alBottom, alLeft, alRight, alClient, alCustom);
   TAnchorKind = (akTop, akLeft, akRight, akBottom);
   TAnchors = set of TAnchorKind;
   TWindowState = (wsNormal, wsMinimized, wsMaximized, wsFullScreen);
   { a key with its shift state, as in the LCL: VK code + scShift/scCtrl/scAlt }
   TShortCut = Word;

   TKeyEvent = procedure(Sender: TObject; var Key: Word; Shift: TShiftState) of object;
   TKeyPressEvent = procedure(Sender: TObject; var Key: char) of object;
   TMouseEvent = procedure(Sender: TObject; Button: TMouseButton;
                           Shift: TShiftState; X, Y: integer) of object;
   TMouseMoveEvent = procedure(Sender: TObject; Shift: TShiftState; X, Y: integer) of object;
   { WheelDelta: 120 per notch, positive = up (away from you), as in the LCL }
   TMouseWheelEvent = procedure(Sender: TObject; Shift: TShiftState; WheelDelta: integer;
                                MousePos: TPoint; var Handled: boolean) of object;
   TCloseEvent = procedure(Sender: TObject; var CloseAction: TCloseAction) of object;
   TCloseQueryEvent = procedure(Sender: TObject; var CanClose: boolean) of object;

const
   scShift = $2000; scCtrl = $4000; scAlt = $8000; scNone = 0;
   mrNone = 0; mrOk = 1; mrCancel = 2; mrAbort = 3; mrRetry = 4; mrIgnore = 5;
   mrYes = 6; mrNo = 7; mrAll = 8; mrNoToAll = 9; mrYesToAll = 10; mrClose = 11;

type
   { the colours of everything; attributes are fg + bg * 16. Entries named  }
   { ...Fg are foreground colours drawn on the parent's background          }
   TTUITheme = record
      Desktop        : byte;    { desktop pattern }
      DesktopChar    : char;
      FormBody       : byte;    { form client area }
      FrameFg, FrameActiveFg : byte;
      TitleFg, TitleActiveFg : byte;
      CloseBoxFg     : byte;
      LabelFg, LabelHotFg : byte;
      DisabledFg     : byte;
      ButtonFace, ButtonFocus, ButtonHot, ButtonDisabled : byte;
      ButtonShadowFg : byte;
      ButtonDefaultMarkFg : byte;
      Edit, EditFocus, EditSelect : byte;
      CheckFg, CheckFocusFg, CheckHotFg : byte;
      GroupFrameFg, GroupTitleFg : byte;
      MenuBar, MenuHot, MenuSel, MenuSelHot, MenuDisabled, MenuSelDisabled : byte;
      StatusBar, StatusHot : byte;
      List, ListFocusSel, ListSel, ListScroll, ComboButton : byte;
      Progress, ProgressDone : byte;
      HintWindow : byte;
      WindowShadow   : boolean; { see-through shadow under forms }
      ButtonShadow   : boolean; { 3d shadow under buttons }
   end;

   { minimum / maximum size in cells (0 = no limit), LCL Constraints }
   TSizeConstraints = class(TPersistent)
   private
      FMinWidth, FMinHeight, FMaxWidth, FMaxHeight: integer;
   published
      property MinWidth: integer read FMinWidth write FMinWidth default 0;
      property MinHeight: integer read FMinHeight write FMinHeight default 0;
      property MaxWidth: integer read FMaxWidth write FMaxWidth default 0;
      property MaxHeight: integer read FMaxHeight write FMaxHeight default 0;
   end;

   TFont = class(TPersistent)
   private
      FColor: TColor;
      FOnChange: TNotifyEvent;
      procedure SetColor(V: TColor);
   public
      constructor Create;
      procedure Assign(Source: TPersistent); override;
   published
      property Color: TColor read FColor write SetColor default clDefault;
   published
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
   end;

   TBrush = class(TPersistent)
   private
      FColor: TColor;
   public
      constructor Create;
   published
      property Color: TColor read FColor write FColor default clDefault;
   end;

   { drawing in a control: local cell coordinates, clipped to the control }
   TCanvas = class
   private
      FOrgX, FOrgY: integer;
      FClip: TRect;
      FFont: TFont;
      FBrush: TBrush;
      procedure Apply; inline;
   public
      constructor Create;
      destructor Destroy; override;
      procedure SetOrigin(X, Y: integer);
      procedure SetClipRect(const ScreenR: TRect);
      { the attribute from Font.Color and Brush.Color }
      function  Attr: byte;
      procedure FillRect(const R: TRect); overload;
      procedure FillRect(X1, Y1, X2, Y2: integer); overload;
      procedure Fill(const R: TRect; Ch: char; A: byte);
      procedure TextOut(X, Y: integer; const S: string); overload;
      procedure TextOut(X, Y: integer; const S: string; A: byte); overload;
      function  TextOutAccel(X, Y: integer; const S: string; A, HotA: byte): integer;
      procedure PutChar(X, Y: integer; Ch: char; A: byte);
      procedure Frame(const R: TRect; Style: integer; A: byte);
      procedure HLine(X1, X2, Y: integer; Ch: char; A: byte);
      procedure VLine(X, Y1, Y2: integer; Ch: char; A: byte);
      procedure SetAttr(const R: TRect; A: byte);
      procedure Shadow(const R: TRect);
      function  TextWidth(const S: string): integer;
      function  TextHeight(const S: string): integer;
   published
      property Font: TFont read FFont;
      property Brush: TBrush read FBrush;
      property OriginX: integer read FOrgX;
      property OriginY: integer read FOrgY;
   end;

   TWinControl = class;
   TCustomForm = class;
   TMenuBarBase = class;
   TAction = class;

   TControl = class(TComponent)
   protected
      FParent: TWinControl;
      FLeft, FTop, FWidth, FHeight: integer;
      FCaption: string;
      FVisible, FEnabled: boolean;
      FColor: TColor;
      FFont: TFont;
      FHint: string;
      FTabOrder: integer;
      FOnClick, FOnDblClick: TNotifyEvent;
      FOnMouseDown, FOnMouseUp: TMouseEvent;
      FOnMouseMove: TMouseMoveEvent;
      FMouseDownInside: boolean;
      FAlign: TAlign;
      FAnchors: TAnchors;
      FConstraints: TSizeConstraints;
      FOnResize: TNotifyEvent;
      FPopupMenu: TMenuBarBase;
      FAction: TAction;
      FActionCaption, FActionHint: string;   { what the action last gave }
      FShowHint: boolean;
      FOnMouseWheel: TMouseWheelEvent;
      procedure Resize; virtual;
      procedure SetAction(V: TAction);
      procedure ActionChanged(Sender: TObject);
      { the action's Caption, Hint, Enabled, Visible (and Checked where it }
      { applies) go to the control                                       }
      procedure ActionChange(A: TAction); virtual;
      procedure SetPopupMenu(V: TMenuBarBase);
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
   private
      procedure SetAlign(V: TAlign);
      procedure SetLeft(V: integer);
      procedure SetTop(V: integer);
      procedure SetWidth(V: integer);
      procedure SetHeight(V: integer);
      procedure SetEnabled(V: boolean);
      procedure SetColor(V: TColor);
      procedure SetFont(V: TFont);
      procedure FontChanged(Sender: TObject);
   protected
      procedure SetVisible(V: boolean); virtual;
      procedure SetCaption(const V: string); virtual;
      procedure SetParent(AParent: TWinControl); virtual;
      procedure TextChanged; virtual;
      procedure SetParentComponent(Value: TComponent); override;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      function  GetParentComponent: TComponent; override;
      function  HasParent: boolean; override;
      { what the control draws; Canvas is set up for it while it runs }
      procedure Paint; virtual;
      procedure Click; virtual;
      procedure DblClick; virtual;
      { X, Y relative to the control }
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); virtual;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); virtual;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); virtual;
      { the left button is still down (auto repeat for scroll arrows and the }
      { like): after 400 ms, then every 55 ms                             }
      procedure MouseHeld(X, Y: integer); virtual;
      { the wheel over the control: OnMouseWheel, then MouseWheel; false = }
      { not used, the parent gets it                                      }
      function  DoMouseWheel(Shift: TShiftState; WheelDelta: integer; MousePos: TPoint): boolean;
      { what the control does with the wheel (scroll lists, ...)          }
      function  MouseWheel(WheelDelta: integer): boolean; virtual;
      procedure KeyDown(var Key: Word; Shift: TShiftState); virtual;
      procedure KeyPress(var Key: char); virtual;
      procedure DoEnter; virtual;
      procedure DoExit; virtual;
      { Alt+letter / letter matched the caption's '&' key: act on it }
      function  HasAccel: boolean; virtual;
      procedure DoAccel; virtual;
      { Enter / Esc on a form go to its Default / Cancel button }
      function  IsDefault: boolean; virtual;
      function  IsCancel: boolean; virtual;
      { a focused control that types text gets plain letters (no access keys) }
      function  WantsChars: boolean; virtual;
      { where the text cursor goes when the control has the focus }
      function  GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean; virtual;
      { the background colour (0..15) this control's text sits on }
      function  BackColor: byte; virtual;
      { Font.Color if set, else Default }
      function  TextColor(Default: byte): byte;
      procedure SetBounds(ALeft, ATop, AWidth, AHeight: integer); virtual;
      procedure Invalidate; virtual;
      procedure Show;
      procedure Hide;
      procedure BringToFront;
      function  ScreenOrigin: TPoint;
      function  ScreenRect: TRect;
      function  ClientOffset: TPoint; virtual;
      function  ClientScreenRect: TRect;
      function  ClientWidthValue: integer; virtual;
      function  ClientHeightValue: integer; virtual;
      function  IsShowing: boolean;
      function  IsEnabledAll: boolean;
      function  CanFocus: boolean; virtual;
      function  Focused: boolean;
      procedure SetFocus; virtual;
      function  GetParentForm: TCustomForm;
      function  Canvas: TCanvas;
      property Parent: TWinControl read FParent write SetParent;
      { alTop/alBottom/alLeft/alRight/alClient: placed by the parent }
      { which parent edges the control keeps its distance to when the }
      { parent is resized: [akLeft, akRight] stretches, [akRight] moves }
      { right click or Shift+F10 (TUIMENU.TPopupMenu) }
      { an action supplies Caption, Hint, Enabled... and what a click does }
      { the Hint in a small window under the mouse (also when a parent - }
      { the form - has ShowHint)                                        }
   published
      property Left: integer read FLeft write SetLeft;
      property Top: integer read FTop write SetTop;
      property Width: integer read FWidth write SetWidth;
      property Height: integer read FHeight write SetHeight;
      property Caption: string read FCaption write SetCaption;
      property Text: string read FCaption write SetCaption;
      property Visible: boolean read FVisible write SetVisible default true;
      property Enabled: boolean read FEnabled write SetEnabled default true;
      property Color: TColor read FColor write SetColor default clDefault;
      property Font: TFont read FFont write SetFont;
      property Hint: string read FHint write FHint;
      property TabOrder: integer read FTabOrder write FTabOrder default -1;
      property Align: TAlign read FAlign write SetAlign default alNone;
      property Anchors: TAnchors read FAnchors write FAnchors default [akLeft, akTop];
      property Constraints: TSizeConstraints read FConstraints;
      property PopupMenu: TMenuBarBase read FPopupMenu write SetPopupMenu;
      property Action: TAction read FAction write SetAction;
      property ShowHint: boolean read FShowHint write FShowHint default false;
      property OnResize: TNotifyEvent read FOnResize write FOnResize;
      property OnClick: TNotifyEvent read FOnClick write FOnClick;
      property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
      property OnMouseDown: TMouseEvent read FOnMouseDown write FOnMouseDown;
      property OnMouseUp: TMouseEvent read FOnMouseUp write FOnMouseUp;
      property OnMouseMove: TMouseMoveEvent read FOnMouseMove write FOnMouseMove;
      property OnMouseWheel: TMouseWheelEvent read FOnMouseWheel write FOnMouseWheel;
   end;
   TControlClass = class of TControl;

   TWinControl = class(TControl)
   private
      FControls: TFPList;
      FTabStop: boolean;
      FOnEnter, FOnExit: TNotifyEvent;
      FOnKeyDown: TKeyEvent;
      FOnKeyPress: TKeyPressEvent;
      FAligning: boolean;
      function GetControl(I: integer): TControl;
      function GetControlCount: integer;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure KeyPress(var Key: char); override;
      procedure DoEnter; override;
      procedure DoExit; override;
      procedure InsertControl(C: TControl);
      procedure RemoveControl(C: TControl);
      procedure SetBounds(ALeft, ATop, AWidth, AHeight: integer); override;
      { places the children that have an Align (LCL order: top, bottom, }
      { left, right, then client)                                       }
      procedure AlignControls; virtual;
      { where the children's (0, 0) is, scrolled: TScrollBox moves it }
      function  ScrollOffset: TPoint; virtual;
      { keys the focused control inside did not use go to its parents   }
      { (not the form): page controls switch with Ctrl+Tab and so on    }
      procedure DialogKey(var Key: Word; Shift: TShiftState); virtual;
      { a control inside got the focus (a scroll box scrolls it into view) }
      procedure ChildFocused(C: TControl); virtual;
      { screen coordinates; the deepest visible control there, or nil }
      function  ControlAtPos(SX, SY: integer): TControl;
      function  CanFocus: boolean; override;
      procedure SetFocus; override;
      { the controls that take the focus, in tab order, all levels down }
      procedure GetTabList(List: TFPList);
      property Controls[I: integer]: TControl read GetControl;
   published
      property ControlCount: integer read GetControlCount;
      property TabStop: boolean read FTabStop write FTabStop;
      property OnEnter: TNotifyEvent read FOnEnter write FOnEnter;
      property OnExit: TNotifyEvent read FOnExit write FOnExit;
      property OnKeyDown: TKeyEvent read FOnKeyDown write FOnKeyDown;
      property OnKeyPress: TKeyPressEvent read FOnKeyPress write FOnKeyPress;
   end;

   { something drawn over everything that takes all input while it is open: }
   { an open menu, a combo box's drop-down list. Application.MenuOpened /    }
   { MenuClosed register it; PaintPopups is called last in every repaint     }
   TOverlayBase = class(TComponent)
   public
      procedure PaintPopups; virtual; abstract;
      procedure CloseMenu; virtual; abstract;
      procedure MenuKey(Key: Word; Ch: char; Shift: TShiftState); virtual; abstract;
      procedure MenuMouse(Down, Up: boolean; X, Y: integer; Buttons: byte); virtual; abstract;
   end;

   { the menu bar (TUIMENU.TMainMenu); on the screen (Application.Menu) or }
   { in a form (Form.Menu)                                                 }
   TMenuBarBase = class(TOverlayBase)
   protected
      FForm: TCustomForm;                  { nil: the screen's menu bar }
      FPopupComponent: TComponent;
   public
      function  BarRect: TRect; virtual; abstract;      { screen coordinates }
      procedure PaintBar; virtual; abstract;
      function  IsOpen: boolean; virtual; abstract;
      procedure Activate; virtual; abstract;            { F10 }
      procedure OpenAt(X: integer); virtual; abstract;  { click on the bar }
      function  AccelKey(Ch: char): boolean; virtual; abstract;
      function  ShortCutKey(SC: TShortCut): boolean; virtual; abstract;
      { a pop-up menu: open its items at X, Y (screen) }
      procedure Popup(X, Y: integer); virtual;
      { a pop-up menu: the control it was opened for }
      property Form: TCustomForm read FForm;
   published
      property PopupComponent: TComponent read FPopupComponent write FPopupComponent;
   end;

   { TUIEXT.TTimer registers with the application, which calls Tick }
   TTimerBase = class(TComponent)
   public
      procedure Tick(Now: longint); virtual; abstract;
   end;

   { the clipboard (inside the program; DOS has none) }
   TClipboard = class
   private
      FText: string;
   public
      function HasText: boolean;
   published
      property AsText: string read FText write FText;
   end;

   TExceptionEvent = procedure(Sender: TObject; E: Exception) of object;

   { the status bar (TUIMENU.TStatusBar); on the screen (Application.  }
   { StatusBar) or in a form (Parent := Form, it aligns to the bottom)  }
   TStatusBarBase = class(TControl)
   public
      function  ShortCutKey(SC: TShortCut): boolean; virtual; abstract;
   end;

   TCustomForm = class(TWinControl)
   private
      FMenu: TMenuBarBase;
      FActiveControl: TWinControl;
      FBorderStyle: TFormBorderStyle;
      FBorderIcons: TBorderIcons;
      FPosition: TPosition;
      FModalResult: TModalResult;
      FWindowState: TWindowState;
      FRestoreBounds: TRect;
      FModal: boolean;
      FPlaced: boolean;
      FKeyPreview: boolean;
      FOnCreate, FOnDestroy, FOnShow, FOnHide, FOnActivate, FOnDeactivate,
      FOnPaint: TNotifyEvent;
      FOnClose: TCloseEvent;
      FOnCloseQuery: TCloseQueryEvent;
      procedure SetActiveControl(C: TWinControl);
      procedure SetMenu(V: TMenuBarBase);
      procedure SetWindowState(V: TWindowState);
      procedure SetBorderStyle(V: TFormBorderStyle);
      function  GetClientWidth: integer;
      function  GetClientHeight: integer;
      procedure SetClientWidth(V: integer);
      procedure SetClientHeight(V: integer);
   protected
      procedure SetVisible(V: boolean); override;
      procedure SetCaption(const V: string); override;
      procedure DoCreate; virtual;
      procedure DoShow; virtual;
      procedure DoHide; virtual;
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
   public
      constructor Create(AOwner: TComponent); override;
      constructor CreateNew(AOwner: TComponent; Dummy: integer = 0); virtual;
      destructor Destroy; override;
      procedure AfterConstruction; override;
      procedure BeforeDestruction; override;
      procedure Paint; override;
      procedure Invalidate; override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      function  ClientOffset: TPoint; override;
      function  ClientWidthValue: integer; override;
      function  ClientHeightValue: integer; override;
      function  BackColor: byte; override;
      function  CloseBoxRect: TRect;              { screen coordinates }
      function  ZoomBoxRect: TRect;               { [↑] maximize / restore }
      function  SizeGripRect: TRect;              { the lower right corner }
      { bsSizeable / bsSizeToolWin: the user can resize the window }
      function  Sizeable: boolean;
      function  HasFrame: boolean;
      function  CanFocus: boolean; override;
      procedure Show;
      procedure Hide;
      function  ShowModal: TModalResult;
      procedure Close;
      function  CloseQuery: boolean; virtual;
      procedure Release;
      procedure BringToFront;
      function  IsActive: boolean;
      procedure SelectNext(Backward: boolean);
      procedure PlaceOnScreen;
      { a menu bar in the window, on the row under the title }
      function  StatusBarControl: TStatusBarBase;
      { wsMaximized fills Application.DesktopRect }
   published
      property ModalResult: TModalResult read FModalResult write FModalResult;
      property ActiveControl: TWinControl read FActiveControl write SetActiveControl;
      property Menu: TMenuBarBase read FMenu write SetMenu;
      property BorderStyle: TFormBorderStyle read FBorderStyle write SetBorderStyle default bsSizeable;
      property BorderIcons: TBorderIcons read FBorderIcons write FBorderIcons;
      property Position: TPosition read FPosition write FPosition default poDesigned;
      property WindowState: TWindowState read FWindowState write SetWindowState default wsNormal;
      property KeyPreview: boolean read FKeyPreview write FKeyPreview;
      property ClientWidth: integer read GetClientWidth write SetClientWidth;
      property ClientHeight: integer read GetClientHeight write SetClientHeight;
      property OnCreate: TNotifyEvent read FOnCreate write FOnCreate;
      property OnDestroy: TNotifyEvent read FOnDestroy write FOnDestroy;
      property OnShow: TNotifyEvent read FOnShow write FOnShow;
      property OnHide: TNotifyEvent read FOnHide write FOnHide;
      property OnActivate: TNotifyEvent read FOnActivate write FOnActivate;
      property OnDeactivate: TNotifyEvent read FOnDeactivate write FOnDeactivate;
      property OnPaint: TNotifyEvent read FOnPaint write FOnPaint;
      property OnClose: TCloseEvent read FOnClose write FOnClose;
      property OnCloseQuery: TCloseQueryEvent read FOnCloseQuery write FOnCloseQuery;
   end;
   TCustomFormClass = class of TCustomForm;

   TForm = class(TCustomForm);
   TFormClass = class of TForm;

   TActionList = class;

   { TAction (LCL ActnList): Caption, Hint, ShortCut, Enabled, Checked,  }
   { Visible, OnExecute, OnUpdate; controls and menu items with Action   }
   { := it show its state and run it when clicked                       }
   TAction = class(TComponent)
   private
      FCaption, FHint: string;
      FShortCut: TShortCut;
      FEnabled, FChecked, FVisible, FAutoCheck: boolean;
      FOnExecute, FOnUpdate: TNotifyEvent;
      FActionList: TActionList;
      FClients: TFPList;
      FTag2: integer;
      procedure SetCaption(const V: string);
      procedure SetHint(const V: string);
      procedure SetShortCut(V: TShortCut);
      procedure SetEnabled(V: boolean);
      procedure SetChecked(V: boolean);
      procedure SetVisible(V: boolean);
      procedure SetActionList(V: TActionList);
      procedure Changed;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      { OnExecute (when enabled); false when there is none }
      function  Execute: boolean; virtual;
      { OnUpdate: called when the program is idle, to set Enabled etc. }
      function  Update: boolean; virtual;
      { a client (control, menu item) is told about every change }
      procedure RegisterChanges(Client: TComponent; OnChange: TNotifyEvent);
      procedure UnRegisterChanges(Client: TComponent);
      { in an .lfm an action sits inside its action list }
      function  GetParentComponent: TComponent; override;
      function  HasParent: boolean; override;
      procedure SetParentComponent(Value: TComponent); override;
   published
      property ActionList: TActionList read FActionList write SetActionList;
      property Caption: string read FCaption write SetCaption;
      property Hint: string read FHint write SetHint;
      property ShortCut: TShortCut read FShortCut write SetShortCut default 0;
      property Enabled: boolean read FEnabled write SetEnabled default true;
      property Checked: boolean read FChecked write SetChecked default false;
      property Visible: boolean read FVisible write SetVisible default true;
      property AutoCheck: boolean read FAutoCheck write FAutoCheck default false;
      property OnExecute: TNotifyEvent read FOnExecute write FOnExecute;
      property OnUpdate: TNotifyEvent read FOnUpdate write FOnUpdate;
   end;

   TActionList = class(TComponent)
   private
      FActions: TFPList;
      FOnUpdate: TNotifyEvent;
      function GetAction(I: integer): TAction;
      function GetCount: integer;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      { runs OnUpdate of the list and of each action }
      procedure UpdateActions;
      { an enabled action with this ShortCut runs; true = found }
      function  IsShortCut(SC: TShortCut): boolean;
      property Actions[I: integer]: TAction read GetAction; default;
   published
      property ActionCount: integer read GetCount;
      property OnUpdate: TNotifyEvent read FOnUpdate write FOnUpdate;
   end;

   TApplication = class(TComponent)
   private
      FForms: TFPList;            { z order, last = top }
      FModalStack: TFPList;
      FReleased: TFPList;
      FMainForm: TCustomForm;
      FTerminated: boolean;
      FInitialized: boolean;
      FTitle: string;
      FCanvas: TCanvas;
      FInvalid: TRect;
      FHasInvalid: boolean;
      FCapture: TControl;
      FCaptureButton: TMouseButton;
      FDragForm: TCustomForm;
      FDragDX, FDragDY: integer;
      FDragSize: boolean;          { FDragForm: resizing, not moving }
      FTimers: TFPList;
      FHoldNext: longint;          { next auto repeat of a held button }
      FOnException: TExceptionEvent;
      FKeyMoveForm: TCustomForm;   { Ctrl+F5: moving / sizing with the keys }
      FMouseX, FMouseY: integer;
      FButtons: byte;
      FHWMouseX, FHWMouseY: integer;
      FHWButtons: byte;
      FActionLists: TFPList;
      FOnScreenResize: TNotifyEvent;
      FShowMainForm: boolean;
      FShowHint: boolean;
      FHintPause, FHintHidePause: longint;
      FHintCtl: TControl;
      FHintStart: longint;
      FHintShown, FHintBlocked: boolean;
      FHintRect: TRect;
      FHintText: string;
      FHintMX, FHintMY: integer;
      FLastActive: TCustomForm;
      FOnIdle: TNotifyEvent;
      FMenu: TMenuBarBase;
      FStatusBar: TStatusBarBase;
      FOpenMenu: TOverlayBase;
      FLastClickCtl: TControl;
      FLastClickTime: longint;
      FLastClickX, FLastClickY: integer;
      FHint, FMenuHint: string;
      function  SafePoll: boolean;
      procedure CheckHint;
      procedure CheckTimers;
      procedure CheckHeld;
      procedure SetMenu(V: TMenuBarBase);
      procedure SetStatusBar(V: TStatusBarBase);
      procedure UpdateHint;
      function  ScreenMenuUsable: boolean;
      procedure PaintPending;
      procedure PaintControl(C: TControl; const Clip: TRect);
      procedure UpdateCaret;
      procedure CheckActive;
      function  PollInput: boolean;
      procedure MouseTo(X, Y: integer; Buttons: byte);
      procedure MousePress(Button: TMouseButton; X, Y: integer);
      procedure MouseRelease(Button: TMouseButton; X, Y: integer);
      function  FormAt(X, Y: integer): TCustomForm;
      procedure FreeReleased;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Initialize;
      procedure CreateForm(InstanceClass: TComponentClass; out Reference);
      procedure Run;
      { input and painting until nothing is left; no waiting }
      procedure ProcessMessages;
      { one round of the loop; idles when there was nothing to do }
      procedure HandleMessage;
      procedure Terminate;
      procedure InvalidateRect(const R: TRect);
      procedure InvalidateAll;
      procedure HandleKey(Key: Word; Ch: char; Shift: TShiftState);
      procedure AddForm(F: TCustomForm);
      procedure RemoveForm(F: TCustomForm);
      procedure BringToFront(F: TCustomForm);
      function  ActiveForm: TCustomForm;
      function  TopModal: TCustomForm;
      procedure SetCapture(C: TControl);
      procedure ReleaseCapture;
      procedure ControlGone(C: TControl);
      procedure ReleaseForm(F: TCustomForm);
      function  FormCount: integer;
      procedure Notification(AComponent: TComponent; Operation: TOperation); override;
      { the screen: a menu bar on the top row, a status bar on the bottom   }
      { row; forms live in DesktopRect between them                         }
      function  DesktopRect: TRect;
      { menus call these when they open and close }
      procedure MenuOpened(M: TOverlayBase);
      procedure MenuClosed(M: TOverlayBase);
      { the open menu (nil when none, or when the overlay is a drop-down) }
      function  OpenMenu: TMenuBarBase;
      { what status bars with AutoHint show: the hint of the menu item   }
      { under the bar, else of the focused control                       }
      { Ctrl+F5 on a form: arrows move it, Shift+arrows size it,       }
      { Z maximizes / restores, Enter or Esc ends                      }
      procedure StartKeyMove(F: TCustomForm);
      { the windows: F6 / Shift+F6 go to the next / previous one }
      procedure NextWindow(Backward: boolean);
      { arrange the visible windows (not modal ones) in the desktop }
      procedure Tile;
      procedure Cascade;
      function  GetForm(I: integer): TCustomForm;
      property Forms[I: integer]: TCustomForm read GetForm;
      { the text mode: 80 x 25/28/43/50/60, 132 x 25/43/50/60 (VESA); the  }
      { forms are kept on the screen; OnScreenResize afterwards           }
      function  SetTextMode(Cols, Rows: integer): boolean;
      { around running another program (a compiler, the program you build): }
      { SuspendScreen gives the screen to it (cleared when Clear, the       }
      { cursor shown); ResumeScreen takes it back: the text mode, the mouse,}
      { everything repainted                                               }
      procedure SuspendScreen(Clear: boolean);
      procedure ResumeScreen;
      { the wheel at X, Y (screen); Delta 120 = one notch up }
      procedure MouseWheelAt(X, Y, Delta: integer);
      procedure AddActionList(L: TActionList);
      procedure RemoveActionList(L: TActionList);
      { OnUpdate of every action list (done when the program is idle) }
      procedure UpdateActions;
      procedure HideHint;
      { hint windows: on (default), the wait before (ms), how long it stays }
      procedure AddTimer(T: TTimerBase);
      procedure RemoveTimer(T: TTimerBase);
      { an exception in an event: OnException, else an error message box }
      procedure ShowException(E: Exception);
      { open the pop-up menu of C (or of its parents) at X, Y; true = done }
      function  DoPopup(C: TControl; X, Y: integer): boolean;
   published
      property Menu: TMenuBarBase read FMenu write SetMenu;
      property StatusBar: TStatusBarBase read FStatusBar write SetStatusBar;
      property OpenOverlay: TOverlayBase read FOpenMenu;
      property Hint: string read FHint;
      property MenuHint: string read FMenuHint write FMenuHint;
      property MainForm: TCustomForm read FMainForm;
      property Terminated: boolean read FTerminated;
      property Title: string read FTitle write FTitle;
      property OnIdle: TNotifyEvent read FOnIdle write FOnIdle;
      property OnScreenResize: TNotifyEvent read FOnScreenResize write FOnScreenResize;
      { false: Run does not show the main form (it can stay hidden and hold }
      { the screen's menu, an IDE's desktop); as in the LCL                 }
      property ShowMainForm: boolean read FShowMainForm write FShowMainForm;
      property ShowHint: boolean read FShowHint write FShowHint;
      property HintPause: longint read FHintPause write FHintPause;
      property HintHidePause: longint read FHintHidePause write FHintHidePause;
      property HintVisible: boolean read FHintShown;
      property HintText: string read FHintText;
      property OnException: TExceptionEvent read FOnException write FOnException;
      property MouseX: integer read FMouseX;
      property MouseY: integer read FMouseY;
   end;

   TScreen = class
   private
      function GetForm(I: integer): TCustomForm;
      function GetActiveForm: TCustomForm;
   public
      function Width: integer;
      function Height: integer;
      function FormCount: integer;
      property Forms[I: integer]: TCustomForm read GetForm;
   published
      property ActiveForm: TCustomForm read GetActiveForm;
   end;

var
   Application : TApplication;
   Screen      : TScreen;
   Theme       : TTUITheme;

   { set before Application.Initialize }
   TUITextRows    : integer = 0;      { 0 = keep the DOS mode; 25/28/43/50/60 }
   TUITextCols    : integer = 0;      { 0 = keep; 80 or 132 (VESA) }
   TUIBrightBack  : boolean = true;   { 16 background colours, no blinking }
   TUIMouseCursor : boolean = true;   { draw the mouse cursor }
   TUIInsertMode  : boolean = true;   { edit fields: insert (line cursor) }
   TUIDblClickMS  : longint = 500;    { two clicks within this: a double click }

var
   Clipboard : TClipboard;
   { set by TUISTD: shows an exception in a message box }
   TUIShowExceptionProc : procedure(E: Exception) = nil;

procedure SetColorTheme;
procedure SetMonoTheme;

{ ----------------------------------------------------------------- .lfm forms }
{ A form's controls can come from a Lazarus style .lfm text: the same       }
{ object / property / end syntax, but every Left, Top, Width and Height is   }
{ in character cells, exactly as FPTUI uses them (no pixel scaling).        }
{ TCustomForm.Create looks for the form's .lfm, in this order:              }
{   1. text registered with RegisterFormText (embedded in the program),      }
{   2. a file registered with RegisterFormFile,                              }
{   3. <unit name>.lfm (the Lazarus convention) in the current folder or    }
{      the program's folder.                                                }
{ With none found the form is empty (controls made in code, as before).     }
procedure RegisterFormText(AClass: TClass; const Lfm: string);
procedure RegisterFormFile(AClass: TClass; const FileName: string);
{ read an .lfm into an existing form: its properties, its controls, their   }
{ events (the form's published methods) and references (FocusControl...)   }
procedure ReadFormText(Form: TComponent; const Lfm: string);
procedure ReadFormFile(Form: TComponent; const FileName: string);
{ the .lfm of a form class (empty: none); where it came from }
function  FindFormLfm(AClass: TClass; out Source: string): string;

var
   { true: an unknown property in an .lfm is an error (EReadError); false: }
   { it is skipped and noted in LfmWarnings                                }
   LfmStrict    : boolean = false;
   LfmWarnings  : TStringList = nil;

{ input for tests (and for programs that want to type): queued and handled }
{ before the keyboard and mouse. Key is a VK_ code (0 for a plain char).   }
procedure TUIPostKey(Key: Word; Ch: char; Shift: TShiftState);
procedure TUIPostChar(Ch: char);
procedure TUIPostString(const S: string);
procedure TUIPostMouse(X, Y: integer; Buttons: byte);
{ the wheel at X, Y: Delta 120 per notch, positive = up }
procedure TUIPostWheel(X, Y, Delta: integer);
procedure TUIPostClick(X, Y: integer);    { press and release the left button }

{ BIOS key word to VK code + char + shift (as DUI does it) }
procedure TranslateBiosKey(K: word; BiosShift: byte; out Key: Word;
                           out Ch: char; out Shift: TShiftState);

{ 'short|long' hints: the short part for the hint window, the long one }
{ for the status bar (no '|': both are the whole text)                  }
function  GetShortHint(const Hint: string): string;
function  GetLongHint(const Hint: string): string;

{ the names of the colours / modal results (clRed, mrOk), for .lfm files }
function  IdentToColor(const Ident: string; var Value: longint): boolean;
function  ColorToIdent(Value: longint; var Ident: string): boolean;
function  IdentToModalResult(const Ident: string; var Value: longint): boolean;
function  ModalResultToIdent(Value: longint; var Ident: string): boolean;

function  ShortCut(Key: Word; Shift: TShiftState): TShortCut;
procedure ShortCutToKey(SC: TShortCut; out Key: Word; out Shift: TShiftState);
function  ShortCutToText(SC: TShortCut): string;
function  TextToShortCut(const S: string): TShortCut;

function  RectsIntersect(const A, B: TRect): boolean;
function  IntersectRects(const A, B: TRect): TRect;
function  UnionRects(const A, B: TRect): TRect;
function  PtInRectI(const R: TRect; X, Y: integer): boolean; inline;

implementation

{=============================================================================}
{  helpers                                                                    }
{=============================================================================}

const
   ColorIdents: array[0..22] of TIdentMapEntry = (
      (Value: clBlack; Name: 'clBlack'), (Value: clNavy; Name: 'clNavy'),
      (Value: clGreen; Name: 'clGreen'), (Value: clTeal; Name: 'clTeal'),
      (Value: clMaroon; Name: 'clMaroon'), (Value: clPurple; Name: 'clPurple'),
      (Value: clOlive; Name: 'clOlive'), (Value: clSilver; Name: 'clSilver'),
      (Value: clGray; Name: 'clGray'), (Value: clBlue; Name: 'clBlue'),
      (Value: clLime; Name: 'clLime'), (Value: clAqua; Name: 'clAqua'),
      (Value: clRed; Name: 'clRed'), (Value: clFuchsia; Name: 'clFuchsia'),
      (Value: clYellow; Name: 'clYellow'), (Value: clWhite; Name: 'clWhite'),
      (Value: clCyan; Name: 'clCyan'), (Value: clBrown; Name: 'clBrown'),
      (Value: clLightGray; Name: 'clLightGray'), (Value: clDarkGray; Name: 'clDarkGray'),
      (Value: clMagenta; Name: 'clMagenta'), (Value: clNone; Name: 'clNone'),
      (Value: clDefault; Name: 'clDefault'));
   ColorIdents2: array[0..4] of TIdentMapEntry = (
      (Value: clLightBlue; Name: 'clLightBlue'), (Value: clLightGreen; Name: 'clLightGreen'),
      (Value: clLightCyan; Name: 'clLightCyan'), (Value: clLightRed; Name: 'clLightRed'),
      (Value: clLightMagenta; Name: 'clLightMagenta'));
   ModalIdents: array[0..11] of TIdentMapEntry = (
      (Value: mrNone; Name: 'mrNone'), (Value: mrOk; Name: 'mrOK'),
      (Value: mrCancel; Name: 'mrCancel'), (Value: mrAbort; Name: 'mrAbort'),
      (Value: mrRetry; Name: 'mrRetry'), (Value: mrIgnore; Name: 'mrIgnore'),
      (Value: mrYes; Name: 'mrYes'), (Value: mrNo; Name: 'mrNo'),
      (Value: mrAll; Name: 'mrAll'), (Value: mrNoToAll; Name: 'mrNoToAll'),
      (Value: mrYesToAll; Name: 'mrYesToAll'), (Value: mrClose; Name: 'mrClose'));

function IdentToColor(const Ident: string; var Value: longint): boolean;
begin
   Result := IdentToInt(Ident, Value, ColorIdents) or IdentToInt(Ident, Value, ColorIdents2);
end;

function ColorToIdent(Value: longint; var Ident: string): boolean;
begin
   Result := IntToIdent(Value, Ident, ColorIdents);
end;

function IdentToModalResult(const Ident: string; var Value: longint): boolean;
begin
   Result := IdentToInt(Ident, Value, ModalIdents);
end;

function ModalResultToIdent(Value: longint; var Ident: string): boolean;
begin
   Result := IntToIdent(Value, Ident, ModalIdents);
end;

function GetShortHint(const Hint: string): string;
var i: integer;
begin
   i := Pos('|', Hint);
   if i = 0 then Result := Hint else Result := Copy(Hint, 1, i - 1);
end;

function GetLongHint(const Hint: string): string;
var i: integer;
begin
   i := Pos('|', Hint);
   if i = 0 then Result := Hint else Result := Copy(Hint, i + 1, MaxInt);
end;

function ShortCut(Key: Word; Shift: TShiftState): TShortCut;
begin
   Result := Key and $FF;
   if ssShift in Shift then Result := Result or scShift;
   if ssCtrl in Shift then Result := Result or scCtrl;
   if ssAlt in Shift then Result := Result or scAlt;
end;

procedure ShortCutToKey(SC: TShortCut; out Key: Word; out Shift: TShiftState);
begin
   Key := SC and $FF;
   Shift := [];
   if SC and scShift <> 0 then Include(Shift, ssShift);
   if SC and scCtrl <> 0 then Include(Shift, ssCtrl);
   if SC and scAlt <> 0 then Include(Shift, ssAlt);
end;

function KeyName(K: Word): string;
begin
   case K of
      VK_BACK: Result := 'Bksp';   VK_TAB: Result := 'Tab';
      VK_RETURN: Result := 'Enter'; VK_ESCAPE: Result := 'Esc';
      VK_SPACE: Result := 'Space'; VK_PRIOR: Result := 'PgUp';
      VK_NEXT: Result := 'PgDn';   VK_END: Result := 'End';
      VK_HOME: Result := 'Home';   VK_LEFT: Result := 'Left';
      VK_UP: Result := 'Up';       VK_RIGHT: Result := 'Right';
      VK_DOWN: Result := 'Down';   VK_INSERT: Result := 'Ins';
      VK_DELETE: Result := 'Del';
      VK_F1..VK_F12: Result := 'F' + IntToStr(K - VK_F1 + 1);
      VK_0..VK_9, VK_A..VK_Z: Result := char(K);
   else
      Result := '';
   end;
end;

function ShortCutToText(SC: TShortCut): string;
var n: string;
begin
   Result := '';
   n := KeyName(SC and $FF);
   if n = '' then exit;
   if SC and scShift <> 0 then Result := Result + 'Shift+';
   if SC and scCtrl <> 0 then Result := Result + 'Ctrl+';
   if SC and scAlt <> 0 then Result := Result + 'Alt+';
   Result := Result + n;
end;

function TextToShortCut(const S: string): TShortCut;
var rest, part: string;
    p: integer;
    k: Word;
begin
   Result := 0;
   rest := UpperCase(Trim(S));
   while true do
   begin
      p := Pos('+', rest);
      if (p <= 1) or (p = Length(rest)) then break;
      part := Copy(rest, 1, p - 1);
      if part = 'SHIFT' then Result := Result or scShift
      else if part = 'CTRL' then Result := Result or scCtrl
      else if part = 'ALT' then Result := Result or scAlt
      else exit(0);
      Delete(rest, 1, p);
   end;
   for k := 1 to 255 do
      if (KeyName(k) <> '') and (UpperCase(KeyName(k)) = rest) then
         exit(Result or k);
   Result := 0;
end;

function RectsIntersect(const A, B: TRect): boolean;
begin
   Result := (A.Left < B.Right) and (B.Left < A.Right) and
             (A.Top < B.Bottom) and (B.Top < A.Bottom);
end;

function IntersectRects(const A, B: TRect): TRect;
begin
   Result.Left := A.Left;     if B.Left > Result.Left then Result.Left := B.Left;
   Result.Top := A.Top;       if B.Top > Result.Top then Result.Top := B.Top;
   Result.Right := A.Right;   if B.Right < Result.Right then Result.Right := B.Right;
   Result.Bottom := A.Bottom; if B.Bottom < Result.Bottom then Result.Bottom := B.Bottom;
   if Result.Right < Result.Left then Result.Right := Result.Left;
   if Result.Bottom < Result.Top then Result.Bottom := Result.Top;
end;

function UnionRects(const A, B: TRect): TRect;
begin
   Result.Left := A.Left;     if B.Left < Result.Left then Result.Left := B.Left;
   Result.Top := A.Top;       if B.Top < Result.Top then Result.Top := B.Top;
   Result.Right := A.Right;   if B.Right > Result.Right then Result.Right := B.Right;
   Result.Bottom := A.Bottom; if B.Bottom > Result.Bottom then Result.Bottom := B.Bottom;
end;

function PtInRectI(const R: TRect; X, Y: integer): boolean; inline;
begin
   Result := (X >= R.Left) and (X < R.Right) and (Y >= R.Top) and (Y < R.Bottom);
end;

function IsEmptyR(const R: TRect): boolean; inline;
begin
   Result := (R.Right <= R.Left) or (R.Bottom <= R.Top);
end;

procedure SetColorTheme;
begin
   with Theme do
   begin
      Desktop := MakeAttr(tcLightGray, tcBlue);   DesktopChar := chShadeLight;
      FormBody := MakeAttr(tcBlack, tcLightGray);
      FrameFg := tcBlack;        FrameActiveFg := tcWhite;
      TitleFg := tcBlack;        TitleActiveFg := tcWhite;
      CloseBoxFg := tcLightGreen;
      LabelFg := tcBlack;        LabelHotFg := tcYellow;
      DisabledFg := tcDarkGray;
      ButtonFace := MakeAttr(tcBlack, tcGreen);
      ButtonFocus := MakeAttr(tcWhite, tcGreen);
      ButtonHot := MakeAttr(tcYellow, tcGreen);
      ButtonDisabled := MakeAttr(tcDarkGray, tcGreen);
      ButtonShadowFg := tcBlack;
      ButtonDefaultMarkFg := tcLightCyan;
      Edit := MakeAttr(tcWhite, tcBlue);
      EditFocus := MakeAttr(tcYellow, tcBlue);
      EditSelect := MakeAttr(tcBlack, tcCyan);
      CheckFg := tcBlack;        CheckFocusFg := tcWhite;  CheckHotFg := tcYellow;
      GroupFrameFg := tcBlack;   GroupTitleFg := tcBlack;
      MenuBar := MakeAttr(tcBlack, tcLightGray);
      MenuHot := MakeAttr(tcRed, tcLightGray);
      MenuSel := MakeAttr(tcBlack, tcGreen);
      MenuSelHot := MakeAttr(tcRed, tcGreen);
      MenuDisabled := MakeAttr(tcDarkGray, tcLightGray);
      MenuSelDisabled := MakeAttr(tcDarkGray, tcGreen);
      StatusBar := MakeAttr(tcBlack, tcLightGray);
      StatusHot := MakeAttr(tcRed, tcLightGray);
      List := MakeAttr(tcBlack, tcCyan);
      ListFocusSel := MakeAttr(tcWhite, tcGreen);
      ListSel := MakeAttr(tcWhite, tcBlue);
      ListScroll := MakeAttr(tcBlue, tcCyan);
      ComboButton := MakeAttr(tcBlack, tcGreen);
      Progress := MakeAttr(tcDarkGray, tcLightGray);
      ProgressDone := MakeAttr(tcWhite, tcBlue);
      HintWindow := MakeAttr(tcBlack, tcCyan);
      WindowShadow := true;
      ButtonShadow := true;
   end;
end;

procedure SetMonoTheme;
begin
   with Theme do
   begin
      Desktop := $07;            DesktopChar := chShadeLight;
      FormBody := $07;
      FrameFg := 7;              FrameActiveFg := 15;
      TitleFg := 7;              TitleActiveFg := 15;
      CloseBoxFg := 15;
      LabelFg := 7;              LabelHotFg := 15;
      DisabledFg := 7;
      ButtonFace := $70;         ButtonFocus := $70;
      ButtonHot := $70;          ButtonDisabled := $70;
      ButtonShadowFg := 0;
      ButtonDefaultMarkFg := 15;
      Edit := $70;               EditFocus := $0F;       EditSelect := $70;
      CheckFg := 7;              CheckFocusFg := 15;     CheckHotFg := 15;
      GroupFrameFg := 7;         GroupTitleFg := 15;
      MenuBar := $70;            MenuHot := $70;
      MenuSel := $07;            MenuSelHot := $0F;
      MenuDisabled := $70;       MenuSelDisabled := $07;
      StatusBar := $70;          StatusHot := $70;
      List := $07;               ListFocusSel := $70;    ListSel := $0F;
      ListScroll := $07;         ComboButton := $70;
      Progress := $07;           ProgressDone := $70;
      HintWindow := $70;
      WindowShadow := false;
      ButtonShadow := false;
   end;
end;

{=============================================================================}
{  posted input                                                               }
{=============================================================================}
type
   TPostKind = (pkKey, pkMouse, pkWheel);
   TPosted = record
      Kind: TPostKind;
      Key: Word;
      Ch: char;
      Shift: TShiftState;
      X, Y: integer;
      Buttons: byte;
   end;

var
   PostQueue: array[0..255] of TPosted;
   PostHead, PostTail: integer;

procedure Post(const P: TPosted);
var n: integer;
begin
   n := (PostTail + 1) mod Length(PostQueue);
   if n = PostHead then exit;           { full: dropped }
   PostQueue[PostTail] := P;
   PostTail := n;
end;

procedure TUIPostKey(Key: Word; Ch: char; Shift: TShiftState);
var p: TPosted;
begin
   p.Kind := pkKey; p.Key := Key; p.Ch := Ch; p.Shift := Shift;
   p.X := 0; p.Y := 0; p.Buttons := 0;
   Post(p);
end;

procedure TUIPostChar(Ch: char);
var k: Word;
begin
   case Ch of
      #8:  TUIPostKey(VK_BACK, #0, []);
      #9:  TUIPostKey(VK_TAB, #0, []);
      #13: TUIPostKey(VK_RETURN, #13, []);
      #27: TUIPostKey(VK_ESCAPE, #27, []);
      ' ': TUIPostKey(VK_SPACE, ' ', []);
   else
      if Ch in ['a'..'z', 'A'..'Z', '0'..'9'] then k := Ord(UpCase(Ch)) else k := 0;
      TUIPostKey(k, Ch, []);
   end;
end;

procedure TUIPostString(const S: string);
var i: integer;
begin
   for i := 1 to Length(S) do TUIPostChar(S[i]);
end;

procedure TUIPostWheel(X, Y, Delta: integer);
var p: TPosted;
begin
   p.Kind := pkWheel; p.Key := 0; p.Ch := #0; p.Shift := [];
   p.X := X; p.Y := Y; p.Buttons := 0;
   p.Key := Word(Delta + 32768);
   Post(p);
end;

procedure TUIPostMouse(X, Y: integer; Buttons: byte);
var p: TPosted;
begin
   p.Kind := pkMouse; p.Key := 0; p.Ch := #0; p.Shift := [];
   p.X := X; p.Y := Y; p.Buttons := Buttons;
   Post(p);
end;

procedure TUIPostClick(X, Y: integer);
begin
   TUIPostMouse(X, Y, 0);
   TUIPostMouse(X, Y, 1);
   TUIPostMouse(X, Y, 0);
end;

{ Alt+letter scan codes, QWERTY rows }
const
   AltRow1 = 'QWERTYUIOP';   { scan 16..25 }
   AltRow2 = 'ASDFGHJKL';    { scan 30..38 }
   AltRow3 = 'ZXCVBNM';      { scan 44..50 }

procedure TranslateBiosKey(K: word; BiosShift: byte; out Key: Word;
                           out Ch: char; out Shift: TShiftState);
var sc: byte;
begin
   sc := K shr 8;
   Ch := char(K and $FF);
   Key := 0;
   Shift := [];
   if BiosShift and 3 <> 0 then Include(Shift, ssShift);
   if BiosShift and 4 <> 0 then Include(Shift, ssCtrl);
   if BiosShift and 8 <> 0 then Include(Shift, ssAlt);
   if (Ch = #0) or ((Ch = #$E0) and (sc <> 0)) then
   begin
      Ch := #0;
      case sc of
         15: begin Key := VK_TAB; Include(Shift, ssShift); end;
         16..25: begin Key := Ord(AltRow1[sc - 15]); Include(Shift, ssAlt); end;
         30..38: begin Key := Ord(AltRow2[sc - 29]); Include(Shift, ssAlt); end;
         44..50: begin Key := Ord(AltRow3[sc - 43]); Include(Shift, ssAlt); end;
         120..128: begin Key := VK_0 + 1 + sc - 120; Include(Shift, ssAlt); end;
         129: begin Key := VK_0; Include(Shift, ssAlt); end;
         71: Key := VK_HOME;   72: Key := VK_UP;     73: Key := VK_PRIOR;
         75: Key := VK_LEFT;   77: Key := VK_RIGHT;  79: Key := VK_END;
         80: Key := VK_DOWN;   81: Key := VK_NEXT;   82: Key := VK_INSERT;
         83: Key := VK_DELETE;
         59..68: Key := VK_F1 + sc - 59;
         133, 134: Key := VK_F11 + sc - 133;
         84..93:   begin Key := VK_F1 + sc - 84;  Include(Shift, ssShift); end;
         94..103:  begin Key := VK_F1 + sc - 94;  Include(Shift, ssCtrl); end;
         104..113: begin Key := VK_F1 + sc - 104; Include(Shift, ssAlt); end;
         115: begin Key := VK_LEFT;   Include(Shift, ssCtrl); end;
         116: begin Key := VK_RIGHT;  Include(Shift, ssCtrl); end;
         117: begin Key := VK_END;    Include(Shift, ssCtrl); end;
         118: begin Key := VK_NEXT;   Include(Shift, ssCtrl); end;
         119: begin Key := VK_HOME;   Include(Shift, ssCtrl); end;
         132: begin Key := VK_PRIOR;  Include(Shift, ssCtrl); end;
         141: begin Key := VK_UP;     Include(Shift, ssCtrl); end;
         145: begin Key := VK_DOWN;   Include(Shift, ssCtrl); end;
         146: begin Key := VK_INSERT; Include(Shift, ssCtrl); end;
         147: begin Key := VK_DELETE; Include(Shift, ssCtrl); end;
         148: begin Key := VK_TAB;    Include(Shift, ssCtrl); end;
         14:  begin Key := VK_BACK;   Include(Shift, ssAlt); end;
      end;
      exit;
   end;
   case Ch of
      #8:  begin Key := VK_BACK; Ch := #0; end;
      #9:  begin Key := VK_TAB; Ch := #0; end;
      #13: Key := VK_RETURN;
      #27: Key := VK_ESCAPE;
      ' ': Key := VK_SPACE;
      #1..#7, #10..#12, #14..#26:
         begin
            Key := Ord('A') + Ord(Ch) - 1;
            Include(Shift, ssCtrl);
            Ch := #0;
         end;
      'a'..'z', 'A'..'Z', '0'..'9':
         Key := Ord(UpCase(Ch));
   end;
end;

{=============================================================================}
{  TFont, TBrush, TCanvas                                                     }
{=============================================================================}

constructor TFont.Create;
begin
   inherited Create;
   FColor := clDefault;
end;

procedure TFont.SetColor(V: TColor);
begin
   if V = FColor then exit;
   FColor := V;
   if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TFont.Assign(Source: TPersistent);
begin
   if Source is TFont then Color := TFont(Source).Color
   else inherited Assign(Source);
end;

constructor TBrush.Create;
begin
   inherited Create;
   FColor := clDefault;
end;

constructor TCanvas.Create;
begin
   inherited Create;
   FFont := TFont.Create;
   FBrush := TBrush.Create;
   FClip := Rect(0, 0, 0, 0);
end;

destructor TCanvas.Destroy;
begin
   FFont.Free;
   FBrush.Free;
   inherited Destroy;
end;

procedure TCanvas.Apply; inline;
begin
   ScrSetClip(FClip);
end;

procedure TCanvas.SetOrigin(X, Y: integer);
begin
   FOrgX := X;
   FOrgY := Y;
end;

procedure TCanvas.SetClipRect(const ScreenR: TRect);
begin
   FClip := ScreenR;
end;

function TCanvas.Attr: byte;
var f, b: integer;
begin
   f := FFont.Color; if (f < 0) or (f > 15) then f := AttrFg(Theme.FormBody);
   b := FBrush.Color; if (b < 0) or (b > 15) then b := AttrBg(Theme.FormBody);
   Result := MakeAttr(f, b);
end;

procedure TCanvas.Fill(const R: TRect; Ch: char; A: byte);
begin
   Apply;
   ScrFill(Rect(R.Left + FOrgX, R.Top + FOrgY, R.Right + FOrgX, R.Bottom + FOrgY), Ch, A);
end;

procedure TCanvas.FillRect(const R: TRect);
begin
   Fill(R, ' ', Attr);
end;

procedure TCanvas.FillRect(X1, Y1, X2, Y2: integer);
begin
   Fill(Rect(X1, Y1, X2, Y2), ' ', Attr);
end;

procedure TCanvas.TextOut(X, Y: integer; const S: string);
begin
   Apply;
   ScrPutStr(X + FOrgX, Y + FOrgY, S, Attr);
end;

procedure TCanvas.TextOut(X, Y: integer; const S: string; A: byte);
begin
   Apply;
   ScrPutStr(X + FOrgX, Y + FOrgY, S, A);
end;

function TCanvas.TextOutAccel(X, Y: integer; const S: string; A, HotA: byte): integer;
begin
   Apply;
   Result := ScrPutAccel(X + FOrgX, Y + FOrgY, S, A, HotA);
end;

procedure TCanvas.PutChar(X, Y: integer; Ch: char; A: byte);
begin
   Apply;
   ScrPutChar(X + FOrgX, Y + FOrgY, Ch, A);
end;

procedure TCanvas.Frame(const R: TRect; Style: integer; A: byte);
begin
   Apply;
   ScrBox(Rect(R.Left + FOrgX, R.Top + FOrgY, R.Right + FOrgX, R.Bottom + FOrgY), Style, A);
end;

procedure TCanvas.HLine(X1, X2, Y: integer; Ch: char; A: byte);
begin
   Apply;
   ScrHLine(X1 + FOrgX, X2 + FOrgX, Y + FOrgY, Ch, A);
end;

procedure TCanvas.VLine(X, Y1, Y2: integer; Ch: char; A: byte);
begin
   Apply;
   ScrVLine(X + FOrgX, Y1 + FOrgY, Y2 + FOrgY, Ch, A);
end;

procedure TCanvas.SetAttr(const R: TRect; A: byte);
begin
   Apply;
   ScrSetAttr(Rect(R.Left + FOrgX, R.Top + FOrgY, R.Right + FOrgX, R.Bottom + FOrgY), A);
end;

procedure TCanvas.Shadow(const R: TRect);
begin
   Apply;
   ScrShadow(Rect(R.Left + FOrgX, R.Top + FOrgY, R.Right + FOrgX, R.Bottom + FOrgY));
end;

function TCanvas.TextWidth(const S: string): integer;
begin
   Result := Length(S);
end;

function TCanvas.TextHeight(const S: string): integer;
begin
   Result := 1;
end;

{=============================================================================}
{  TControl                                                                   }
{=============================================================================}

constructor TControl.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FVisible := true;
   FEnabled := true;
   FColor := clDefault;
   FTabOrder := -1;
   FFont := TFont.Create;
   FFont.OnChange := @FontChanged;
   FConstraints := TSizeConstraints.Create;
   FAnchors := [akLeft, akTop];
   FWidth := 10;
   FHeight := 1;
end;

destructor TControl.Destroy;
begin
   if Application <> nil then Application.ControlGone(Self);
   SetAction(nil);
   if FParent <> nil then FParent.RemoveControl(Self);
   FFont.Free;
   FConstraints.Free;
   inherited Destroy;
end;

function TControl.GetParentComponent: TComponent;
begin
   Result := FParent;
end;

function TControl.HasParent: boolean;
begin
   Result := FParent <> nil;
end;

procedure TControl.SetParentComponent(Value: TComponent);
begin
   if Value is TWinControl then SetParent(TWinControl(Value));
end;

procedure TControl.FontChanged(Sender: TObject);
begin
   Invalidate;
end;

procedure TControl.SetFont(V: TFont);
begin
   FFont.Assign(V);
end;

procedure TControl.SetParent(AParent: TWinControl);
begin
   if FParent = AParent then exit;
   if AParent = Self then raise Exception.Create('A control cannot be its own parent');
   Invalidate;
   if FParent <> nil then FParent.RemoveControl(Self);
   FParent := nil;
   if AParent <> nil then AParent.InsertControl(Self);
   Invalidate;
end;

procedure TControl.SetLeft(V: integer);
begin
   SetBounds(V, FTop, FWidth, FHeight);
end;

procedure TControl.SetTop(V: integer);
begin
   SetBounds(FLeft, V, FWidth, FHeight);
end;

procedure TControl.SetWidth(V: integer);
begin
   SetBounds(FLeft, FTop, V, FHeight);
end;

procedure TControl.SetHeight(V: integer);
begin
   SetBounds(FLeft, FTop, FWidth, V);
end;

procedure TControl.SetBounds(ALeft, ATop, AWidth, AHeight: integer);
var resized: boolean;
begin
   with FConstraints do
   begin
      if (FMaxWidth > 0) and (AWidth > FMaxWidth) then AWidth := FMaxWidth;
      if (FMaxHeight > 0) and (AHeight > FMaxHeight) then AHeight := FMaxHeight;
      if AWidth < FMinWidth then AWidth := FMinWidth;
      if AHeight < FMinHeight then AHeight := FMinHeight;
   end;
   if AWidth < 0 then AWidth := 0;
   if AHeight < 0 then AHeight := 0;
   if (ALeft = FLeft) and (ATop = FTop) and (AWidth = FWidth) and (AHeight = FHeight) then exit;
   resized := (AWidth <> FWidth) or (AHeight <> FHeight);
   Invalidate;
   FLeft := ALeft;
   FTop := ATop;
   FWidth := AWidth;
   FHeight := AHeight;
   Invalidate;
   if resized then Resize;
end;

procedure TControl.Resize;
begin
   if Assigned(FOnResize) and not (csDestroying in ComponentState) then FOnResize(Self);
end;

procedure TControl.SetVisible(V: boolean);
var f: TCustomForm;
begin
   if V = FVisible then exit;
   if not V then Invalidate;
   FVisible := V;
   if (FAlign <> alNone) and (FParent <> nil) then FParent.AlignControls;
   if V then Invalidate
   else
   begin
      { a hidden control gives up the focus }
      f := GetParentForm;
      if (f <> nil) and (f.FActiveControl <> nil) and not f.FActiveControl.IsShowing then
         f.SelectNext(false);
   end;
end;

procedure TControl.SetAlign(V: TAlign);
begin
   if V = FAlign then exit;
   FAlign := V;
   if FParent <> nil then FParent.AlignControls;
end;

procedure TControl.SetEnabled(V: boolean);
begin
   if V = FEnabled then exit;
   FEnabled := V;
   Invalidate;
end;

procedure TControl.SetColor(V: TColor);
begin
   if V = FColor then exit;
   FColor := V;
   Invalidate;
end;

procedure TControl.SetCaption(const V: string);
begin
   if V = FCaption then exit;
   FCaption := V;
   TextChanged;
   Invalidate;
end;

procedure TControl.TextChanged;
begin
end;

procedure TControl.Paint;
begin
end;

procedure TControl.Click;
begin
   if Assigned(FOnClick) then FOnClick(Self)
   else if FAction <> nil then FAction.Execute;
end;

procedure TControl.SetAction(V: TAction);
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
      FActionCaption := FCaption;
      FActionHint := FHint;
      ActionChange(V);
   end;
end;

procedure TControl.ActionChanged(Sender: TObject);
begin
   ActionChange(TAction(Sender));
end;

procedure TControl.ActionChange(A: TAction);
begin
   { Caption and Hint follow the action unless the program changed them }
   { (a tool button with a short caption keeps it)                     }
   if (A.Caption <> '') and (FCaption = FActionCaption) then Caption := A.Caption;
   FActionCaption := A.Caption;
   if (A.Hint <> '') and (FHint = FActionHint) then Hint := A.Hint;
   FActionHint := A.Hint;
   Enabled := A.Enabled;
   Visible := A.Visible;
end;

procedure TControl.MouseHeld(X, Y: integer);
begin
end;

function TControl.DoMouseWheel(Shift: TShiftState; WheelDelta: integer; MousePos: TPoint): boolean;
begin
   Result := false;
   if Assigned(FOnMouseWheel) then FOnMouseWheel(Self, Shift, WheelDelta, MousePos, Result);
   if not Result then Result := MouseWheel(WheelDelta);
end;

function TControl.MouseWheel(WheelDelta: integer): boolean;
begin
   Result := false;
end;

procedure TControl.SetPopupMenu(V: TMenuBarBase);
begin
   if V = FPopupMenu then exit;
   if FPopupMenu <> nil then FPopupMenu.RemoveFreeNotification(Self);
   FPopupMenu := V;
   if V <> nil then V.FreeNotification(Self);
end;

procedure TControl.Notification(AComponent: TComponent; Operation: TOperation);
begin
   inherited Notification(AComponent, Operation);
   if (Operation = opRemove) and (AComponent = FPopupMenu) then FPopupMenu := nil;
   if (Operation = opRemove) and (AComponent = FAction) then FAction := nil;
end;

procedure TMenuBarBase.Popup(X, Y: integer);
begin
end;

function TClipboard.HasText: boolean;
begin
   Result := FText <> '';
end;

procedure TControl.DblClick;
begin
   if Assigned(FOnDblClick) then FOnDblClick(Self);
end;

procedure TControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FMouseDownInside := true;
   if Assigned(FOnMouseDown) then FOnMouseDown(Self, Button, Shift, X, Y);
end;

procedure TControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var inside: boolean;
begin
   inside := FMouseDownInside and (X >= 0) and (Y >= 0) and (X < FWidth) and (Y < FHeight);
   FMouseDownInside := false;
   if Assigned(FOnMouseUp) then FOnMouseUp(Self, Button, Shift, X, Y);
   if inside and (Button = mbLeft) and IsEnabledAll then Click;
end;

procedure TControl.MouseMove(Shift: TShiftState; X, Y: integer);
begin
   if Assigned(FOnMouseMove) then FOnMouseMove(Self, Shift, X, Y);
end;

procedure TControl.KeyDown(var Key: Word; Shift: TShiftState);
begin
end;

procedure TControl.KeyPress(var Key: char);
begin
end;

procedure TControl.DoEnter;
begin
   Invalidate;
end;

procedure TControl.DoExit;
begin
   Invalidate;
end;

function TControl.HasAccel: boolean;
begin
   Result := false;
end;

procedure TControl.DoAccel;
begin
end;

function TControl.IsDefault: boolean;
begin
   Result := false;
end;

function TControl.IsCancel: boolean;
begin
   Result := false;
end;

function TControl.WantsChars: boolean;
begin
   Result := false;
end;

function TControl.GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean;
begin
   X := 0; Y := 0; Shape := csHidden;
   Result := false;
end;

function TControl.BackColor: byte;
begin
   if (FColor >= 0) and (FColor <= 15) then Result := FColor
   else if FParent <> nil then Result := FParent.BackColor
   else Result := AttrBg(Theme.FormBody);
end;

function TControl.TextColor(Default: byte): byte;
begin
   if (FFont.Color >= 0) and (FFont.Color <= 15) then Result := FFont.Color
   else Result := Default;
end;

procedure TControl.Invalidate;
var r: TRect;
begin
   if (Application = nil) or (csDestroying in ComponentState) then exit;
   if not IsShowing then exit;
   r := ScreenRect;
   { stay inside the parents' client areas }
   if FParent <> nil then r := IntersectRects(r, FParent.ClientScreenRect);
   Application.InvalidateRect(r);
end;

procedure TControl.Show;
begin
   Visible := true;
end;

procedure TControl.Hide;
begin
   Visible := false;
end;

procedure TControl.BringToFront;
begin
   if FParent = nil then exit;
   FParent.FControls.Remove(Self);
   FParent.FControls.Add(Self);
   Invalidate;
end;

function TControl.ScreenOrigin: TPoint;
var p, sc: TPoint;
begin
   if FParent = nil then Result := Point(FLeft, FTop)
   else
   begin
      p := FParent.ScreenOrigin;
      sc := FParent.ScrollOffset;
      Result := FParent.ClientOffset;
      Result.X := Result.X + p.X + FLeft - sc.X;
      Result.Y := Result.Y + p.Y + FTop - sc.Y;
   end;
end;

function TWinControl.ScrollOffset: TPoint;
begin
   Result := Point(0, 0);
end;

procedure TWinControl.DialogKey(var Key: Word; Shift: TShiftState);
begin
end;

procedure TWinControl.ChildFocused(C: TControl);
begin
end;

function TControl.ScreenRect: TRect;
var p: TPoint;
begin
   p := ScreenOrigin;
   Result := Rect(p.X, p.Y, p.X + FWidth, p.Y + FHeight);
end;

function TControl.ClientOffset: TPoint;
begin
   Result := Point(0, 0);
end;

function TControl.ClientScreenRect: TRect;
var p, o: TPoint;
begin
   p := ScreenOrigin;
   o := ClientOffset;
   Result.Left := p.X + o.X;
   Result.Top := p.Y + o.Y;
   Result.Right := Result.Left + ClientWidthValue;
   Result.Bottom := Result.Top + ClientHeightValue;
end;

function TControl.ClientWidthValue: integer;
begin
   Result := FWidth;
end;

function TControl.ClientHeightValue: integer;
begin
   Result := FHeight;
end;

function TControl.IsShowing: boolean;
var c: TControl;
begin
   c := Self;
   while c <> nil do
   begin
      if not c.FVisible then exit(false);
      if c.FParent = nil then
         exit((c is TCustomForm) or
              ((Application <> nil) and (TControl(Application.FStatusBar) = c)));
      c := c.FParent;
   end;
   Result := false;
end;

function TControl.IsEnabledAll: boolean;
var c: TControl;
begin
   c := Self;
   while c <> nil do
   begin
      if not c.FEnabled then exit(false);
      c := c.FParent;
   end;
   Result := true;
end;

function TControl.CanFocus: boolean;
begin
   Result := false;
end;

function TControl.Focused: boolean;
var f: TCustomForm;
begin
   f := GetParentForm;
   Result := (f <> nil) and (TControl(f.FActiveControl) = Self);
end;

procedure TControl.SetFocus;
begin
end;

function TControl.GetParentForm: TCustomForm;
var c: TControl;
begin
   c := Self;
   while c.FParent <> nil do c := c.FParent;
   if c is TCustomForm then Result := TCustomForm(c) else Result := nil;
end;

function TControl.Canvas: TCanvas;
begin
   Result := Application.FCanvas;
end;

{=============================================================================}
{  TWinControl                                                                }
{=============================================================================}

constructor TWinControl.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FControls := TFPList.Create;
   FTabStop := true;
end;

destructor TWinControl.Destroy;
begin
   { the children are owned by the form, not by us: just let go of them }
   while FControls.Count > 0 do
      TControl(FControls[FControls.Count - 1]).Parent := nil;
   FreeAndNil(FControls);
   inherited Destroy;
end;

function TWinControl.GetControl(I: integer): TControl;
begin
   Result := TControl(FControls[I]);
end;

function TWinControl.GetControlCount: integer;
begin
   if FControls = nil then Result := 0 else Result := FControls.Count;
end;

procedure TWinControl.InsertControl(C: TControl);
var i, n: integer;
begin
   FControls.Add(C);
   C.FParent := Self;
   { a new focusable control goes to the end of the tab order }
   if (C is TWinControl) and (C.FTabOrder < 0) then
   begin
      n := 0;
      for i := 0 to FControls.Count - 2 do
         if TControl(FControls[i]) is TWinControl then inc(n);
      C.FTabOrder := n;
   end;
   AlignControls;
end;

procedure TWinControl.RemoveControl(C: TControl);
var f: TCustomForm;
    a: TControl;
begin
   f := GetParentForm;
   if (f <> nil) and (f.FActiveControl <> nil) then
   begin
      { the focus was on C or inside it }
      a := f.FActiveControl;
      while (a <> nil) and (a <> C) do a := a.FParent;
      if a = C then f.FActiveControl := nil;
   end;
   if FControls <> nil then FControls.Remove(C);
   C.FParent := nil;
   if (C.FAlign <> alNone) and not (csDestroying in ComponentState) then AlignControls;
end;

procedure TWinControl.SetBounds(ALeft, ATop, AWidth, AHeight: integer);
var ow, oh, dw, dh, i, l, t, w, h: integer;
    c: TControl;
begin
   ow := ClientWidthValue;
   oh := ClientHeightValue;
   inherited SetBounds(ALeft, ATop, AWidth, AHeight);
   dw := ClientWidthValue - ow;
   dh := ClientHeightValue - oh;
   { anchored children follow the change of the client size }
   if ((dw <> 0) or (dh <> 0)) and (FControls <> nil) then
      for i := 0 to FControls.Count - 1 do
      begin
         c := TControl(FControls[i]);
         if c.FAlign <> alNone then continue;
         l := c.FLeft; t := c.FTop; w := c.FWidth; h := c.FHeight;
         if akRight in c.FAnchors then
            if akLeft in c.FAnchors then inc(w, dw) else inc(l, dw);
         if akBottom in c.FAnchors then
            if akTop in c.FAnchors then inc(h, dh) else inc(t, dh);
         if (l <> c.FLeft) or (t <> c.FTop) or (w <> c.FWidth) or (h <> c.FHeight) then
            c.SetBounds(l, t, w, h);
      end;
   AlignControls;
end;

procedure TWinControl.AlignControls;
var r: TRect;
    i: integer;
    c: TControl;
    a: TAlign;
begin
   if FAligning or (FControls = nil) then exit;
   FAligning := true;
   try
      r := Rect(0, 0, ClientWidthValue, ClientHeightValue);
      for a := alTop to alClient do
         for i := 0 to FControls.Count - 1 do
         begin
            c := TControl(FControls[i]);
            if (c.FAlign <> a) or not c.FVisible then continue;
            case a of
               alTop:
                  begin
                     c.SetBounds(r.Left, r.Top, r.Right - r.Left, c.FHeight);
                     inc(r.Top, c.FHeight);
                  end;
               alBottom:
                  begin
                     c.SetBounds(r.Left, r.Bottom - c.FHeight, r.Right - r.Left, c.FHeight);
                     dec(r.Bottom, c.FHeight);
                  end;
               alLeft:
                  begin
                     c.SetBounds(r.Left, r.Top, c.FWidth, r.Bottom - r.Top);
                     inc(r.Left, c.FWidth);
                  end;
               alRight:
                  begin
                     c.SetBounds(r.Right - c.FWidth, r.Top, c.FWidth, r.Bottom - r.Top);
                     dec(r.Right, c.FWidth);
                  end;
               alClient:
                  c.SetBounds(r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top);
            end;
         end;
   finally
      FAligning := false;
   end;
end;

function TWinControl.ControlAtPos(SX, SY: integer): TControl;
var i: integer;
    c, d: TControl;
begin
   Result := nil;
   if not PtInRectI(ClientScreenRect, SX, SY) then exit;
   for i := FControls.Count - 1 downto 0 do
   begin
      c := TControl(FControls[i]);
      if not c.FVisible then continue;
      if PtInRectI(c.ScreenRect, SX, SY) then
      begin
         if c is TWinControl then
         begin
            d := TWinControl(c).ControlAtPos(SX, SY);
            if d <> nil then exit(d);
         end;
         exit(c);
      end;
   end;
end;

function TWinControl.CanFocus: boolean;
begin
   Result := FTabStop and IsShowing and IsEnabledAll;
end;

procedure TWinControl.SetFocus;
var f: TCustomForm;
begin
   f := GetParentForm;
   if (f = nil) or not CanFocus then exit;
   if not f.IsActive and (Application <> nil) then f.BringToFront;
   f.SetActiveControl(Self);
end;

function CompareTab(A, B: pointer): integer;
begin
   Result := TControl(A).FTabOrder - TControl(B).FTabOrder;
end;

procedure TWinControl.GetTabList(List: TFPList);
var sorted: TFPList;
    i, j: integer;
    c: TControl;
    tmp: pointer;
begin
   sorted := TFPList.Create;
   try
      for i := 0 to FControls.Count - 1 do
         if TControl(FControls[i]) is TWinControl then sorted.Add(FControls[i]);
      { stable insertion sort by TabOrder (lists are short) }
      for i := 1 to sorted.Count - 1 do
      begin
         j := i;
         while (j > 0) and (CompareTab(sorted[j - 1], sorted[j]) > 0) do
         begin
            tmp := sorted[j - 1]; sorted[j - 1] := sorted[j]; sorted[j] := tmp;
            dec(j);
         end;
      end;
      for i := 0 to sorted.Count - 1 do
      begin
         c := TControl(sorted[i]);
         if not (c.FVisible and c.FEnabled) then continue;
         if c.CanFocus then List.Add(c);
         if TWinControl(c).ControlCount > 0 then TWinControl(c).GetTabList(List);
      end;
   finally
      sorted.Free;
   end;
end;

procedure TWinControl.KeyDown(var Key: Word; Shift: TShiftState);
begin
   if Assigned(FOnKeyDown) then FOnKeyDown(Self, Key, Shift);
end;

procedure TWinControl.KeyPress(var Key: char);
begin
   if Assigned(FOnKeyPress) then FOnKeyPress(Self, Key);
end;

procedure TWinControl.DoEnter;
begin
   inherited DoEnter;
   if Assigned(FOnEnter) then FOnEnter(Self);
end;

procedure TWinControl.DoExit;
begin
   inherited DoExit;
   if Assigned(FOnExit) then FOnExit(Self);
end;

{=============================================================================}
{  TCustomForm                                                                }
{=============================================================================}

constructor TCustomForm.Create(AOwner: TComponent);
var lfm, src: string;
begin
   CreateNew(AOwner);
   { as Lazarus: the form's .lfm (if it has one) makes its controls here; }
   { a constructor of the form class can add more after inherited Create  }
   if (ClassType <> TForm) and (ClassType <> TCustomForm) then
   begin
      lfm := FindFormLfm(ClassType, src);
      if lfm <> '' then ReadFormText(Self, lfm);
   end;
end;

constructor TCustomForm.CreateNew(AOwner: TComponent; Dummy: integer);
begin
   inherited Create(AOwner);
   FVisible := false;
   FBorderStyle := bsSizeable;
   FBorderIcons := [biSystemMenu, biMaximize];
   FConstraints.MinWidth := 12;
   FConstraints.MinHeight := 3;
   FPosition := poDesigned;
   FLeft := 5;
   FTop := 3;
   FWidth := 40;
   FHeight := 12;
   if Application <> nil then Application.AddForm(Self);
end;

destructor TCustomForm.Destroy;
begin
   if Application <> nil then Application.RemoveForm(Self);
   inherited Destroy;
end;

procedure TCustomForm.AfterConstruction;
begin
   inherited AfterConstruction;
   { as in the LCL: OnCreate after the whole constructor chain ran }
   DoCreate;
end;

procedure TCustomForm.BeforeDestruction;
begin
   if Assigned(FOnDestroy) then FOnDestroy(Self);
   inherited BeforeDestruction;
end;

procedure TCustomForm.DoCreate;
begin
   if Assigned(FOnCreate) then FOnCreate(Self);
end;

procedure TCustomForm.DoShow;
begin
   if Assigned(FOnShow) then FOnShow(Self);
end;

procedure TCustomForm.DoHide;
begin
   if Assigned(FOnHide) then FOnHide(Self);
end;

function TCustomForm.HasFrame: boolean;
begin
   Result := FBorderStyle <> bsNone;
end;

function TCustomForm.ClientOffset: TPoint;
begin
   if HasFrame then Result := Point(1, 1) else Result := Point(0, 0);
   if FMenu <> nil then inc(Result.Y);
end;

function TCustomForm.ClientWidthValue: integer;
begin
   if HasFrame then Result := FWidth - 2 else Result := FWidth;
   if Result < 0 then Result := 0;
end;

function TCustomForm.ClientHeightValue: integer;
begin
   if HasFrame then Result := FHeight - 2 else Result := FHeight;
   if FMenu <> nil then dec(Result);
   if Result < 0 then Result := 0;
end;

function TCustomForm.GetClientWidth: integer;
begin
   Result := ClientWidthValue;
end;

function TCustomForm.GetClientHeight: integer;
begin
   Result := ClientHeightValue;
end;

procedure TCustomForm.SetClientWidth(V: integer);
begin
   if HasFrame then inc(V, 2);
   Width := V;
end;

procedure TCustomForm.SetClientHeight(V: integer);
begin
   if HasFrame then inc(V, 2);
   if FMenu <> nil then inc(V);
   Height := V;
end;

function TCustomForm.BackColor: byte;
begin
   if (FColor >= 0) and (FColor <= 15) then Result := FColor
   else Result := AttrBg(Theme.FormBody);
end;

function TCustomForm.CanFocus: boolean;
begin
   Result := false;
end;

procedure TCustomForm.SetMenu(V: TMenuBarBase);
begin
   if V = FMenu then exit;
   if FMenu <> nil then
   begin
      FMenu.CloseMenu;
      FMenu.FForm := nil;
      FMenu.RemoveFreeNotification(Self);
   end;
   FMenu := V;
   if V <> nil then
   begin
      if (Application <> nil) and (Application.FMenu = V) then Application.Menu := nil;
      V.FForm := Self;
      V.FreeNotification(Self);
   end;
   AlignControls;
   Invalidate;
end;

procedure TCustomForm.Notification(AComponent: TComponent; Operation: TOperation);
begin
   inherited Notification(AComponent, Operation);
   if (Operation = opRemove) and (AComponent = FMenu) then
   begin
      FMenu := nil;
      AlignControls;
      Invalidate;
   end;
end;

function TCustomForm.StatusBarControl: TStatusBarBase;
var i: integer;
begin
   for i := ControlCount - 1 downto 0 do
      if (Controls[i] is TStatusBarBase) and Controls[i].Visible then
         exit(TStatusBarBase(Controls[i]));
   Result := nil;
end;

procedure TCustomForm.SetBorderStyle(V: TFormBorderStyle);
begin
   if V = FBorderStyle then exit;
   FBorderStyle := V;
   Invalidate;
end;

procedure TCustomForm.SetCaption(const V: string);
begin
   inherited SetCaption(V);
end;

function TCustomForm.Sizeable: boolean;
begin
   Result := FBorderStyle in [bsSizeable, bsSizeToolWin];
end;

function TCustomForm.ZoomBoxRect: TRect;
begin
   if Sizeable and (biMaximize in FBorderIcons) and (FWidth >= 14) then
      Result := Rect(FLeft + FWidth - 5, FTop, FLeft + FWidth - 2, FTop + 1)
   else
      Result := Rect(0, 0, 0, 0);
end;

function TCustomForm.SizeGripRect: TRect;
begin
   if Sizeable and (FWindowState = wsNormal) then
      Result := Rect(FLeft + FWidth - 1, FTop + FHeight - 1, FLeft + FWidth, FTop + FHeight)
   else
      Result := Rect(0, 0, 0, 0);
end;

procedure TCustomForm.SetWindowState(V: TWindowState);
var d: TRect;
begin
   if V = wsFullScreen then V := wsMaximized;
   if V = wsMinimized then V := wsNormal;      { no icons in text mode }
   if V = FWindowState then exit;
   if V = wsMaximized then
   begin
      FRestoreBounds := Rect(FLeft, FTop, FLeft + FWidth, FTop + FHeight);
      if Application <> nil then d := Application.DesktopRect else d := ScrRect;
      FWindowState := V;
      SetBounds(d.Left, d.Top, d.Right - d.Left, d.Bottom - d.Top);
   end
   else
   begin
      FWindowState := V;
      with FRestoreBounds do SetBounds(Left, Top, Right - Left, Bottom - Top);
   end;
   Invalidate;
end;

function TCustomForm.CloseBoxRect: TRect;
begin
   if HasFrame and (biSystemMenu in FBorderIcons) and (FWidth >= 8) then
      Result := Rect(FLeft + 2, FTop, FLeft + 5, FTop + 1)
   else
      Result := Rect(0, 0, 0, 0);
end;

procedure TCustomForm.Invalidate;
var r: TRect;
begin
   if (Application = nil) or (csDestroying in ComponentState) or not FVisible then exit;
   r := ScreenRect;
   if Theme.WindowShadow and HasFrame then
   begin
      inc(r.Right, 2);
      inc(r.Bottom, 1);
   end;
   Application.InvalidateRect(r);
end;

procedure TCustomForm.Paint;
var bg, body, fa, ta: byte;
    active: boolean;
    s: string;
    x, w: integer;
begin
   bg := BackColor;
   body := MakeAttr(AttrFg(Theme.FormBody), bg);
   Canvas.Fill(Rect(0, 0, FWidth, FHeight), ' ', body);
   if HasFrame then
   begin
      active := IsActive;
      if active then
      begin
         fa := MakeAttr(Theme.FrameActiveFg, bg);
         ta := MakeAttr(Theme.TitleActiveFg, bg);
      end
      else
      begin
         fa := MakeAttr(Theme.FrameFg, bg);
         ta := MakeAttr(Theme.TitleFg, bg);
      end;
      { Ctrl+F5 move / size mode: the frame in the close box colour }
      if (Application <> nil) and (Application.FKeyMoveForm = Self) then
         fa := MakeAttr(Theme.CloseBoxFg, bg);
      if active and (FBorderStyle <> bsSingle) and (FBorderStyle <> bsToolWindow) then
         Canvas.Frame(Rect(0, 0, FWidth, FHeight), 2, fa)
      else
         Canvas.Frame(Rect(0, 0, FWidth, FHeight), 1, fa);
      if Caption <> '' then
      begin
         s := ' ' + Caption + ' ';
         w := FWidth - 12;
         if Length(s) > w then s := Copy(s, 1, w);
         x := (FWidth - Length(s)) div 2;
         if x < 6 then x := 6;
         Canvas.TextOut(x, 0, s, ta);
      end;
      if active and not IsEmptyR(CloseBoxRect) then
         Canvas.TextOut(2, 0, '[' + chSquare + ']', MakeAttr(Theme.CloseBoxFg, bg));
      if active and not IsEmptyR(ZoomBoxRect) then
         if FWindowState = wsMaximized then
            Canvas.TextOut(FWidth - 5, 0, '[' + #18 + ']', MakeAttr(Theme.CloseBoxFg, bg))
         else
            Canvas.TextOut(FWidth - 5, 0, '[' + #24 + ']', MakeAttr(Theme.CloseBoxFg, bg));
      { the size grip: the lower right corner, in the close box colour }
      if active and not IsEmptyR(SizeGripRect) then
         Canvas.PutChar(FWidth - 1, FHeight - 1, #217, MakeAttr(Theme.CloseBoxFg, bg));
   end;
   if FMenu <> nil then FMenu.PaintBar;
   if Assigned(FOnPaint) then FOnPaint(Self);
end;

procedure TCustomForm.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCustomForm.SetActiveControl(C: TWinControl);
var old, p: TWinControl;
begin
   if C = FActiveControl then exit;
   if (C <> nil) and (C.GetParentForm <> Self) then exit;
   old := FActiveControl;
   FActiveControl := C;
   if old <> nil then old.DoExit;
   if (C <> nil) and (FActiveControl = C) then
   begin
      p := C.FParent;
      while (p <> nil) and (p <> Self) do
      begin
         p.ChildFocused(C);
         p := p.FParent;
      end;
      C.DoEnter;
   end;
end;

procedure TCustomForm.SelectNext(Backward: boolean);
var list: TFPList;
    i: integer;
begin
   list := TFPList.Create;
   try
      GetTabList(list);
      if list.Count = 0 then
      begin
         SetActiveControl(nil);
         exit;
      end;
      i := list.IndexOf(FActiveControl);
      if i < 0 then
      begin
         if Backward then i := list.Count - 1 else i := 0;
      end
      else if Backward then
      begin
         dec(i);
         if i < 0 then i := list.Count - 1;
      end
      else
      begin
         inc(i);
         if i >= list.Count then i := 0;
      end;
      SetActiveControl(TWinControl(list[i]));
   finally
      list.Free;
   end;
end;

procedure TCustomForm.PlaceOnScreen;
var cx, cy: integer;
    m: TCustomForm;
    d: TRect;
begin
   if Application <> nil then d := Application.DesktopRect else d := ScrRect;
   case FPosition of
      poScreenCenter, poDesktopCenter:
         begin
            FLeft := d.Left + (d.Right - d.Left - FWidth) div 2;
            FTop := d.Top + (d.Bottom - d.Top - FHeight) div 2;
         end;
      poMainFormCenter, poOwnerFormCenter:
         begin
            m := nil;
            if (FPosition = poOwnerFormCenter) and (Owner is TCustomForm) then
               m := TCustomForm(Owner)
            else if Application <> nil then m := Application.MainForm;
            if (m <> nil) and (m <> Self) and m.FVisible then
            begin
               cx := m.FLeft + m.FWidth div 2;
               cy := m.FTop + m.FHeight div 2;
               FLeft := cx - FWidth div 2;
               FTop := cy - FHeight div 2;
            end
            else
            begin
               FLeft := d.Left + (d.Right - d.Left - FWidth) div 2;
               FTop := d.Top + (d.Bottom - d.Top - FHeight) div 2;
            end;
         end;
   end;
   if FLeft + FWidth > d.Right then FLeft := d.Right - FWidth;
   if FTop + FHeight > d.Bottom then FTop := d.Bottom - FHeight;
   if FLeft < d.Left then FLeft := d.Left;
   if FTop < d.Top then FTop := d.Top;
   FPlaced := true;
end;

procedure TCustomForm.SetVisible(V: boolean);
begin
   if V = FVisible then exit;
   if V then
   begin
      if not FPlaced then PlaceOnScreen;
      FVisible := true;
      if Application <> nil then Application.BringToFront(Self);
      if (FActiveControl = nil) or not FActiveControl.CanFocus then SelectNext(false);
      Invalidate;
      DoShow;
   end
   else
   begin
      Invalidate;
      FVisible := false;
      DoHide;
   end;
end;

procedure TCustomForm.Show;
begin
   Visible := true;
   BringToFront;
end;

procedure TCustomForm.Hide;
begin
   Visible := false;
end;

procedure TCustomForm.BringToFront;
begin
   if Application <> nil then Application.BringToFront(Self);
end;

function TCustomForm.IsActive: boolean;
begin
   Result := (Application <> nil) and (Application.ActiveForm = Self);
end;

function TCustomForm.ShowModal: TModalResult;
var prevFocus: TCustomForm;
begin
   if FVisible then Hide;
   prevFocus := Application.ActiveForm;
   FModal := true;
   FModalResult := mrNone;
   Application.FModalStack.Add(Self);
   try
      Show;
      repeat
         Application.HandleMessage;
         if Application.Terminated and (FModalResult = mrNone) then
            FModalResult := mrCancel;
      until FModalResult <> mrNone;
   finally
      Application.FModalStack.Remove(Self);
      FModal := false;
      Hide;
      if (prevFocus <> nil) and prevFocus.FVisible then prevFocus.BringToFront;
   end;
   Result := FModalResult;
end;

function TCustomForm.CloseQuery: boolean;
begin
   Result := true;
   if Assigned(FOnCloseQuery) then FOnCloseQuery(Self, Result);
end;

procedure TCustomForm.Close;
var closeAction: TCloseAction;
begin
   if not CloseQuery then exit;
   if (Application <> nil) and (Application.MainForm = Self) then closeAction := caFree
   else closeAction := caHide;
   if Assigned(FOnClose) then FOnClose(Self, closeAction);
   if closeAction = caNone then exit;
   if FModal then
   begin
      if FModalResult = mrNone then FModalResult := mrCancel;
      exit;
   end;
   if (Application <> nil) and (Application.MainForm = Self) then
   begin
      Hide;
      Application.Terminate;
      exit;
   end;
   case closeAction of
      caHide, caMinimize: Hide;
      caFree: Release;
   end;
end;

procedure TCustomForm.Release;
begin
   Hide;
   if Application <> nil then Application.ReleaseForm(Self);
end;

{=============================================================================}
{  .lfm forms                                                                 }
{=============================================================================}

var
   FormTextNames, FormTextBodies, FormFiles: TStringList;

procedure RegisterFormText(AClass: TClass; const Lfm: string);
var i: integer;
begin
   i := FormTextNames.IndexOf(AClass.ClassName);
   if i >= 0 then FormTextBodies[i] := Lfm
   else
   begin
      FormTextNames.Add(AClass.ClassName);
      FormTextBodies.Add(Lfm);
   end;
end;

procedure RegisterFormFile(AClass: TClass; const FileName: string);
begin
   FormFiles.Values[AClass.ClassName] := FileName;
end;

function LoadText(const FileName: string): string;
var t: TStringList;
begin
   t := TStringList.Create;
   try
      t.LoadFromFile(FileName);
      Result := t.Text;
   finally
      t.Free;
   end;
end;

function FindFormLfm(AClass: TClass; out Source: string): string;
var i: integer;
    f, u: string;
begin
   Result := '';
   Source := '';
   i := FormTextNames.IndexOf(AClass.ClassName);
   if i >= 0 then
   begin
      Source := '(registered text)';
      exit(FormTextBodies[i]);
   end;
   f := FormFiles.Values[AClass.ClassName];
   if (f <> '') and FileExists(f) then
   begin
      Source := f;
      exit(LoadText(f));
   end;
   { Lazarus: unit1.pas has unit1.lfm }
   u := AClass.UnitName;
   if u = '' then exit;
   for f in [u + '.lfm', LowerCase(u) + '.lfm', UpperCase(u) + '.LFM',
             ExtractFilePath(ParamStr(0)) + u + '.lfm',
             ExtractFilePath(ParamStr(0)) + LowerCase(u) + '.lfm',
             ExtractFilePath(ParamStr(0)) + UpperCase(u) + '.LFM'] do
      if FileExists(f) then
      begin
         Source := f;
         exit(LoadText(f));
      end;
end;

type
   TLfmReaderEvents = class
      procedure PropertyNotFound(Reader: TReader; Instance: TPersistent; var PropName: string;
                                 IsPath: boolean; var Handled, Skip: boolean);
   end;

procedure TLfmReaderEvents.PropertyNotFound(Reader: TReader; Instance: TPersistent;
   var PropName: string; IsPath: boolean; var Handled, Skip: boolean);
var n: string;
begin
   if LfmStrict then exit;
   if Instance is TComponent then n := TComponent(Instance).Name else n := Instance.ClassName;
   LfmWarnings.Add(n + '.' + PropName + ': no such property (skipped)');
   Skip := true;
end;

procedure ReadFormText(Form: TComponent; const Lfm: string);
var src: TStringStream;
    bin: TMemoryStream;
    rd: TReader;
    ev: TLfmReaderEvents;
begin
   src := TStringStream.Create(Lfm);
   bin := TMemoryStream.Create;
   ev := TLfmReaderEvents.Create;
   try
      ObjectTextToBinary(src, bin);
      bin.Position := 0;
      rd := TReader.Create(bin, 4096);
      try
         rd.OnPropertyNotFound := @ev.PropertyNotFound;
         rd.ReadRootComponent(Form);
      finally
         rd.Free;
      end;
   finally
      ev.Free;
      bin.Free;
      src.Free;
   end;
end;

procedure ReadFormFile(Form: TComponent; const FileName: string);
begin
   ReadFormText(Form, LoadText(FileName));
end;

{=============================================================================}
{  TAction, TActionList                                                       }
{=============================================================================}

type
   PActionClient = ^TActionClient;
   TActionClient = record
      Client: TComponent;
      OnChange: TNotifyEvent;
   end;

constructor TAction.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FEnabled := true;
   FVisible := true;
   FClients := TFPList.Create;
end;

destructor TAction.Destroy;
var i: integer;
begin
   SetActionList(nil);
   for i := 0 to FClients.Count - 1 do Dispose(PActionClient(FClients[i]));
   FreeAndNil(FClients);
   inherited Destroy;
end;

procedure TAction.RegisterChanges(Client: TComponent; OnChange: TNotifyEvent);
var p: PActionClient;
begin
   UnRegisterChanges(Client);
   New(p);
   p^.Client := Client;
   p^.OnChange := OnChange;
   FClients.Add(p);
end;

procedure TAction.UnRegisterChanges(Client: TComponent);
var i: integer;
begin
   if FClients = nil then exit;
   for i := FClients.Count - 1 downto 0 do
      if PActionClient(FClients[i])^.Client = Client then
      begin
         Dispose(PActionClient(FClients[i]));
         FClients.Delete(i);
      end;
end;

procedure TAction.Changed;
var i: integer;
begin
   if FClients = nil then exit;
   for i := 0 to FClients.Count - 1 do
      with PActionClient(FClients[i])^ do
         if Assigned(OnChange) then OnChange(Self);
end;

procedure TAction.SetCaption(const V: string);
begin
   if V = FCaption then exit;
   FCaption := V;
   Changed;
end;

procedure TAction.SetHint(const V: string);
begin
   if V = FHint then exit;
   FHint := V;
   Changed;
end;

procedure TAction.SetShortCut(V: TShortCut);
begin
   if V = FShortCut then exit;
   FShortCut := V;
   Changed;
end;

procedure TAction.SetEnabled(V: boolean);
begin
   if V = FEnabled then exit;
   FEnabled := V;
   Changed;
end;

procedure TAction.SetChecked(V: boolean);
begin
   if V = FChecked then exit;
   FChecked := V;
   Changed;
end;

procedure TAction.SetVisible(V: boolean);
begin
   if V = FVisible then exit;
   FVisible := V;
   Changed;
end;

procedure TAction.SetActionList(V: TActionList);
begin
   if V = FActionList then exit;
   if (FActionList <> nil) and (FActionList.FActions <> nil) then FActionList.FActions.Remove(Self);
   FActionList := V;
   if V <> nil then V.FActions.Add(Self);
end;

function TAction.GetParentComponent: TComponent;
begin
   Result := FActionList;
end;

function TAction.HasParent: boolean;
begin
   Result := FActionList <> nil;
end;

procedure TAction.SetParentComponent(Value: TComponent);
begin
   if Value is TActionList then ActionList := TActionList(Value);
end;

function TAction.Execute: boolean;
begin
   Result := false;
   Update;
   if not FEnabled then exit;
   if FAutoCheck then Checked := not FChecked;
   if Assigned(FOnExecute) then
   begin
      FOnExecute(Self);
      Result := true;
   end;
end;

function TAction.Update: boolean;
begin
   Result := Assigned(FOnUpdate);
   if Result then FOnUpdate(Self);
end;

constructor TActionList.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FActions := TFPList.Create;
   if Application <> nil then Application.AddActionList(Self);
end;

destructor TActionList.Destroy;
begin
   if Application <> nil then Application.RemoveActionList(Self);
   while FActions.Count > 0 do TAction(FActions[FActions.Count - 1]).ActionList := nil;
   FreeAndNil(FActions);
   inherited Destroy;
end;

function TActionList.GetAction(I: integer): TAction;
begin
   Result := TAction(FActions[I]);
end;

function TActionList.GetCount: integer;
begin
   Result := FActions.Count;
end;

procedure TActionList.UpdateActions;
var i: integer;
begin
   if Assigned(FOnUpdate) then FOnUpdate(Self);
   for i := 0 to FActions.Count - 1 do GetAction(i).Update;
end;

function TActionList.IsShortCut(SC: TShortCut): boolean;
var i: integer;
    a: TAction;
begin
   Result := false;
   if SC = 0 then exit;
   for i := 0 to FActions.Count - 1 do
   begin
      a := GetAction(i);
      if (a.FShortCut = SC) and a.FVisible then
      begin
         a.Update;
         if a.FEnabled then a.Execute;
         exit(true);
      end;
   end;
end;

{=============================================================================}
{  TApplication                                                               }
{=============================================================================}

constructor TApplication.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FForms := TFPList.Create;
   FModalStack := TFPList.Create;
   FReleased := TFPList.Create;
   FTimers := TFPList.Create;
   FActionLists := TFPList.Create;
   FShowMainForm := true;
   FShowHint := true;
   FHintPause := 800;
   FHintHidePause := 5000;
   FCanvas := TCanvas.Create;
   FMouseX := -1;
   FMouseY := -1;
   FHWMouseX := -1;
   FHWMouseY := -1;
end;

destructor TApplication.Destroy;
begin
   FreeReleased;
   { every form, top first (each one unregisters itself in Destroy), then }
   { anything else the application owns                                  }
   while FForms.Count > 0 do TObject(FForms[FForms.Count - 1]).Free;
   DestroyComponents;
   FForms.Free;
   FreeAndNil(FTimers);
   FreeAndNil(FActionLists);
   FModalStack.Free;
   FReleased.Free;
   FCanvas.Free;
   if FInitialized then ScrDone;
   inherited Destroy;
end;

procedure TApplication.Initialize;
begin
   if FInitialized then exit;
   ScrInit;
   if TUITextCols > 80 then
   begin
      if TUITextRows > 0 then ScrSetMode(TUITextCols, TUITextRows)
      else ScrSetMode(TUITextCols, 25);
   end
   else if TUITextRows = 60 then ScrSetMode(80, 60)
   else if TUITextRows > 0 then ScrSetRows(TUITextRows);
   if HWMono then SetMonoTheme else SetColorTheme;
   if TUIBrightBack and not HWMono then HWSetBlink(false);
   if FStatusBar <> nil then FStatusBar.SetBounds(0, ScrRows - 1, ScrCols, 1);
   FInitialized := true;
   InvalidateAll;
end;

procedure TApplication.CreateForm(InstanceClass: TComponentClass; out Reference);
var instance: TComponent;
begin
   if not FInitialized then Initialize;
   instance := TComponent(InstanceClass.NewInstance);
   TComponent(Reference) := instance;     { set before the constructor, as in the LCL }
   try
      instance.Create(Self);
   except
      TComponent(Reference) := nil;
      raise;
   end;
   if (FMainForm = nil) and (instance is TCustomForm) then
      FMainForm := TCustomForm(instance);
end;

procedure TApplication.Run;
begin
   if not FInitialized then Initialize;
   if FShowMainForm and (FMainForm <> nil) and not FMainForm.Visible then FMainForm.Show;
   repeat
      HandleMessage;
   until FTerminated;
end;

procedure TApplication.Terminate;
begin
   FTerminated := true;
end;

function TApplication.FormCount: integer;
begin
   Result := FForms.Count;
end;

procedure TApplication.AddForm(F: TCustomForm);
begin
   if FForms.IndexOf(F) < 0 then FForms.Add(F);
end;

procedure TApplication.RemoveForm(F: TCustomForm);
var r: TRect;
begin
   { a form freed while it is shown: repaint where it was (F.Invalidate }
   { does nothing any more, the form is being destroyed)                }
   if F.FVisible then
   begin
      r := F.ScreenRect;
      if Theme.WindowShadow and F.HasFrame then
      begin
         inc(r.Right, 2);
         inc(r.Bottom, 1);
      end;
      InvalidateRect(r);
   end;
   FForms.Remove(F);
   FModalStack.Remove(F);
   FReleased.Remove(F);
   if FMainForm = F then FMainForm := nil;
   if FLastActive = F then FLastActive := nil;
   if FDragForm = F then FDragForm := nil;
   if FKeyMoveForm = F then FKeyMoveForm := nil;
   if (FCapture <> nil) and (FCapture.GetParentForm = F) then FCapture := nil;
end;

procedure TApplication.Notification(AComponent: TComponent; Operation: TOperation);
begin
   inherited Notification(AComponent, Operation);
   if Operation <> opRemove then exit;
   if AComponent = FMenu then begin FMenu := nil; InvalidateAll; end;
   if AComponent = FStatusBar then begin FStatusBar := nil; InvalidateAll; end;
   if AComponent = FOpenMenu then FOpenMenu := nil;
end;

procedure TApplication.SetMenu(V: TMenuBarBase);
begin
   if V = FMenu then exit;
   if FMenu <> nil then
   begin
      FMenu.CloseMenu;
      FMenu.RemoveFreeNotification(Self);
   end;
   FMenu := V;
   if V <> nil then
   begin
      if V.FForm <> nil then V.FForm.Menu := nil;
      V.FForm := nil;
      V.FreeNotification(Self);
   end;
   InvalidateAll;
end;

procedure TApplication.SetStatusBar(V: TStatusBarBase);
begin
   if V = FStatusBar then exit;
   if FStatusBar <> nil then FStatusBar.RemoveFreeNotification(Self);
   FStatusBar := V;
   if V <> nil then
   begin
      V.Parent := nil;
      V.FAlign := alNone;
      V.FreeNotification(Self);
      V.SetBounds(0, ScrRows - 1, ScrCols, 1);
   end;
   InvalidateAll;
end;

function TApplication.DesktopRect: TRect;
begin
   Result := ScrRect;
   if FMenu <> nil then inc(Result.Top);
   if (FStatusBar <> nil) and FStatusBar.FVisible then dec(Result.Bottom);
end;

function TApplication.ScreenMenuUsable: boolean;
begin
   Result := (FMenu <> nil) and (TopModal = nil);
end;

function TApplication.OpenMenu: TMenuBarBase;
begin
   if FOpenMenu is TMenuBarBase then Result := TMenuBarBase(FOpenMenu) else Result := nil;
end;

procedure TApplication.MenuOpened(M: TOverlayBase);
begin
   if (FOpenMenu <> nil) and (FOpenMenu <> M) then FOpenMenu.CloseMenu;
   FOpenMenu := M;
   FDragForm := nil;
   FCapture := nil;
end;

procedure TApplication.MenuClosed(M: TOverlayBase);
begin
   if FOpenMenu = M then FOpenMenu := nil;
   FMenuHint := '';
end;

procedure TApplication.AddActionList(L: TActionList);
begin
   if (FActionLists <> nil) and (FActionLists.IndexOf(L) < 0) then FActionLists.Add(L);
end;

procedure TApplication.RemoveActionList(L: TActionList);
begin
   if FActionLists <> nil then FActionLists.Remove(L);
end;

procedure TApplication.UpdateActions;
var i: integer;
begin
   if FActionLists = nil then exit;
   for i := 0 to FActionLists.Count - 1 do TActionList(FActionLists[i]).UpdateActions;
end;

{ the action lists owned by F (or by its owner chain) take the shortcut }
function FormActionShortCut(F: TCustomForm; SC: TShortCut): boolean;
var i: integer;
    l: TActionList;
begin
   Result := false;
   if (F = nil) or (Application.FActionLists = nil) then exit;
   for i := 0 to Application.FActionLists.Count - 1 do
   begin
      l := TActionList(Application.FActionLists[i]);
      if (l.Owner = F) and l.IsShortCut(SC) then exit(true);
   end;
end;

procedure TApplication.HideHint;
begin
   if FHintShown then
   begin
      FHintShown := false;
      InvalidateRect(FHintRect);
   end;
end;

function EffectiveShowHint(C: TControl): boolean;
begin
   Result := false;
   while C <> nil do
   begin
      if C.FShowHint then exit(true);
      C := C.FParent;
   end;
end;

{ the hint window: the mouse rests on a control with a Hint (and ShowHint) }
procedure TApplication.CheckHint;
var f: TCustomForm;
    c: TControl;
    now, w, x, y: integer;
begin
   if not FShowHint or (FOpenMenu <> nil) or (FButtons <> 0) or (FMouseX < 0) or
      (FDragForm <> nil) or (FKeyMoveForm <> nil) then
   begin
      HideHint;
      FHintCtl := nil;
      exit;
   end;
   { after a key the hint waits for the mouse to move }
   if FHintBlocked then
   begin
      if (FMouseX = FHintMX) and (FMouseY = FHintMY) then exit;
      FHintBlocked := false;
   end;
   c := nil;
   f := FormAt(FMouseX, FMouseY);
   if (f <> nil) and ((TopModal = nil) or (f = TopModal)) then
   begin
      c := f.ControlAtPos(FMouseX, FMouseY);
      while (c <> nil) and ((GetShortHint(c.Hint) = '') or not EffectiveShowHint(c)) do c := c.FParent;
   end;
   if (c = nil) and (FHintCtl = nil) then exit;
   { (the clock is read only when a hint is pending) }
   now := HWTicks;
   if c <> FHintCtl then
   begin
      HideHint;
      FHintCtl := c;
      FHintStart := now;
      exit;
   end;
   if c = nil then exit;
   if not FHintShown and (now - FHintStart >= FHintPause) and
      (now - FHintStart < FHintPause + FHintHidePause) then
   begin
      FHintText := GetShortHint(c.Hint);
      w := Length(FHintText) + 2;
      if w > ScrCols then w := ScrCols;
      x := FMouseX;
      y := FMouseY + 1;
      if x + w > ScrCols then x := ScrCols - w;
      if y >= ScrRows then y := FMouseY - 1;
      FHintRect := Rect(x, y, x + w, y + 1);
      FHintShown := true;
      InvalidateRect(FHintRect);
   end
   else if FHintShown and (now - FHintStart >= FHintPause + FHintHidePause) then
      HideHint;
end;

procedure TApplication.AddTimer(T: TTimerBase);
begin
   if (FTimers <> nil) and (FTimers.IndexOf(T) < 0) then FTimers.Add(T);
end;

procedure TApplication.RemoveTimer(T: TTimerBase);
begin
   if FTimers <> nil then FTimers.Remove(T);
end;

procedure TApplication.CheckTimers;
var i: integer;
    now: longint;
begin
   if (FTimers = nil) or (FTimers.Count = 0) then exit;
   now := HWTicks;
   i := 0;
   while i < FTimers.Count do
   begin
      { a timer's OnTimer may free timers: walk the list carefully }
      TTimerBase(FTimers[i]).Tick(now);
      inc(i);
   end;
end;

procedure TApplication.CheckHeld;
var now: longint;
    o: TPoint;
begin
   if (FCapture = nil) or (FButtons and 1 = 0) or (FCaptureButton <> mbLeft) then exit;
   now := HWTicks;
   if now - FHoldNext < 0 then exit;
   FHoldNext := now + 55;
   o := FCapture.ScreenOrigin;
   FCapture.MouseHeld(FMouseX - o.X, FMouseY - o.Y);
end;

function TApplication.GetForm(I: integer): TCustomForm;
begin
   Result := TCustomForm(FForms[I]);
end;

{ the windows Tile / Cascade / F6 work with: visible, framed, not modal }
function WindowList: TFPList;
var i: integer;
    f: TCustomForm;
begin
   Result := TFPList.Create;
   for i := 0 to Application.FormCount - 1 do
   begin
      f := Application.Forms[i];
      if f.Visible and f.HasFrame and (Application.FModalStack.IndexOf(f) < 0) then Result.Add(f);
   end;
end;

procedure TApplication.NextWindow(Backward: boolean);
var l: TFPList;
    f: TCustomForm;
begin
   l := WindowList;
   try
      if l.Count < 2 then exit;
      if Backward then
      begin
         { the top window goes to the bottom }
         f := TCustomForm(l[l.Count - 1]);
         FForms.Remove(f);
         FForms.Insert(0, f);
         f.Invalidate;
         TCustomForm(l[l.Count - 2]).BringToFront;
      end
      else
         TCustomForm(l[0]).BringToFront;   { the bottom one comes up }
      CheckActive;
   finally
      l.Free;
   end;
end;

procedure TApplication.Tile;
var l: TFPList;
    d: TRect;
    n, cols, rows, i, c, r, x1, y1, x2, y2, w, h: integer;
    f: TCustomForm;
begin
   l := WindowList;
   try
      n := l.Count;
      if n = 0 then exit;
      d := DesktopRect;
      cols := 1;
      while cols * cols < n do inc(cols);
      rows := (n + cols - 1) div cols;
      for i := 0 to n - 1 do
      begin
         f := TCustomForm(l[i]);
         if f.FWindowState = wsMaximized then f.WindowState := wsNormal;
         c := i mod cols;
         r := i div cols;
         x1 := d.Left + (d.Right - d.Left) * c div cols;
         x2 := d.Left + (d.Right - d.Left) * (c + 1) div cols;
         y1 := d.Top + (d.Bottom - d.Top) * r div rows;
         y2 := d.Top + (d.Bottom - d.Top) * (r + 1) div rows;
         if f.Sizeable then f.SetBounds(x1, y1, x2 - x1, y2 - y1)
         else
         begin
            { a fixed size window: in the middle of its tile }
            w := f.Width; h := f.Height;
            f.SetBounds(x1 + (x2 - x1 - w) div 2, y1 + (y2 - y1 - h) div 2, w, h);
         end;
         { keep it on the desktop (a window with a large minimum size may }
         { then overlap its neighbour)                                    }
         if f.FLeft + f.FWidth > d.Right then f.Left := d.Right - f.FWidth;
         if f.FTop + f.FHeight > d.Bottom then f.Top := d.Bottom - f.FHeight;
         if f.FLeft < d.Left then f.Left := d.Left;
         if f.FTop < d.Top then f.Top := d.Top;
      end;
      InvalidateAll;
   finally
      l.Free;
   end;
end;

procedure TApplication.Cascade;
var l: TFPList;
    d: TRect;
    n, i, w, h: integer;
    f: TCustomForm;
begin
   l := WindowList;
   try
      n := l.Count;
      if n = 0 then exit;
      d := DesktopRect;
      for i := 0 to n - 1 do
      begin
         f := TCustomForm(l[i]);
         if f.FWindowState = wsMaximized then f.WindowState := wsNormal;
         if f.Sizeable then
         begin
            w := d.Right - d.Left - (n - 1) * 2;
            h := d.Bottom - d.Top - (n - 1);
         end
         else
         begin
            w := f.Width;
            h := f.Height;
         end;
         f.SetBounds(d.Left + i * 2, d.Top + i, w, h);
      end;
      InvalidateAll;
   finally
      l.Free;
   end;
end;

function TApplication.SetTextMode(Cols, Rows: integer): boolean;
var d: TRect;
    i, l, t, w, h: integer;
    f: TCustomForm;
begin
   if not FInitialized then Initialize;
   if FOpenMenu <> nil then FOpenMenu.CloseMenu;
   HideHint;
   if (Cols <= 80) and (Rows <> 60) then Result := ScrSetRows(Rows)
   else Result := ScrSetMode(Cols, Rows);
   if TUIBrightBack and not HWMono then HWSetBlink(false);
   if FStatusBar <> nil then FStatusBar.SetBounds(0, ScrRows - 1, ScrCols, 1);
   d := DesktopRect;
   { every form back on the screen; maximized ones fill the new desktop }
   for i := 0 to FForms.Count - 1 do
   begin
      f := TCustomForm(FForms[i]);
      if f.FWindowState = wsMaximized then
      begin
         f.SetBounds(d.Left, d.Top, d.Right - d.Left, d.Bottom - d.Top);
         continue;
      end;
      l := f.FLeft; t := f.FTop; w := f.FWidth; h := f.FHeight;
      if f.Sizeable then
      begin
         if w > d.Right - d.Left then w := d.Right - d.Left;
         if h > d.Bottom - d.Top then h := d.Bottom - d.Top;
      end;
      if l + w > d.Right then l := d.Right - w;
      if t + h > d.Bottom then t := d.Bottom - h;
      if l < d.Left then l := d.Left;
      if t < d.Top then t := d.Top;
      f.SetBounds(l, t, w, h);
   end;
   FHWMouseX := -1;
   InvalidateAll;
   if Assigned(FOnScreenResize) then FOnScreenResize(Self);
end;

procedure TApplication.SuspendScreen(Clear: boolean);
var blank: array of word;
    i: integer;
begin
   if not FInitialized then Initialize;
   if FOpenMenu <> nil then FOpenMenu.CloseMenu;
   HideHint;
   if Clear then
   begin
      SetLength(blank, ScrCols * ScrRows);
      for i := 0 to High(blank) do blank[i] := $0720;
      HWWriteCells(0, blank[0], Length(blank));
      HWSetCursor(0, 0, csLine);
   end
   else HWSetCursor(0, ScrRows - 1, csLine);
end;

procedure TApplication.ResumeScreen;
var c, r: integer;
begin
   { the other program may have changed the text mode }
   HWCurrentMode(c, r);
   if (c <> ScrCols) or (r <> ScrRows) then SetTextMode(ScrCols, ScrRows)
   else
   begin
      if TUIBrightBack and not HWMono then HWSetBlink(false);
      HWMouseInit;
   end;
   while HWKeyPressed do HWReadKey;
   ScrResend;
   FHWMouseX := -1;
   InvalidateAll;
   ProcessMessages;
end;

procedure TApplication.MouseWheelAt(X, Y, Delta: integer);
var f: TCustomForm;
    c: TControl;
    o: TPoint;
    sh: TShiftState;
    k: byte;
begin
   if (FOpenMenu <> nil) or (Delta = 0) then exit;
   HideHint;
   f := FormAt(X, Y);
   if (f = nil) or ((TopModal <> nil) and (f <> TopModal)) then exit;
   c := f.ControlAtPos(X, Y);
   if c = nil then c := f;
   sh := [];
   k := HWShiftState;
   if k and 3 <> 0 then Include(sh, ssShift);
   if k and 4 <> 0 then Include(sh, ssCtrl);
   { the control under the mouse, else its parents }
   while c <> nil do
   begin
      if c.IsEnabledAll then
      begin
         o := c.ScreenOrigin;
         if c.DoMouseWheel(sh, Delta, Point(X - o.X, Y - o.Y)) then exit;
      end;
      c := c.FParent;
   end;
end;

procedure TApplication.ShowException(E: Exception);
begin
   if Assigned(FOnException) then FOnException(Self, E)
   else if Assigned(TUIShowExceptionProc) then TUIShowExceptionProc(E)
   else HWBeep;
end;

function TApplication.SafePoll: boolean;
begin
   Result := true;
   try
      Result := PollInput;
      CheckTimers;
      CheckHeld;
      CheckHint;
   except
      on E: Exception do ShowException(E);
   end;
end;

function TApplication.DoPopup(C: TControl; X, Y: integer): boolean;
var p: TControl;
begin
   Result := false;
   p := C;
   while (p <> nil) and (p.FPopupMenu = nil) do p := p.FParent;
   if p = nil then exit;
   p.FPopupMenu.PopupComponent := C;
   p.FPopupMenu.Popup(X, Y);
   Result := true;
end;

procedure TApplication.StartKeyMove(F: TCustomForm);
begin
   if (F = nil) or not F.FVisible then exit;
   FKeyMoveForm := F;
   F.Invalidate;
end;

procedure TApplication.UpdateHint;
var f: TCustomForm;
    hc: TControl;
    h: string;
    i: integer;
    sb: TStatusBarBase;
begin
   h := '';
   if FKeyMoveForm <> nil then
   begin
      if FKeyMoveForm.Sizeable then
         h := 'Move: arrows  Size: Shift+arrows  Z: maximize  Enter: done'
      else
         h := 'Move: arrows  Enter: done';
   end
   else if FOpenMenu <> nil then h := FMenuHint
   else
   begin
      f := ActiveForm;
      if (f <> nil) and (f.FActiveControl <> nil) then h := GetLongHint(f.FActiveControl.Hint);
      { the mouse over a control that takes no focus (a tool bar button) }
      { shows its Hint                                                 }
      if (f <> nil) and (FMouseX >= 0) and (FormAt(FMouseX, FMouseY) = f) then
      begin
         hc := f.ControlAtPos(FMouseX, FMouseY);
         if (hc <> nil) and not (hc is TWinControl) and (hc.Hint <> '') then h := GetLongHint(hc.Hint);
      end;
   end;
   if h = FHint then exit;
   FHint := h;
   if FStatusBar <> nil then FStatusBar.Invalidate;
   for i := 0 to FForms.Count - 1 do
   begin
      sb := TCustomForm(FForms[i]).StatusBarControl;
      if sb <> nil then sb.Invalidate;
   end;
end;

procedure TApplication.ReleaseForm(F: TCustomForm);
begin
   if FReleased.IndexOf(F) < 0 then FReleased.Add(F);
end;

procedure TApplication.FreeReleased;
var f: TObject;
begin
   while FReleased.Count > 0 do
   begin
      f := TObject(FReleased[FReleased.Count - 1]);
      FReleased.Delete(FReleased.Count - 1);
      f.Free;
   end;
end;

procedure TApplication.ControlGone(C: TControl);
begin
   if FCapture = C then FCapture := nil;
   if FLastClickCtl = C then FLastClickCtl := nil;
   if FHintCtl = C then
   begin
      HideHint;
      FHintCtl := nil;
   end;
end;

procedure TApplication.SetCapture(C: TControl);
begin
   FCapture := C;
end;

procedure TApplication.ReleaseCapture;
begin
   FCapture := nil;
end;

procedure TApplication.BringToFront(F: TCustomForm);
var top: TCustomForm;
begin
   top := TopModal;
   if (top <> nil) and (top <> F) then exit;   { a modal form stays on top }
   if FForms.IndexOf(F) < 0 then exit;
   if FForms[FForms.Count - 1] <> pointer(F) then
   begin
      FForms.Remove(F);
      FForms.Add(F);
      F.Invalidate;
   end;
   CheckActive;
end;

function TApplication.TopModal: TCustomForm;
begin
   if FModalStack.Count = 0 then Result := nil
   else Result := TCustomForm(FModalStack[FModalStack.Count - 1]);
end;

function TApplication.ActiveForm: TCustomForm;
var i: integer;
begin
   Result := TopModal;
   if Result <> nil then exit;
   for i := FForms.Count - 1 downto 0 do
      if TCustomForm(FForms[i]).FVisible then exit(TCustomForm(FForms[i]));
end;

{ the active form changed: both frames repaint, events fire }
procedure TApplication.CheckActive;
var a: TCustomForm;
begin
   a := ActiveForm;
   if a = FLastActive then exit;
   if FLastActive <> nil then
   begin
      FLastActive.Invalidate;
      if Assigned(FLastActive.FOnDeactivate) then FLastActive.FOnDeactivate(FLastActive);
   end;
   FLastActive := a;
   if a <> nil then
   begin
      a.Invalidate;
      if Assigned(a.FOnActivate) then a.FOnActivate(a);
   end;
end;

function TApplication.FormAt(X, Y: integer): TCustomForm;
var i: integer;
    f: TCustomForm;
begin
   for i := FForms.Count - 1 downto 0 do
   begin
      f := TCustomForm(FForms[i]);
      if f.FVisible and PtInRectI(f.ScreenRect, X, Y) then exit(f);
   end;
   Result := nil;
end;

procedure TApplication.InvalidateRect(const R: TRect);
var c: TRect;
begin
   c := IntersectRects(R, ScrRect);
   if IsEmptyR(c) then exit;
   if FHasInvalid then FInvalid := UnionRects(FInvalid, c)
   else FInvalid := c;
   FHasInvalid := true;
end;

procedure TApplication.InvalidateAll;
begin
   InvalidateRect(ScrRect);
end;

procedure TApplication.PaintControl(C: TControl; const Clip: TRect);
var r, cr: TRect;
    i: integer;
    w: TWinControl;
begin
   if not C.FVisible then exit;
   r := C.ScreenRect;
   cr := IntersectRects(r, Clip);
   if IsEmptyR(cr) then exit;
   FCanvas.SetOrigin(r.Left, r.Top);
   FCanvas.SetClipRect(cr);
   FCanvas.Font.Color := clDefault;
   FCanvas.Brush.Color := clDefault;
   C.Paint;
   if C is TWinControl then
   begin
      w := TWinControl(C);
      if w.ControlCount = 0 then exit;
      cr := IntersectRects(w.ClientScreenRect, cr);
      if IsEmptyR(cr) then exit;
      for i := 0 to w.ControlCount - 1 do
         PaintControl(w.Controls[i], cr);
   end;
end;

procedure TApplication.PaintPending;
var r: TRect;
    i: integer;
    f: TCustomForm;
begin
   CheckActive;
   if not FHasInvalid then exit;
   r := FInvalid;
   FHasInvalid := false;
   { the desktop }
   ScrSetClip(IntersectRects(r, DesktopRect));
   ScrFill(r, Theme.DesktopChar, Theme.Desktop);
   { the forms, bottom to top, each with its shadow }
   for i := 0 to FForms.Count - 1 do
   begin
      f := TCustomForm(FForms[i]);
      if not f.FVisible then continue;
      PaintControl(f, r);
      if Theme.WindowShadow and f.HasFrame then
      begin
         ScrSetClip(r);
         ScrWindowShadow(f.ScreenRect);
      end;
   end;
   { the screen's menu bar and status bar, then any open menu on top }
   if (FMenu <> nil) and RectsIntersect(r, FMenu.BarRect) then
   begin
      ScrSetClip(r);
      FMenu.PaintBar;
   end;
   if (FStatusBar <> nil) and FStatusBar.FVisible then PaintControl(FStatusBar, r);
   if FOpenMenu <> nil then
   begin
      ScrSetClip(r);
      FOpenMenu.PaintPopups;
   end;
   if FHintShown then
   begin
      ScrSetClip(r);
      ScrFill(FHintRect, ' ', Theme.HintWindow);
      ScrPutStr(FHintRect.Left + 1, FHintRect.Top, FHintText, Theme.HintWindow);
   end;
   ScrClipAll;
end;

procedure TApplication.UpdateCaret;
var f: TCustomForm;
    c: TWinControl;
    x, y: integer;
    shape: TCursorShape;
    o: TPoint;
begin
   f := ActiveForm;
   c := nil;
   if (f <> nil) and (FOpenMenu = nil) then c := f.FActiveControl;
   if (c <> nil) and c.IsShowing and c.GetCaretPos(x, y, shape) then
   begin
      o := c.ScreenOrigin;
      x := x + o.X;
      y := y + o.Y;
      if PtInRectI(IntersectRects(c.ScreenRect, ScrRect), x, y) then
      begin
         ScrSetCursor(x, y, shape);
         exit;
      end;
   end;
   ScrSetCursor(0, 0, csHidden);
end;

procedure TApplication.MouseTo(X, Y: integer; Buttons: byte);
var old: byte;
    o: TPoint;
    nl, nt: integer;
    sh: TShiftState;
begin
   old := FButtons;
   if (X <> FMouseX) or (Y <> FMouseY) then
   begin
      FMouseX := X;
      FMouseY := Y;
      ScrSetMouse(X, Y, TUIMouseCursor and HWMousePresent);
      if FOpenMenu <> nil then
      else if (FDragForm <> nil) and FDragSize then
      begin
         { resizing by the corner: inside the desktop, at least the minimum }
         nl := X - FDragForm.FLeft + 1;
         nt := Y - FDragForm.FTop + 1;
         if FDragForm.FLeft + nl > DesktopRect.Right then nl := DesktopRect.Right - FDragForm.FLeft;
         if FDragForm.FTop + nt > DesktopRect.Bottom then nt := DesktopRect.Bottom - FDragForm.FTop;
         FDragForm.SetBounds(FDragForm.FLeft, FDragForm.FTop, nl, nt);
      end
      else if FDragForm <> nil then
      begin
         nl := X - FDragDX;
         nt := Y - FDragDY;
         if nt < DesktopRect.Top then nt := DesktopRect.Top;
         if nt > DesktopRect.Bottom - 1 then nt := DesktopRect.Bottom - 1;
         if nl + FDragForm.FWidth < 4 then nl := 4 - FDragForm.FWidth;
         if nl > ScrCols - 4 then nl := ScrCols - 4;
         FDragForm.Invalidate;
         FDragForm.FLeft := nl;
         FDragForm.FTop := nt;
         FDragForm.Invalidate;
      end
      else if FCapture <> nil then
      begin
         o := FCapture.ScreenOrigin;
         sh := [];
         if Buttons and 1 <> 0 then Include(sh, ssLeft);
         FCapture.MouseMove(sh, X - o.X, Y - o.Y);
      end;
   end;
   FButtons := Buttons;
   if FOpenMenu <> nil then
   begin
      FOpenMenu.MenuMouse((old and 1 = 0) and (Buttons and 1 <> 0),
                          (old and 1 <> 0) and (Buttons and 1 = 0), X, Y, Buttons);
      exit;
   end;
   if (old and 1 = 0) and (Buttons and 1 <> 0) then MousePress(mbLeft, X, Y);
   if (old and 2 = 0) and (Buttons and 2 <> 0) then MousePress(mbRight, X, Y);
   if (old and 1 <> 0) and (Buttons and 1 = 0) then MouseRelease(mbLeft, X, Y);
   if (old and 2 <> 0) and (Buttons and 2 = 0) then MouseRelease(mbRight, X, Y);
end;

procedure TApplication.MousePress(Button: TMouseButton; X, Y: integer);
var f, m: TCustomForm;
    c: TControl;
    o: TPoint;
begin
   if (FCapture <> nil) or (FDragForm <> nil) then exit;
   if FKeyMoveForm <> nil then
   begin
      FKeyMoveForm.Invalidate;
      FKeyMoveForm := nil;
   end;
   m := TopModal;
   { the screen's menu bar and status bar (not while a modal form runs) }
   if (FMenu <> nil) and PtInRectI(FMenu.BarRect, X, Y) then
   begin
      if m <> nil then HWBeep
      else if Button = mbLeft then FMenu.OpenAt(X);
      exit;
   end;
   if (FStatusBar <> nil) and FStatusBar.FVisible and PtInRectI(FStatusBar.ScreenRect, X, Y) then
   begin
      if m <> nil then HWBeep
      else
      begin
         FCapture := FStatusBar;
         FCaptureButton := Button;
         FStatusBar.MouseDown(Button, [], X - FStatusBar.FLeft, Y - FStatusBar.FTop);
      end;
      exit;
   end;
   f := FormAt(X, Y);
   if (m <> nil) and (f <> m) then
   begin
      HWBeep;
      exit;
   end;
   if f = nil then exit;
   if f <> ActiveForm then f.BringToFront;
   if Button = mbLeft then
   begin
      if (f.FMenu <> nil) and PtInRectI(f.FMenu.BarRect, X, Y) then
      begin
         f.FMenu.OpenAt(X);
         exit;
      end;
      if PtInRectI(f.CloseBoxRect, X, Y) then
      begin
         f.Close;
         exit;
      end;
      if PtInRectI(f.ZoomBoxRect, X, Y) then
      begin
         if f.FWindowState = wsMaximized then f.WindowState := wsNormal
         else f.WindowState := wsMaximized;
         exit;
      end;
      if PtInRectI(f.SizeGripRect, X, Y) then
      begin
         FDragForm := f;               { resize by the lower right corner }
         FDragSize := true;
         exit;
      end;
      if f.HasFrame and (Y = f.FTop) then
      begin
         { a double click on the title maximizes / restores }
         if f.Sizeable and (biMaximize in f.FBorderIcons) and (FLastClickCtl = f) and
            (Y = FLastClickY) and (HWTicks - FLastClickTime <= TUIDblClickMS) then
         begin
            FLastClickCtl := nil;
            if f.FWindowState = wsMaximized then f.WindowState := wsNormal
            else f.WindowState := wsMaximized;
            exit;
         end;
         FLastClickCtl := f;
         FLastClickX := X;
         FLastClickY := Y;
         FLastClickTime := HWTicks;
         if f.FWindowState = wsMaximized then exit;
         FDragSize := false;
         FDragForm := f;               { drag the window by its title row }
         FDragDX := X - f.FLeft;
         FDragDY := Y - f.FTop;
         exit;
      end;
   end;
   c := f.ControlAtPos(X, Y);
   if c = nil then c := f;
   if not c.IsEnabledAll then exit;
   if (c is TWinControl) and TWinControl(c).CanFocus then TWinControl(c).SetFocus;
   if (Button = mbRight) and DoPopup(c, X, Y) then exit;
   FHoldNext := HWTicks + 400;
   FCapture := c;
   FCaptureButton := Button;
   o := c.ScreenOrigin;
   c.MouseDown(Button, [], X - o.X, Y - o.Y);
   { a second left click on the same cell soon after: a double click }
   if Button = mbLeft then
   begin
      if (c = FLastClickCtl) and (X = FLastClickX) and (Y = FLastClickY) and
         (HWTicks - FLastClickTime <= TUIDblClickMS) then
      begin
         FLastClickCtl := nil;
         c.DblClick;
      end
      else
      begin
         FLastClickCtl := c;
         FLastClickX := X;
         FLastClickY := Y;
         FLastClickTime := HWTicks;
      end;
   end;
end;

procedure TApplication.MouseRelease(Button: TMouseButton; X, Y: integer);
var c: TControl;
    o: TPoint;
begin
   if FDragForm <> nil then
   begin
      if Button = mbLeft then FDragForm := nil;
      exit;
   end;
   if (FCapture = nil) or (Button <> FCaptureButton) then exit;
   c := FCapture;
   FCapture := nil;
   o := c.ScreenOrigin;
   c.MouseUp(Button, [], X - o.X, Y - o.Y);
end;

{ Alt+letter or (outside text fields) a plain letter: the control with that  }
{ access key acts. One match: it acts; several: the focus moves among them. }
procedure CollectAccel(W: TWinControl; Ch: char; List: TFPList);
var i: integer;
    c: TControl;
begin
   for i := 0 to W.ControlCount - 1 do
   begin
      c := W.Controls[i];
      if not (c.Visible and c.Enabled) then continue;
      if c.HasAccel and (AccelChar(c.Caption) = Ch) then List.Add(c);
      if c is TWinControl then CollectAccel(TWinControl(c), Ch, List);
   end;
end;

function FindAccel(F: TCustomForm; Ch: char): boolean;
var list: TFPList;
    i: integer;
begin
   Result := false;
   if Ch = #0 then exit;
   list := TFPList.Create;
   try
      CollectAccel(F, UpCase(Ch), list);
      if list.Count = 0 then exit;
      Result := true;
      if list.Count = 1 then TControl(list[0]).DoAccel
      else
      begin
         i := list.IndexOf(F.FActiveControl);
         i := (i + 1) mod list.Count;
         if TControl(list[i]) is TWinControl then TWinControl(list[i]).SetFocus;
      end;
   finally
      list.Free;
   end;
end;

function FindFlagged(W: TWinControl; Default: boolean): TControl;
var i: integer;
    c: TControl;
begin
   Result := nil;
   for i := 0 to W.ControlCount - 1 do
   begin
      c := W.Controls[i];
      if not (c.Visible and c.Enabled) then continue;
      if (Default and c.IsDefault) or (not Default and c.IsCancel) then exit(c);
      if c is TWinControl then
      begin
         Result := FindFlagged(TWinControl(c), Default);
         if Result <> nil then exit;
      end;
   end;
end;

procedure TApplication.HandleKey(Key: Word; Ch: char; Shift: TShiftState);
var f: TCustomForm;
    c: TWinControl;
    b: TControl;
    k: Word;
    chr: char;
    sb: TStatusBarBase;
    sc: TShortCut;
    isAltKey: boolean;
    x1, y1: integer;
    csh: TCursorShape;
    p: TWinControl;
begin
   { a key puts the hint window away until the mouse moves }
   if FHintShown or (FHintCtl <> nil) then
   begin
      HideHint;
      FHintBlocked := true;
      FHintMX := FMouseX;
      FHintMY := FMouseY;
      FHintCtl := nil;
   end;
   { an open menu takes every key }
   if FOpenMenu <> nil then
   begin
      FOpenMenu.MenuKey(Key, Ch, Shift);
      exit;
   end;
   { moving / sizing a window with the keys }
   if FKeyMoveForm <> nil then
   begin
      f := FKeyMoveForm;
      case Key of
         VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN:
            begin
               k := Key;
               if ssShift in Shift then
               begin
                  if f.Sizeable and (f.FWindowState = wsNormal) then
                     case k of
                        VK_LEFT:  f.SetBounds(f.FLeft, f.FTop, f.FWidth - 1, f.FHeight);
                        VK_RIGHT: if f.FLeft + f.FWidth < DesktopRect.Right then
                                     f.SetBounds(f.FLeft, f.FTop, f.FWidth + 1, f.FHeight);
                        VK_UP:    f.SetBounds(f.FLeft, f.FTop, f.FWidth, f.FHeight - 1);
                        VK_DOWN:  if f.FTop + f.FHeight < DesktopRect.Bottom then
                                     f.SetBounds(f.FLeft, f.FTop, f.FWidth, f.FHeight + 1);
                     end;
               end
               else if f.FWindowState = wsNormal then
                  case k of
                     VK_LEFT:  if f.FLeft + f.FWidth > 4 then f.Left := f.FLeft - 1;
                     VK_RIGHT: if f.FLeft < ScrCols - 4 then f.Left := f.FLeft + 1;
                     VK_UP:    if f.FTop > DesktopRect.Top then f.Top := f.FTop - 1;
                     VK_DOWN:  if f.FTop < DesktopRect.Bottom - 1 then f.Top := f.FTop + 1;
                  end;
            end;
         VK_Z:
            if f.Sizeable then
               if f.FWindowState = wsMaximized then f.WindowState := wsNormal
               else f.WindowState := wsMaximized;
         VK_RETURN, VK_ESCAPE, VK_F5:
            begin
               FKeyMoveForm := nil;
               f.Invalidate;
            end;
      end;
      exit;
   end;
   f := ActiveForm;
   if (Key = VK_F5) and (Shift = [ssCtrl]) and (f <> nil) and f.HasFrame then
   begin
      StartKeyMove(f);
      exit;
   end;
   isAltKey := (ssAlt in Shift) and
               (((Key >= VK_A) and (Key <= VK_Z)) or ((Key >= VK_0) and (Key <= VK_9)));
   { F6 / Shift+F6: the next / previous window }
   if (Key = VK_F6) and ((Shift = []) or (Shift = [ssShift])) and (TopModal = nil) then
   begin
      NextWindow(Shift = [ssShift]);
      exit;
   end;
   { F10: the form's menu, else the screen's }
   if (Key = VK_F10) and (Shift = []) then
   begin
      if (f <> nil) and (f.FMenu <> nil) then begin f.FMenu.Activate; exit; end;
      if ScreenMenuUsable then begin FMenu.Activate; exit; end;
   end;
   if f = nil then
   begin
      { no form: the screen's menu and status bar still work }
      if isAltKey and ScreenMenuUsable and FMenu.AccelKey(char(Key)) then exit;
      sc := ShortCut(Key, Shift);
      if (Key <> 0) and ScreenMenuUsable and FMenu.ShortCutKey(sc) then exit;
      if (Key <> 0) and (FStatusBar <> nil) then FStatusBar.ShortCutKey(sc);
      exit;
   end;
   c := f.FActiveControl;
   k := Key;
   if (k = VK_F10) and (Shift = [ssShift]) then
   begin
      { the pop-up menu of the focused control, at its text cursor }
      if c <> nil then b := c else b := f;
      if b.GetCaretPos(x1, y1, csh) then
         DoPopup(b, b.ScreenOrigin.X + x1, b.ScreenOrigin.Y + y1 + 1)
      else
         DoPopup(b, b.ScreenOrigin.X + 1, b.ScreenOrigin.Y + 1);
      exit;
   end;
   if k <> 0 then
   begin
      if f.FKeyPreview then f.KeyDown(k, Shift);
      if (k <> 0) and (c <> nil) then c.KeyDown(k, Shift);
      if (k <> 0) and (c <> nil) then
      begin
         p := c.FParent;
         while (p <> nil) and (p <> f) and (k <> 0) do
         begin
            p.DialogKey(k, Shift);
            p := p.FParent;
         end;
      end;
      if k = 0 then exit;
      { Alt+letter: the form's menu bar, its controls, the screen's menu bar }
      if isAltKey then
      begin
         if (f.FMenu <> nil) and f.FMenu.AccelKey(char(k)) then exit;
         if FindAccel(f, char(k)) then exit;
         if ScreenMenuUsable and FMenu.AccelKey(char(k)) then exit;
         { no access key: maybe a shortcut (Alt+X, Alt+G...) }
      end;
      { menu and status bar shortcuts (Ctrl/Alt combinations, F-keys, ...) }
      if (Shift * [ssCtrl, ssAlt] <> []) or (k >= VK_F1) and (k <= VK_F12) or
         (k = VK_INSERT) or (k = VK_DELETE) then
      begin
         sc := ShortCut(k, Shift);
         if (f.FMenu <> nil) and f.FMenu.ShortCutKey(sc) then exit;
         if FormActionShortCut(f, sc) then exit;
         sb := f.StatusBarControl;
         if (sb <> nil) and sb.ShortCutKey(sc) then exit;
         if TopModal = nil then
         begin
            if ScreenMenuUsable and FMenu.ShortCutKey(sc) then exit;
            if (FMainForm <> f) and FormActionShortCut(FMainForm, sc) then exit;
            if (FStatusBar <> nil) and FStatusBar.ShortCutKey(sc) then exit;
         end;
      end;
      if (ssAlt in Shift) and (k = VK_F4) then
      begin
         f.Close;
         exit;
      end;
      case k of
         VK_TAB:
            begin
               f.SelectNext(ssShift in Shift);
               exit;
            end;
         VK_RETURN:
            begin
               b := FindFlagged(f, true);
               if b <> nil then begin b.Click; exit; end;
            end;
         VK_ESCAPE:
            begin
               b := FindFlagged(f, false);
               if b <> nil then begin b.Click; exit; end;
               if f.FModal then begin f.FModalResult := mrCancel; exit; end;
            end;
         VK_DOWN, VK_RIGHT:
            if Shift = [] then begin f.SelectNext(false); exit; end;
         VK_UP, VK_LEFT:
            if Shift = [] then begin f.SelectNext(true); exit; end;
      end;
   end;
   if Ch <> #0 then
   begin
      chr := Ch;
      if f.FKeyPreview then f.KeyPress(chr);
      if (chr <> #0) and (c <> nil) then c.KeyPress(chr);
      if (chr <> #0) and (chr > ' ') and ((c = nil) or not c.WantsChars) then
         FindAccel(f, chr);
   end;
end;

{ one round of input; true = something happened }
function TApplication.PollInput: boolean;
var k: word;
    key: Word;
    ch: char;
    sh: TShiftState;
    mx, my: integer;
    mb: byte;
    wh: integer;
    p: TPosted;
begin
   Result := false;
   { posted input first (tests, macros) }
   while PostHead <> PostTail do
   begin
      p := PostQueue[PostHead];
      PostHead := (PostHead + 1) mod Length(PostQueue);
      Result := true;
      case p.Kind of
         pkKey:   HandleKey(p.Key, p.Ch, p.Shift);
         pkMouse: MouseTo(p.X, p.Y, p.Buttons);
         pkWheel:
            begin
               MouseTo(p.X, p.Y, FButtons);
               MouseWheelAt(p.X, p.Y, integer(p.Key) - 32768);
            end;
      end;
      { a modal form opened by this event runs its own loop: stop here so }
      { that the rest of the queue goes to it in order                    }
      exit;
   end;
   if HWMousePresent then
   begin
      HWMouseRead(mx, my, mb, wh);
      if wh <> 0 then
      begin
         MouseWheelAt(mx, my, -wh * 120);
         Result := true;
      end;
      { only a change of the real mouse counts: posted mouse events are }
      { not undone by a mouse that has not moved                        }
      if (mx <> FHWMouseX) or (my <> FHWMouseY) or (mb <> FHWButtons) then
      begin
         FHWMouseX := mx;
         FHWMouseY := my;
         FHWButtons := mb;
         MouseTo(mx, my, mb);
         Result := true;
      end;
   end;
   while HWKeyPressed do
   begin
      k := HWReadKey;
      TranslateBiosKey(k, HWShiftState, key, ch, sh);
      if (key <> 0) or (ch <> #0) then HandleKey(key, ch, sh);
      Result := true;
      if FTerminated then break;
   end;
end;

procedure TApplication.HandleMessage;
var busy: boolean;
begin
   if not FInitialized then Initialize;
   busy := SafePoll;
   FreeReleased;
   UpdateHint;
   if FHasInvalid or (ActiveForm <> FLastActive) then
   begin
      PaintPending;
      busy := true;
   end;
   UpdateCaret;
   ScrFlush;
   if not busy then
   begin
      UpdateActions;
      if Assigned(FOnIdle) then FOnIdle(Self);
      HWIdle;
   end;
end;

procedure TApplication.ProcessMessages;
var n: integer;
begin
   if not FInitialized then Initialize;
   n := 0;
   repeat
      inc(n);
      if not SafePoll then break;
   until FTerminated or (n > 1000);
   FreeReleased;
   UpdateActions;
   UpdateHint;
   PaintPending;
   UpdateCaret;
   ScrFlush;
end;

{=============================================================================}
{  TScreen                                                                    }
{=============================================================================}

function TScreen.Width: integer;
begin
   Result := ScrCols;
end;

function TScreen.FormCount: integer;
begin
   Result := Application.FormCount;
end;

function TScreen.GetForm(I: integer): TCustomForm;
begin
   Result := Application.Forms[I];
end;

function TScreen.GetActiveForm: TCustomForm;
begin
   Result := Application.ActiveForm;
end;

function TScreen.Height: integer;
begin
   Result := ScrRows;
end;

initialization
   FormTextNames := TStringList.Create;
   FormTextBodies := TStringList.Create;
   FormFiles := TStringList.Create;
   LfmWarnings := TStringList.Create;
   RegisterClasses([TAction, TActionList]);
   RegisterIntegerConsts(TypeInfo(TColor), @IdentToColor, @ColorToIdent);
   RegisterIntegerConsts(TypeInfo(TModalResult), @IdentToModalResult, @ModalResultToIdent);
   SetColorTheme;
   Clipboard := TClipboard.Create;
   Application := TApplication.Create(nil);
   Screen := TScreen.Create;
finalization
   { not FreeAndNil: the forms need Application while they are freed }
   Application.Free;
   Application := nil;
   FreeAndNil(Screen);
   FreeAndNil(Clipboard);
   FreeAndNil(FormTextNames);
   FreeAndNil(FormTextBodies);
   FreeAndNil(FormFiles);
   FreeAndNil(LfmWarnings);
end.
