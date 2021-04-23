[SUPER:MSSQL]
[MULTILINE_START]
if  not exists 	(select * from SUPER..TIDSSTYRING where PARAMETERE like '%KONTERING%')
Begin
update SUPER..PARAMETERE set VERDI='T' where NAVN='KONTERINGTESTMODUS'
PRINT('Satt til Testmodus')
END
else  
declare @versjon as varchar(25)
set @versjon = (select max(Verdi) from super..PARAMETERE where navn='KONTERINGVERSJON')
print ('Oppgradering av kontering fra '+ @versjon)
[MULTILINE_END]