@echo off
echo Kontering 17.2.6
echo Kopierer nodvendige filer....
copy C:\Temp\SUPER_Kontering\Misc\StoppSuper.exe c:\super\StoppSuper.exe /y
echo Stopper Super... >> c:\temp\SUPER_Kontering\log.txt
start c:\super\stoppsuper.exe kontroll 2
c:\super\wait.exe 130
c:\super\taskkill.exe /F /IM stoppsuper.exe 
c:\super\taskkill.exe /F /IM super.exe 


If exist c:\super\super.exe goto KONTERING

goto end

:KONTERING
if not exist c:\super\Konteringsoppgjoer md c:\super\Konteringsoppgjoer
if not exist c:\super\Konteringsoppgjoer\Scripts md c:\super\Konteringsoppgjoer\Scripts

cd Super
copy  FINANSRAPPORT.CDS c:\super\FINANSRAPPORT.CDS /y
copy  FINANSRAPPORTKOLONNE.CDS c:\super\FINANSRAPPORTKOLONNE.CDS /y
copy  FINANSRAPPORTSQL.CDS c:\super\FINANSRAPPORTSQL.CDS /y
copy  Kontering.exe c:\super\Kontering.exe /y
if not exist c:\super\SQLRunner.exe copy SQLRunner.exe c:\super\SQLRunner.exe 
cd ..
cd Scripts
copy  Konteringsnavn.SQL c:\super\Konteringsnavn.SQL /y
copy  Testmodus.SQL c:\super\Testmodus.SQL /y
copy  Aktivering_tidsstyring.SQL c:\super\Aktivering_tidsstyring.SQL /y
cd ..
copy  Scripts c:\super\Konteringsoppgjoer\Scripts /y

c:\super\wait.exe 5 

c:\super\SQLRunner.EXE -RUN Testmodus.SQL  >> c:\temp\SUPER_Kontering\log.txt

c:\super\wait.exe 5 

c:\Super\SQLRunner.EXE -RUN Aktivering_tidsstyring.SQL  >> c:\temp\SUPER_Kontering\log.txt

c:\super\wait.exe 5 

c:\super\SQLRunner.EXE -RUN Konteringsnavn.SQL  >> c:\temp\SUPER_Kontering\log.txt
c:\super\wait.exe 5 


c:\super\Kontering.exe -LESINNOPPSETT  >> c:\temp\SUPER_Kontering\log.txt
c:\super\wait.exe 5 

echo Kontering Kjørt %date% > c:\temp\kontering_%date%.txt

cd Misc
regedit /s kontering_version.reg  >> c:\temp\SUPER_Kontering\log.txt
xcopy  C:\Temp\SUPER_Kontering\Misc\matrise.xml c:\super\matrise.xml /y /r
:end

echo Starter Super... >> c:\temp\SUPER_Kontering\log.txt
echo ^<?xml version="1.0"?^> > c:\super\StartSuper.xml
echo ^<vbd^> >> c:\super\StartSuper.xml
echo ^<starttime^>%date:~6,4%-%date:~3,2%-%date:~0,2%T01:00:00^</starttime^> >> c:\super\StartSuper.xml
echo ^</vbd^> >> c:\super\StartSuper.xml

REM ::Opprydding
REM del c:\temp\Super_Kontering\*.CDS
REM del c:\temp\Super_Kontering\*.exe
REM del c:\temp\Super_Kontering\*.sql
REM del c:\temp\Super_Kontering\*.bat
REM del c:\temp\Super_Kontering\*.xml
REM del c:\temp\Super_Kontering\*.reg
REM if exist c:\super\Konteringsnavn.SQL del c:\super\Konteringsnavn.SQL  >> c:\temp\SUPER_Kontering\log.txt