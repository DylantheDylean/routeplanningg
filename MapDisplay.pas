 unit MapDisplay;

  interface

  uses
    Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
    Dialogs, ExtCtrls, Math, Types;

  type
    TLocationPoint = record
      Name: string;
      Latitude: Double;
      Longitude: Double;
      Address: string;
    end;

    TRouteMapDisplay = class(TCustomPanel)  //inherits the tcustompanel methods
    private
      FLocations: array of TLocationPoint;                          //froute order locations so that first in froute is first lcoation e.g if its 4 relates 4th location i location array but its the 1st location for the route
      FRoute: array of Integer;
      FMinLat, FMaxLat, FMinLon, FMaxLon: Double;
      FShowGrid: Boolean;
      FShowCoordinates: Boolean;
      FMapTitle: string;
      FStartLocationIndex: Integer;
      FEndLocationIndex: Integer;
      FOnLocationClick: TNotifyEvent;
      FClickedLocationIndex: Integer;
      FMousePosition: TPoint;
       FLastMouseX, FLastMouseY: Integer;

      procedure CalculateBounds;
      function LatLonToPixel(Lat, Lon: Double): TPoint;
      function PixelToLatLon(X, Y: Integer): TLocationPoint;
      procedure DrawBackground;
      procedure DrawGrid;
      procedure DrawLocation(Canvas: TCanvas; const Loc: TLocationPoint; Index: Integer);
      procedure DrawRoute(Canvas: TCanvas);
      procedure DrawLegend;
      procedure DrawTitle;
      procedure DrawCoordinateInfo;
      function GetLocationColor(Index: Integer): TColor;
      function GetLocationSize(Index: Integer): Integer;

    protected   //if private then get error Cannot reduce the visibility of overridden method and public shouldnt be
      procedure Paint; override;
      procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
      procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;

    public
      constructor Create(AOwner: TComponent); override;  //panel map displayed on is owner

      // Location management
      function AddLocation(const Name, Address: string; Lat, Lon: Double): Integer;
      procedure RemoveLocation(Index: Integer);
      procedure ClearLocations;

      // Route management
      procedure SetRoute(const RouteIndices: array of Integer);
      procedure SetStartEndPoints(StartIndex, EndIndex: Integer);
      procedure ClearRoute;

      // Display options
      procedure SetShowGrid(Value: Boolean);
      procedure SetShowCoordinates(Value: Boolean);
      procedure SetMapTitle(const Title: string);

      // Utility functions
      function GetLocationCount: Integer;
      function GetLocation(Index: Integer): TLocationPoint;
      function GetTotalRouteDistance: Double;
      procedure ZoomToFit;
      procedure SaveMapToFile(const FileName: string);

      // Properties
      property OnLocationClick: TNotifyEvent read FOnLocationClick write FOnLocationClick;
      property ClickedLocationIndex: Integer read FClickedLocationIndex;
    end;

  implementation

  constructor TRouteMapDisplay.Create(AOwner: TComponent);
  begin
    inherited;

    // Set default properties
    Color := clWhite;
    BevelOuter := bvLowered;
    BevelInner := bvRaised;
    Width := 600;
    Height := 400;

    // Initialize settings
    FShowGrid := True;
    FShowCoordinates := True;
    FMapTitle := 'Route Map';
    FStartLocationIndex := -1;
    FEndLocationIndex := -1;
    FClickedLocationIndex := -1;

    // Enable mouse events and painting
    ControlStyle := ControlStyle + [csCaptureMouse, csOpaque];

    // Set default bounds for empty map (Cape Town area)
    FMinLat := -34.0;
    FMaxLat := -33.0;
    FMinLon := 18.0;
    FMaxLon := 19.0;
  end;

  // ============================================================================
  // LOCATION MANAGEMENT
  // ============================================================================

  function TRouteMapDisplay.AddLocation(const Name, Address: string; Lat, Lon: Double): Integer;
  var
    NewLocation: TLocationPoint;
    Len: Integer;
  begin
    NewLocation.Name := Name;
    NewLocation.Address := Address;
    NewLocation.Latitude := Lat;
    NewLocation.Longitude := Lon;

    Len := Length(FLocations);
    SetLength(FLocations, Len + 1);
    FLocations[Len] := NewLocation;

    CalculateBounds;
    Invalidate; // Force repaint

    Result := Len;
  end;

  procedure TRouteMapDisplay.RemoveLocation(Index: Integer);
  var
    i,CorrectPosition : Integer;

  begin
    if (Index < 0) or (Index >= Length(FLocations)) then Exit;

    // Shift locations down
    for i := Index to length(FLocations) - 2 do
      FLocations[i] := FLocations[i + 1];

   SetLength(FLocations, Length(FLocations) - 1);



    CorrectPosition  :=0;

    // Update route indices
    for i := 0 to length(FRoute) -1 do
    begin
      if FRoute[i] > Index then
        begin
          FRoute[CorrectPosition ] := FRoute[i] -1;
          CorrectPosition  :=CorrectPosition  +1;
        end
      else if FRoute[i] = Index then
        continue
      else
        FRoute[CorrectPosition] := FRoute[i];
        inc(CorrectPosition );
    end;

    SetLength( FRoute ,CorrectPosition  );

    CalculateBounds;
    Invalidate; // Force repaint
  end;

  procedure TRouteMapDisplay.ClearLocations;
  begin
    SetLength(FLocations, 0);
    SetLength(FRoute, 0);
    FStartLocationIndex := -1;
    FEndLocationIndex := -1;

    // Reset to default bounds
    FMinLat := -34.0;
    FMaxLat := -33.0;
    FMinLon := 18.0;
    FMaxLon := 19.0;

    Invalidate; // Force repaint
  end;

  // ============================================================================
  // ROUTE MANAGEMENT
  // ============================================================================

  procedure TRouteMapDisplay.SetRoute(const RouteIndices: array of Integer);
var
  i: Integer;
begin
  SetLength(FRoute, Length(RouteIndices));

  // Ensure the route order reflects actual travel sequence

  for i := 0 to High(RouteIndices) do
    FRoute[i] := RouteIndices[i];

  Invalidate; // Force repaint
end;

  procedure TRouteMapDisplay.SetStartEndPoints(StartIndex, EndIndex: Integer);
  begin
    FStartLocationIndex := StartIndex;
    FEndLocationIndex := EndIndex;
    Invalidate; // Force repaint
  end;

  procedure TRouteMapDisplay.ClearRoute;
  begin
    SetLength(FRoute, 0);
    Invalidate; // Force repaint
  end;
                      //here
  // ============================================================================
  // COORDINATE CALCULATIONS
  // ============================================================================

  procedure TRouteMapDisplay.CalculateBounds;
  var
    i: Integer;
    Padding: Double;
  begin
    if Length(FLocations) = 0 then
    begin
      FMinLat := -34.0;
      FMaxLat := -33.0;
      FMinLon := 18.0;
      FMaxLon := 19.0;
      Exit;
    end;

    FMinLat := FLocations[0].Latitude;
    FMaxLat := FLocations[0].Latitude;
    FMinLon := FLocations[0].Longitude;
    FMaxLon := FLocations[0].Longitude;

    for i := 1 to High(FLocations) do
    begin
      if FLocations[i].Latitude < FMinLat then FMinLat := FLocations[i].Latitude;
      if FLocations[i].Latitude > FMaxLat then FMaxLat := FLocations[i].Latitude;
      if FLocations[i].Longitude < FMinLon then FMinLon := FLocations[i].Longitude;
      if FLocations[i].Longitude > FMaxLon then FMaxLon := FLocations[i].Longitude;
    end;

    // Add padding (10% of range)
    Padding := Max((FMaxLat - FMinLat) * 0.1, 0.001);//either 10 range or 0.001 whatever bigger
    FMinLat := FMinLat - Padding;
    FMaxLat := FMaxLat + Padding;

    Padding := Max((FMaxLon - FMinLon) * 0.1, 0.001);
    FMinLon := FMinLon - Padding;
    FMaxLon := FMaxLon + Padding;
  end;
  function TRouteMapDisplay.LatLonToPixel(Lat, Lon: Double): TPoint;
  var
    X, Y: Integer;
    MapWidth, MapHeight: Integer;
  begin
    MapWidth := Width - 60;  // Leave space for margins
    MapHeight := Height - 80; // Leave space for title and legend

    if (FMaxLat = FMinLat) or (FMaxLon = FMinLon) then
    begin
      Result := Point(Width div 2, Height div 2);
      Exit;
    end;
                                               //here not happy with the distortioan tho  table mountain being above camps bay
    X := Round((Lon - FMinLon) / (FMaxLon - FMinLon) * MapWidth) ;
    Y := Round((FMaxLat - Lat) / (FMaxLat - FMinLat) * MapHeight) ;

    Result := Point(X, Y);
  end;

  function TRouteMapDisplay.PixelToLatLon(X, Y: Integer): TLocationPoint;
  var
    Lat, Lon: Double;
    MapWidth, MapHeight: Integer;
  begin
    MapWidth := Width - 60;
    MapHeight := Height - 80;

    if (MapWidth <= 0) or (MapHeight <= 0) then
    begin
      Result.Latitude := 0;
      Result.Longitude := 0;
      Exit;
    end;

    Lon := FMinLon + ((X ) / MapWidth) * (FMaxLon - FMinLon);
    Lat := FMaxLat - ((Y ) / MapHeight) * (FMaxLat - FMinLat);

    Result.Latitude := Lat;
    Result.Longitude := Lon;
    Result.Name := '';
    Result.Address := '';
  end;

  // ============================================================================
  // DRAWING METHODS
  // ============================================================================

  procedure TRouteMapDisplay.DrawBackground;
  begin
    Canvas.Brush.Color := Color;
    Canvas.Brush.Style := bsSolid;
    Canvas.FillRect(ClientRect);
  end;

  procedure TRouteMapDisplay.DrawGrid;
  var
    i: Integer;
    GridSpacing: Integer;
  begin
    if not FShowGrid then Exit;

    Canvas.Pen.Color := RGB(230, 230, 230);
    Canvas.Pen.Width := 1;
    Canvas.Pen.Style := psDot;

    GridSpacing := 20;

    // Vertical lines
    for i := 0 to (Width div GridSpacing) do
    begin
      Canvas.MoveTo(i * GridSpacing, 0);
      Canvas.LineTo(i * GridSpacing, Height);
    end;

    // Horizontal lines
    for i := 0 to (Height div GridSpacing) do
    begin
      Canvas.MoveTo(0, i * GridSpacing);
      Canvas.LineTo(Width, i * GridSpacing);
    end;

    Canvas.Pen.Style := psSolid;
  end;

  function TRouteMapDisplay.GetLocationColor(Index: Integer): TColor;         //here
  begin
    if Index = FStartLocationIndex then
      Result := clGreen
    else if Index = FEndLocationIndex then
      Result := clRed
    else
      Result := clBlue;
  end;

  function TRouteMapDisplay.GetLocationSize(Index: Integer): Integer;
  begin
    if (Index = FStartLocationIndex) or (Index = FEndLocationIndex) then
      Result := 10
    else
      Result := 8;
  end;

procedure TRouteMapDisplay.DrawLocation(Canvas: TCanvas; const Loc: TLocationPoint; Index: Integer);
var
  Pt: TPoint;
  Radius: Integer;
  TextWidth, TextHeight: Integer;
  DisplayNumber: string;
  RoutePosition: Integer;
  i: Integer;
begin
  Pt := LatLonToPixel(Loc.Latitude, Loc.Longitude);
  Radius := GetLocationSize(Index);

  // Draw location circle
  Canvas.Brush.Color := GetLocationColor(Index);
  Canvas.Brush.Style := bsSolid;
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Width := 2;
  Canvas.Pen.Style := psSolid;
  Canvas.Ellipse(Pt.X - Radius, Pt.Y - Radius, Pt.X + Radius, Pt.Y + Radius);

  // Draw location name
  Canvas.Font.Color := clBlack;
  Canvas.Font.Size := 9;
  Canvas.Font.Style := [fsBold];
  Canvas.Brush.Color := clWhite;
  Canvas.Pen.Color := clBlack;
  Canvas.Pen.Width := 1;

  TextWidth := Canvas.TextWidth(Loc.Name);
  TextHeight := Canvas.TextHeight(Loc.Name);

  // Draw text background
  Canvas.Rectangle(Pt.X + 11, Pt.Y + TextHeight div 2 + 2,
                  Pt.X + 11 + TextWidth + 4, Pt.Y - TextHeight div 2 - 2);

  // Draw text
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(Pt.X + 15, Pt.Y - TextHeight div 2, Loc.Name);
  Canvas.Brush.Style := bsSolid;

  // Determine what number/letter to display
  RoutePosition := -1;

  // If there's a route, find this location's position in the route
  if Length(FRoute) > 0 then
  begin
    for i := 0 to High(FRoute) do
    begin
      if FRoute[i] = Index then
      begin
        RoutePosition := i + 1; // +1 to make it 1-based instead of 0-based
        Break;
      end;
    end;
  end;

  // Choose display: route position or location index
  if RoutePosition > 0 then
    DisplayNumber := IntToStr(RoutePosition)
  else
    DisplayNumber := IntToStr(Index + 1);

  // Draw the number on the location
  Canvas.Font.Color := clWhite;
  Canvas.Font.Size := 8;
  Canvas.Font.Style := [fsBold];
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(Pt.X - 3, Pt.Y - 6, DisplayNumber);
  Canvas.Brush.Style := bsSolid;
end;

  procedure TRouteMapDisplay.DrawRoute(Canvas: TCanvas);                      //here
  var
    i: Integer;
    Pt1, Pt2: TPoint;

    dx, dy: Double;
    angle: Double;
    ArrowPoints: array[0..2] of TPoint;
  begin
    if Length(FRoute) < 2 then Exit;

    Canvas.Pen.Color := RGB(0, 100, 200);
    Canvas.Pen.Width := 3;
    Canvas.Pen.Style := psSolid;



    for i := 0 to Length(FRoute) - 2 do
    begin

      Pt1 := LatLonToPixel(FLocations[FRoute[i]].Latitude, FLocations[FRoute[i]].Longitude);
      Pt2 := LatLonToPixel(FLocations[FRoute[i+1]].Latitude, FLocations[FRoute[i+1]].Longitude);

      // Draw line
      Canvas.MoveTo(Pt1.X, Pt1.Y);
      Canvas.LineTo(Pt2.X, Pt2.Y);
                                                   //add something for when lines like go over each other loopback make more clear think ideas

    end;
  end;

  procedure TRouteMapDisplay.DrawTitle;
  begin
    Canvas.Font.Color := clBlack;
    Canvas.Font.Size := 12;
    Canvas.Font.Style := [fsBold];
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(10, 10, FMapTitle);
    Canvas.Brush.Style := bsSolid;
  end;

  procedure TRouteMapDisplay.DrawLegend;
  var
    LegendY: Integer;
  begin
    LegendY := Height - 30;

    Canvas.Font.Color := clBlack;
    Canvas.Font.Size := 8;
    Canvas.Font.Style := [];
    Canvas.Brush.Style := bsClear;

    // Start point legend
    Canvas.Brush.Color := clGreen;
    Canvas.Brush.Style := bsSolid;
    Canvas.Pen.Color := clBlack;
    Canvas.Ellipse(10, LegendY, 20, LegendY + 10);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(25, LegendY, 'Start');

    // End point legend
    Canvas.Brush.Color := clRed;
    Canvas.Brush.Style := bsSolid;
    Canvas.Ellipse(70, LegendY, 80, LegendY + 10);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(85, LegendY, 'End');

    // Stop point legend
    Canvas.Brush.Color := clBlue;
    Canvas.Brush.Style := bsSolid;
    Canvas.Ellipse(120, LegendY, 130, LegendY + 10);
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(135, LegendY, 'Stop');

    Canvas.Brush.Style := bsSolid;
  end;

  procedure TRouteMapDisplay.DrawCoordinateInfo;                     //here
  var
    CoordText: string;
    MouseLatLon: TLocationPoint;

  begin


    MouseLatLon := PixelToLatLon(FMousePosition.X, FMousePosition.Y);
    CoordText := Format('Lat: %.4f, Lon: %.4f', [MouseLatLon.Latitude, MouseLatLon.Longitude]);  //$4f floating point number 4 values replaced by the first thing brackets next the next thjing in brackers

     // Clear old coordinates area (bottom right corner)
    Canvas.Brush.Color := clWhite;  // Same as background
    Canvas.FillRect(Rect(Width - 160, Height - 25, Width, Height));


    Canvas.Font.Color := clBlack;
    Canvas.Font.Size := 8;
    Canvas.Brush.Style := bsClear;
    Canvas.TextOut(Width - 150, Height - 20, CoordText);

  end;

  // ============================================================================
  // MAIN PAINT METHOD
  // ============================================================================

  procedure TRouteMapDisplay.Paint;
  var
    i: Integer;
  begin
    inherited;

    DrawBackground;
    DrawGrid;
    DrawTitle;
    DrawRoute(Canvas);

    // Draw locations (on top of route)
    for i := 0 to Length(FLocations) -1 do
      DrawLocation(Canvas, FLocations[i], i);

    DrawLegend;

  end;

  // ============================================================================
  // MOUSE EVENTS
  // ============================================================================


  procedure TRouteMapDisplay.MouseMove(Shift: TShiftState; X, Y: Integer);
  begin
    inherited;
    FMousePosition := Point(X, Y);

    // Only update if mouse actually moved to a different pixel
    if (X <> FLastMouseX) or (Y <> FLastMouseY) then
    begin
      if FShowCoordinates then
        DrawCoordinateInfo;

      FLastMouseX := X;
      FLastMouseY := Y;
    end;
  end;

  procedure TRouteMapDisplay.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);          //here
  var
    i: Integer;
    Pt: TPoint;
    Distance: Double;
  begin
    inherited;

    if Button = mbLeft then
    begin
      // Check if clicked on a location
      for i := 0 to Length(FLocations) -1 do
      begin
        Pt := LatLonToPixel(FLocations[i].Latitude, FLocations[i].Longitude);
        Distance := Sqrt(Sqr(X - Pt.X) + Sqr(Y - Pt.Y));

        if Distance <= GetLocationSize(i) + 2 then
        begin
          FClickedLocationIndex := i;

          FOnLocationClick(Self);

        end;
      end;

      FClickedLocationIndex := -1;//missed
    end;
  end;

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  function TRouteMapDisplay.GetLocationCount: Integer;
  begin
    Result := Length(FLocations);
  end;

  function TRouteMapDisplay.GetLocation(Index: Integer): TLocationPoint;
  begin
    if (Index >= 0) and (Index < Length(FLocations)) then
      Result := FLocations[Index]
    else
    begin
      Result.Name := '';
      Result.Address := '';
      Result.Latitude := 0;
      Result.Longitude := 0;
    end;
  end;

  function TRouteMapDisplay.GetTotalRouteDistance: Double;                              //unused
  var
    i: Integer;
    Lat1, Lon1, Lat2, Lon2: Double;
    R, dLat, dLon, a, c: Double;
  begin
    Result := 0;
    if Length(FRoute) < 2 then Exit;

    R := 6371; // Earth's radius in km

    for i := 0 to Length(FRoute) - 2 do
    begin

       //radians
      Lat1 := FLocations[FRoute[i]].Latitude * Pi / 180;
      Lon1 := FLocations[FRoute[i]].Longitude * Pi / 180;
      Lat2 := FLocations[FRoute[i+1]].Latitude * Pi / 180;
      Lon2 := FLocations[FRoute[i+1]].Longitude * Pi / 180;

      dLat := Lat2 - Lat1;                                                                                     //haversines formula
      dLon := Lon2 - Lon1;

      a := Sin(dLat/2) * Sin(dLat/2) + Cos(Lat1) * Cos(Lat2) * Sin(dLon/2) * Sin(dLon/2);
      c := 2 * ArcTan2(Sqrt(a), Sqrt(1-a));

      Result := Result + R * c;
    end;
  end;

  procedure TRouteMapDisplay.ZoomToFit;                //unused
  begin
    CalculateBounds;
    Invalidate;
  end;

  procedure TRouteMapDisplay.SaveMapToFile(const FileName: string);                  //unused
  var
    Bitmap: TBitmap;
  begin
    Bitmap := TBitmap.Create;
    try
      Bitmap.Width := Width;
      Bitmap.Height := Height;
      Bitmap.Canvas.Brush.Color := Color;
      Bitmap.Canvas.FillRect(Rect(0, 0, Width, Height));

      // Copy current map to bitmap
      PaintTo(Bitmap.Canvas, 0, 0);

      Bitmap.SaveToFile(FileName);
    finally
      Bitmap.Free;
    end;
  end;

  // ============================================================================
  // PROPERTY SETTERS
  // ============================================================================

  procedure TRouteMapDisplay.SetShowGrid(Value: Boolean);
  begin

      FShowGrid := Value;
      Invalidate;

  end;

  procedure TRouteMapDisplay.SetShowCoordinates(Value: Boolean);
  begin

      FShowCoordinates := Value;
      Invalidate;

  end;

  procedure TRouteMapDisplay.SetMapTitle(const Title: string);
  begin


      FMapTitle := Title;
      Invalidate;

  end;

  end.
