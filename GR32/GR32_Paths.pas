unit GR32_Paths;

interface

uses
  Classes, GR32, GR32_Polygons, Math;

type
  TCustomPath = class;

  TCustomSegment = class(TPersistent)
  protected
    procedure BreakSegment(Path: TCustomPath; const P1, P2: TFloatPoint); virtual; abstract;
    function FindClosestPoint(const P1, P2, P: TFloatPoint): TFloatPoint; virtual; abstract;
  end;

  TLineSegment = class(TCustomSegment)
  protected
    procedure BreakSegment(Path: TCustomPath; const P1, P2: TFloatPoint); override;
    function FindClosestPoint(const P1, P2, P: TFloatPoint): TFloatPoint; override;
  end;

  PControlPoints = ^TControlPoints;
  TControlPoints = array [0..1] of TFloatPoint;

  TBezierSegment = class(TCustomSegment)
  private
    FControlPoints: TControlPoints;
    function GetControlPoints: PControlPoints;
  protected
    procedure BreakSegment(Path: TCustomPath; const P1, P2: TFloatPoint); override;
    function FindClosestPoint(const P1, P2, P: TFloatPoint): TFloatPoint; override;
  public
    constructor Create; overload;
    constructor Create(const C1, C2: TFloatPoint); overload;
    function GetCoefficient(const P1, P2, P: TFloatPoint): TFloat;
    procedure CurveThroughPoint(Path: TCustomPath; Index: Integer; P: TFloatPoint;
      Coeff: TFloat);
    property ControlPoints: PControlPoints read GetControlPoints;
  end;

  TSegmentList = class(TList)
  private
    function GetCustomSegment(Index: Integer): TCustomSegment;
    procedure SetCustomSegment(Index: Integer;
      const Value: TCustomSegment);
  public
    property Items[Index: Integer]: TCustomSegment read GetCustomSegment write SetCustomSegment; default;
  end;

  TCustomPath = class(TPersistent)
  private
    FVertices: TArrayOfFloatPoint;
    FOutput: TArrayOfFloatPoint;
    FSegmentList: TSegmentList;
    FVertCount: Integer;
    FOutCount: Integer;
    function GetOutputCapacity: Integer;
    function GetVertexCapacity: Integer;
    procedure SetOutputCapacity(const Value: Integer);
    procedure SetVertexCapacity(const Value: Integer);
    function GetEndPoint: TFloatPoint;
    function GetStartPoint: TFloatPoint;
    procedure SetEndPoint(const Value: TFloatPoint);
    procedure SetStartPoint(const Value: TFloatPoint);
    function GetSegment(Index: Integer): TCustomSegment;
    function GetVertex(Index: Integer): TFloatPoint;
    function GetLastSegment: TCustomSegment;
    function GetSegmentCount: Integer;
  protected
    procedure AppendPoint(const Point: TFloatPoint);
  public
    constructor Create;
    destructor Destroy; override;
    function ConvertToPolygon: TPolygon32;
    function FindClosestVertex(const P: TFloatPoint): PFloatPoint;
    function FindClosestSegment(const P: TFloatPoint;
      out Segment: TCustomSegment; out OutPoint: TFloatPoint): Integer;
    function GetCoefficient(const P: TFloatPoint; Index: Integer): TFloat;
    procedure CurveThroughPoint(const P: TFloatPoint; Index: Integer; Coeff: TFloat);
    procedure AddStartPoint(const P: TFloatPoint);
    procedure AddSegment(const P: TFloatPoint; Segment: TCustomSegment);
    procedure InsertSegment(const P: TFloatPoint; Segment: TCustomSegment; Index: Integer);
    procedure DeleteSegment(Index: Integer);
    procedure RemoveSegment(Segment: TCustomSegment);
    function IndexOf(Segment: TCustomSegment): Integer;
    procedure Offset(const Dx, Dy: TFloat);
    property VertexCapacity: Integer read GetVertexCapacity write SetVertexCapacity;
    property OutputCapacity: Integer read GetOutputCapacity write SetOutputCapacity;
    property StartPoint: TFloatPoint read GetStartPoint write SetStartPoint;
    property EndPoint: TFloatPoint read GetEndPoint write SetEndPoint;
    property Segments[Index: Integer]: TCustomSegment read GetSegment;
    property Vertices[Index: Integer]: TFloatPoint read GetVertex;
    property VertexCount: Integer read FVertCount;
    property SegmentCount: Integer read GetSegmentCount;
    property LastSegment: TCustomSegment read GetLastSegment;
  end;

var
  BezierTolerance: Single = 1;

function SqrDistance(const A, B: TFloatPoint): TFloat;
function AddPoints(const A, B: TFloatPoint): TFloatPoint;

implementation

uses
  SysUtils, GR32_LowLevel;

function AddPoints(const A, B: TFloatPoint): TFloatPoint;
begin
  Result.X := A.X + B.X;
  Result.Y := A.Y + B.Y;
end;

// Returns square of the distance between points A and B.
function SqrDistance(const A, B: TFloatPoint): TFloat;
begin
  Result := Sqr(A.X - B.X) + Sqr(A.Y - B.Y);
end;


// Returns a point on the line from A to B perpendicular to C.
function PointOnLine(const A, B, C: TFloatPoint): TFloatPoint;
var
  dx, dy, r: Single;
begin
  dx := B.X - A.X;
  dy := B.Y - A.Y;
  r := ((C.X - A.X) * dx + (C.Y - A.Y) * dy) / (Sqr(dx) + Sqr(dy));
  if InRange(r, 0, 1) then
  begin
    Result.X := A.X + r * dx;
    Result.Y := A.Y + r * dy;
  end
  else
  begin
    if SqrDistance(A, C) < SqrDistance(B, C) then
      Result := A
    else
      Result := B;
  end;
end;

function Flatness(P1, P2, P3, P4: TFloatPoint): Single;
begin
  Result :=
    Abs(P1.X + P3.X - 2*P2.X) +
    Abs(P1.Y + P3.Y - 2*P2.Y) +
    Abs(P2.X + P4.X - 2*P3.X) +
    Abs(P2.Y + P4.Y - 2*P3.Y);
end;

{ TLineSegment }

procedure TLineSegment.BreakSegment(Path: TCustomPath; const P1, P2: TFloatPoint);
begin
  Path.AppendPoint(P2);
end;

function TLineSegment.FindClosestPoint(const P1, P2, P: TFloatPoint): TFloatPoint;
begin
  Result := PointOnLine(P1, P2, P);
end;

{ TBezierSegment }

procedure TBezierSegment.BreakSegment(Path: TCustomPath; const P1, P2: TFloatPoint);
var
  C1, C2: TFloatPoint;

  procedure Recurse(const P1, P2, P3, P4: TFloatPoint);
  var
    P12, P23, P34, P123, P234, P1234: TFloatPoint;
  begin
    if Flatness(P1, P2, P3, P4) < BezierTolerance then
    begin
      Path.AppendPoint(P4);
    end
    else
    begin
      P12.X   := (P1.X + P2.X) * 1/2;
      P12.Y   := (P1.Y + P2.Y) * 1/2;
      P23.X   := (P2.X + P3.X) * 1/2;
      P23.Y   := (P2.Y + P3.Y) * 1/2;
      P34.X   := (P3.X + P4.X) * 1/2;
      P34.Y   := (P3.Y + P4.Y) * 1/2;
      P123.X  := (P12.X + P23.X) * 1/2;
      P123.Y  := (P12.Y + P23.Y) * 1/2;
      P234.X  := (P23.X + P34.X) * 1/2;
      P234.Y  := (P23.Y + P34.Y) * 1/2;
      P1234.X := (P123.X + P234.X) * 1/2;
      P1234.Y := (P123.Y + P234.Y) * 1/2;

      Recurse(P1, P12, P123, P1234);
      Recurse(P1234, P234, P34, P4);
    end;
  end;

begin
  C1 := AddPoints(FControlPoints[0], P1);
  C2 := AddPointS(FControlPoints[1], P2);
  Recurse(P1, C1, C2, P2);
end;

constructor TBezierSegment.Create(const C1, C2: TFloatPoint);
begin
  FControlPoints[0] := C1;
  FControlPoints[1] := C2;
end;

constructor TBezierSegment.Create;
begin
  //
end;

const
  Epsilon = 1;

function TBezierSegment.FindClosestPoint(const P1, P2, P: TFloatPoint): TFloatPoint;
var
  C1, C2: TFloatPoint;

  function FindPoint(const P1, P2, P3, P4: TFloatPoint; D1, D2: TFloat): TFloatPoint;
  var
    P12, P23, P34, P123, P234, P1234: TFloatPoint;
    NewD: TFloat;
  begin
    P12.X   := (P1.X + P2.X) * 1/2;
    P12.Y   := (P1.Y + P2.Y) * 1/2;
    P23.X   := (P2.X + P3.X) * 1/2;
    P23.Y   := (P2.Y + P3.Y) * 1/2;
    P34.X   := (P3.X + P4.X) * 1/2;
    P34.Y   := (P3.Y + P4.Y) * 1/2;
    P123.X  := (P12.X + P23.X) * 1/2;
    P123.Y  := (P12.Y + P23.Y) * 1/2;
    P234.X  := (P23.X + P34.X) * 1/2;
    P234.Y  := (P23.Y + P34.Y) * 1/2;
    P1234.X := (P123.X + P234.X) * 1/2;
    P1234.Y := (P123.Y + P234.Y) * 1/2;

    NewD := SqrDistance(P, P1234);
    if (NewD < D1) and (NewD < D2) then
    begin
      P12 := FindPoint(P1, P12, P123, P1234, D1, NewD);
      P23 := FindPoint(P1234, P234, P34, P4, NewD, D2);
      if SqrDistance(P, P12) < SqrDistance(P, P23) then
        Result := P12
      else
        Result := P23;
    end
    else
      case CompareValue(D1, D2, Epsilon) of
       -1: Result := FindPoint(P1, P12, P123, P1234, D1, NewD);
        1: Result := FindPoint(P1234, P234, P34, P4, NewD, D2);
        0: Result := P1234;
      end;
  end;

begin
  C1 := AddPoints(FControlPoints[0], P1);
  C2 := AddPointS(FControlPoints[1], P2);
  Result := FindPoint(P1, C1, C2, P2, Infinity, Infinity);
end;

procedure TBezierSegment.CurveThroughPoint(Path: TCustomPath; Index: Integer;
  P: TFloatPoint; Coeff: TFloat);
var
  P1, P2, C1, C2, D1, D2: TFloatPoint;
  t, t3, s, s3, w, a, ax, ay, a1, a2: TFloat;
begin
  P1 := Path.Vertices[Index];
  P2 := Path.Vertices[Index + 1];
  C1 := FControlPoints[0];
  C2 := FControlPoints[1];

  t := Coeff;
  t3 := t * t * t;

  s := 1 - t;
  s3 := s * s * s;

  w := (P.X - s3 * P1.X - t3 * P2.X) / (3 * s * t);
  ax := ((w - P1.X - t * (P2.X - P1.X)) / (C1.X + t * (C2.X - C1.X)));

  w := (P.Y - s3 * P1.Y - t3 * P2.Y) / (3 * s * t);
  ay := ((w - P1.Y - t * (P2.Y - P1.Y)) / (C1.Y + t * (C2.Y - C1.Y)));

  C1.X := ax * C1.X;
  C1.Y := ay * C1.Y;
                                                 
  C2.X := ax * C2.X;
  C2.Y := ay * C2.Y;

  FControlPoints[0] := C1;
  FControlPoints[1] := C2;

  if (Index > 0) and (Path.Segments[Index - 1] is TBezierSegment) then
  begin
    D1 := TBezierSegment(Path.Segments[Index - 1]).ControlPoints[1];
    a1 := Sqrt(Sqr(D1.X) + Sqr(D1.Y));

    D1.X := ax * D1.X;
    D1.Y := ay * D1.Y;

    a := Sqrt(Sqr(D1.X) + Sqr(D1.Y));
    D1.X := a1 / a * D1.X;
    D1.Y := a1 / a * D1.Y;
    (Path.Segments[Index - 1] as TBezierSegment).ControlPoints[1] := D1;
  end;

  if (Index < Path.SegmentCount - 1) and (Path.Segments[Index + 1] is TBezierSegment) then
  begin
    D2 := TBezierSegment(Path.Segments[Index + 1]).ControlPoints[0];
    a2 := Sqrt(Sqr(D2.X) + Sqr(D2.Y));

    D2.X := ax * D2.X;
    D2.Y := ay * D2.Y;

    a := Sqrt(Sqr(D2.X) + Sqr(D2.Y));
    D2.X := a2 / a * D2.X;
    D2.Y := a2 / a * D2.Y;
    (Path.Segments[Index + 1] as TBezierSegment).ControlPoints[0] := D2;
  end;
end;


function TBezierSegment.GetControlPoints: PControlPoints;
begin
  Result := @FControlPoints;
end;

function TBezierSegment.GetCoefficient(const P1, P2, P: TFloatPoint): TFloat;
var
  C1, C2, OutPoint: TFloatPoint;

  function FindPoint(const P1, P2, P3, P4: TFloatPoint; D1, D2, Delta, Pos: TFloat; out POut: TFloatPoint): TFloat;
  var
    P12, P23, P34, P123, P234, P1234: TFloatPoint;
    R1, R2, NewD: TFloat;
  begin
    P12.X   := (P1.X + P2.X) * 1/2;
    P12.Y   := (P1.Y + P2.Y) * 1/2;
    P23.X   := (P2.X + P3.X) * 1/2;
    P23.Y   := (P2.Y + P3.Y) * 1/2;
    P34.X   := (P3.X + P4.X) * 1/2;
    P34.Y   := (P3.Y + P4.Y) * 1/2;
    P123.X  := (P12.X + P23.X) * 1/2;
    P123.Y  := (P12.Y + P23.Y) * 1/2;
    P234.X  := (P23.X + P34.X) * 1/2;
    P234.Y  := (P23.Y + P34.Y) * 1/2;
    P1234.X := (P123.X + P234.X) * 1/2;
    P1234.Y := (P123.Y + P234.Y) * 1/2;

    Delta := Delta * 1/2;
    NewD := SqrDistance(P, P1234);
    if (NewD < D1) and (NewD < D2) then
    begin
      R1 := FindPoint(P1, P12, P123, P1234, D1, NewD, Delta, Pos - Delta, P12);
      R2 := FindPoint(P1234, P234, P34, P4, NewD, D2, Delta, Pos + Delta, P23);
      if SqrDistance(P, P12) < SqrDistance(P, P23) then
      begin
        POut := P12;
        Result := R1;
      end
      else
      begin
        POut := P23;
        Result := R2;
      end;
    end
    else
      case CompareValue(D1, D2, Epsilon) of
       -1: Result := FindPoint(P1, P12, P123, P1234, D1, NewD, Delta, Pos - Delta, POut);
        1: Result := FindPoint(P1234, P234, P34, P4, NewD, D2, Delta, Pos + Delta, POut);
        0:
          begin
            POut := P1234;
            Result := Pos;
          end;
      end;
  end;

begin
  C1 := AddPoints(P1, FControlPoints[0]);
  C2 := AddPoints(P2, FControlPoints[1]);
  Result := FindPoint(P1, C1, C2, P2, Infinity, Infinity, 0.5, 0.5, OutPoint);
end;

{ TCustomPath }

procedure TCustomPath.AddSegment(const P: TFloatPoint; Segment: TCustomSegment);
begin
  FSegmentList.Add(Segment);
  if High(FVertices) < FVertCount then
    SetLength(FVertices, Length(FVertices) * 2);

  FVertices[FVertCount] := P;
  Inc(FVertCount);
end;

procedure TCustomPath.AddStartPoint(const P: TFloatPoint);
begin
  FVertices[0] := P;
  Inc(FVertCount);
end;

procedure TCustomPath.AppendPoint(const Point: TFloatPoint);
begin
  if High(FOutput) < FOutCount then
    SetLength(FOutput, Length(FOutput) * 2);
  FOutput[FOutCount] := Point;
  Inc(FOutCount);
end;

function TCustomPath.ConvertToPolygon: TPolygon32;
var
  I: Integer;
  FixedPoints: TArrayOfFixedPoint;
begin
  FOutput := nil;
  SetLength(FOutput, 4);
  FOutCount := 0;
  
  AppendPoint(StartPoint);
  for I := 0 to FSegmentList.Count - 1 do
    FSegmentList[I].BreakSegment(Self, FVertices[I], FVertices[I + 1]);

  Result := TPolygon32.Create;
  SetLength(FixedPoints, FOutCount);
  for I := 0 to FOutCount - 1 do
    FixedPoints[I] := FixedPoint(FOutput[I]);
  Result.Points[0] := FixedPoints;
end;

constructor TCustomPath.Create;
begin
  FVertCount := 0;
  FOutCount := 0;
  SetLength(FVertices, 4);
  SetLengtH(FOutput, 4);
  FSegmentList := TSegmentList.Create;
end;

procedure TCustomPath.CurveThroughPoint(const P: TFloatPoint; Index: Integer; Coeff: TFloat);
var
  S: TCustomSegment;
begin
  S := FSegmentList[Index];
  if S is TBezierSegment then
    TBezierSegment(S).CurveThroughPoint(Self, Index, P, Coeff);
end;

procedure TCustomPath.DeleteSegment(Index: Integer);
var
  S: TCustomSegment;
begin
  S := FSegmentList[Index];
  if Assigned(S) then
  begin
    FreeAndNil(S);
    MoveLongWord(FVertices[Index+1], FVertices[Index], FVertCount - Index);
    Dec(FVertCount);
  end;
end;

destructor TCustomPath.Destroy;
var
  I: Integer;
begin
  FVertices := nil;
  FOutput := nil;
  for I := 0 to FSegmentList.Count - 1 do
    FSegmentList[I].Free;
  FSegmentList.Clear;
  FSegmentList.Free;
  inherited;
end;

function TCustomPath.FindClosestSegment(const P: TFloatPoint;
  out Segment: TCustomSegment; out OutPoint: TFloatPoint): Integer;
var
  S: TCustomSegment;
  Q: TFloatPoint;
  I: Integer;
  d, d_min: TFloat;
begin
  d_min := MaxSingle;
  Segment := nil;
  for I := 0 to FSegmentList.Count - 1 do
  begin
    S := FSegmentList[I];
    Q := S.FindClosestPoint(FVertices[I], FVertices[I + 1], P);
    d := SqrDistance(P, Q);
    if d < d_min then
    begin
      d_min := d;
      Segment := S;
      OutPoint := Q;
      Result := I;
    end;
  end;
end;

function TCustomPath.FindClosestVertex(const P: TFloatPoint): PFloatPoint;
var
  I: Integer;
  D, MinD: TFloat;
begin
  MinD := Infinity;
  for I := 0 to FVertCount - 1 do
  begin
    D := SqrDistance(P, FVertices[I]);
    if D < MinD then
    begin
      MinD := D;
      Result := @FVertices[I];
    end;
  end;
end;

function TCustomPath.GetCoefficient(const P: TFloatPoint;
  Index: Integer): TFloat;
var
  S: TCustomSegment;
begin
  Result := 0;
  S := FSegmentList[Index];
  if S is TBezierSegment then
    Result := TBezierSegment(S).GetCoefficient(FVertices[Index], FVertices[Index + 1], P);
end;

function TCustomPath.GetEndPoint: TFloatPoint;
begin
  Result := FVertices[FVertCount - 1];
end;

function TCustomPath.GetLastSegment: TCustomSegment;
begin
  Result := FSegmentList.Last;
end;

function TCustomPath.GetOutputCapacity: Integer;
begin
  Result := Length(FOutput);
end;

function TCustomPath.GetSegment(Index: Integer): TCustomSegment;
begin
  Result := FSegmentList[Index];
end;

function TCustomPath.GetSegmentCount: Integer;
begin
  Result := FSegmentList.Count;
end;

function TCustomPath.GetStartPoint: TFloatPoint;
begin
  Result := FVertices[0];
end;

function TCustomPath.GetVertex(Index: Integer): TFloatPoint;
begin
  Result := FVertices[Index];
end;

function TCustomPath.GetVertexCapacity: Integer;
begin
  Result := Length(FVertices);
end;

function TCustomPath.IndexOf(Segment: TCustomSegment): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FSegmentList.Count - 1 do
    if FSegmentList[I] = Segment then
    begin
      Result := I;
      Exit;
    end;
end;

procedure TCustomPath.InsertSegment(const P: TFloatPoint;
  Segment: TCustomSegment; Index: Integer);
begin
  FSegmentList.Insert(Index, Segment);
  if High(FVertices) < FVertCount then
    SetLength(FVertices, Length(FVertices) * 2);

  Move(FVertices[Index], FVertices[Index + 1], (FVertCount - Index) * SizeOf(TFloatPoint));
  FVertices[Index] := P;
  Inc(FVertCount);

end;

procedure TCustomPath.Offset(const Dx, Dy: TFloat);
var
  I: Integer;
begin
  for I := 0 to FVertCount - 1 do
    with FVertices[I] do
    begin
      X := X + Dx;
      Y := Y + Dy;
    end;
end;

procedure TCustomPath.RemoveSegment(Segment: TCustomSegment);
begin
  DeleteSegment(IndexOf(Segment));
end;

procedure TCustomPath.SetEndPoint(const Value: TFloatPoint);
begin
  FVertices[FVertCount - 1] := Value;
end;

procedure TCustomPath.SetOutputCapacity(const Value: Integer);
begin
  SetLength(FOutput, Value);
end;

procedure TCustomPath.SetStartPoint(const Value: TFloatPoint);
begin
  FVertices[0] := Value;
end;

procedure TCustomPath.SetVertexCapacity(const Value: Integer);
begin
  SetLength(FVertices, Value);
end;

{ TSegmentList }

function TSegmentList.GetCustomSegment(Index: Integer): TCustomSegment;
begin
  Result := List[Index];
end;

procedure TSegmentList.SetCustomSegment(Index: Integer;
  const Value: TCustomSegment);
begin
  List[Index] := Value;
end;

end.
