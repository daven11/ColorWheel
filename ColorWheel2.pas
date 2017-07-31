unit ColorWheel2;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, GDIPAPI, GDIPOBJ, math, extctrls;

type

  TColorPaletteStyle = (tcpsMonochromatic, tcpsComplementary, tcpsAnalogous,
          tcpsTriad, tcpsSplitComplementary, tcpsRectangle, tcpsSquare,
          tcpsFreeForm2, tcpsFreeForm3, tcpsFreeform4);

  TColorWheel2 = class(TCustomPanel)
  private
    { Private declarations }
    // control bounds used to detect mouse down
    FControlBoundRects : array[0..3] of TRect;
    // size of the control border
    FBorderSize: integer;
    // selected control
    FSelectedControl : integer;
    // Colors changed event
    FColorsChanged: TNotifyEvent;
    // radius of the controls location
    FRadius : integer;
    // hue of the controls
    FHueArray : Array[0..4] of double;
    // number of active controls
    FNumColors : Integer;
    // Type of the color controls
    FSwatchType : TColorPaletteStyle;

    // Paint routines
    procedure PaintControls;
    procedure DrawCircle(x, y: integer; c: TRGBTriple; center : Tpoint;Marked : boolean);
    procedure PaintCircle(Bitmap: TBitmap);

    // control functions
    function getAngle(x, y: integer): double;
    procedure MoveBigControl(controlIndex: integer; angle: double);
    function getJoinedControls(selected, test: integer): integer;
    function hsv2rgb(hue, sat, value: double): TRGBTriple;
    procedure HueSaturationAtPoint(positionx, positiony: Integer; size: Integer; var hue, sat: double);
    function ConvertHSVToColor(h, s, v: double): TColor;

    // interface functions
    procedure SetNumControls(const Value: integer);
    procedure SetBorderSize(const Value: integer);
    procedure SetColorsChanged(const Value: TNotifyEvent);
    procedure DoColorsChanged;
    function getNumControls: integer;
    procedure SetSwatchType(const Value: TColorPaletteStyle);

  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor destroy; override;
    function getColor(index : Integer) : TColor;

  published
    { Published declarations }
    property NumControls : integer read getNumControls write SetNumControls;
    property BorderSize : integer read FBorderSize write SetBorderSize;
    property ColorsChanged : TNotifyEvent read FColorsChanged write SetColorsChanged;
    property SwatchType : TColorPaletteStyle read FSwatchType write SetSwatchType;
    property Color;
  end;
  PRGBTripleArray = ^TRGBTripleArray;
  TRGBTripleArray = array [Byte] of TRGBTriple;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('MTS', [TColorWheel2]);
end;

{ TColorWheel2 }

function TColorWheel2.ConvertHSVToColor(h, s, v: double): TColor;
var
   f,p,q,t : double;
   r,g,b : byte;
   i : integer;
begin
     while h < 0 do
     begin
       h := h + 360;
     end;
     if h = 360 then
        h := 0.0;
     h := h/60.0;
     i := floor(h);
     f := h - i;
     p := v*(1.0 - s);
     q := v*(1.0 - s * f);
     t := v*(1.0 - (s * (1.0-f)));
     case i of
          0: begin
                  r := round(v*255);
                  g := round(t*255);
                  b := round(p*255);
             end;
          1: begin
                  r := round(q*255);
                  g := round(v*255);
                  b := round(p*255);
             end;
          2: begin
                  r := round(p*255);
                  g := round(v*255);
                  b := round(t*255);
             end;
          3: begin
                  r := round(p*255);
                  g := round(q*255);
                  b := round(v*255);
             end;
          4: begin
                  r := round(t*255);
                  g := round(p*255);
                  b := round(v*255);
             end;
          5: begin
                  r := round(v*255);
                  g := round(p*255);
                  b := round(q*255);
             end;
          else
          begin
            r := 0;
            g := 0;
            b := 0;
          end;
     end;
     result := r + g shl 8 + b shl 16;
end;

constructor TColorWheel2.Create(AOwner: TComponent);
begin
     inherited;
     Width := 250;
     Height := 250;
     FBorderSize := 10;
     FSelectedControl := -1;
     ControlStyle := ControlStyle + [csOpaque];
     DoubleBuffered := true;
end;

destructor TColorWheel2.destroy;
begin
   inherited;
end;

procedure TColorWheel2.DrawCircle(x,y : integer; c : TRGBTriple; center : Tpoint; Marked : boolean);
var
   graphics : TGPGraphics;
   Pen : TGPPen;
   Brush : TGPSolidBrush;
begin

  graphics := TGPGraphics.Create(Canvas.Handle);
  graphics.SetSmoothingMode(SmoothingModeAntiAlias);
  pen := TGPPen.Create(makeColor(190,0,0,0));
  brush := TGPSolidBrush.Create(makeColor(255, c.rgbtRed, c.rgbtGreen, c.rgbtBlue));
  try

    graphics.DrawLine(pen, center.X, center.Y, x, y);
    brush.SetColor(makeColor(255,255,255,255));
    graphics.FillEllipse(Brush, x-9, y-9, 18, 18);
    brush.SetColor(makeColor(255, c.rgbtRed, c.rgbtGreen, c.rgbtBlue));
    graphics.FillEllipse(Brush, x-6, y-6, 12, 12);
    if Marked then
      Pen.SetWidth(2.0)
    else
      Pen.SetWidth(1.0);
    graphics.DrawEllipse(Pen, x-9, y-9, 18, 18);
  finally
    pen.free;
    brush.free;
    graphics.free;
  end;
end;


//
// For the selected integer that is passed in
// if it's one of the controls that moves other
// controls then if test is moved with this one then
// it returns true, otherwise false.
//
function TColorWheel2.getJoinedControls(selected, test : integer) : integer;
begin
     result := 0;

     case FSwatchType of
            tcpsMonochromatic, tcpsComplementary, tcpsAnalogous: result := 1;
            tcpsTriad, tcpsSplitComplementary :
            begin
             if selected = 0 then
                result := 1
             else if (selected in [1,2]) and (test in [1, 2]) then
             begin
                  result := 1;
                  if ((selected = 1) and (test = 2)) or ((selected = 2) and (test = 1)) then
                     result := -1
             end
             else
                 result := 0;
            end;
            tcpsFreeForm2, tcpsFreeForm3, tcpsFreeForm4:
            begin
             if selected = 0 then
                result := 1
             else if selected = test then
                  result := 1
             else
                 result := 0;
            end;
            tcpsRectangle, tcpsSquare:
            begin
             if selected in [0,2] then
                result := 1
             else if (selected in [1,3]) and (test in [1,3]) then
                  result := 1
             else
                 result := 0;
            end;
       end;
end;

function TColorWheel2.getNumControls: integer;
begin
  result := FNumColors;
end;

procedure TColorWheel2.PaintControls;
var
   center : TPoint;
   i : integer;
   x,y : double;
   c : TRGBTriple;
   hue, sat : double;
begin
     center := Point(width div 2, height div 2);
     for i := 0 to NumControls - 1 do
     begin
          x := Fradius * cos(FHueArray[i] * PI/180);
          y := Fradius * sin(FHueArray[i] * PI/180);
          x := x + center.x;
          y := y + center.y;
          HueSaturationAtPoint(round(x), round(y) ,min(width,height), hue,sat);
          c := hsv2rgb(hue, sat, 1.0);

          drawCircle(round(x),round(y),c, center, i=0);
          FControlBoundRects[i] := rect(round(x)-10,
            round(y)-10, round(x)+ 10, round(y)+10);
     end;
end;

function TColorWheel2.getAngle(x, y : integer) : double;
begin
            if x = 0 then
            begin
                 if y <0 then
                    result := 270
                 else
                     result := 90;
            end
            else
            begin
              if x < 0 then
                 result := (arctan(y/x)-PI)*(180/PI) // calc the angle and conver to degrees
              else
                 result := (arctan(y/x))*(180/PI); // calc the angle and conver to degrees
              if result <0 then
                 result := result + 360;
            end;
end;

function TColorWheel2.hsv2rgb(hue, sat, value : double) : TRGBTriple;
var
  i, f, p, q,t : double;
  s : integer;
begin
  i := Floor(hue * 6);
  f := hue * 6 - i;
  p := value * (1-sat);
  q := value * (1 - f * sat);
  t := value * (1 - (1-f) * sat);
  s := round(i) mod 6;
  case s of
    0: begin
      result.rgbtRed := round(value * 255);
      result.rgbtGreen := round(t * 255);
      result.rgbtBlue := round(p * 255);
    end;
    1: begin
      result.rgbtRed := round(q * 255);
      result.rgbtGreen := round(value * 255);
      result.rgbtBlue := round(p * 255);
    end;
    2: begin
      result.rgbtRed := round(p * 255);
      result.rgbtGreen := round(value * 255);
      result.rgbtBlue := round(t * 255);
    end;
    3: begin
      result.rgbtRed := round(p * 255);
      result.rgbtGreen := round(q * 255);
      result.rgbtBlue := round(value * 255);
    end;
    4: begin
      result.rgbtRed := round(t * 255);
      result.rgbtGreen := round(p * 255);
      result.rgbtBlue := round(value * 255);
    end;
    5: begin
      result.rgbtRed := round(value * 255);
      result.rgbtGreen := round(p * 255);
      result.rgbtBlue := round(q * 255);
    end;
    else
    begin
      result.rgbtRed := round(value * 255);
      result.rgbtGreen := round(t * 255);
      result.rgbtBlue := round(p * 255);
    end;
  end;


end;

procedure TColorWheel2.PaintCircle(Bitmap : TBitmap);
var
  center : Tpoint;
  i, j : integer;
  p : PRGBTripleArray;
  x, y : integer;
  theta : double;
  lng : double;
  h, w : integer;
  c : TRGBTriple;
  radius : double;
   graphics : TGPGraphics;
   Pen : TGPPen;
   hue, sat : double;
begin

  h := bitmap.height;
  w := bitmap.width;
  center := Point(w div 2, h div 2);
  radius := min(w,h) div 2;
  for j := 0 to h - 1 do
  begin
       p := bitmap.scanline[j];
       for i := 0 to w - 1 do
       begin
            x := i - center.x;
            y := j - center.y;

            lng := sqrt(x*x + y * y);
            if lng > (min(w,h) div 2) then
            begin
              p[i].rgbtRed := color and $FF;
              p[i].rgbtGreen := (color and $FF00) shr 8;
              p[i].rgbtBlue := (color and $FF0000) shr 16;
              continue;
            end;

            HueSaturationAtPoint(i,j,min(w,h), hue,sat);
            c := hsv2rgb(hue, sat, 1.0);

            p[i] := c;

       end;
  end;

  graphics := TGPGraphics.Create(Bitmap.Canvas.Handle);
  graphics.SetSmoothingMode(SmoothingModeAntiAlias);
  pen := TGPPen.Create(makeColor(190,0,0,0));
  pen.setwidth(2.0);
  try
    graphics.DrawEllipse(Pen,
      center.x-radius+1, center.y-radius+1,
      2*radius-2, 2*radius-2);
  finally
    pen.free;
    graphics.free;
  end;
  
end;

procedure TColorWheel2.Paint;
var
  w, h : integer;
  bitmap : TBitmap;
begin
  canvas.brush.Color := clWhite;
  canvas.framerect(clientrect);
  canvas.Brush.color := clWhite;
  canvas.fillrect(rect(0,0,width, height));
  w := width - 2 * FBorderSize;
  h := height - 2 * FBorderSize;
  bitmap := Tbitmap.Create;
  try
    bitmap.width := w;
    bitmap.height := h;
    bitmap.pixelformat := pf24bit;
    PaintCircle(bitmap);
    Canvas.Draw(FBorderSize, FBorderSize, Bitmap);
    PaintControls;
  finally
    Bitmap.free;
  end;

end;

procedure TColorWheel2.SetNumControls(const Value: integer);
begin
  FNumColors := Value;
end;

procedure TColorWheel2.SetBorderSize(const Value: integer);
begin
  FBorderSize := Value;
end;

procedure TColorWheel2.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
begin
  inherited;
  Fradius := min(width div 2 - FBorderSize, height div 2 - FBorderSize);
end;

procedure TColorWheel2.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
   i : integer;
begin
// is the mouse down in the band of the knobs
   for i := 0 to FNumColors - 1 do
   begin
        if PtInRect(FControlBoundRects[i], point(x,y)) then
        begin
             FSelectedControl := i;
             break;
        end;
   end;
end;

procedure TColorWheel2.MoveBigControl(controlIndex : integer; angle : double);
begin
     FHueArray[controlIndex] := FHueArray[controlIndex] + angle;
     while FHueArray[controlIndex] > 360 do
           FHueArray[controlIndex] := FHueArray[controlIndex] - 360;
     while FHueArray[controlIndex] < 0 do
           FHueArray[controlIndex] := FHueArray[controlIndex] + 360;
end;

procedure TColorWheel2.HueSaturationAtPoint(positionx, positiony : integer; size : Integer; var hue, sat : double);
var
  c, dx, dy, d : double;
begin

  c := size / 2;
  dx := (positionx - c) / c;
  dy := (positiony - c) / c;
  d := sqrt(dx*dx + dy*dy);

  sat :=  d;

  if d = 0 then
    hue := 0
  else
  begin
    hue := Math.ArcCos(dx / d) / 3.1417 / 2;
    if dy < 0 then
      hue := 1 - hue;
  end;
end;

procedure TColorWheel2.MouseMove(Shift: TShiftState; X, Y: Integer);
var
   center : TPoint;
   w, h : integer;
   newAngle, angleDelta : double;
   i, diff : integer;
begin
     if FSelectedControl <> -1 then
     begin
          w := width - 2 * FBorderSize;
          h := height - 2 * FBorderSize;
          center := Point(w div 2, h div 2);
          x := x - center.x;
          y := y - center.y;
          newAngle := getAngle(x, y);
          if FSelectedControl = 0 then
          begin
            FRadius := round(sqrt(x*x + y*y));
            FRadius := min(FRadius, min(width div 2 - FBorderSize, height div 2 - FBorderSize));
          end;
          angleDelta := newAngle - FHueArray[FSelectedControl];
          for i := 0 to FNumColors - 1 do
          begin
               diff := getJoinedControls(FSelectedControl, i);
               if diff = 1 then
                 MoveBigControl(i, angleDelta)
               else if diff = -1 then
                 MoveBigControl(i, -angleDelta);
          end;
          invalidate;
          DoColorsChanged;
     end;
end;

procedure TColorWheel2.MouseUp(Button: TMouseButton; Shift: TShiftState; X,
  Y: Integer);
begin
     FSelectedControl := -1;
end;

procedure TColorWheel2.SetColorsChanged(const Value: TNotifyEvent);
begin
  FColorsChanged := Value;
end;

procedure TColorWheel2.SetSwatchType(const Value: TColorPaletteStyle);
begin
  if FSwatchType <> Value then
  begin
   FSwatchType := Value;
   if not (csLoading in componentState) then
   begin

   case FSwatchType of
        tcpsMonochromatic:
        begin
          FNumColors := 1;
          FHueArray[0] := 0;
        end;
        tcpsComplementary, tcpsFreeForm2:
        begin
          FNumColors := 2;
          FHueArray[0] := 0;
          FHueArray[1] := 180;
        end;
        tcpsAnalogous:
        begin
          FNumColors := 3;
          FHueArray[0] := -20;
          FHueArray[1] := 0;
          FHueArray[2] := 20;
        end;
        tcpsTriad, tcpsFreeForm3:
        begin
          FNumColors := 3;
          FHueArray[0] := 0;
          FHueArray[1] := 120;
          FHueArray[2] := 240;
        end;
        tcpsSplitComplementary:
        begin
          FNumColors := 3;
          FHueArray[0] := 0;
          FHueArray[1] := 160;
          FHueArray[2] := 200;
        end;
        tcpsRectangle, tcpsFreeform4:
        begin
          FNumColors := 4;
          FHueArray[0] := 0;
          FHueArray[1] := 45;
          FHueArray[2] := 180;
          FHueArray[3] := 220;
        end;
        tcpsSquare:
        begin
          FNumColors := 4;
          FHueArray[0] := 0;
          FHueArray[1] := 90;
          FHueArray[2] := 180;
          FHueArray[3] := 270;
        end;
   end;
    invalidate;
    DoColorsChanged;
   end;
  end;
end;

procedure TColorWheel2.DoColorsChanged;
begin
     if assigned(FColorsChanged) then
        FColorsChanged(self);
end;

function TColorWheel2.getColor(index: Integer): TColor;
var
  hue, sat : double;
  c : TRGBTriple;
begin

  sat := FRadius / min(width div 2 - FBorderSize, height div 2 - FBorderSize);
  hue := FHueArray[index];
  result := ConvertHSVToColor(hue, sat, 1.0);
end;

end.
