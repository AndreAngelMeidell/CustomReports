[SUPER:MSSQL]
[MULTILINE_START]
if not exists(select * from super..PARAMETERE where navn = 'KONTERINGSNAVN')
begin
	insert into super..PARAMETERE ( NR ,NAVN ,VERDI ,PARAMETERTYPE ,BESKRIVELSE ,KATEGORI ,LEDETEKST)
	values  ( (select max(nr)+1 from super..PARAMETERE),'KONTERINGSNAVN' , -- NAVN - varchar(50)
	          'Konteringsoppgjoer_v3' , -- VERDI - varchar(200)
	          0 , -- PARAMETERTYPE - int
	          'Navn på konteringsoppgjør som skal kjøres' , -- BESKRIVELSE - varchar(50)
	          7 , -- KATEGORI - int
	          'Konteringsoppgjør navn'  -- LEDETEKST - varchar(50)
	        );
end
else
begin  
	update super..parametere set verdi='Konteringsoppgjoer_v3' where navn='KONTERINGSNAVN';
end
[MULTILINE_END]
[SUPER:MSSQL]
[MULTILINE_START]
delete from SUPER..konteringskonto where kontonr=511225;
delete from SUPER..konteringskonto where kontonr=511225;
delete from SUPER..konteringskonto where kontonr=2992;
insert into SUPER..konteringskonto (kontonr,navn) values (2992,'Tredjepartsomsetning');
delete from SUPER..konteringskonto where kontonr=7320;
insert into SUPER..konteringskonto (kontonr,navn) values (7320,'Markedsfærings- og Reklamekostnad');
delete from SUPER..konteringskonto where kontonr=3030;
insert into SUPER..konteringskonto (kontonr,navn) values (3030,'Justering salg, ikke registrert kasse');
delete from SUPER..konteringskonto where kontonr=4300;
insert into SUPER..konteringskonto (kontonr,navn) values (4300,'Varekjøp');
delete from SUPER..konteringskonto where kontonr=7770;
insert into SUPER..konteringskonto (kontonr,navn) values (7770,'Bankomkostninger og gebyrer');
delete from SUPER..konteringskonto where kontonr=544088;
insert into SUPER..konteringskonto (kontonr,navn) values (544088,'Blackhawk Kiwi');
delete from SUPER..konteringskonto where kontonr=544110;
insert into SUPER..konteringskonto (kontonr,navn) values (544110,'Blackhawk KMH');
delete from SUPER..konteringskonto where kontonr=544242;
insert into SUPER..konteringskonto (kontonr,navn) values (544242,'Blackhawk Meny');
delete from SUPER..konteringskonto where kontonr=519231;
insert into SUPER..konteringskonto (kontonr,navn) values (519231,'DNB Bank ASA(BIB)');
delete from SUPER..konteringskonto where kontonr=515470;
insert into SUPER..konteringskonto (kontonr,navn) values (515470,'Voucher Meny');
delete from SUPER..konteringskonto where kontonr=541319;
insert into SUPER..konteringskonto (kontonr,navn) values (541319,'Spill i kasse Kiwi');
delete from SUPER..konteringskonto where kontonr=1515;
insert into SUPER..konteringskonto (kontonr,navn) values (1515,'Bankkort');
delete from SUPER..konteringskonto where kontonr=1567;
insert into SUPER..konteringskonto (kontonr,navn) values (1567,'Tredjepartsomsetning');  
delete from SUPER..konteringskonto where kontonr=3708;
insert into SUPER..konteringskonto (kontonr,navn) values (3708,'Andre provisjonsinntekter');  
delete from SUPER..konteringskonto where kontonr=5988;
insert into SUPER..konteringskonto (kontonr,navn) values (5988,'Personalrabatt');  
delete from SUPER..konteringskonto where kontonr=3010;
insert into SUPER..konteringskonto (kontonr,navn) values (3010,'Frimerker salg');     
delete from SUPER..konteringskonto where kontonr=3705;
insert into SUPER..konteringskonto (kontonr,navn) values (3705,'Provisjon telekort');  
delete from SUPER..konteringskonto where kontonr=1593;
insert into SUPER..konteringskonto (kontonr,navn) values (1593,'Salg Flax');       
delete from SUPER..konteringskonto where kontonr=3620;
insert into SUPER..konteringskonto (kontonr,navn) values (3620,'Leieinntekter');       
delete from SUPER..konteringskonto where kontonr=3700;
insert into SUPER..konteringskonto (kontonr,navn) values (3700,'Provisjon Norsk Tipping');           
delete from SUPER..konteringskonto where kontonr=513079;
insert into SUPER..konteringskonto (kontonr,navn) values (513079,'Gjeld til KIWI HK');           
delete from SUPER..konteringskonto where kontonr=7771;
insert into SUPER..konteringskonto (kontonr,navn) values (7771,'Øredifferanse');
delete from SUPER..konteringskonto where kontonr=1599;
insert into SUPER..konteringskonto (kontonr,navn) values (1599,'NG ASA'); 
delete from SUPER..konteringskonto where kontonr=1594;
insert into SUPER..konteringskonto (kontonr,navn) values (1594,'FlaxAktivering');  
delete from SUPER..konteringskonto where kontonr=1542;
insert into SUPER..konteringskonto (kontonr,navn) values (1542,'Tilgodelapper');
IF NOT EXISTS(SELECT * FROM SUPER..konteringskonto WHERE Kontonr = 7792)
	INSERT into SUPER..Konteringskonto (kontonr,navn) values (7792,'Gjenglemte verdier');

[MULTILINE_END]
[SUPER:MSSQL]
[MULTILINE_START]
IF NOT EXISTS(SELECT * FROM dbo.VAREEGENSKAP WHERE VAREEGENSKAPNR = 46)
	BEGIN
		INSERT INTO dbo.VAREEGENSKAP
		VALUES  ( 46,'Catering')
	END
[MULTILINE_END]
--- Parametere
[SUPER:MSSQL]
[MULTILINE_START]
update SUPER..parametere set verdi=10 where navn='GODKJENTTALLAVVIK';
update SUPER..parametere set verdi=4 where navn='KONTERINGBEHANDLINGSTID';       
update SUPER..parametere set verdi=9802 where navn like '%VGRUTPANT%';
update SUPER..parametere set verdi=9801 where navn like '%VGRINNPANT%';
update SUPER..parametere set verdi=99 where navn like '%AVDUTPANT%';
update SUPER..parametere set verdi=99 where navn like '%AVDINNPANT%';
IF 'text' <> (SELECT TYPE_NAME(c.user_type_id) FROM sys.objects AS o JOIN sys.columns AS c  ON o.object_id = c.object_id WHERE o.name = 'FINANSRAPPORTSQL' and c.name ='SQLTEKST') BEGIN alter table finansrapportsql alter column sqltekst text END;
update utsalgssted set GLN=(select GLN from utsalgssted where utsalgsstednr=0);
[MULTILINE_END]
[VARESALG:MSSQL]
[MULTILINE_START] 
IF 2 = (SELECT scale FROM sys.objects AS o JOIN sys.columns AS c  ON o.object_id = c.object_id WHERE o.name = 'BONGVAREGENFELT' and c.name ='VERDI1') BEGIN alter table bongvaregenfelt alter column verdi1 decimal(15,3) END;
[MULTILINE_END] 
[VARESALG:MSSQL]
[MULTILINE_START]
if not exists(select * from sys.tables t inner join sys.columns c on (t.object_id = c.object_id) where t.name = 'BANKKORT' and c.name = 'PROSJEKTKODE')
	begin
		alter table varesalg..BANKKORT add PROSJEKTKODE varchar(20);
	end 
[MULTILINE_END]
[VARESALG:MSSQL]
[MULTILINE_START]
-- Bankkort del2 
update bankkort set prosjektkode=17 where typenr in (1,9,20,30,35,36);
update bankkort set prosjektkode=15 where typenr=3; 
update bankkort set prosjektkode=14 where typenr=4;
update bankkort set prosjektkode=13 where typenr=6; 
update bankkort set prosjektkode=14 where typenr=14; 
update bankkort set prosjektkode=19 where typenr=19;
update bankkort set prosjektkode=20 where typenr=20;
update bankkort set prosjektkode=15 where typenr=34; 
update bankkort set prosjektkode=36 where typenr=36; 
update bankkort set prosjektkode=43 where typenr=56;
update bankkort set prosjektkode=15 where typenr=55; 
delete from bankkort where typenr=73;
insert into bankkort (typenr, navn, prosjektkode) values (73,'BBS SENTERGAVEKORT2','');
update bankkort set prosjektkode=44 where typenr=5;
update bankkort set prosjektkode=45 where typenr=73;
DELETE FROM varesalg..BANKKORT WHERE TYPENR=91;
insert into varesalg..bankkort (typenr,navn,prosjektkode) values (91,'VISA PREPAID','15');
UPDATE VARESALG..Bankkort SET debetkontonr = NULL WHERE typenr = 998
[MULTILINE_END]
[SUPER:MSSQL]
[MULTILINE_START]
if exists(select * FROM sys.views where name = 'KonteringIkkeGodkjent')
drop view KonteringIkkeGodkjent 
[MULTILINE_END]
[SUPER:MSSQL]
[MULTILINE_START]
create view [dbo].[KonteringIkkeGodkjent] 
as 
	select 
	(select BUTIKKNAVN from dbo.SYSTEMOPPSETT) as Butikknavn
	,k.OPPGJOERFORDATO
	,k.ZNR
	,sum(kl.DEBETBELOEP) as Debetbeloep
	,sum(kl.KREDITBELOEP) as Kreditbeloep
    ,sum(kl.DEBETBELOEP) - sum(kl.KREDITBELOEP) as Diff
	from dbo.KONTERINGSOPPGJOER as k 
		inner join dbo.KONTERINGSOPPGJOERLINJE kl on (k.ZNR = kl.ZNR)
	where (k.OPPGJOERFORDATO >= GETDATE() - 90) 
		and (k.OPPGJOERFORDATO < GETDATE()) 
		and (k.GODKJENT IS NULL)
	group by k.OPPGJOERFORDATO, k.ZNR
[MULTILINE_END]
[SUPER:MSSQL]
[MULTILINE_START]
if exists(select * from parametere where navn='KONTERINGVERSJON')
update PARAMETERE set VERDI='17.2.6' where navn='KONTERINGVERSJON';
[MULTILINE_END]
[SUPER:MSSQL]
[MULTILINE_START]
if not exists(select * from parametere where navn='KONTERINGVERSJON')
	insert into PARAMETERE (nr,NAVN,VERDI,PARAMETERTYPE,BESKRIVELSE,KATEGORI,LEDETEKST) 
	VALUES ((SELECT MAX(NR)+1 from super..PARAMETERE),'KONTERINGVERSJON','17.1.1',1,'Versjon konteringsregler',10,'Versjon Konteringsregler');
[MULTILINE_END]
[SUPER:MSSQL]
[MULTILINE_START]
if not exists (SELECT * FROM super.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='FinansRapport' and COLUMN_NAME='RAPPORTTYPE')
	begin
		alter table FinansRapport add RAPPORTTYPE integer  
	end
[MULTILINE_END]