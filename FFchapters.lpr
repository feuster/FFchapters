program FFchapters;

{$mode objfpc}{$H+}
{$MACRO ON}

{____________________________________________________________
|  _______________________________________________________  |
| |                                                       | |
| |             FFmpeg based chapter creation             | |
| | (c) 2018 Alexander Feuster (alexander.feuster@web.de) | |
| |             http://www.github.com/feuster             | |
| |_______________________________________________________| |
|___________________________________________________________}

//define program basics
{$DEFINE PROGVERSION:='1.2'}

{___________________________________________________________}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp,
  { you can add units after this }
  Windows, StrUtils, math, crt, LazUTF8;

type

  { TApp }

  TApp = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
    function WindowsOSLanguage: String;
  end;

const
  //program title
  STR_Title:    String = ' __________________________________________________ '+#13#10+
                         '|  ______________________________________________  |'+#13#10+
                         '| |                                              | |'+#13#10+
                         '| |**********************************************| |'+#13#10+
                         '| |        FFmpeg based chapter creation         | |'+#13#10+
                         '| |          (c) 2018 Alexander Feuster          | |'+#13#10+
                         '| |        http://www.github.com/feuster         | |'+#13#10+
                         '| |______________________________________________| |'+#13#10+
                         '|__________________________________________________|'+#13#10;

  //CPU architecture
  STR_CPU:      String = {$I %FPCTARGET%};

  //Build date&time
  STR_Build:    String = {$I %DATE%}+' '+{$I %TIME%};

  //Date
  STR_Date:     String = {$I %DATE%};

  //message strings
  STR_Warning:  String = 'Warning: ';
  STR_Info:     String = 'Info:    ';
  STR_Error:    String = 'Error:   ';
  STR_Debug:    String = 'Debug:   ';
  STR_Space:    String = '         ';

var
  Debug:            Boolean;
  InputFile:        TStringList;
  OutputFile:       TStringList;
  Chapters:         TStringList;
  ChapterFile:      String;
  LogFile:          String;
  Counter:          Integer;
  ReadLine:         String;
  Buffer:           String;
  TIMECODE_Time:    Extended;
  TIMECODE_Sec:     Extended;
  TIMECODE_Sec_Frac:Extended;
  Hours:            Integer;
  Minutes:          Integer;
  Seconds:          Integer;
  MilliSeconds:     Integer;
  Chapter:          Integer;
  ChapterText:      String;
  Chapter_Diff:     Extended;
  STR_Title_CPU:    String;
{ TApp }

function TApp.WindowsOSLanguage: String;
//Helper function to determine OS language (derived from http://wiki.freepascal.org/Windows_system_language/de)
var
  chrCountry: array [0..255] of char;

begin
  chrCountry[0]:=Chr(0); //initialize first char as 0 to get rid of annoying compiler warning
  GetLocaleInfo(GetSystemDefaultLCID, LOCALE_SLANGUAGE, chrCountry, SizeOf(chrCountry) - 1);
  Result:=chrCountry;
end;

procedure TApp.DoRun;
label
  CleanUp;
var
  ErrorMsg:   String;
  StepBuffer: Extended;
  //program version
  STR_Version:    String = PROGVERSION;

begin
  //add CPU architecture info to title
  if STR_CPU='x86_64' then
    STR_Title_CPU:=StringReplace(STR_Title,'**********************************************','           FFchapters V'+STR_Version+' (64Bit)            ',[])
  else if STR_CPU='i386' then
    STR_Title_CPU:=StringReplace(STR_Title,'**********************************************','           FFchapters V'+STR_Version+' (32Bit)            ',[])
  else
    STR_Title_CPU:=StringReplace(STR_Title,'**********************************************','               FFchapters V'+STR_Version+'                ',[]);

  //show application title
  WriteLn(UTF8toConsole(STR_Title_CPU));

  try
  //quick check parameters
  ErrorMsg:=CheckOptions('hbls:i:o:', 'help buildinfo license step: input: output:');
  if ErrorMsg<>'' then begin
    WriteLn(#13#10+STR_Error+' '+ErrorMsg+#13#10);
    Terminate;
    Exit;
  end;

  //parse parameters for help
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  //parse parameters for buildinfo
  if HasOption('b', 'buildinfo') then begin
    WriteLn(UTF8toConsole(STR_Title_CPU));
    WriteLn(UTF8toConsole('Build info: '+STR_Build));
    Terminate;
    Exit;
  end;

  //show license info
  if HasOption('l', 'license') then
    begin
      //show FFchapters license
      WriteLn('FFchapters V'+STR_Version+' (c) '+STR_Date[1..4]+' Alexander Feuster (alexander.feuster@web.de)'+#13#10+
              'http://www.github.com/feuster'+#13#10+
              'This program is provided "as-is" without any warranties for any data loss,'+#13#10+
              'device defects etc. Use at own risk!'+#13#10+
              'Free for personal use. Commercial use is prohibited without permission.'+#13#10);
      Terminate;
      Exit;
    end;
  { add your program here }

  //Check for debug mode
  if FileExists(ExtractFilePath(ParamStr(0))+'debug') then
    begin
      Debug:=true;
      WriteLn(STR_Warning+'debug mode active'+#13#10);
    end
  else
    Debug:=false;

  //check commandline arguments
  if ParamCount=0 then
    begin
      WriteLn(STR_Error+'No start arguments given');
      WriteLn(STR_Info+'For help try');
      WriteLn(STR_Space, ExtractFileName(ExeName), ' --help'+#13#10);
      Terminate;
      Exit;
    end;

  //check if input file is available
  if HasOption('i', 'input') then
    begin
      LogFile:=(GetOptionValue('i', 'input'));
      if FileExists(LogFile)=false then
        begin
          WriteLn(STR_Error+'Input file "'+UTF8toConsole(LogFile)+'" does not exist'+#13#10);
          Terminate;
          Exit;
        end;
    end
  else
    begin
      WriteLn(STR_Error+'No input file set'+#13#10);
      Terminate;
      Exit;
    end;

  //check for chapter file path parameter
  if HasOption('o', 'output') then
    begin
      ChapterFile:=(GetOptionValue('o', 'output'));
    end
  else
    begin
      ChapterFile:=ChangeFileExt(LogFile,'_Chapters.txt');
      WriteLn(STR_Warning+'Output file not set');
      WriteLn(STR_Info+'using "'+UTF8toConsole(ChapterFile)+'" as Output file'+#13#10);
    end;

  //minimal difference between chapter timecodes (default)
  Chapter_Diff:= 120.0;
  //parse parameters for steps between chapter timecodes (override default)
  if HasOption('s', 'step') then
    begin
      StepBuffer:=StrToFloat(GetOptionValue('s', 'step'));
      if StepBuffer>-1 then
        Chapter_Diff:=StepBuffer;
    end;
  if Chapter_Diff=0 then
    WriteLn(UTF8toConsole(STR_Info+'using all analyzed chapters without difference step'))
  else
    WriteLn(UTF8toConsole(STR_Info+'Chapter step set to '+FloatToStr(Chapter_Diff))+'s');

  //create work stringlists
  InputFile:=TStringList.Create;
  InputFile.LoadFromFile(LogFile);
  OutputFile:=TStringList.Create;
  Chapters:=TStringList.Create;

  //set chapter text according to Windows OS language
  writeln(STR_Info+'detected "'+WindowsOSLanguage+'" as default Windows OS language');
  if AnsiPos('deutsch',LowerCase(WindowsOSLanguage))>0 then
    begin
      WriteLn(STR_Info+'using german "Kapitel" as generic chapter text'+#13#10);
      ChapterText:='Kapitel '
    end
  else
    begin
      WriteLn(STR_Info+'using english/international "Chapter" as generic chapter text'+#13#10);
      ChapterText:='Chapter ';
    end;

  //define Decimal Separator of FFMPEG analyzer statistics timecodes
  DefaultFormatSettings.DecimalSeparator:='.';

  //parse FFMPEG analyzer statistics
  for Counter:=0 to InputFile.Count-1 do
    begin
      //do not create more than 99 chapters
      if Chapter>98 then
        begin
          WriteLn(STR_Info+'already 99 chapters created. Stopping now.');
          break;
        end;

      //read FFMPEG analyzer statistics line
      ReadLine:=InputFile.Strings[Counter];

      //extract timecodes from FFMPEG scence change detection
      if AnsiPos('Parsed_showinfo',ReadLine)>0 then
        begin
          if AnsiPos('pts_time',readLine)>0 then
            begin
              Buffer:=AnsiRightStr(ReadLine,Length(ReadLine)-AnsiPos('pts_time:',ReadLine)-8);
              Buffer:=AnsiLeftStr(Buffer,AnsiPos(' ',Buffer)-1);
              //Padding needed for later sorting
              if AnsiPos('.',Buffer)=0 then
                Buffer:=Buffer+'.00';
              while (AnsiPos('.',Buffer)<=Length(Buffer)-3) and (Length(Buffer)>5) do
                Buffer:=AnsiLeftStr(Buffer,AnsiPos('.',Buffer)-1);
              if AnsiPos('.',Buffer)=0 then
                Buffer:=Buffer+'.00';
              if AnsiMidStr(Buffer,Length(Buffer)-1,1)='.' then
                Buffer:=Buffer+'0';
              Buffer:=PadLeft(Buffer,16);
              Chapters.Add(Buffer);
              //DEBUG: print timecode
              if Debug then WriteLn(STR_Debug+'Scenechange "pts_time":    '+Buffer);
            end;
        end;

      //extract timecodes from FFMPEG black detection
      if AnsiPos('blackdetect',ReadLine)>0 then
        begin
          if AnsiPos('black_start',readLine)>0 then
            begin
              Buffer:=AnsiRightStr(ReadLine,Length(ReadLine)-AnsiPos('black_start:',ReadLine)-11);
              Buffer:=AnsiLeftStr(Buffer,AnsiPos(' ',Buffer)-1);
              //Padding needed for later sorting
              if AnsiPos('.',Buffer)=0 then
                Buffer:=Buffer+'.00';
              while (AnsiPos('.',Buffer)<=Length(Buffer)-3) and (Length(Buffer)>5) do
                Buffer:=AnsiLeftStr(Buffer,AnsiPos('.',Buffer)-1);
              if AnsiPos('.',Buffer)=0 then
                Buffer:=Buffer+'.00';
              if AnsiMidStr(Buffer,Length(Buffer)-1,1)='.' then
                Buffer:=Buffer+'0';
              Buffer:=PadLeft(Buffer,16);
              Chapters.Add(Buffer);
              //DEBUG: print timecode
              if Debug then WriteLn(STR_Debug+'Black "black_start": '+Buffer);
            end;
        end;

      //extract timecodes from FFMPEG black frame detection
      if AnsiPos('Parsed_blackframe',ReadLine)>0 then
        begin
          if AnsiPos(' t:',readLine)>0 then
            begin
              Buffer:=AnsiRightStr(ReadLine,Length(ReadLine)-AnsiPos(' t:',ReadLine)-2);
              Buffer:=AnsiLeftStr(Buffer,AnsiPos(' ',Buffer)-5);
              //Padding needed for later sorting
              if AnsiPos('.',Buffer)=0 then
                Buffer:=Buffer+'.00';
              while (AnsiPos('.',Buffer)<=Length(Buffer)-3) and (Length(Buffer)>5) do
                Buffer:=AnsiLeftStr(Buffer,AnsiPos('.',Buffer)-1);
              if AnsiPos('.',Buffer)=0 then
                Buffer:=Buffer+'.00';
              if AnsiMidStr(Buffer,Length(Buffer)-1,1)='.' then
                Buffer:=Buffer+'0';
              Buffer:=PadLeft(Buffer,16);
              Chapters.Add(Buffer);
              //DEBUG: print timecode
              if Debug then WriteLn(STR_Debug+'Blackframe "t": '+Buffer);
            end;
        end;

    end;

  //check if chapter timecodes are available or quit
  if Chapters.Count=0 then
    begin
      WriteLn(STR_Error+'no chapter timecodes found'+#13#10);
      goto CleanUp;
    end;

  //sort chapters from lowest to highest timecode
  Chapters.Sort;

  //trim padding which is not needed anymore after sorting
  for Chapter:=0 to Chapters.Count-1 do
    begin
      Chapters.Strings[Chapter]:=Trim(Chapters.Strings[Chapter]);
    end;

  //DEBUG: store created timecodes in file
  if Debug then
    begin
      WriteLn(STR_Debug+'storing sorted timecodes in "'+UTF8toConsole(ChangeFileExt(ChapterFile,'_timecodes.txt'))+'"'+#13#10);
      Chapters.SaveToFile(ChangeFileExt(ChapterFile,'_timecodes.txt'));
    end;

  //remove chapters whose timecodes are to close together
  Chapter:=Chapters.Count-1;
  if Chapter_Diff>0 then
    begin
      while Chapter>0 do
        begin
          if StrToFloat(Chapters.Strings[Chapter])<=StrToFloat(Chapters.Strings[Chapter-1])+Chapter_Diff then
            begin
              //DEBUG: print deleted timecode
              if Debug then WriteLn(STR_Debug+'timecodes time diff below '+FloatToStr(Chapter_Diff)+'s for chapters #'+FormatFloat('00',Chapter-1)+' '+Chapters.Strings[Chapter-1]+'s (deleted) <-> #'+FormatFloat('00',Chapter)+' '+Chapters.Strings[Chapter]+'s (not deleted)');
              Chapters.Delete(Chapter-1);
              Chapter:=Chapters.Count-1;
            end
          else
            dec(Chapter);
        end;
    end;

  //check if lowest entry has minimum timecode entry difference to start timecode 00:00:00
  if Chapter_Diff>0 then
    begin
      if StrToFloat(Chapters.Strings[0])<Chapter_Diff then
        Chapters.Delete(0);
    end;

  //convert timecodes to hh:mm:ss.mmm time format
  for Chapter:=0 to Chapters.Count-1 do
    begin
      //split the floating point timecode seconds in integer and fracture parts
      TIMECODE_Time:=StrToFloat(Chapters.Strings[Chapter]);
      TIMECODE_Sec:=Trunc(TIMECODE_Time);
      TIMECODE_Sec_Frac:=SimpleRoundTo(Frac(TIMECODE_Time),-2);

      //convert timecode values parts to hh:mm:ss time values
      Hours:=Round(Trunc(TIMECODE_Sec/3600));
      TIMECODE_Sec:=TIMECODE_Sec-(Hours*3600);
      Minutes:=Round(Trunc(TIMECODE_Sec/60));
      TIMECODE_Sec:=TIMECODE_Sec-(Minutes*60);
      Seconds:=Round(Trunc(TIMECODE_Sec));
      MilliSeconds:=Round(TIMECODE_Sec_Frac*1000);

      //add chapter time to temporary chapter list
      Chapters.Strings[Chapter]:=FormatFloat('00',Hours)+':'+FormatFloat('00',Minutes)+':'+FormatFloat('00',Seconds)+'.'+FormatFloat('000',MilliSeconds);
    end;

  //create first chapter entry for static start position
  OutputFile.Add('CHAPTER01=00:00:00.000');
  OutputFile.Add('CHAPTER01NAME=Kapitel 1');

  //create dynamic chapter entries according to available chapter times
  for Chapter:=0 to Chapters.Count-1 do
    begin
      OutputFile.Add('CHAPTER'+FormatFloat('00',CHAPTER+2)+'='+Chapters.Strings[Chapter]);
      OutputFile.Add('CHAPTER'+FormatFloat('00',CHAPTER+2)+'NAME='+ChapterText+IntToStr(Chapter+2));
    end;

  //create chapter file
  WriteLn(STR_Info+'creating chapter file "'+UTF8toConsole(ChapterFile)+'" with');
  WriteLn(STR_Info+'['+IntToStr(Chapters.Count)+'] chapters'+#13#10);
  OutputFile.SaveToFile(ChapterFile);

  //Clean up
CleanUp:
  if InputFile<>NIL then
    InputFile.Free;
  if OutputFile<>NIL then
    OutputFile.Free;
  if Chapters<>NIL then
    Chapters.Free;

  //stop program loop
  WriteLn(STR_Info+'exit program now'+#13#10);

  //stop program loop on exception with error message
  Except
    on E: Exception do
      begin
        WriteLn(STR_Error+'fatal error "'+E.Message+'"'+#13#10);
      end;
  end;

  //terminate program
  Terminate;
end;

constructor TApp.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TApp.Destroy;
begin
  inherited Destroy;
end;

procedure TApp.WriteHelp;
begin
  { add your help code here }
  WriteLn(STR_Title_CPU);
  WriteLn('Build info:   ', ExtractFileName(ExeName), ' -b (--buildinfo)');
  WriteLn('              Shows the build info.'+#13#10);
  WriteLn('License info: ', ExtractFileName(ExeName), ' -l (--license)');
  WriteLn('              Shows the license info.'+#13#10);
  WriteLn('Help:         ', ExtractFileName(ExeName), ' -h (--help)');
  WriteLn('              Shows this help text.'+#13#10);
  WriteLn('Input File:   ', ExtractFileName(ExeName), ' -i (--input=) <Filepath>');
  WriteLn('              Sets the full path to the log file with raw chapters log output from ffmpeg.'+#13#10);
  WriteLn('Chapter File: ', ExtractFileName(ExeName), ' -o (--output=) <Filepath>');
  WriteLn('              Sets the outputpath for the generated chapter file.'+#13#10);
  WriteLn('Chapter Step: ', ExtractFileName(ExeName), ' -s (--step=) <seconds>');
  WriteLn('              Sets the step difference in seconds between two chapters.');
  WriteLn('              Set to 0 to use all analyzed chapters.'+#13#10);
  WriteLn('Usage:        ', ExtractFileName(ExeName), ' -i <FFmpeg_Log_File> -o <Chapter_Output_File> (-s <seconds>)'+#13#10);
  WriteLn('');
  WriteLn('FFmpeg Log:   FFchapters needs a log file with all raw information for the chapter extraction.');
  WriteLn('              This log file can be created by using a FFmpeg filter combination: Scene, Black and Blackframe detection'+#13#10);
  WriteLn('FFmpeg example commandline:');
  WriteLn('ffmpeg -i "Video_File" -vf blackdetect=d=1.0:pic_th=0.90:pix_th=0.00,blackframe=98:32,"select=''gt(scene,0.75)'',showinfo" -an -f null - 2> "FFmpeg_Log_File"');
end;

var
  Application: TApp;
begin
  Application:=TApp.Create(nil);
  Application.Run;
  Application.Free;
end.

