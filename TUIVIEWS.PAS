{-----------------------------------------------------------------------------}
{  TUIVIEWS - data views, LCL names (ComCtrls):                                }
{     TListView   ViewStyle vsReport (columns with a header) / vsList;        }
{                 Columns (Caption, Width, Alignment), Items (Caption,        }
{                 SubItems, Checked, Data, Selected), ItemIndex, Selected,    }
{                 Checkboxes, GridLines, ShowColumnHeaders, AutoSort,         }
{                 SortColumn, SortDirection, AlphaSort, OnSelectItem,         }
{                 OnColumnClick, OnCompare, OnItemChecked, OnDblClick         }
{     TTreeView   Items (TTreeNodes: Add, AddChild, AddChildFirst, Insert,     }
{                 Clear, Count, Item[], GetFirstNode, FindNodeWithText),      }
{                 TTreeNode (Text, Data, Expanded, HasChildren, Count,        }
{                 Items[], Parent, Level, Index, Expand, Collapse, Delete,    }
{                 GetFirstChild, GetNextSibling, GetPrevSibling, GetNext,     }
{                 MakeVisible, Selected), Selected, ShowLines, ShowRoot,      }
{                 FullExpand, FullCollapse, OnChange, OnChanging,             }
{                 OnExpanding (fill children lazily), OnExpanded,             }
{                 OnCollapsing, OnCollapsed                                    }
{     TTrackBar   Min, Max, Position, Orientation, Frequency, LineSize,       }
{                 PageSize, TickStyle, OnChange                               }
{-----------------------------------------------------------------------------}
unit TUIViews;

{$mode objfpc}{$H+}
{$I TUI.INC}

interface

uses Classes, SysUtils, Types, TUIHW, TUIScrn, TUICtrl, TUIList, TUIGrid;

type
   { ================================================================ list view }
   TListView = class;
   TListItems = class;

   TListColumn = class(TCollectionItem)
   private
      FCaption: string;
      FWidth: integer;
      FAlignment: TAlignment;
      procedure SetCaption(const V: string);
      procedure SetWidth(V: integer);
      procedure SetAlignment(V: TAlignment);
   public
      constructor Create(ACollection: TCollection); override;
   published
      property Caption: string read FCaption write SetCaption;
      property Width: integer read FWidth write SetWidth default 10;
      property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
   end;

   TListColumns = class(TCollection)
   private
      FView: TListView;
      function GetItem(I: integer): TListColumn;
   protected
      procedure Update(Item: TCollectionItem); override;
   public
      constructor Create(AView: TListView);
      function Add: TListColumn;
      property Items[I: integer]: TListColumn read GetItem; default;
   end;

   TListItem = class(TPersistent)
   private
      FOwner: TListItems;
      FCaption: string;
      FSubItems: TStringList;
      FChecked: boolean;
      FData: pointer;
      procedure SetCaption(const V: string);
      procedure SetChecked(V: boolean);
      function  GetIndex: integer;
      function  GetSelected: boolean;
      procedure SetSelected(V: boolean);
      procedure SubChanged(Sender: TObject);
   public
      constructor Create(AOwner: TListItems);
      destructor Destroy; override;
      procedure Delete;
      { column 0 = Caption, 1.. = SubItems }
      function  ColumnText(I: integer): string;
      property Data: pointer read FData write FData;
   published
      property Caption: string read FCaption write SetCaption;
      property SubItems: TStringList read FSubItems;
      property Checked: boolean read FChecked write SetChecked;
      property Index: integer read GetIndex;
      property Selected: boolean read GetSelected write SetSelected;
   end;

   TListItems = class(TPersistent)
   private
      FView: TListView;
      FList: TFPList;
      function  GetItem(I: integer): TListItem;
      function  GetCount: integer;
   public
      constructor Create(AView: TListView);
      destructor Destroy; override;
      function  Add: TListItem;
      function  Insert(Index: integer): TListItem;
      procedure Delete(Index: integer);
      procedure Clear;
      function  IndexOf(Item: TListItem): integer;
      function  FindCaption(const S: string): TListItem;
      property Item[I: integer]: TListItem read GetItem; default;
   published
      property Count: integer read GetCount;
   end;

   TViewStyle = (vsIcon, vsSmallIcon, vsList, vsReport);
   TSortDirection = (sdAscending, sdDescending);
   TSortType = (stNone, stData, stText, stBoth);
   TLVSelectItemEvent = procedure(Sender: TObject; Item: TListItem; Selected: boolean) of object;
   TLVColumnClickEvent = procedure(Sender: TObject; Column: TListColumn) of object;
   TLVCompareEvent = procedure(Sender: TObject; Item1, Item2: TListItem; Data: integer;
                               var Compare: integer) of object;
   TLVCheckedItemEvent = procedure(Sender: TObject; Item: TListItem) of object;

   TListView = class(TWinControl)
   private
      FColumns: TListColumns;
      FItems: TListItems;
      FViewStyle: TViewStyle;
      FItemIndex, FTopIndex, FScrollX: integer;
      FCheckboxes, FGridLines, FShowHeaders, FAutoSort: boolean;
      FSortColumn: integer;
      FSortDirection: TSortDirection;
      FSortType: TSortType;
      FVBar, FHBar: boolean;
      FSizingCol: integer;
      FThumbV: boolean;
      FHoldV: TScrollHit;
      FDownOnItem: boolean;
      FOnSelectItem: TLVSelectItemEvent;
      FOnColumnClick: TLVColumnClickEvent;
      FOnCompare: TLVCompareEvent;
      FOnItemChecked: TLVCheckedItemEvent;
      procedure SetViewStyle(V: TViewStyle);
      procedure SetColumns(V: TListColumns);
      procedure SetItemIndex(V: integer);
      function  GetSelected: TListItem;
      procedure SetSelected(V: TListItem);
      procedure SetCheckboxes(V: boolean);
      procedure SetGridLines(V: boolean);
      procedure SetShowHeaders(V: boolean);
      function  Report: boolean;
      function  HeaderRows: integer;
      function  TotalWidth: integer;
      procedure Measure;
      function  ViewW: integer;
      function  ViewH: integer;
      function  Rows: integer;
      function  MaxTop: integer;
      function  MaxX: integer;
      function  ColLeft(I: integer): integer;      { relative to the scrolled area }
      procedure UserSelect(I: integer);
      procedure ItemsChanged;
      procedure ToggleCheck(I: integer);
      procedure HitV(H: TScrollHit);
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure KeyPress(var Key: char); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseHeld(X, Y: integer); override;
      function  MouseWheel(WheelDelta: integer): boolean; override;
      procedure DblClick; override;
      function  WantsChars: boolean; override;
      function  GetItemAt(X, Y: integer): TListItem;
      procedure AlphaSort;
      procedure Sort;
      procedure MakeCurrentVisible;
      procedure BeginUpdate;
      procedure EndUpdate;
      { a click on a column header sorts by it (again: the other way) }
   published
      property Columns: TListColumns read FColumns write SetColumns;
      property Items: TListItems read FItems;
      property ViewStyle: TViewStyle read FViewStyle write SetViewStyle default vsReport;
      property ItemIndex: integer read FItemIndex write SetItemIndex default -1;
      property Selected: TListItem read GetSelected write SetSelected;
      property TopIndex: integer read FTopIndex;
      property HorzScroll: integer read FScrollX;
      property Checkboxes: boolean read FCheckboxes write SetCheckboxes default false;
      property GridLines: boolean read FGridLines write SetGridLines default false;
      property ShowColumnHeaders: boolean read FShowHeaders write SetShowHeaders default true;
      property AutoSort: boolean read FAutoSort write FAutoSort default true;
      property SortColumn: integer read FSortColumn write FSortColumn default -1;
      property SortDirection: TSortDirection read FSortDirection write FSortDirection default sdAscending;
      property SortType: TSortType read FSortType write FSortType default stNone;
      property OnSelectItem: TLVSelectItemEvent read FOnSelectItem write FOnSelectItem;
      property OnColumnClick: TLVColumnClickEvent read FOnColumnClick write FOnColumnClick;
      property OnCompare: TLVCompareEvent read FOnCompare write FOnCompare;
      property OnItemChecked: TLVCheckedItemEvent read FOnItemChecked write FOnItemChecked;
   end;

   { ================================================================ tree view }
   TTreeView = class;
   TTreeNodes = class;

   TTreeNode = class(TPersistent)
   private
      FOwner: TTreeNodes;
      FParent: TTreeNode;
      FChildren: TFPList;
      FText: string;
      FData: pointer;
      FExpanded, FHasChildren: boolean;
      procedure SetText(const V: string);
      procedure SetExpanded(V: boolean);
      function  GetCount: integer;
      function  GetItem(I: integer): TTreeNode;
      function  GetLevel: integer;
      function  GetIndex: integer;
      function  GetHasChildren: boolean;
      procedure SetHasChildren(V: boolean);
      function  GetSelected: boolean;
      procedure SetSelected(V: boolean);
      function  Siblings: TFPList;
   public
      constructor Create(AOwner: TTreeNodes);
      destructor Destroy; override;
      procedure Expand(Recurse: boolean);
      procedure Collapse(Recurse: boolean);
      procedure Delete;
      procedure DeleteChildren;
      procedure MakeVisible;
      function  GetFirstChild: TTreeNode;
      function  GetLastChild: TTreeNode;
      function  GetNextSibling: TTreeNode;
      function  GetPrevSibling: TTreeNode;
      { the next node in tree order (depth first) }
      function  GetNext: TTreeNode;
      function  IsVisible: boolean;
      { 'Root/Child/Node' }
      function  GetTextPath: string;
      property Data: pointer read FData write FData;
      { also true before the children are added (filled in OnExpanding) }
      property Items[I: integer]: TTreeNode read GetItem; default;
      property Parent: TTreeNode read FParent;
      property Owner: TTreeNodes read FOwner;
   published
      property Text: string read FText write SetText;
      property Expanded: boolean read FExpanded write SetExpanded;
      property HasChildren: boolean read GetHasChildren write SetHasChildren;
      property Count: integer read GetCount;
      property Level: integer read GetLevel;
      property Index: integer read GetIndex;
      property Selected: boolean read GetSelected write SetSelected;
   end;

   TTreeNodes = class(TPersistent)
   private
      FView: TTreeView;
      FRoots: TFPList;
      FUpdate: integer;
      function  GetCount: integer;
      function  GetItem(I: integer): TTreeNode;
      procedure Changed;
      function  InsertAt(AParent: TTreeNode; Index: integer; const S: string): TTreeNode;
   public
      constructor Create(AView: TTreeView);
      destructor Destroy; override;
      { a new last node on Sibling's level (Sibling nil: a root) }
      function  Add(Sibling: TTreeNode; const S: string): TTreeNode;
      function  AddFirst(Sibling: TTreeNode; const S: string): TTreeNode;
      function  AddChild(AParent: TTreeNode; const S: string): TTreeNode;
      function  AddChildFirst(AParent: TTreeNode; const S: string): TTreeNode;
      { a new node before Sibling }
      function  Insert(Sibling: TTreeNode; const S: string): TTreeNode;
      procedure Delete(Node: TTreeNode);
      procedure Clear;
      procedure BeginUpdate;
      procedure EndUpdate;
      function  GetFirstNode: TTreeNode;
      function  FindNodeWithText(const S: string): TTreeNode;
      { all the nodes, in tree order }
      property Item[I: integer]: TTreeNode read GetItem; default;
      property Owner: TTreeView read FView;
   published
      property Count: integer read GetCount;
   end;

   TTVChangedEvent = procedure(Sender: TObject; Node: TTreeNode) of object;
   TTVChangingEvent = procedure(Sender: TObject; Node: TTreeNode; var AllowChange: boolean) of object;
   TTVExpandingEvent = procedure(Sender: TObject; Node: TTreeNode; var AllowExpansion: boolean) of object;
   TTVCollapsingEvent = procedure(Sender: TObject; Node: TTreeNode; var AllowCollapse: boolean) of object;
   TTVExpandedEvent = procedure(Sender: TObject; Node: TTreeNode) of object;

   TTreeView = class(TWinControl)
   private
      FItems: TTreeNodes;
      FSelected: TTreeNode;
      FRows: array of TTreeNode;
      FRowCount: integer;
      FRowsOK: boolean;
      FTopRow, FScrollX: integer;
      FShowLines, FShowRoot, FShowButtons: boolean;
      FVBar, FHBar: boolean;
      FMaxW: integer;
      FThumbV, FThumbH: boolean;
      FHoldV, FHoldH: TScrollHit;
      FOnChange: TTVChangedEvent;
      FOnChanging: TTVChangingEvent;
      FOnExpanding: TTVExpandingEvent;
      FOnCollapsing: TTVCollapsingEvent;
      FOnExpanded, FOnCollapsed: TTVExpandedEvent;
      procedure SetSelected(V: TTreeNode);
      procedure SetShowLines(V: boolean);
      procedure SetShowRoot(V: boolean);
      procedure BuildRows;
      procedure Measure;
      function  ViewW: integer;
      function  ViewH: integer;
      function  MaxTop: integer;
      function  MaxX: integer;
      function  RowOf(N: TTreeNode): integer;
      function  Prefix(N: TTreeNode): string;
      function  ButtonCol(N: TTreeNode): integer;
      procedure NodesChanged;
      procedure UserSelect(N: TTreeNode);
      procedure HitV(H: TScrollHit);
      procedure HitH(H: TScrollHit);
   protected
      function  CanExpand(N: TTreeNode): boolean; virtual;
      function  CanCollapse(N: TTreeNode): boolean; virtual;
      procedure Expanded(N: TTreeNode); virtual;
      procedure Collapsed(N: TTreeNode); virtual;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure KeyPress(var Key: char); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseHeld(X, Y: integer); override;
      function  MouseWheel(WheelDelta: integer): boolean; override;
      procedure DblClick; override;
      function  WantsChars: boolean; override;
      function  GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean; override;
      function  GetNodeAt(X, Y: integer): TTreeNode;
      procedure FullExpand;
      procedure FullCollapse;
      procedure MakeSelectedVisible;
      function  VisibleRowCount: integer;
   published
      property Items: TTreeNodes read FItems;
      property Selected: TTreeNode read FSelected write SetSelected;
      property TopRow: integer read FTopRow;
      property ShowLines: boolean read FShowLines write SetShowLines default true;
      property ShowRoot: boolean read FShowRoot write SetShowRoot default true;
      property ShowButtons: boolean read FShowButtons write FShowButtons default true;
      property OnChange: TTVChangedEvent read FOnChange write FOnChange;
      property OnChanging: TTVChangingEvent read FOnChanging write FOnChanging;
      property OnExpanding: TTVExpandingEvent read FOnExpanding write FOnExpanding;
      property OnExpanded: TTVExpandedEvent read FOnExpanded write FOnExpanded;
      property OnCollapsing: TTVCollapsingEvent read FOnCollapsing write FOnCollapsing;
      property OnCollapsed: TTVExpandedEvent read FOnCollapsed write FOnCollapsed;
   end;

   { =============================================================== track bar }
   TTrackBarOrientation = (trHorizontal, trVertical);
   TTickStyle = (tsNone, tsAuto, tsManual);

   TTrackBar = class(TWinControl)
   private
      FMin, FMax, FPosition, FFrequency, FLineSize, FPageSize: integer;
      FOrientation: TTrackBarOrientation;
      FTickStyle: TTickStyle;
      FDragging: boolean;
      FOnChange: TNotifyEvent;
      procedure SetPosition(V: integer);
      procedure SetMin(V: integer);
      procedure SetMax(V: integer);
      procedure SetOrientation(V: TTrackBarOrientation);
      function  Len: integer;
      function  PosToCell(P: integer): integer;
      function  CellToPos(C: integer): integer;
   public
      constructor Create(AOwner: TComponent); override;
      procedure Paint; override;
      procedure KeyDown(var Key: Word; Shift: TShiftState); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
      procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
      function  GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean; override;
      function  MouseWheel(WheelDelta: integer): boolean; override;
   published
      property Min: integer read FMin write SetMin default 0;
      property Max: integer read FMax write SetMax default 10;
      property Position: integer read FPosition write SetPosition default 0;
      property Frequency: integer read FFrequency write FFrequency default 1;
      property LineSize: integer read FLineSize write FLineSize default 1;
      property PageSize: integer read FPageSize write FPageSize default 2;
      property Orientation: TTrackBarOrientation read FOrientation write SetOrientation default trHorizontal;
      property TickStyle: TTickStyle read FTickStyle write FTickStyle default tsAuto;
      property OnChange: TNotifyEvent read FOnChange write FOnChange;
   end;

implementation

{=============================================================================}
{  TListColumn, TListColumns                                                  }
{=============================================================================}

constructor TListColumn.Create(ACollection: TCollection);
begin
   inherited Create(ACollection);
   FWidth := 10;
end;

procedure TListColumn.SetCaption(const V: string);
begin
   FCaption := V;
   Changed(false);
end;

procedure TListColumn.SetWidth(V: integer);
begin
   if V < 2 then V := 2;
   FWidth := V;
   Changed(false);
end;

procedure TListColumn.SetAlignment(V: TAlignment);
begin
   FAlignment := V;
   Changed(false);
end;

constructor TListColumns.Create(AView: TListView);
begin
   inherited Create(TListColumn);
   FView := AView;
end;

function TListColumns.GetItem(I: integer): TListColumn;
begin
   Result := TListColumn(inherited GetItem(I));
end;

function TListColumns.Add: TListColumn;
begin
   Result := TListColumn(inherited Add);
end;

procedure TListColumns.Update(Item: TCollectionItem);
begin
   if FView <> nil then FView.Invalidate;
end;

{=============================================================================}
{  TListItem, TListItems                                                      }
{=============================================================================}

constructor TListItem.Create(AOwner: TListItems);
begin
   inherited Create;
   FOwner := AOwner;
   FSubItems := TStringList.Create;
   FSubItems.OnChange := @SubChanged;
end;

destructor TListItem.Destroy;
begin
   FSubItems.OnChange := nil;
   FSubItems.Free;
   inherited Destroy;
end;

procedure TListItem.SubChanged(Sender: TObject);
begin
   if (FOwner <> nil) and (FOwner.FView <> nil) then FOwner.FView.Invalidate;
end;

procedure TListItem.SetCaption(const V: string);
begin
   FCaption := V;
   SubChanged(nil);
end;

procedure TListItem.SetChecked(V: boolean);
begin
   FChecked := V;
   SubChanged(nil);
end;

function TListItem.GetIndex: integer;
begin
   Result := FOwner.FList.IndexOf(Self);
end;

function TListItem.GetSelected: boolean;
begin
   Result := FOwner.FView.FItemIndex = GetIndex;
end;

procedure TListItem.SetSelected(V: boolean);
begin
   if V then FOwner.FView.ItemIndex := GetIndex
   else if GetSelected then FOwner.FView.ItemIndex := -1;
end;

procedure TListItem.Delete;
begin
   FOwner.Delete(GetIndex);
end;

function TListItem.ColumnText(I: integer): string;
begin
   if I = 0 then Result := FCaption
   else if I - 1 < FSubItems.Count then Result := FSubItems[I - 1]
   else Result := '';
end;

constructor TListItems.Create(AView: TListView);
begin
   inherited Create;
   FView := AView;
   FList := TFPList.Create;
end;

destructor TListItems.Destroy;
begin
   Clear;
   FList.Free;
   inherited Destroy;
end;

function TListItems.GetItem(I: integer): TListItem;
begin
   Result := TListItem(FList[I]);
end;

function TListItems.GetCount: integer;
begin
   Result := FList.Count;
end;

function TListItems.Add: TListItem;
begin
   Result := Insert(FList.Count);
end;

function TListItems.Insert(Index: integer): TListItem;
begin
   Result := TListItem.Create(Self);
   FList.Insert(Index, Result);
   FView.ItemsChanged;
end;

procedure TListItems.Delete(Index: integer);
begin
   if (Index < 0) or (Index >= FList.Count) then exit;
   TListItem(FList[Index]).Free;
   FList.Delete(Index);
   if FView.FItemIndex > Index then dec(FView.FItemIndex)
   else if FView.FItemIndex = Index then
      if FView.FItemIndex >= FList.Count then FView.FItemIndex := FList.Count - 1;
   FView.ItemsChanged;
end;

procedure TListItems.Clear;
var i: integer;
begin
   for i := 0 to FList.Count - 1 do TListItem(FList[i]).Free;
   FList.Clear;
   if FView <> nil then
   begin
      FView.FItemIndex := -1;
      FView.ItemsChanged;
   end;
end;

function TListItems.IndexOf(Item: TListItem): integer;
begin
   Result := FList.IndexOf(Item);
end;

function TListItems.FindCaption(const S: string): TListItem;
var i: integer;
begin
   for i := 0 to FList.Count - 1 do
      if CompareText(GetItem(i).FCaption, S) = 0 then exit(GetItem(i));
   Result := nil;
end;

{=============================================================================}
{  TListView                                                                  }
{=============================================================================}

constructor TListView.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FColumns := TListColumns.Create(Self);
   FItems := TListItems.Create(Self);
   FViewStyle := vsReport;
   FItemIndex := -1;
   FShowHeaders := true;
   FAutoSort := true;
   FSortColumn := -1;
   FSizingCol := -1;
   FWidth := 40;
   FHeight := 10;
end;

destructor TListView.Destroy;
begin
   FreeAndNil(FItems);
   FColumns.FView := nil;
   FreeAndNil(FColumns);
   inherited Destroy;
end;

procedure TListView.BeginUpdate;
begin
end;

procedure TListView.EndUpdate;
begin
   ItemsChanged;
end;

procedure TListView.ItemsChanged;
begin
   if FItems = nil then exit;
   if FItemIndex >= FItems.Count then FItemIndex := FItems.Count - 1;
   Measure;
   if FTopIndex > MaxTop then FTopIndex := MaxTop;
   Invalidate;
end;

procedure TListView.SetColumns(V: TListColumns);
begin
   FColumns.Assign(V);
end;

procedure TListView.SetViewStyle(V: TViewStyle);
begin
   if V = FViewStyle then exit;
   FViewStyle := V;
   FScrollX := 0;
   ItemsChanged;
end;

procedure TListView.SetCheckboxes(V: boolean);
begin
   FCheckboxes := V;
   Invalidate;
end;

procedure TListView.SetGridLines(V: boolean);
begin
   FGridLines := V;
   Invalidate;
end;

procedure TListView.SetShowHeaders(V: boolean);
begin
   FShowHeaders := V;
   ItemsChanged;
end;

function TListView.Report: boolean;
begin
   Result := (FViewStyle = vsReport) and (FColumns.Count > 0);
end;

function TListView.HeaderRows: integer;
begin
   if Report and FShowHeaders then Result := 1 else Result := 0;
end;

function TListView.TotalWidth: integer;
var i: integer;
begin
   Result := 0;
   if Report then
      for i := 0 to FColumns.Count - 1 do inc(Result, FColumns[i].Width);
end;

procedure TListView.Measure;
begin
   FVBar := FItems.Count > Height - HeaderRows;
   FHBar := Report and (TotalWidth > Width - ord(FVBar));
   if FHBar and not FVBar then FVBar := FItems.Count > Height - HeaderRows - 1;
   if FScrollX > MaxX then FScrollX := MaxX;
   if FScrollX < 0 then FScrollX := 0;
end;

function TListView.ViewW: integer;
begin
   Result := Width - ord(FVBar);
end;

function TListView.ViewH: integer;
begin
   Result := Height - ord(FHBar);
end;

function TListView.Rows: integer;
begin
   Result := ViewH - HeaderRows;
   if Result < 1 then Result := 1;
end;

function TListView.MaxTop: integer;
begin
   Result := FItems.Count - Rows;
   if Result < 0 then Result := 0;
end;

function TListView.MaxX: integer;
begin
   Result := TotalWidth - ViewW;
   if Result < 0 then Result := 0;
end;

function TListView.ColLeft(I: integer): integer;
var j: integer;
begin
   Result := 0;
   for j := 0 to I - 1 do inc(Result, FColumns[j].Width);
end;

procedure TListView.MakeCurrentVisible;
begin
   Measure;
   if FItemIndex < 0 then exit;
   if FItemIndex < FTopIndex then FTopIndex := FItemIndex;
   if FItemIndex >= FTopIndex + Rows then FTopIndex := FItemIndex - Rows + 1;
end;

procedure TListView.SetItemIndex(V: integer);
var old: integer;
begin
   if V >= FItems.Count then V := FItems.Count - 1;
   if V < -1 then V := -1;
   if V = FItemIndex then exit;
   old := FItemIndex;
   FItemIndex := V;
   MakeCurrentVisible;
   Invalidate;
   if Assigned(FOnSelectItem) then
   begin
      if old >= 0 then FOnSelectItem(Self, FItems[old], false);
      if V >= 0 then FOnSelectItem(Self, FItems[V], true);
   end;
end;

procedure TListView.UserSelect(I: integer);
begin
   if FItems.Count = 0 then exit;
   if I < 0 then I := 0;
   if I >= FItems.Count then I := FItems.Count - 1;
   SetItemIndex(I);
   MakeCurrentVisible;
   Invalidate;
end;

function TListView.GetSelected: TListItem;
begin
   if FItemIndex >= 0 then Result := FItems[FItemIndex] else Result := nil;
end;

procedure TListView.SetSelected(V: TListItem);
begin
   if V = nil then SetItemIndex(-1) else SetItemIndex(FItems.IndexOf(V));
end;

procedure TListView.ToggleCheck(I: integer);
begin
   if not FCheckboxes or (I < 0) or (I >= FItems.Count) then exit;
   FItems[I].Checked := not FItems[I].Checked;
   if Assigned(FOnItemChecked) then FOnItemChecked(Self, FItems[I]);
end;

{ sort: OnCompare if set, else the text of SortColumn (numbers as numbers) }
procedure TListView.Sort;
var i, j, d, c: integer;
    sel: TListItem;
    l: TFPList;
    t: pointer;

   function Cmp(A, B: TListItem): integer;
   begin
      Result := 0;
      if Assigned(FOnCompare) then FOnCompare(Self, A, B, FSortColumn, Result)
      else
      begin
         c := FSortColumn;
         if c < 0 then c := 0;
         Result := CompareCellText(A.ColumnText(c), B.ColumnText(c));
      end;
      if FSortDirection = sdDescending then Result := -Result;
   end;

begin
   sel := GetSelected;
   l := FItems.FList;
   for i := 1 to l.Count - 1 do
   begin
      j := i;
      while j > 0 do
      begin
         d := Cmp(TListItem(l[j - 1]), TListItem(l[j]));
         if d <= 0 then break;
         t := l[j - 1]; l[j - 1] := l[j]; l[j] := t;
         dec(j);
      end;
   end;
   if sel <> nil then FItemIndex := l.IndexOf(sel);
   MakeCurrentVisible;
   Invalidate;
end;

procedure TListView.AlphaSort;
begin
   Sort;
end;

procedure TListView.Paint;
var a, sel, ha, la: byte;
    i, c, y, x, w, cw, n, r: integer;
    s: string;
    it: TListItem;
    o: TPoint;
    vw: integer;

   procedure Cell(XX, YY, WW: integer; const T: string; Al: TAlignment; At: byte);
   var tx: integer;
       ss: string;
   begin
      { clip against the scrolled view by hand: only whole characters }
      ss := Copy(T, 1, WW);
      case Al of
         taRightJustify: tx := XX + WW - Length(ss);
         taCenter:       tx := XX + (WW - Length(ss)) div 2;
      else
         tx := XX;
      end;
      Canvas.TextOut(tx, YY, ss, At);
   end;

begin
   Measure;
   if FTopIndex > MaxTop then FTopIndex := MaxTop;
   a := Theme.List;
   if (Color >= 0) and (Color <= 15) then a := MakeAttr(AttrFg(a), Color);
   if not IsEnabledAll then a := MakeAttr(Theme.DisabledFg, AttrBg(a));
   if Focused then sel := Theme.ListFocusSel else sel := Theme.ListSel;
   ha := Theme.MenuBar;
   la := MakeAttr(tcDarkGray, AttrBg(a));
   vw := ViewW;
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   { the header }
   if HeaderRows > 0 then
   begin
      { gray across the whole width, also over the scroll bar's column }
      Canvas.Fill(Rect(0, 0, Width, 1), ' ', ha);
      for c := 0 to FColumns.Count - 1 do
      begin
         x := ColLeft(c) - FScrollX;
         cw := FColumns[c].Width;
         if (x + cw <= 0) or (x >= vw) then continue;
         s := FColumns[c].Caption;
         if c = FSortColumn then
            if FSortDirection = sdAscending then s := s + ' ' + chArrowUp
            else s := s + ' ' + chArrowDown;
         Cell(x + 1, 0, cw - 2, s, taLeftJustify, ha);
         if x + cw - 1 < vw then Canvas.PutChar(x + cw - 1, 0, #179, ha);
      end;
   end;
   { the rows }
   for i := 0 to Rows - 1 do
   begin
      r := FTopIndex + i;
      if r >= FItems.Count then
      begin
         { below the last item: the grid lines go on to the bottom }
         if Report and FGridLines then
            for c := 0 to FColumns.Count - 1 do
            begin
               x := ColLeft(c) - FScrollX + FColumns[c].Width - 1;
               if (x >= 0) and (x < vw) then Canvas.PutChar(x, HeaderRows + i, #179, la);
            end;
         continue;
      end;
      it := FItems[r];
      y := HeaderRows + i;
      if r = FItemIndex then
      begin
         Canvas.Fill(Rect(0, y, vw, y + 1), ' ', sel);
         n := sel;
      end
      else n := a;
      if Report then
         for c := 0 to FColumns.Count - 1 do
         begin
            x := ColLeft(c) - FScrollX;
            cw := FColumns[c].Width;
            if (x + cw <= 0) or (x >= vw) then continue;
            s := it.ColumnText(c);
            w := cw - 2;
            if (c = 0) and FCheckboxes then
            begin
               if it.Checked then s := '[X] ' + s else s := '[ ] ' + s;
            end;
            Cell(x + 1, y, w, s, FColumns[c].Alignment, n);
            if FGridLines and (x + cw - 1 < vw) then
            begin
               if r = FItemIndex then Canvas.PutChar(x + cw - 1, y, #179, MakeAttr(tcDarkGray, AttrBg(sel)))
               else Canvas.PutChar(x + cw - 1, y, #179, la);
            end;
         end
      else
      begin
         s := it.Caption;
         if FCheckboxes then
            if it.Checked then s := '[X] ' + s else s := '[ ] ' + s;
         Cell(1, y, vw - 2, s, taLeftJustify, n);
      end;
   end;
   o := ScreenOrigin;
   la := MakeAttr(AttrFg(Theme.ListScroll), AttrBg(a));
   if FVBar then DrawVScroll(o.X + vw, o.Y + HeaderRows, Rows, FTopIndex, MaxTop, la);
   if FHBar then DrawHScroll(o.X, o.Y + ViewH, vw, FScrollX, MaxX, la);
end;

procedure TListView.KeyDown(var Key: Word; Shift: TShiftState);
begin
   inherited KeyDown(Key, Shift);
   if (Key = 0) or (Shift * [ssAlt, ssCtrl] <> []) then exit;
   Measure;
   case Key of
      VK_UP:    UserSelect(FItemIndex - 1);
      VK_DOWN:  UserSelect(FItemIndex + 1);
      VK_PRIOR: UserSelect(FItemIndex - (Rows - 1));
      VK_NEXT:  if FItemIndex < 0 then UserSelect(Rows - 1) else UserSelect(FItemIndex + Rows - 1);
      VK_HOME:  UserSelect(0);
      VK_END:   UserSelect(FItems.Count - 1);
      VK_SPACE: if FCheckboxes then ToggleCheck(FItemIndex) else exit;
      VK_LEFT, VK_RIGHT:
         if FHBar then
         begin
            if Key = VK_LEFT then dec(FScrollX, 4) else inc(FScrollX, 4);
            Measure;
            Invalidate;
         end
         else exit;
   else
      exit;
   end;
   Key := 0;
end;

procedure TListView.KeyPress(var Key: char);
var i, k, n: integer;
    s: string;
begin
   inherited KeyPress(Key);
   if Key <= ' ' then exit;
   n := FItems.Count;
   i := FItemIndex;
   for k := 1 to n do
   begin
      i := (i + 1) mod n;
      if i < 0 then i := 0;
      s := FItems[i].Caption;
      if (s <> '') and (UpCase(s[1]) = UpCase(Key)) then
      begin
         UserSelect(i);
         break;
      end;
   end;
   Key := #0;
end;

function TListView.WantsChars: boolean;
begin
   Result := true;
end;

function TListView.GetItemAt(X, Y: integer): TListItem;
var r: integer;
begin
   Result := nil;
   Measure;
   if (X < 0) or (X >= ViewW) or (Y < HeaderRows) or (Y >= ViewH) then exit;
   r := FTopIndex + Y - HeaderRows;
   if r < FItems.Count then Result := FItems[r];
end;

procedure TListView.HitV(H: TScrollHit);
begin
   case H of
      shLineUp:   dec(FTopIndex);
      shLineDown: inc(FTopIndex);
      shPageUp:   dec(FTopIndex, Rows - 1);
      shPageDown: inc(FTopIndex, Rows - 1);
      shThumb:    FThumbV := true;
   end;
   if FTopIndex > MaxTop then FTopIndex := MaxTop;
   if FTopIndex < 0 then FTopIndex := 0;
   Invalidate;
end;

procedure TListView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var c, cx, xx: integer;
    it: TListItem;
begin
   inherited MouseDown(Button, Shift, X, Y);
   FHoldV := shNone;
   FDownOnItem := false;
   if Button <> mbLeft then exit;
   Measure;
   if FVBar and (X = ViewW) and (Y >= HeaderRows) and (Y < ViewH) then
   begin
      FHoldV := ScrollHitAt(Y - HeaderRows, Rows, FTopIndex, MaxTop);
      HitV(FHoldV);
      if FHoldV = shThumb then FHoldV := shNone;
      exit;
   end;
   if FHBar and (Y = ViewH) then
   begin
      case ScrollHitAt(X, ViewW, FScrollX, MaxX) of
         shLineUp:   dec(FScrollX);
         shLineDown: inc(FScrollX);
         shPageUp:   dec(FScrollX, ViewW - 1);
         shPageDown: inc(FScrollX, ViewW - 1);
      end;
      Measure;
      Invalidate;
      exit;
   end;
   if (Y < HeaderRows) then
   begin
      { a header: its right edge resizes, elsewhere OnColumnClick / sort }
      xx := X + FScrollX;
      for c := 0 to FColumns.Count - 1 do
      begin
         cx := ColLeft(c);
         if (xx >= cx) and (xx < cx + FColumns[c].Width) then
         begin
            if xx = cx + FColumns[c].Width - 1 then
            begin
               FSizingCol := c;
               exit;
            end;
            if Assigned(FOnColumnClick) then FOnColumnClick(Self, FColumns[c]);
            if FAutoSort then
            begin
               if FSortColumn = c then
               begin
                  if FSortDirection = sdAscending then FSortDirection := sdDescending
                  else FSortDirection := sdAscending;
               end
               else
               begin
                  FSortColumn := c;
                  FSortDirection := sdAscending;
               end;
               Sort;
            end;
            exit;
         end;
      end;
      exit;
   end;
   it := GetItemAt(X, Y);
   if it = nil then exit;
   UserSelect(it.Index);
   FDownOnItem := true;
   { a click on the [ ] box }
   if FCheckboxes and (X + FScrollX * ord(Report) >= 1) and (X + FScrollX * ord(Report) <= 3) then
      ToggleCheck(it.Index);
end;

procedure TListView.MouseMove(Shift: TShiftState; X, Y: integer);
var it: TListItem;
begin
   inherited MouseMove(Shift, X, Y);
   if not (ssLeft in Shift) then exit;
   if FSizingCol >= 0 then
      FColumns[FSizingCol].Width := X + FScrollX - ColLeft(FSizingCol) + 1
   else if FThumbV then
   begin
      FTopIndex := ScrollPosAt(Y - HeaderRows, Rows, MaxTop);
      Invalidate;
   end
   else if FDownOnItem then
   begin
      it := GetItemAt(X, Y);
      if it <> nil then UserSelect(it.Index);
   end;
end;

procedure TListView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FSizingCol := -1;
   FThumbV := false;
   FHoldV := shNone;
   inherited MouseUp(Button, Shift, X, Y);
end;

procedure TListView.MouseHeld(X, Y: integer);
begin
   if (FHoldV <> shNone) and (X = ViewW) and
      (ScrollHitAt(Y - HeaderRows, Rows, FTopIndex, MaxTop) = FHoldV) then HitV(FHoldV);
end;

procedure TListView.DblClick;
begin
   if FDownOnItem then inherited DblClick;
end;

{=============================================================================}
{  TTreeNode                                                                  }
{=============================================================================}

constructor TTreeNode.Create(AOwner: TTreeNodes);
begin
   inherited Create;
   FOwner := AOwner;
   FChildren := TFPList.Create;
end;

destructor TTreeNode.Destroy;
begin
   while FChildren.Count > 0 do
   begin
      TTreeNode(FChildren[FChildren.Count - 1]).Free;
   end;
   FChildren.Free;
   if (FOwner <> nil) and (FOwner.FView <> nil) and (FOwner.FView.FSelected = Self) then
      FOwner.FView.FSelected := nil;
   Siblings.Remove(Self);
   inherited Destroy;
end;

function TTreeNode.Siblings: TFPList;
begin
   if FParent <> nil then Result := FParent.FChildren else Result := FOwner.FRoots;
end;

procedure TTreeNode.SetText(const V: string);
begin
   FText := V;
   FOwner.Changed;
end;

function TTreeNode.GetCount: integer;
begin
   Result := FChildren.Count;
end;

function TTreeNode.GetItem(I: integer): TTreeNode;
begin
   Result := TTreeNode(FChildren[I]);
end;

function TTreeNode.GetLevel: integer;
var n: TTreeNode;
begin
   Result := 0;
   n := FParent;
   while n <> nil do
   begin
      inc(Result);
      n := n.FParent;
   end;
end;

function TTreeNode.GetIndex: integer;
begin
   Result := Siblings.IndexOf(Self);
end;

function TTreeNode.GetHasChildren: boolean;
begin
   Result := FHasChildren or (FChildren.Count > 0);
end;

procedure TTreeNode.SetHasChildren(V: boolean);
begin
   FHasChildren := V;
   FOwner.Changed;
end;

function TTreeNode.GetSelected: boolean;
begin
   Result := (FOwner.FView <> nil) and (FOwner.FView.FSelected = Self);
end;

procedure TTreeNode.SetSelected(V: boolean);
begin
   if FOwner.FView = nil then exit;
   if V then FOwner.FView.Selected := Self
   else if GetSelected then FOwner.FView.Selected := nil;
end;

procedure TTreeNode.SetExpanded(V: boolean);
begin
   if V then Expand(false) else Collapse(false);
end;

procedure TTreeNode.Expand(Recurse: boolean);
var i: integer;
begin
   if not FExpanded and GetHasChildren then
      if (FOwner.FView = nil) or FOwner.FView.CanExpand(Self) then
      begin
         FExpanded := true;
         FOwner.Changed;
         if FOwner.FView <> nil then FOwner.FView.Expanded(Self);
      end;
   if Recurse then
      for i := 0 to FChildren.Count - 1 do GetItem(i).Expand(true);
end;

procedure TTreeNode.Collapse(Recurse: boolean);
var i: integer;
begin
   if Recurse then
      for i := 0 to FChildren.Count - 1 do GetItem(i).Collapse(true);
   if FExpanded then
      if (FOwner.FView = nil) or FOwner.FView.CanCollapse(Self) then
      begin
         FExpanded := false;
         FOwner.Changed;
         if FOwner.FView <> nil then FOwner.FView.Collapsed(Self);
      end;
end;

procedure TTreeNode.Delete;
begin
   FOwner.Delete(Self);
end;

procedure TTreeNode.DeleteChildren;
begin
   while FChildren.Count > 0 do TTreeNode(FChildren[FChildren.Count - 1]).Free;
   FOwner.Changed;
end;

function TTreeNode.GetFirstChild: TTreeNode;
begin
   if FChildren.Count > 0 then Result := GetItem(0) else Result := nil;
end;

function TTreeNode.GetLastChild: TTreeNode;
begin
   if FChildren.Count > 0 then Result := GetItem(FChildren.Count - 1) else Result := nil;
end;

function TTreeNode.GetNextSibling: TTreeNode;
var l: TFPList;
    i: integer;
begin
   l := Siblings;
   i := l.IndexOf(Self);
   if (i >= 0) and (i < l.Count - 1) then Result := TTreeNode(l[i + 1]) else Result := nil;
end;

function TTreeNode.GetPrevSibling: TTreeNode;
var l: TFPList;
    i: integer;
begin
   l := Siblings;
   i := l.IndexOf(Self);
   if i > 0 then Result := TTreeNode(l[i - 1]) else Result := nil;
end;

function TTreeNode.GetNext: TTreeNode;
var n: TTreeNode;
begin
   if FChildren.Count > 0 then exit(GetItem(0));
   n := Self;
   while n <> nil do
   begin
      Result := n.GetNextSibling;
      if Result <> nil then exit;
      n := n.FParent;
   end;
   Result := nil;
end;

function TTreeNode.IsVisible: boolean;
var n: TTreeNode;
begin
   n := FParent;
   while n <> nil do
   begin
      if not n.FExpanded then exit(false);
      n := n.FParent;
   end;
   Result := true;
end;

procedure TTreeNode.MakeVisible;
var n: TTreeNode;
begin
   n := FParent;
   while n <> nil do
   begin
      n.Expand(false);
      n := n.FParent;
   end;
   if (FOwner.FView <> nil) and (FOwner.FView.FSelected = Self) then
      FOwner.FView.MakeSelectedVisible;
end;

function TTreeNode.GetTextPath: string;
begin
   if FParent <> nil then Result := FParent.GetTextPath + '/' + FText
   else Result := FText;
end;

{=============================================================================}
{  TTreeNodes                                                                 }
{=============================================================================}

constructor TTreeNodes.Create(AView: TTreeView);
begin
   inherited Create;
   FView := AView;
   FRoots := TFPList.Create;
end;

destructor TTreeNodes.Destroy;
begin
   FView := nil;
   Clear;
   FRoots.Free;
   inherited Destroy;
end;

procedure TTreeNodes.Changed;
begin
   if (FUpdate = 0) and (FView <> nil) then FView.NodesChanged;
end;

procedure TTreeNodes.BeginUpdate;
begin
   inc(FUpdate);
end;

procedure TTreeNodes.EndUpdate;
begin
   if FUpdate > 0 then dec(FUpdate);
   Changed;
end;

function TTreeNodes.InsertAt(AParent: TTreeNode; Index: integer; const S: string): TTreeNode;
var l: TFPList;
begin
   Result := TTreeNode.Create(Self);
   Result.FText := S;
   Result.FParent := AParent;
   if AParent <> nil then l := AParent.FChildren else l := FRoots;
   if (Index < 0) or (Index > l.Count) then Index := l.Count;
   l.Insert(Index, Result);
   Changed;
end;

function TTreeNodes.Add(Sibling: TTreeNode; const S: string): TTreeNode;
begin
   if Sibling = nil then Result := InsertAt(nil, -1, S)
   else Result := InsertAt(Sibling.FParent, -1, S);
end;

function TTreeNodes.AddFirst(Sibling: TTreeNode; const S: string): TTreeNode;
begin
   if Sibling = nil then Result := InsertAt(nil, 0, S)
   else Result := InsertAt(Sibling.FParent, 0, S);
end;

function TTreeNodes.AddChild(AParent: TTreeNode; const S: string): TTreeNode;
begin
   Result := InsertAt(AParent, -1, S);
end;

function TTreeNodes.AddChildFirst(AParent: TTreeNode; const S: string): TTreeNode;
begin
   Result := InsertAt(AParent, 0, S);
end;

function TTreeNodes.Insert(Sibling: TTreeNode; const S: string): TTreeNode;
begin
   if Sibling = nil then Result := InsertAt(nil, -1, S)
   else Result := InsertAt(Sibling.FParent, Sibling.Index, S);
end;

procedure TTreeNodes.Delete(Node: TTreeNode);
var v: TTreeView;
    next: TTreeNode;
begin
   if Node = nil then exit;
   v := FView;
   next := nil;
   if (v <> nil) and (v.FSelected <> nil) then
   begin
      { the selection inside the deleted branch moves to a neighbour }
      next := v.FSelected;
      while (next <> nil) and (next <> Node) do next := next.FParent;
      if next = Node then
      begin
         next := Node.GetNextSibling;
         if next = nil then next := Node.GetPrevSibling;
         if next = nil then next := Node.FParent;
      end
      else next := v.FSelected;
   end;
   Node.Free;
   if v <> nil then v.FSelected := next;
   Changed;
end;

procedure TTreeNodes.Clear;
begin
   while FRoots.Count > 0 do TTreeNode(FRoots[FRoots.Count - 1]).Free;
   if FView <> nil then FView.FSelected := nil;
   Changed;
end;

function TTreeNodes.GetFirstNode: TTreeNode;
begin
   if FRoots.Count > 0 then Result := TTreeNode(FRoots[0]) else Result := nil;
end;

function TTreeNodes.GetCount: integer;
var n: TTreeNode;
begin
   Result := 0;
   n := GetFirstNode;
   while n <> nil do
   begin
      inc(Result);
      n := n.GetNext;
   end;
end;

function TTreeNodes.GetItem(I: integer): TTreeNode;
begin
   Result := GetFirstNode;
   while (Result <> nil) and (I > 0) do
   begin
      Result := Result.GetNext;
      dec(I);
   end;
end;

function TTreeNodes.FindNodeWithText(const S: string): TTreeNode;
begin
   Result := GetFirstNode;
   while (Result <> nil) and (CompareText(Result.FText, S) <> 0) do Result := Result.GetNext;
end;

{=============================================================================}
{  TTreeView                                                                  }
{=============================================================================}

constructor TTreeView.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FItems := TTreeNodes.Create(Self);
   FShowLines := true;
   FShowRoot := true;
   FShowButtons := true;
   FWidth := 30;
   FHeight := 10;
end;

destructor TTreeView.Destroy;
begin
   FreeAndNil(FItems);
   inherited Destroy;
end;

procedure TTreeView.NodesChanged;
begin
   FRowsOK := false;
   Invalidate;
end;

procedure TTreeView.SetShowLines(V: boolean);
begin
   FShowLines := V;
   NodesChanged;
end;

procedure TTreeView.SetShowRoot(V: boolean);
begin
   FShowRoot := V;
   NodesChanged;
end;

{ the expanded part of the tree as a list of rows }
procedure TTreeView.BuildRows;
var n: TTreeNode;
    w: integer;
begin
   if FRowsOK then exit;
   FRowCount := 0;
   FMaxW := 0;
   n := FItems.GetFirstNode;
   while n <> nil do
   begin
      if FRowCount >= Length(FRows) then SetLength(FRows, FRowCount * 2 + 16);
      FRows[FRowCount] := n;
      inc(FRowCount);
      w := Length(Prefix(n)) + Length(n.FText) + 1;
      if w > FMaxW then FMaxW := w;
      { the next visible node: into the children only when expanded }
      if n.FExpanded and (n.FChildren.Count > 0) then n := n.GetFirstChild
      else
      begin
         while (n <> nil) and (n.GetNextSibling = nil) do n := n.FParent;
         if n <> nil then n := n.GetNextSibling;
      end;
   end;
   FRowsOK := true;
end;

procedure TTreeView.Measure;
begin
   BuildRows;
   FVBar := FRowCount > Height;
   FHBar := FMaxW > Width - ord(FVBar);
   if FHBar and not FVBar then FVBar := FRowCount > Height - 1;
   if FTopRow > MaxTop then FTopRow := MaxTop;
   if FScrollX > MaxX then FScrollX := MaxX;
end;

function TTreeView.ViewW: integer;
begin
   Result := Width - ord(FVBar);
end;

function TTreeView.ViewH: integer;
begin
   Result := Height - ord(FHBar);
   if Result < 1 then Result := 1;
end;

function TTreeView.VisibleRowCount: integer;
begin
   BuildRows;
   Result := FRowCount;
end;

function TTreeView.MaxTop: integer;
begin
   Result := FRowCount - ViewH;
   if Result < 0 then Result := 0;
end;

function TTreeView.MaxX: integer;
begin
   Result := FMaxW - ViewW;
   if Result < 0 then Result := 0;
end;

function TTreeView.RowOf(N: TTreeNode): integer;
var i: integer;
begin
   BuildRows;
   for i := 0 to FRowCount - 1 do
      if FRows[i] = N then exit(i);
   Result := -1;
end;

{ the lines and the button in front of a node's text:                 }
{   '│ ' / '  ' for each ancestor level, '├─' / '└─' for the node,     }
{   then '+' (collapsed), '-' (expanded) or '─' (no children), ' '     }
function TTreeView.Prefix(N: TTreeNode): string;
var a: TTreeNode;
    s, g: string;
    lv: integer;
begin
   s := '';
   lv := N.Level;
   a := N.FParent;
   while a <> nil do
   begin
      if (a.FParent = nil) and not FShowRoot then break;
      if FShowLines and (a.GetNextSibling <> nil) then g := #179' ' else g := '  ';
      s := g + s;
      a := a.FParent;
   end;
   if (lv > 0) or FShowRoot then
   begin
      if not FShowLines then s := s + '  '
      else if N.GetNextSibling <> nil then s := s + #195#196
      else s := s + #192#196;
   end;
   if FShowButtons and N.GetHasChildren then
   begin
      if N.FExpanded then s := s + '-' else s := s + '+';
   end
   else if FShowLines and ((lv > 0) or FShowRoot) then s := s + #196
   else s := s + ' ';
   Result := s + ' ';
end;

function TTreeView.ButtonCol(N: TTreeNode): integer;
begin
   Result := Length(Prefix(N)) - 2;
end;

function TTreeView.CanExpand(N: TTreeNode): boolean;
begin
   Result := true;
   if Assigned(FOnExpanding) then FOnExpanding(Self, N, Result);
end;

function TTreeView.CanCollapse(N: TTreeNode): boolean;
begin
   Result := true;
   if Assigned(FOnCollapsing) then FOnCollapsing(Self, N, Result);
end;

procedure TTreeView.Expanded(N: TTreeNode);
begin
   if Assigned(FOnExpanded) then FOnExpanded(Self, N);
end;

procedure TTreeView.Collapsed(N: TTreeNode);
var p: TTreeNode;
begin
   { the selection inside a collapsed branch goes to the branch }
   if FSelected <> nil then
   begin
      p := FSelected.FParent;
      while (p <> nil) and (p <> N) do p := p.FParent;
      if p = N then SetSelected(N);
   end;
   if Assigned(FOnCollapsed) then FOnCollapsed(Self, N);
end;

procedure TTreeView.SetSelected(V: TTreeNode);
var allow: boolean;
begin
   if V = FSelected then exit;
   allow := true;
   if Assigned(FOnChanging) then FOnChanging(Self, V, allow);
   if not allow then exit;
   FSelected := V;
   if V <> nil then V.MakeVisible;
   MakeSelectedVisible;
   Invalidate;
   if Assigned(FOnChange) then FOnChange(Self, V);
end;

procedure TTreeView.UserSelect(N: TTreeNode);
begin
   if N <> nil then SetSelected(N);
end;

procedure TTreeView.MakeSelectedVisible;
var r: integer;
begin
   if FSelected = nil then exit;
   Measure;
   r := RowOf(FSelected);
   if r < 0 then exit;
   if r < FTopRow then FTopRow := r;
   if r >= FTopRow + ViewH then FTopRow := r - ViewH + 1;
   Invalidate;
end;

procedure TTreeView.FullExpand;
var n: TTreeNode;
begin
   FItems.BeginUpdate;
   try
      n := FItems.GetFirstNode;
      while n <> nil do
      begin
         n.Expand(true);
         n := n.GetNextSibling;
      end;
   finally
      FItems.EndUpdate;
   end;
end;

procedure TTreeView.FullCollapse;
var n: TTreeNode;
begin
   FItems.BeginUpdate;
   try
      n := FItems.GetFirstNode;
      while n <> nil do
      begin
         n.Collapse(true);
         n := n.GetNextSibling;
      end;
   finally
      FItems.EndUpdate;
   end;
   MakeSelectedVisible;
end;

procedure TTreeView.Paint;
var a, sel, la: byte;
    i, r: integer;
    n: TTreeNode;
    p, s: string;
    o: TPoint;
begin
   Measure;
   a := Theme.List;
   if (Color >= 0) and (Color <= 15) then a := MakeAttr(AttrFg(a), Color);
   if not IsEnabledAll then a := MakeAttr(Theme.DisabledFg, AttrBg(a));
   if Focused then sel := Theme.ListFocusSel else sel := Theme.ListSel;
   la := MakeAttr(tcDarkGray, AttrBg(a));
   Canvas.Fill(Rect(0, 0, Width, Height), ' ', a);
   for i := 0 to ViewH - 1 do
   begin
      r := FTopRow + i;
      if r >= FRowCount then break;
      n := FRows[r];
      p := Prefix(n);
      s := ' ' + n.FText + ' ';
      Canvas.TextOut(-FScrollX, i, p, la);
      if n.GetHasChildren and FShowButtons then
         Canvas.PutChar(Length(p) - 2 - FScrollX, i, p[Length(p) - 1], MakeAttr(tcBlack, AttrBg(a)));
      if n = FSelected then
         Canvas.TextOut(Length(p) - 1 - FScrollX, i, s, sel)
      else
         Canvas.TextOut(Length(p) - 1 - FScrollX, i, s, a);
   end;
   o := ScreenOrigin;
   la := MakeAttr(AttrFg(Theme.ListScroll), AttrBg(a));
   if FVBar then DrawVScroll(o.X + ViewW, o.Y, ViewH, FTopRow, MaxTop, la);
   if FHBar then DrawHScroll(o.X, o.Y + ViewH, ViewW, FScrollX, MaxX, la);
end;

function TTreeView.GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean;
begin
   X := 0; Y := 0; Shape := csHidden;
   Result := false;
end;

procedure TTreeView.KeyDown(var Key: Word; Shift: TShiftState);
var r: integer;
    n: TTreeNode;
begin
   inherited KeyDown(Key, Shift);
   if (Key = 0) or (Shift * [ssAlt, ssCtrl] <> []) then exit;
   Measure;
   n := FSelected;
   if n = nil then
   begin
      if (FRowCount > 0) and (Key in [VK_UP, VK_DOWN, VK_HOME, VK_END, VK_PRIOR, VK_NEXT,
                                      VK_LEFT, VK_RIGHT]) then
      begin
         UserSelect(FRows[0]);
         Key := 0;
      end;
      exit;
   end;
   r := RowOf(n);
   case Key of
      VK_UP:    if r > 0 then UserSelect(FRows[r - 1]);
      VK_DOWN:  if r < FRowCount - 1 then UserSelect(FRows[r + 1]);
      VK_PRIOR: begin r := r - (ViewH - 1); if r < 0 then r := 0; UserSelect(FRows[r]); end;
      VK_NEXT:  begin r := r + ViewH - 1; if r >= FRowCount then r := FRowCount - 1; UserSelect(FRows[r]); end;
      VK_HOME:  UserSelect(FRows[0]);
      VK_END:   UserSelect(FRows[FRowCount - 1]);
      VK_RIGHT:
         if n.GetHasChildren and not n.FExpanded then n.Expand(false)
         else if n.FChildren.Count > 0 then UserSelect(n.GetFirstChild);
      VK_LEFT:
         if n.FExpanded then n.Collapse(false)
         else if n.FParent <> nil then UserSelect(n.FParent);
   else
      exit;
   end;
   MakeSelectedVisible;
   Key := 0;
end;

procedure TTreeView.KeyPress(var Key: char);
var r, k: integer;
    n: TTreeNode;
begin
   inherited KeyPress(Key);
   if FSelected <> nil then
      case Key of
         '+': begin FSelected.Expand(false); Key := #0; exit; end;
         '-': begin FSelected.Collapse(false); Key := #0; MakeSelectedVisible; exit; end;
         '*': begin FSelected.Expand(true); Key := #0; exit; end;
      end;
   if Key <= ' ' then exit;
   { a letter: the next visible node starting with it }
   BuildRows;
   r := RowOf(FSelected);
   for k := 1 to FRowCount do
   begin
      r := (r + 1) mod FRowCount;
      if r < 0 then r := 0;
      n := FRows[r];
      if (n.FText <> '') and (UpCase(n.FText[1]) = UpCase(Key)) then
      begin
         UserSelect(n);
         break;
      end;
   end;
   Key := #0;
end;

function TTreeView.WantsChars: boolean;
begin
   Result := true;
end;

function TTreeView.GetNodeAt(X, Y: integer): TTreeNode;
var r: integer;
begin
   Result := nil;
   Measure;
   if (X < 0) or (X >= ViewW) or (Y < 0) or (Y >= ViewH) then exit;
   r := FTopRow + Y;
   if r < FRowCount then Result := FRows[r];
end;

procedure TTreeView.HitV(H: TScrollHit);
begin
   case H of
      shLineUp:   dec(FTopRow);
      shLineDown: inc(FTopRow);
      shPageUp:   dec(FTopRow, ViewH - 1);
      shPageDown: inc(FTopRow, ViewH - 1);
      shThumb:    FThumbV := true;
   end;
   if FTopRow > MaxTop then FTopRow := MaxTop;
   if FTopRow < 0 then FTopRow := 0;
   Invalidate;
end;

procedure TTreeView.HitH(H: TScrollHit);
begin
   case H of
      shLineUp:   dec(FScrollX);
      shLineDown: inc(FScrollX);
      shPageUp:   dec(FScrollX, ViewW - 1);
      shPageDown: inc(FScrollX, ViewW - 1);
      shThumb:    FThumbH := true;
   end;
   if FScrollX > MaxX then FScrollX := MaxX;
   if FScrollX < 0 then FScrollX := 0;
   Invalidate;
end;

procedure TTreeView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
var n: TTreeNode;
begin
   inherited MouseDown(Button, Shift, X, Y);
   FHoldV := shNone;
   FHoldH := shNone;
   if Button <> mbLeft then exit;
   Measure;
   if FVBar and (X = ViewW) and (Y < ViewH) then
   begin
      FHoldV := ScrollHitAt(Y, ViewH, FTopRow, MaxTop);
      HitV(FHoldV);
      if FHoldV = shThumb then FHoldV := shNone;
      exit;
   end;
   if FHBar and (Y = ViewH) and (X < ViewW) then
   begin
      FHoldH := ScrollHitAt(X, ViewW, FScrollX, MaxX);
      HitH(FHoldH);
      if FHoldH = shThumb then FHoldH := shNone;
      exit;
   end;
   n := GetNodeAt(X, Y);
   if n = nil then exit;
   { a click on the +/- button opens or closes the node }
   if FShowButtons and n.GetHasChildren and (X + FScrollX = ButtonCol(n)) then
   begin
      n.Expanded := not n.FExpanded;
      MakeSelectedVisible;
      exit;
   end;
   UserSelect(n);
end;

procedure TTreeView.MouseMove(Shift: TShiftState; X, Y: integer);
begin
   inherited MouseMove(Shift, X, Y);
   if not (ssLeft in Shift) then exit;
   if FThumbV then
   begin
      FTopRow := ScrollPosAt(Y, ViewH, MaxTop);
      Invalidate;
   end
   else if FThumbH then
   begin
      FScrollX := ScrollPosAt(X, ViewW, MaxX);
      Invalidate;
   end;
end;

procedure TTreeView.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FThumbV := false;
   FThumbH := false;
   FHoldV := shNone;
   FHoldH := shNone;
   inherited MouseUp(Button, Shift, X, Y);
end;

procedure TTreeView.MouseHeld(X, Y: integer);
begin
   if (FHoldV <> shNone) and (X = ViewW) and (ScrollHitAt(Y, ViewH, FTopRow, MaxTop) = FHoldV) then
      HitV(FHoldV);
   if (FHoldH <> shNone) and (Y = ViewH) and (ScrollHitAt(X, ViewW, FScrollX, MaxX) = FHoldH) then
      HitH(FHoldH);
end;

{ a double click on a node with children opens / closes it (then OnDblClick) }
procedure TTreeView.DblClick;
begin
   if (FSelected <> nil) and FSelected.GetHasChildren then
   begin
      FSelected.Expanded := not FSelected.FExpanded;
      MakeSelectedVisible;
   end;
   inherited DblClick;
end;

{=============================================================================}
{  TTrackBar                                                                  }
{=============================================================================}

constructor TTrackBar.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FMax := 10;
   FFrequency := 1;
   FLineSize := 1;
   FPageSize := 2;
   FTickStyle := tsAuto;
   FWidth := 21;
   FHeight := 1;
end;

procedure TTrackBar.SetPosition(V: integer);
begin
   if V < FMin then V := FMin;
   if V > FMax then V := FMax;
   if V = FPosition then exit;
   FPosition := V;
   Invalidate;
   if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TTrackBar.SetMin(V: integer);
begin
   FMin := V;
   if FMax < V then FMax := V;
   SetPosition(FPosition);
   Invalidate;
end;

procedure TTrackBar.SetMax(V: integer);
begin
   FMax := V;
   if FMin > V then FMin := V;
   SetPosition(FPosition);
   Invalidate;
end;

procedure TTrackBar.SetOrientation(V: TTrackBarOrientation);
begin
   if V = FOrientation then exit;
   FOrientation := V;
   SetBounds(Left, Top, Height, Width);
end;

function TTrackBar.Len: integer;
begin
   if FOrientation = trHorizontal then Result := Width else Result := Height;
end;

function TTrackBar.PosToCell(P: integer): integer;
begin
   if FMax <= FMin then exit(0);
   Result := ((P - FMin) * (Len - 1) + (FMax - FMin) div 2) div (FMax - FMin);
end;

function TTrackBar.CellToPos(C: integer): integer;
begin
   if Len <= 1 then exit(FMin);
   Result := FMin + (C * (FMax - FMin) + (Len - 1) div 2) div (Len - 1);
end;

procedure TTrackBar.Paint;
var a, ta: byte;
    i, p, t: integer;
    line, tick: char;
begin
   a := MakeAttr(Theme.GroupFrameFg, BackColor);
   if Focused then ta := Theme.ListFocusSel else ta := MakeAttr(tcBlack, BackColor);
   if not IsEnabledAll then begin a := MakeAttr(Theme.DisabledFg, BackColor); ta := a; end;
   if FOrientation = trHorizontal then begin line := #196; tick := #197; end
   else begin line := #179; tick := #197; end;
   Canvas.Fill(Rect(0, 0, Width, Height), line, a);
   { the ticks }
   if (FTickStyle = tsAuto) and (FFrequency > 0) then
   begin
      p := FMin;
      while p <= FMax do
      begin
         t := PosToCell(p);
         if FOrientation = trHorizontal then
            for i := 0 to Height - 1 do Canvas.PutChar(t, i, tick, a)
         else
            for i := 0 to Width - 1 do Canvas.PutChar(i, t, tick, a);
         inc(p, FFrequency);
      end;
   end;
   { the thumb }
   t := PosToCell(FPosition);
   if FOrientation = trHorizontal then
      for i := 0 to Height - 1 do Canvas.PutChar(t, i, chBlock, ta)
   else
      for i := 0 to Width - 1 do Canvas.PutChar(i, t, chBlock, ta);
end;

function TTrackBar.GetCaretPos(out X, Y: integer; out Shape: TCursorShape): boolean;
begin
   X := 0; Y := 0; Shape := csHidden;
   Result := false;
end;

procedure TTrackBar.KeyDown(var Key: Word; Shift: TShiftState);
var horiz: boolean;
begin
   inherited KeyDown(Key, Shift);
   if (Key = 0) or (Shift * [ssAlt, ssCtrl] <> []) then exit;
   horiz := FOrientation = trHorizontal;
   if (horiz and (Key = VK_LEFT)) or (not horiz and (Key = VK_UP)) then
      Position := FPosition - FLineSize
   else if (horiz and (Key = VK_RIGHT)) or (not horiz and (Key = VK_DOWN)) then
      Position := FPosition + FLineSize
   else if Key = VK_PRIOR then Position := FPosition - FPageSize
   else if Key = VK_NEXT then Position := FPosition + FPageSize
   else if Key = VK_HOME then Position := FMin
   else if Key = VK_END then Position := FMax
   else exit;
   Key := 0;
end;

procedure TTrackBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   inherited MouseDown(Button, Shift, X, Y);
   if Button <> mbLeft then exit;
   FDragging := true;
   if FOrientation = trHorizontal then Position := CellToPos(X) else Position := CellToPos(Y);
end;

procedure TTrackBar.MouseMove(Shift: TShiftState; X, Y: integer);
var c: integer;
begin
   inherited MouseMove(Shift, X, Y);
   if not (FDragging and (ssLeft in Shift)) then exit;
   if FOrientation = trHorizontal then c := X else c := Y;
   if c < 0 then c := 0;
   if c >= Len then c := Len - 1;
   Position := CellToPos(c);
end;

procedure TTrackBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
   FDragging := false;
   inherited MouseUp(Button, Shift, X, Y);
end;


function TListView.MouseWheel(WheelDelta: integer): boolean;
begin
   Measure;
   FTopIndex := FTopIndex - (WheelDelta div 120) * 3;
   if FTopIndex > MaxTop then FTopIndex := MaxTop;
   if FTopIndex < 0 then FTopIndex := 0;
   Invalidate;
   Result := true;
end;

function TTreeView.MouseWheel(WheelDelta: integer): boolean;
begin
   Measure;
   FTopRow := FTopRow - (WheelDelta div 120) * 3;
   if FTopRow > MaxTop then FTopRow := MaxTop;
   if FTopRow < 0 then FTopRow := 0;
   Invalidate;
   Result := true;
end;

{ the wheel moves the track bar a line a notch (up / away: back) }
function TTrackBar.MouseWheel(WheelDelta: integer): boolean;
begin
   Position := FPosition - (WheelDelta div 120) * FLineSize;
   Result := true;
end;

initialization
   RegisterClasses([TListView, TTreeView, TTrackBar]);
end.
