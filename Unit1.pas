unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, ImgList, MMSystem;

type
  TForm1 = class(TForm)
    Image1: TImage;
    Render: TTimer;
    WrdRs: TImageList;
    Player: TImageList;
    Move: TTimer;
    Water: TImageList;
    DbgInfo: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure RenderTimer(Sender: TObject);
    procedure MoveTimer(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure DbgInfoTimer(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

const
  LvlWdt=10;
  LvlHdt=7;
  PxlSz=32;

var
  Form1: TForm1;
  //Координаты игрока на карте
  PX, PY: integer;
  //Координаты камеры
  CMR: integer=0;
  CMB: integer=0;
  //Индекс материала для создания
  Mtrl: integer=0;
  //Взгляд игрока
  SeeDRT: integer=3;
  //Движение
  MoveL, MoveR, MoveU, MoveD: boolean;
  //Уровень
  LvlDsn: array of array of string;
  //Actn - оторбражение уведомления "Использовать"
  SVMapT, DLG, Actn: boolean;
  TmOut: integer=30;
  //Анимация воды
  WtrC: integer=0;
  DLGL: TStringList;
  DLGC: integer=0;
  fps: integer=0;
  //MapL - название файла загруженной карты
  ResH, MapL: string;

implementation

{$R *.dfm}

procedure LDMap(MapN:string);
var
  WdtAr, HdtAr: integer; s: string; f: TextFile;
begin
  WdtAr:=-1;
  HdtAr:=-1;
  MapL:=MapN;
  AssignFile(f, MapN);
  Reset(f);
  while not Eof(f) do begin
    ReadLn(f,s);
    if trim(s)<>'' then begin
      inc(HdtAr);
      SetLength(LvlDsn,HdtAr+1);
      while pos(';',s)>0 do begin
        inc(WdtAr);
        SetLength(LvlDsn[HdtAr],WdtAr+1);
        LvlDsn[HdtAr,WdtAr]:=copy(s,1,pos(';',s)-1);
        delete(s,1,pos(';',s));
      end;
      WdtAr:=-1;
    end;
  end;

  CloseFile(f);

  Form1.Render.Enabled:=true;
  Form1.Move.Enabled:=true;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  //Ресурсы игрока
  ResH:='';

  LDMap('map.txt');

  //Randomize;

  //DoubleBuffered:=true;

  //Размер
  Image1.Width:=(LvlWdt+1)*PxlSz;
  Image1.Height:=(LvlHdt+1)*PxlSz;

  Form1.ClientWidth:=(LvlWdt+1)*PxlSz;
  Form1.ClientHeight:=(LvlHdt+1)*PxlSz;

  //Координаты игрока
  PY:=3;
  PX:=5;

  //mciSendString('play Overworld_Day.wav',nil,0,0);
end;

function TextDraw(text: string): boolean; //Вывод текста
begin
  Form1.Image1.Canvas.Brush.Color:=clGray;
  Form1.Image1.Canvas.Rectangle(Form1.Image1.Width div 2 - Form1.Image1.Canvas.TextWidth(text) div 2 - 7,Form1.Image1.Height - Form1.Image1.Canvas.TextHeight(text)-17,Form1.Image1.Width div 2 + Form1.Image1.Canvas.TextWidth(text) div 2 + 10,Form1.Image1.Height - Form1.Image1.Canvas.TextHeight(text)+11);
  Form1.Image1.Canvas.Font.Color:=clWhite;
  Form1.Image1.Canvas.TextOut(Form1.Image1.Width div 2 - Form1.Image1.Canvas.TextWidth(text) div 2,Form1.Image1.Height - Form1.Image1.Canvas.TextHeight(text)-10,text);
  //Form1.Image1.Canvas.Font.Color:=clWhite;
  //Form1.Image1.Canvas.TextOut(Form1.Image1.Width div 2 - Form1.Image1.Canvas.TextWidth(text) div 2 + 1,Form1.Image1.Height - Form1.Image1.Canvas.TextHeight(text)-11,text);
end;

function ChkEdt(Y, X: integer): boolean; //Проверка на возможность редактирования блока
begin
result:=true;
if Y<0 then result:=false;
if X<0 then result:=false;
if X>Length(LvlDsn[0])-1 then result:=false;
if Y>Length(LvlDsn)-1 then result:=false;
end;

function ChkMv(Y, X: integer):boolean; //Проверка ячеек на возможность ходить по ним, а также триггеры
var
  TGRT: string;
begin
  result:=false;
  if (Y<0) or (X<0) or (X>Length(LvlDsn[0])-1) or (Y>Length(LvlDsn)-1) then begin result:=false; exit; end;

  if (LvlDsn[Y,X]='OBJ:0') or (LvlDsn[Y,X]='OBJ:2') or (LvlDsn[Y,X]='OBJ:12') or (LvlDsn[Y,X]='OBJ:13')
  or (LvlDsn[Y,X]='OBJ:38') or (LvlDsn[Y,X]='OBJ:41') or (LvlDsn[Y,X]='OBJ:42') or (LvlDsn[Y,X]='OBJ:54')
  or (LvlDsn[Y,X]='OBJ:55') then result:=true;

  if copy(LvlDsn[Y,X],1,4)='TGR:' then begin //Триггеры
    TGRT:=copy(LvlDsn[Y,X],pos('TGR:',LvlDsn[Y,X])+4,length(LvlDsn[Y,X])-pos('TGR:',LvlDsn[Y,X])-3);

    //Отключаем движение
    MoveL:=false;
    MoveR:=false;
    MoveU:=false;
    MoveD:=false;

    //Диалоги
    if pos('&DLG',TGRT)>0 then begin
      DLGL:=TStringList.Create;
      DLG:=true;
      DLGL.Text:=StringReplace(TGRT,'<BR>',#13#10,[rfReplaceAll]);
      DLGL.Delete(0);
      //ShowMessage(DLGL.Text);
    end;

    //Найденные предметы
    if pos('&RES',TGRT)>0 then begin
      ResH:=ResH+copy(TGRT,pos('&RES ',TGRT)+5,Length(TGRT)-pos('&RES ',TGRT)-4);
      //LvlDsn[Y,X]:='OBJ:'+copy(TGRT,1,pos('&',TGRT)-1);
      LvlDsn[Y,X]:='OBJ:1';

      DLGL:=TStringList.Create;
      DLG:=true;
      DLGL.Text:='Подобран '+copy(TGRT,pos('&RES ',TGRT)+5,Length(TGRT)-pos('&RES ',TGRT)-4);
    end;

    //Закрытые двери
    if pos('&DOOR',TGRT)>0 then
      if pos(copy(TGRT,pos('&DOOR ',TGRT)+6,Length(TGRT)-pos('&DOOR ',TGRT)-5),ResH)>0 then begin
        LvlDsn[Y,X]:='OBJ:'+copy(TGRT,1,pos('&',TGRT)-1);

        DLGL:=TStringList.Create;
        DLG:=true;
        DLGL.Text:='Дверь открыта с помощью '+copy(TGRT,pos('&DOOR ',TGRT)+6,Length(TGRT)-pos('&DOOR ',TGRT)-5);
      end else begin
        DLGL:=TStringList.Create;
        DLG:=true;
        DLGL.Text:='Дверь закрыта, необходим '+copy(TGRT,pos('&DOOR ',TGRT)+6,Length(TGRT)-pos('&DOOR ',TGRT)-5);
      end;

      if pos('&LDMAP',TGRT)>0 then begin
        Form1.Move.Enabled:=false;
        Form1.Render.Enabled:=false;
        PY:=1;
        PX:=1;
        CMR:=-4;
        CMB:=-2;
        LDMap(copy(TGRT,pos('&LDMAP ',TGRT)+7,Length(TGRT)-pos('&LDMAP ',TGRT)-6));
      end;
      //Триггеры
    end;

  end;

//Сохранение карты
procedure SvMap(MapN:string);
var
  i, j: integer; s: string; f: TStringList;
begin
  for i:=0 to Length(LvlDsn)-1 do begin
    for j:=0 to Length(LvlDsn[0])-1 do
      s:=s+LvlDsn[i,j]+';';
    s:=s+#13#10;
  end;

  f:=TStringList.Create;
  f.Text:=s;
  f.SaveToFile(MapN);
  f.Free;
  SvMapT:=true;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  //Движение персонажа
  if Key=ord('A') then MoveL:=true;
  if Key=ord('D') then MoveR:=true;
  if Key=ord('W') then MoveU:=true;
  if Key=ord('S') then MoveD:=true;

  //Перейти к следующему фразе диалога или закрыть его
  if DLG then if Key=13 then if DLGC<DLGL.Count-1 then inc(DLGC) else begin DLG:=false; DLGC:=0; DLGL.Free; end;

  //Создание блока
  if Key=ord('U') then begin
    case SeeDRT of
      1: if ChkEdt(PY,PX-1) then LvlDsn[PY,PX-1]:='OBJ:'+IntToStr(Mtrl);
      2: if ChkEdt(PY,PX+1) then LvlDsn[PY,PX+1]:='OBJ:'+IntToStr(Mtrl);
      3: if ChkEdt(PY-1,PX) then LvlDsn[PY-1,PX]:='OBJ:'+IntToStr(Mtrl);
      0: if ChkEdt(PY+1,PX) then LvlDsn[PY+1,PX]:='OBJ:'+IntToStr(Mtrl);
    end;
    PlaySound('wood2.wav', 0, SND_ASYNC);
  end;

  //Материалы
  if Key=ord('H') then if Mtrl>0 then dec(Mtrl);
  if Key=ord('K') then if Mtrl<71 then inc(Mtrl);
  if Key=ord('J') then Mtrl:=0;
  if Key=ord('I') then Mtrl:=StrToInt(InputBox('Материал', 'Номер материала', '0'));

  //Создание и редактирование триггера
  if Key=ord('T') then
    case SeeDRT of
      1: if ChkEdt(PY,PX-1) then LvlDsn[PY,PX-1]:=InputBox('Создание триггера', 'Действие триггера', LvlDsn[PY,PX-1]);
      2: if ChkEdt(PY,PX+1) then LvlDsn[PY,PX+1]:=InputBox('Создание триггера', 'Действие триггера', LvlDsn[PY,PX+1]);
      3: if ChkEdt(PY-1,PX) then LvlDsn[PY-1,PX]:=InputBox('Создание триггера', 'Действие триггера', LvlDsn[PY-1,PX]);
      0: if ChkEdt(PY+1,PX) then LvlDsn[PY+1,PX]:=InputBox('Создание триггера', 'Действие триггера', LvlDsn[PY+1,PX]);
    end;

  //Включить или отключить показ отладочной информации
  if Key=ord('P') then if DbgInfo.Enabled then begin Caption:='Vris Engine'; DbgInfo.Enabled:=false; end else DbgInfo.Enabled:=true;

  //Сохранение карты
  if Key=VK_F5 then SVMap(MapL);

end;

//Рендер сцены
procedure TForm1.RenderTimer(Sender: TObject);
var
  i, j: integer; OBJT: string;
begin
  inc(fps);

  Image1.Canvas.Brush.Color:=clBlack;
  //Очищаем предыдущую сцену
  Image1.Canvas.FillRect(Rect(0,0,(LvlWdt+1)*PxlSz,(LvlHdt+1)*PxlSz));

  for i:=CMB to (LvlHdt+1)+CMB do
    for j:=CMR to (LvlWdt+1)+CMR do begin

      //Отрисовываем только загруженные ячейки
      if (i>-1) and (j>-1) and (j<Length(LvlDsn[0])) and (i<Length(LvlDsn)) then begin
      //Отрисовка объектов
      if copy(LvlDsn[i,j],1,4)='OBJ:' then begin
        OBJT:=copy(LvlDsn[i,j],pos('OBJ:',LvlDsn[i,j])+4,length(LvlDsn[i,j])-pos('OBJ:',LvlDsn[i,j])-3);
        WrdRs.Draw(Image1.Canvas,(j-CMR)*PxlSz,(i-CMB)*PxlSz,StrToInt(OBJT));
      end;
      //Отрисовка триггеров
      if copy(LvlDsn[i,j],1,4)='TGR:' then begin
        OBJT:=copy(LvlDsn[i,j],pos('TGR:',LvlDsn[i,j])+4,length(LvlDsn[i,j])-pos('OBJ:',LvlDsn[i,j])-3);
        if pos('&',OBJT)>0 then OBJT:=copy(OBJT,1,pos('&',OBJT)-1);
        WrdRs.Draw(Image1.Canvas,(j-CMR)*PxlSz,(i-CMB)*PxlSz,StrToInt(OBJT));
      end;

      //Вода c анимацией
      //if LvlDsn[i,j]=25 then Water.Draw(Image1.Canvas,(j-CMR)*PxlSz,(i-CMB)*PxlSz,WtrC);

      {if LvlDsn[i,j]=0 then begin
        Image1.Canvas.Brush.Color:=RGB(random(255), random(255), random(255));
        Image1.Canvas.Pen.Color:=Image1.Canvas.Brush.Color;
        Image1.Canvas.Rectangle(j*PxlSz,i*PxlSz,j*PxlSz+PxlSz,i*PxlSz+PxlSz);
      end;}

      end;
    end;

  //Анимация воды
  //if WtrC=31 then WtrC:=0 else inc(WtrC);

  //Отрисовка игрока
  Player.Draw(Image1.Canvas,(PX-CMR)*PxlSz,(PY-CMB)*PxlSz,SeeDRT);

  //Разрешение игры
  Image1.Canvas.Brush.Style:=bsClear;
  Image1.Canvas.Font.Color:=clGray;
  Image1.Canvas.TextOut(6,6,IntToStr(Image1.Width)+'x'+IntToStr(Image1.Height));
  Image1.Canvas.Font.Color:=clWhite;
  Image1.Canvas.TextOut(5,5,IntToStr(Image1.Width)+'x'+IntToStr(Image1.Height));

  //Уведомление о сохранении
  if SVMapT then if TmOut>0 then begin
    dec(TmOut);
    Image1.Canvas.Font.Color:=clGray;
    Image1.Canvas.TextOut(6,20,'Карта сохранена');
    Image1.Canvas.Font.Color:=clWhite;
    Image1.Canvas.TextOut(5,19,'Карта сохранена');
  end else begin TmOut:=30; SVMapT:=false; end;

  //Проверка триггеры и отрисовка диалогов
  if DLG then TextDraw(DLGL.Strings[DLGC]) else
    case SeeDRT of
      1: if ChkEdt(PY,PX-1) then if copy(LvlDsn[PY,PX-1],1,4)='TGR:' then TextDraw('Нажмите влево, чтобы использовать');
      2: if ChkEdt(PY,PX+1) then if copy(LvlDsn[PY,PX+1],1,4)='TGR:' then TextDraw('Нажмите вправо, чтобы использовать');
      3: if ChkEdt(PY-1,PX) then if copy(LvlDsn[PY-1,PX],1,4)='TGR:' then TextDraw('Нажмите вверх, чтобы использовать');
      0: if ChkEdt(PY+1,PX) then if copy(LvlDsn[PY+1,PX],1,4)='TGR:' then TextDraw('Нажмите вниз, чтобы использовать');
    end;

  //HUD
  Image1.Canvas.Brush.Color:=clGray;
  Image1.Canvas.Rectangle(5,35,45,75);
  WrdRs.Draw(Image1.Canvas,9,39,Mtrl);
end;

procedure TForm1.MoveTimer(Sender: TObject);
begin
  //Двишение доступно только вне диалогов
  if DLG=false then begin
  //Движение
    if MoveL then begin if ChkMv(PY,PX-1) then if SeeDRT=1 then begin dec(PX); dec(CMR); end; SeeDRT:=1; end;
    if MoveR then begin if ChkMv(PY,PX+1) then if SeeDRT=2 then begin inc(PX); inc(CMR); end; SeeDRT:=2; end;
    if MoveU then begin if ChkMv(PY-1,PX) then if SeeDRT=3 then begin dec(PY); dec(CMB); end; SeeDRT:=3; end;
    if MoveD then begin if ChkMv(PY+1,PX) then if SeeDRT=0 then begin inc(PY); inc(CMB); end; SeeDRT:=0; end;
  end;
end;

procedure TForm1.FormKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (MoveL=true) or (MoveR=true) or (MoveU=true) or (MoveD=true) then begin
    PlaySound('wood2_.wav', 0, SND_ASYNC);
    //if LvlDsn[PY,PX]=320 then PlaySound('door_open.wav', 0, SND_ASYNC);
  end;

  //При отпускании клавиш переставать двигатся
  if Key=ord('A') then MoveL:=false;
  if Key=ord('D') then MoveR:=false;
  if Key=ord('W') then MoveU:=false;
  if Key=ord('S') then MoveD:=false;

end;

procedure TForm1.DbgInfoTimer(Sender: TObject);
begin
  //Отладочная информация
  case SeeDRT of
    1: if ChkEdt(PY,PX-1) then Caption:='FPS='+IntToStr(fps)+' X='+IntToStr(PX) + ' Y='+IntToStr(PY)+' CX='+IntToStr(CMR)+' CY='+IntToStr(CMB)+' ResSee='+LvlDsn[PY,PX-1];
    2: if ChkEdt(PY,PX+1) then Caption:='FPS='+IntToStr(fps)+' X='+IntToStr(PX) + ' Y='+IntToStr(PY)+' CX='+IntToStr(CMR)+' CY='+IntToStr(CMB)+' ResSee='+LvlDsn[PY,PX+1];
    3: if ChkEdt(PY-1,PX) then Caption:='FPS='+IntToStr(fps)+' X='+IntToStr(PX) + ' Y='+IntToStr(PY)+' CX='+IntToStr(CMR)+' CY='+IntToStr(CMB)+' ResSee='+LvlDsn[PY-1,PX];
    0: if ChkEdt(PY+1,PX) then Caption:='FPS='+IntToStr(fps)+' X='+IntToStr(PX) + ' Y='+IntToStr(PY)+' CX='+IntToStr(CMR)+' CY='+IntToStr(CMB)+' ResSee='+LvlDsn[PY+1,PX];
  else Caption:='FPS='+IntToStr(fps)+' X='+IntToStr(PX) + ' Y='+IntToStr(PY)+' CX='+IntToStr(CMR)+' CY='+IntToStr(CMB);
  end;
  fps:=0;
end;

end.
