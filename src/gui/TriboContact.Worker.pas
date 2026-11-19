unit TriboContact.Worker;

interface

uses
  System.SysUtils, System.Classes,
  TriboContact.Models, TriboContact.Runner, TriboContact.CcxManager;

type
  TWorkerMode = (wmSolveCase, wmLoadSweep, wmSetupCcx);

  TWorkerLogEvent = reference to procedure(const AMsg: string);
  TWorkerSolveDoneEvent = reference to procedure(ABundle: TComparisonBundle;
    const AError: string; ACancelled: Boolean);
  TWorkerSweepDoneEvent = reference to procedure(const APoints: TArray<TSweepPoint>;
    const AError: string; ACancelled: Boolean);
  TWorkerCcxDoneEvent = reference to procedure(const ACcxPath, AError: string);

  TSolverWorkerThread = class(TThread)
  private
    FMode: TWorkerMode;
    FCase: TContactCase;
    FLoadsMn: TDoubleArray;
    FUrl: string;
    FCancelled: Boolean;
    FOnLog: TWorkerLogEvent;
    FOnSolveDone: TWorkerSolveDoneEvent;
    FOnSweepDone: TWorkerSweepDoneEvent;
    FOnCcxDone: TWorkerCcxDoneEvent;
    procedure QueueLog(const AMsg: string);
    procedure QueueSolveDone(ABundle: TComparisonBundle; const AError: string;
      ACancelled: Boolean);
    procedure QueueSweepDone(const APoints: TArray<TSweepPoint>; const AError: string;
      ACancelled: Boolean);
    procedure QueueCcxDone(const ACcxPath, AError: string);
  protected
    procedure Execute; override;
  public
    constructor CreateSolve(const ACase: TContactCase;
      const AOnLog: TWorkerLogEvent; const AOnDone: TWorkerSolveDoneEvent);
    constructor CreateSweep(const ACase: TContactCase; const ALoadsMn: TDoubleArray;
      const AOnLog: TWorkerLogEvent; const AOnDone: TWorkerSweepDoneEvent);
    constructor CreateSetupCcx(const AUrl: string;
      const AOnLog: TWorkerLogEvent; const AOnDone: TWorkerCcxDoneEvent);
    procedure RequestCancel;
    property Mode: TWorkerMode read FMode;
  end;

implementation

constructor TSolverWorkerThread.CreateSolve(const ACase: TContactCase;
  const AOnLog: TWorkerLogEvent; const AOnDone: TWorkerSolveDoneEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FMode := wmSolveCase;
  FCase := ACase.Clone;
  FOnLog := AOnLog;
  FOnSolveDone := AOnDone;
end;

constructor TSolverWorkerThread.CreateSweep(const ACase: TContactCase;
  const ALoadsMn: TDoubleArray; const AOnLog: TWorkerLogEvent;
  const AOnDone: TWorkerSweepDoneEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FMode := wmLoadSweep;
  FCase := ACase.Clone;
  FLoadsMn := Copy(ALoadsMn);
  FOnLog := AOnLog;
  FOnSweepDone := AOnDone;
end;

constructor TSolverWorkerThread.CreateSetupCcx(const AUrl: string;
  const AOnLog: TWorkerLogEvent; const AOnDone: TWorkerCcxDoneEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FMode := wmSetupCcx;
  FUrl := AUrl;
  FOnLog := AOnLog;
  FOnCcxDone := AOnDone;
end;

procedure TSolverWorkerThread.RequestCancel;
begin
  FCancelled := True;
  Terminate;
end;

procedure TSolverWorkerThread.QueueLog(const AMsg: string);
var
  Callback: TWorkerLogEvent;
  MsgCopy: string;
begin
  if Terminated or not Assigned(FOnLog) then
    Exit;
  Callback := FOnLog;
  MsgCopy := AMsg;
  TThread.Queue(Self,
    procedure
    begin
      Callback(MsgCopy);
    end);
end;

procedure TSolverWorkerThread.QueueSolveDone(ABundle: TComparisonBundle;
  const AError: string; ACancelled: Boolean);
var
  Callback: TWorkerSolveDoneEvent;
  ErrCopy: string;
begin
  if not Assigned(FOnSolveDone) then
  begin
    ABundle.Free;
    Exit;
  end;
  Callback := FOnSolveDone;
  ErrCopy := AError;
  TThread.Queue(Self,
    procedure
    begin
      Callback(ABundle, ErrCopy, ACancelled);
    end);
end;

procedure TSolverWorkerThread.QueueSweepDone(const APoints: TArray<TSweepPoint>;
  const AError: string; ACancelled: Boolean);
var
  Callback: TWorkerSweepDoneEvent;
  PtsCopy: TArray<TSweepPoint>;
  ErrCopy: string;
begin
  if not Assigned(FOnSweepDone) then
    Exit;
  Callback := FOnSweepDone;
  PtsCopy := Copy(APoints);
  ErrCopy := AError;
  TThread.Queue(Self,
    procedure
    begin
      Callback(PtsCopy, ErrCopy, ACancelled);
    end);
end;

procedure TSolverWorkerThread.QueueCcxDone(const ACcxPath, AError: string);
var
  Callback: TWorkerCcxDoneEvent;
  PathCopy, ErrCopy: string;
begin
  if not Assigned(FOnCcxDone) then
    Exit;
  Callback := FOnCcxDone;
  PathCopy := ACcxPath;
  ErrCopy := AError;
  TThread.Queue(Self,
    procedure
    begin
      Callback(PathCopy, ErrCopy);
    end);
end;

procedure TSolverWorkerThread.Execute;
var
  Bundle: TComparisonBundle;
  SweepPts: TArray<TSweepPoint>;
  CcxPath, Diag, ErrMsg: string;
  LogProc: TProc<string>;
begin
  LogProc :=
    procedure(S: string)
    begin
      QueueLog(S);
    end;

  case FMode of
    wmSolveCase:
      begin
        Bundle := nil;
        ErrMsg := '';
        try
          Bundle := RunCase(FCase, LogProc, @FCancelled);
          if FCancelled then
            FreeAndNil(Bundle);
        except
          on E: Exception do
          begin
            FreeAndNil(Bundle);
            ErrMsg := E.Message;
          end;
        end;
        QueueSolveDone(Bundle, ErrMsg, FCancelled);
      end;

    wmLoadSweep:
      begin
        SetLength(SweepPts, 0);
        ErrMsg := '';
        try
          SweepPts := RunLoadSweep(FCase, FLoadsMn, LogProc, @FCancelled);
          if FCancelled then
            SetLength(SweepPts, 0);
        except
          on E: Exception do
          begin
            SetLength(SweepPts, 0);
            ErrMsg := E.Message;
          end;
        end;
        QueueSweepDone(SweepPts, ErrMsg, FCancelled);
      end;

    wmSetupCcx:
      begin
        CcxPath := '';
        ErrMsg := '';
        try
          CcxPath := SetupCcx(FUrl, LogProc);
          if not SmokeTestCcx(CcxPath, Diag) then
            ErrMsg := 'CalculiX smoke test failed: ' + Diag;
        except
          on E: Exception do
            ErrMsg := E.Message;
        end;
        QueueCcxDone(CcxPath, ErrMsg);
      end;
  end;
end;

end.
