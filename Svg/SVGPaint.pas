{******************************************************************}
{ SVG fill classes                                                 }
{                                                                  }
{ home page : http://www.mwcs.de                                   }
{ email     : martin.walter@mwcs.de                                }
{                                                                  }
{ date      : 05-04-2008                                           }
{                                                                  }
{ Use of this file is permitted for commercial and non-commercial  }
{ use, as long as the author is credited.                          }
{ This file (c) 2005, 2008 Martin Walter                           }
{                                                                  }
{ Thanks to:                                                       }
{ Kiriakos Vlahos (deprecated xlink:href to href)                  }
{ Kiriakos Vlahos (fixed gradient transform)                       }
{ Kiriakos Vlahos (fixed LinearGradient and RadialGradient)        }
{                                                                  }
{ This Software is distributed on an "AS IS" basis, WITHOUT        }
{ WARRANTY OF ANY KIND, either express or implied.                 }
{                                                                  }
{ *****************************************************************}

unit SVGPaint;

interface

uses
  Winapi.Windows,
  Winapi.GDIPOBJ,
  Winapi.GDIPAPI,
  System.UITypes,
  System.Classes,
  Winapi.msxml,
  SVGTypes,
  SVG;

type
  TStopColors = record
    Colors: packed array of ARGB;
    Positions: packed array of Single;
    Count: Integer;
  end;

  TSVGStop = class(TSVGObject)
  strict private
    FStop: TFloat;
    FStopColor: TColor;
    FOpacity: TFloat;
  protected
    procedure AssignTo(Dest: TPersistent); override;
  public
    procedure Clear; override;
    procedure ReadIn(const Node: IXMLDOMNode); override;
    function ReadInAttr(const AttrName, AttrValue: string): Boolean; override;
    procedure PaintToGraphics(Graphics: TGPGraphics); override;
    procedure PaintToPath(Path: TGPGraphicsPath); override;

    property Stop: TFloat read FStop write FStop;
    property StopColor: TColor read FStopColor write FStopColor;

    property Opacity: TFloat read FOpacity write FOpacity;
  end;

  TSVGFiller = class(TSVGMatrix)
  public
    procedure ReadIn(const Node: IXMLDOMNode); override;
    function GetBrush(Alpha: Byte; const DestObject: TSVGBasic): TGPBrush; virtual; abstract;
    procedure PaintToGraphics(Graphics: TGPGraphics); override;
    procedure PaintToPath(Path: TGPGraphicsPath); override;
  end;

  TSVGGradient = class(TSVGFiller)
  {
    SpreadMethod is not implemented
    Assumed to be repeat for LinearGradient and pad for RadialGradient
  }
  private
    FURI: string;
    FGradientUnits: TGradientUnits;
  protected
    procedure AssignTo(Dest: TPersistent); override;
    function GetColors(Alpha: Byte): TStopColors; virtual;
  public
    procedure ReadIn(const Node: IXMLDOMNode); override;
    function ReadInAttr(const AttrName, AttrValue: string): Boolean; override;
  end;

  TSVGLinearGradient = class(TSVGGradient)
  private
    FX1: TFloat;
    FY1: TFloat;
    FX2: TFloat;
    FY2: TFloat;
  protected
    procedure AssignTo(Dest: TPersistent); override;
  public
    function ReadInAttr(const AttrName, AttrValue: string): Boolean; override;
    function GetBrush(Alpha: Byte; const DestObject: TSVGBasic): TGPBrush; override;
    procedure Clear; override;

    property X1: TFloat read FX1 write FX1;
    property Y1: TFloat read FY1 write FY1;
    property X2: TFloat read FX2 write FX2;
    property Y2: TFloat read FY2 write FY2;
  end;

  TSVGRadialGradient = class(TSVGGradient)
  private
    FCX: TFloat;
    FCY: TFloat;
    FR: TFloat;
    FFX: TFloat;
    FFY: TFloat;
  protected
    procedure AssignTo(Dest: TPersistent); override;
  public
    procedure Clear; override;
    procedure ReadIn(const Node: IXMLDOMNode); override;
    function ReadInAttr(const AttrName, AttrValue: string): Boolean; override;
    function GetBrush(Alpha: Byte; const DestObject: TSVGBasic): TGPBrush; override;

    property CX: TFloat read FCX write FCX;
    property CY: TFloat read FCY write FCY;
    property R: TFloat read FR write FR;
    property FX: TFloat read FFX write FFX;
    property FY: TFloat read FFY write FFY;
  end;

implementation

uses
  System.Types,
  System.SysUtils,
  System.Math,
  SVGCommon,
  SVGParse,
  SVGStyle,
  SVGColor;

// TSVGStop

procedure TSVGStop.PaintToPath(Path: TGPGraphicsPath);
begin
end;

procedure TSVGStop.ReadIn(const Node: IXMLDOMNode);
Var
  S: string;
begin
  inherited;

  // opacity and stop-color are CSS properties
  if not HasValue(FOpacity) then
  begin
    if Assigned(FStyle) then
    begin
      S := FStyle['stop-opacity'];
      if S <> '' then
        FOpacity := EnsureRange(ParsePercent(S), 0, 1);
    end
  end;
  if not HasValue(FOpacity) then FOpacity := 1;  //  default

  if FStopColor = SVG_INHERIT_COLOR then
  begin
    if Assigned(FStyle) then
    begin
      S := FStyle['stop-color'];
      if S <> '' then
        FStopColor := GetSVGColor(S);
    end
  end;
  if FStopColor = SVG_INHERIT_COLOR then FStopColor := TColors.Black; // default

  if GetRoot.Grayscale then
    FStopColor := GetSVGGrayscale(FStopColor)
  else if (GetRoot.FixedColor  <> SVG_INHERIT_COLOR) and
    (FStopColor <> SVG_NONE_COLOR)
  then
    FStopColor := GetRoot.FixedColor;
end;

function TSVGStop.ReadInAttr(const AttrName, AttrValue: string): Boolean;
begin
  Result := True;
  if AttrName = 'offset' then FStop := ParsePercent(AttrValue)
  else if AttrName = 'stop-opacity' then FOpacity := EnsureRange(ParsePercent(AttrValue), 0, 1)
  else if AttrName = 'stop-color' then FStopColor := GetSVGColor(AttrValue)
  else
    Result := inherited;
end;

procedure TSVGStop.AssignTo(Dest: TPersistent);
begin
  inherited;
  if Dest is TSVGStop then
  begin
    TSVGStop(Dest).FStop := FStop;
    TSVGStop(Dest).FStopColor := FStopColor;
    TSVGStop(Dest).FOpacity := FOpacity;
  end;
end;

procedure TSVGStop.Clear;
begin
  inherited;
  FOpacity := UndefinedFloat;
  FStopColor := SVG_INHERIT_COLOR;
end;

procedure TSVGStop.PaintToGraphics(Graphics: TGPGraphics);
begin
end;

// TSVGFiller

procedure TSVGFiller.PaintToPath(Path: TGPGraphicsPath);
begin
end;

procedure TSVGFiller.ReadIn(const Node: IXMLDOMNode);
begin
  inherited;
  Display := tbFalse;
end;

procedure TSVGFiller.PaintToGraphics(Graphics: TGPGraphics);
begin
end;

// TSVGGradient

procedure TSVGGradient.ReadIn(const Node: IXMLDOMNode);
var
  ChildNode: IXMLDOMNode;
  Stop: TSVGStop;
begin
  inherited;

  ChildNode := Node.firstChild;
  while Assigned(ChildNode) do
  begin
    if ChildNode.nodeName = 'stop' then
    begin
      Stop := TSVGStop.Create(Self);
      Stop.ReadIn(ChildNode);
    end;
    ChildNode := ChildNode.nextSibling;
  end;

  if FURI <> '' then
  begin
    FURI := Trim(FURI);
    if (FURI <> '') and (FURI[1] = '#') then
      FURI := Copy(FURI, 2);
  end;
end;

function TSVGGradient.ReadInAttr(const AttrName, AttrValue: string): Boolean;
begin
  Result := True;
  if AttrName = 'gradientUnits' then FGradientUnits := ParseGradientUnits(AttrValue)
  else if AttrName = 'xlink:href' then FURI := AttrValue
  else if AttrName = 'href' then FURI := AttrValue
  else if AttrName = 'gradientTransform' then PureMatrix := ParseTransform(AttrValue)
  else
    Result := inherited;
end;

// TSVGLinearGradient

function TSVGLinearGradient.ReadInAttr(const AttrName,
  AttrValue: string): Boolean;
begin
  Result := True;
  if AttrName = 'x1' then FX1 := ParseLength(AttrValue)
  else if AttrName = 'x2' then FX2 := ParseLength(AttrValue)
  else if AttrName = 'y1' then FY1 := ParseLength(AttrValue)
  else if AttrName = 'y2' then FY2 := ParseLength(AttrValue)
  else
    Result := inherited;
end;

procedure TSVGLinearGradient.AssignTo(Dest: TPersistent);
begin
  inherited;
  if Dest is TSVGLinearGradient then
  begin
    TSVGLinearGradient(Dest).FX1 := FX1;
    TSVGLinearGradient(Dest).FY1 := FY1;
    TSVGLinearGradient(Dest).FX2 := FX2;
    TSVGLinearGradient(Dest).FY2 := FY2;
  end;
end;

procedure TSVGLinearGradient.Clear;
begin
  inherited;
  FX1 := UndefinedFloat;
  FX2 := UndefinedFloat;
  FY1 := UndefinedFloat;
  FY2 := UndefinedFloat;
end;

function TSVGLinearGradient.GetBrush(Alpha: Byte; const DestObject: TSVGBasic): TGPBrush;
var
  Brush: TGPLinearGradientBrush;
  TGP: TGPMatrix;
  Colors: TStopColors;
  BoundsRect: TRectF;
  MX1, MX2, MY1, MY2: TFloat;
begin
  BoundsRect :=  DestObject.ObjectBounds;
  if HasValue(FX1) then MX1 := FX1 else MX1 := BoundsRect.Left;
  if HasValue(FX2) then MX2 := FX2 else MX2 := BoundsRect.Right;
  if HasValue(FY1) then MY1 := FY1 else MY1 := BoundsRect.Top;
  if HasValue(FY2) then MY2 := FY2 else MY2 := BoundsRect.Top;
  if FGradientUnits = guObjectBoundingBox then begin
    // X1, X2, Y1, Y2 are relative to the Object Bounding Rect
    if HasValue(FX1) then MX1 := BoundsRect.Left + FX1 * BoundsRect.Width;
    if HasValue(FX2) then MX2 := BoundsRect.Left + FX2 * BoundsRect.Width;
    if HasValue(FY1) then MY1 := BoundsRect.Top + FY1 * BoundsRect.Height;
    if HasValue(FY2) then MY2 := BoundsRect.Top + FY2 * BoundsRect.Height;
  end;

  Brush := TGPLinearGradientBrush.Create(MakePoint(MX1, MY1), MakePoint(MX2, MY2), 0, 0);

  Colors := GetColors(Alpha);

  Brush.SetInterpolationColors(PGPColor(Colors.Colors),
    PSingle(Colors.Positions), Colors.Count);

  if not PureMatrix.IsEmpty then
  begin
    TGP := PureMatrix.ToGPMatrix;
    Brush.SetTransform(TGP);
    TGP.Free;
  end;

  Result := Brush;
end;

// TSVGRadialGradient

procedure TSVGRadialGradient.AssignTo(Dest: TPersistent);
begin
  inherited;
  if Dest is TSVGRadialGradient then
  begin
    TSVGRadialGradient(Dest).FCX := FCX;
    TSVGRadialGradient(Dest).FCY := FCY;
    TSVGRadialGradient(Dest).FFX := FFX;
    TSVGRadialGradient(Dest).FFY := FFY;
    TSVGRadialGradient(Dest).FR := FR;
  end;
end;

procedure TSVGRadialGradient.Clear;
begin
  inherited;
  FCX := UndefinedFloat;
  FCY := UndefinedFloat;
  FR := UndefinedFloat;
  FFX := FCX;
  FFY := FCY;
end;

procedure TSVGRadialGradient.ReadIn(const Node: IXMLDOMNode);
begin
  inherited;
  if not HasValue(FFX) then
    FFX := FCX;
  if not HasValue(FFY) then
    FFY := FCY;
end;

function TSVGRadialGradient.ReadInAttr(const AttrName,
  AttrValue: string): Boolean;
begin
  Result := True;
  if AttrName = 'cx' then FCX := ParseLength(AttrValue)
  else if AttrName = 'cy' then FCY := ParseLength(AttrValue)
  else if AttrName = 'r' then FR := ParseLength(AttrValue)
  else if AttrName = 'fx' then FFX := ParseLength(AttrValue)
  else if AttrName = 'fy' then FFY := ParseLength(AttrValue)
  else
    Result := inherited;
end;

function TSVGRadialGradient.GetBrush(Alpha: Byte; const DestObject: TSVGBasic): TGPBrush;
var
  Brush: TGPPathGradientBrush;
  Path: TGPGraphicsPath;
  TGP: TGPMatrix;
  Colors: TStopColors;
  RevColors: TStopColors;
  BoundsRect: TRectF;
  MCX, MCY, MR, MFX, MFY: TFloat;
  i: integer;
begin
  BoundsRect :=  DestObject.ObjectBounds;
  if HasValue(FCX) then MCX := FCX else MCX := BoundsRect.Left + 0.5 * BoundsRect.Width;
  if HasValue(FFX) then MFX := FFX else MFX := MCX;
  if HasValue(FCY) then MCY := FCY else MCY := BoundsRect.Top + 0.5 * BoundsRect.Height;
  if HasValue(FFY) then MFY := FFY else MFY := MCY;
  if HasValue(FR) then
    MR := FR
  else
    MR := 0.5 * Sqrt(Sqr(BoundsRect.Width) + Sqr(BoundsRect.Height))/Sqrt(2);
  if FGradientUnits = guObjectBoundingBox then begin
    // CX, CY, R, FX, FY are relative to the Object Bounding Rect
    if HasValue(FCX) then MCX := BoundsRect.Left + FCX * BoundsRect.Width;
    if HasValue(FFX) then MFX := BoundsRect.Left + FFX * BoundsRect.Width;
    if HasValue(FCY) then MCY := BoundsRect.Top + FCY * BoundsRect.Height;
    if HasValue(FFY) then MFY := BoundsRect.Top + FFY * BoundsRect.Height;
    if HasValue(FR) then
      MR := FR * Sqrt(Sqr(BoundsRect.Width) + Sqr(BoundsRect.Height))/Sqrt(2);
  end;

  Path := TGPGraphicsPath.Create;
  if HasValue(FR) then
    Path.AddEllipse(MCX - MR, MCY - MR, 2 * MR, 2 * MR)
  else
    Path.AddEllipse(ToGPRectF(BoundsRect));

  Brush := TGPPathGradientBrush.Create(Path);
  Path.Free;

  Colors := GetColors(Alpha);

  SetLength(RevColors.Colors, Colors.Count);
  SetLength(RevColors.Positions, Colors.Count);
  // Reverse colors! TGPPathGradientBrush uses colors from outside to inside unlike svg
  for i := 0 to Colors.Count - 1 do
  begin
    RevColors.Colors[i] := Colors.Colors[Colors.Count - 1 - i];
    RevColors.Positions[i] := 1 - Colors.Positions[Colors.Count - 1 - i];
  end;
  if Colors.Count > 0 then
    // Temporarily store last color. Used in TSVGBasic.BeforePaint
    DestObject.FillColor := Integer(RevColors.Colors[0]);

  Brush.SetInterpolationColors(PARGB(RevColors.Colors), PSingle(RevColors.Positions), Colors.Count);

  if HasValue(FFX) and HasValue(FFY) then
    Brush.SetCenterPoint(MakePoint(MFX, MFY));

  if not PureMatrix.IsEmpty then
  begin
    TGP := PureMatrix.ToGPMatrix;
    Brush.SetTransform(TGP);
    TGP.Free;
  end;

  Result := Brush;
end;

procedure TSVGGradient.AssignTo(Dest: TPersistent);
begin
  inherited;
  if Dest is TSVGGradient then
  begin
    TSVGGradient(Dest).FURI := FURI;
    TSVGGradient(Dest).FGradientUnits := FGradientUnits;
  end;
end;

function TSVGGradient.GetColors(Alpha: Byte): TStopColors;
var
  C, Start, ColorCount: Integer;
  Stop: TSVGStop;
  Item: TSVGGradient;
begin
  Result.Count := 0;
  if FURI = '' then
    Item := Self
  else
  begin
    Item := TSVGGradient(GetRoot.FindByID(FURI));
    if not (Item is TSVGGradient) then
      Exit;
  end;

  Start := 0;
  ColorCount := Item.Count;

  if Item.Count = 0 then
    Exit;

  if TSVGStop(Item.Items[ColorCount - 1]).Stop < 1 then
    Inc(ColorCount);

  if TSVGStop(Item.Items[0]).Stop > 0 then
  begin
    Inc(ColorCount);
    Inc(Start);
  end;

  SetLength(Result.Colors, ColorCount);
  SetLength(Result.Positions, ColorCount);

  if Start > 0 then
  begin
    Stop := TSVGStop(Item.Items[0]);
    Result.Colors[0] := ConvertColor(Stop.StopColor, Round(Alpha * Stop.Opacity));
    Result.Positions[0] := 0;
  end;

   for C := 0 to Item.Count - 1 do
  begin
    Stop := TSVGStop(Item.Items[C]);
    Result.Colors[C + Start] := ConvertColor(Stop.StopColor, Round(Alpha * Stop.Opacity));
    Result.Positions[C + Start] := Stop.Stop;
  end;

  if (ColorCount - Start) > Item.Count then
  begin
    Stop := TSVGStop(Item.Items[Item.Count - 1]);
    Result.Colors[ColorCount - 1] := ConvertColor(Stop.StopColor, Round(Alpha * Stop.Opacity));
    Result.Positions[ColorCount - 1] := 1;
  end;

  Result.Count := ColorCount;
end;

end.
