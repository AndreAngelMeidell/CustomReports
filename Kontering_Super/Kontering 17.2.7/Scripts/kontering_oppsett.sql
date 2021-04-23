/*	
	Oppsett for kontering
	Version:		17.2.7
	Versjonnr sist endret av:  Andre Meidell

	Endret 20200814 laget til [vareegenskap] = N'43' for alle kjeder på MBXP kontoer ref Jira NG-1468
	Endret 20200826 flexaktivering
	Endret 20201104 fra NG, CUP of JPC korttyper og UPDATE varesalg..EANINFO for panto
	Endret 20210414 NG-2203

	
*/
use super--§§§§ Konteringsoppgjoer
if not exists (SELECT * FROM super.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='KONTERINGSOPPGJOER' and COLUMN_NAME='SLETTET')
begin
	alter table super..konteringsoppgjoer add SLETTET datetime null;
end
go
use super-- legge til kolonne revisjon
if not exists (SELECT * FROM super.INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME='KONTERINGSOPPGJOER' and COLUMN_NAME='REVISJON')
begin
	alter table super..konteringsoppgjoer add REVISJON int;
end
go
if exists(select * from super..PARAMETERE where NAVN = 'KONTERINGSNAVN' and VERDI = 'Konteringsoppgjoer_v3')
begin
update super..KONTERINGSOPPGJOER set REVISJON = 1 where REVISJON is null;
end
go
use SUPER --§§§§ Konteringsoppgjoerlinjelogg, ny revisjon
if not exists(SELECT * FROM sys.tables WHERE  name = 'KONTERINGSOPPGJOERLINJELOGG')
begin
	CREATE TABLE [Super].[dbo].[KONTERINGSOPPGJOERLINJELOGG](
		[KONTERINGSOPPGJOERLINJELOGGID] [int] IDENTITY(1,1) NOT NULL,
		[ZNR] [int] NOT NULL,
		[UTSALGSSTEDNR] [int] NULL,
		[AVDELINGSNR] [int] NULL,
		[DEBETKONTONR] [int] NULL,
		[DEBETBELOEP] [decimal](15, 2) NULL,
		[KREDITKONTONR] [int] NULL,
		[KREDITBELOEP] [decimal](15, 2) NULL,
		[MVAPROSENT] [decimal](15, 4) NULL,
		[FRITEKST1] [varchar](50) NULL,
		[FRITEKST2] [varchar](50) NULL,
		[FRITEKST3] [varchar](50) NULL,
		[DATO] [datetime] NULL,
		[REVISJON] [int] NULL
	 CONSTRAINT [KONTERINGSOPPGJOERLINJELOGG_PKKONTERINGSOPPGJOERLINJELOGG] PRIMARY KEY CLUSTERED 
	(
		[KONTERINGSOPPGJOERLINJELOGGID] ASC
	)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]
end
go
--§§§§ Konteringskontoer
-- denne tabellen kan inneholde flere rader pr konteringskonto, dersom det f.eks er flere føringer på kontoen men med ulik vareegenskaper (f.eks 2992)
drop table super..KONTERINGSKONTO
go
create table super..KONTERINGSKONTO (kontonr int
									, navn varchar(50)
									, fritekst1 varchar(50)
									, fritekst2 varchar(50)
									, fritekst3 varchar(50)
									, flgegenregel bit default 0 not null
									, flgprovisjonsregel bit default 0 not null
									, vareegenskap varchar(50), varetype varchar(50)
									, mvaprosent int
									, mvaprosentprovisjon int
									, flgoverstyrmvaprosent bit default 0 not null
									, kontonrprovisjon int
									, flgomvendtprovisjon bit default 0 not null
									,[flgoverstyrfritekst1provisjon] [bit] NULL
									,[overstyrfritekst1Text] [varchar](50) NULL
									, notat text)
go
begin try --Legger inn data i konteringskonto tabell
	delete from super..KONTERINGSKONTO --Legger inn konteringskonto på nytt.
	insert [Super].[dbo].[KONTERINGSKONTO] --Kontonr 1500 Utestående kundefordring
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon]) 
	values 
		(1500
		, N'Utestående kundefordring' --[KONTONR]
		, null --[NAVN]
		, null --[fritekst1]
		, null --[fritekst2]
		, 0 --[fritekst3]
		, 0 --[flgegenregel]
		, null --[flgprovisjonsregel]
		, null --[vareegenskap]
		, null
		, null
		, null
		, 0
		, null
		, 0)
		,
		--Kontonr 1515 Bankkort
		(1515
			, N'Bankkort'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)	
			,(1520 --Viderefakturering
			, N'Viderefakturering'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)	
			, (1542	--1545 Tilgodelapper
			, N'Tilgodelapper'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)
			-- 1543 Fordringer trumfsjekker
			, (1543
			, N'Fordringer trumfsjekker'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)
			 --1567 Tredjepartsomsetning
			,(1567
			, N'Tredjepartsomsetning'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)
			
			--1599 NG ASA  (Typisk Norsk)
			, (1599
			, N'NG ASA'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)
			 --1795 Interimkonto utlegg
			, (1795
			, N'Interimkonto utlegg'
			, N'Utlegg'
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

			 --1900 Kasse
			,(1900			-- Konto
			, N'Kontantomsetning'		-- NAVN
			, N'Kontanter fra servicepunkt 3.p. tjenester'			-- fritekst1
			, null			-- fritekst2
			, null			-- fritekst3
			, 0				-- flgegenregel
			, 0				-- flgprovisjonsregel
			, null			-- vareegenskap
			, null			-- varetype
			, null			-- notat		
			, null			-- mvaprosent
			, null			-- mvaprosentprovisjon
			, 1				-- flgoverstyrmvaprosent
			, null			-- kontonrprovisjon
			, 0)			-- flgomvendtprovisjon
			--1910 DnB Nor
			, (1910
			, N'Bank (DnB NOR)'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (1920
			, N'Bank (Nordea)'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0) --1920

	insert [Super].[dbo].[KONTERINGSKONTO] --1930 Bank (Andre)
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (1930
			, N'Bank (Andre)'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2310 Konsernkonto DnB NOR driftskonto
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2310
			, N'Konsernkonto DnB NOR driftskonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2311 Konsernkonto DnB NOR tippekonto
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2311
			, N'Konsernkonto DnB NOR tippekonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2312 Konsernkonto DnB NOR vekselkonto
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2312
			, N'Konsernkonto DnB NOR vekselkonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2313 Konsernkonto DnB NOR annet
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2313
			, N'Konsernkonto DnB NOR annet'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2320
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2320
			, N'Konsernkonto Nordea driftskonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2321
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2321
			, N'Konsernkonto Nordea tippekonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2322
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2322
			, N'Konsernkonto Nordea vekselkonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2323
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2323
			, N'Konsernkonto Nordea annet'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2330
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2330
			, N'Bank utenfor konsernkonto, driftskonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2331
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2331
			, N'Bank utenfor konsernkonto, tippekonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2332
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2332
			, N'Bank utenfor konsernkonto, veksel'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2333
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2333
			, N'Bank utenfor konsernkonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2334
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2334
			, N'Bank utenfor konsernkonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2335
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2335
			, N'Bank utenfor konsernkonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2336
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2336
			, N'Bank utenfor konsernkonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2337
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2337
			, N'Bank utenfor konsernkonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2338
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2338
			, N'Bank utenfor konsernkonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2339
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2339
			, N'Bank utenfor konsernkonto'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2340
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2340
			, N'Bank utenfor konsernkonto, PiB'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2345
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2345
			, N'Bank utenfor konsernkonto, PiB'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2915
			, N'NG ASA Elektronisk gavekort'
			, N'Elektroniske gavekort oppgjør'
			, null
			, '36'
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	--insert [Super].[dbo].[KONTERINGSKONTO] --2992 Ligger dobblet og ødelegger for MyPack! Panto bruker også 2992 men her er kontonr og annet hardkodet
	-- ([KONTONR], [NAVN], [fritekst1], [fritekst2], [fritekst3], [flgegenregel], [flgprovisjonsregel], [vareegenskap], [varetype], [notat], [mvaprosent], [mvaprosentprovisjon], [flgoverstyrmvaprosent], [kontonrprovisjon], [flgomvendtprovisjon])
	--values (2992, N'Tredjepartsomsetning', NULL, NULL, NULL, 0, 0, NULL, NULL, NULL, NULL, NULL, 0, NULL, 0)
	
	insert [Super].[dbo].[KONTERINGSKONTO] --2992
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2992
			, N'Andre provisjonsinntekter'
			, 'Salg Ruter billetter'
			, null
			, '6'
			, 1
			, 0
			, N'42'
			, null
			, null
			, null
			, null
			, 1
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --2992 Salg MyPack
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2992
			, N'Tredjepartsomsetning'
			, 'Salg MyPack'
			, NULL
			, '4'
			, 1
			, 0
			, '39'
			, null
			, null
			, null
			, null
			, 1
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (2999
			, N'Annen kortsiktig gjeld, ikke rentebærende'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3000
			, N'Varesalg'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)
	
	insert [Super].[dbo].[KONTERINGSKONTO]  --3000 Varesalg Apotek vare
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3000
			, N'Varesalg Apotekvarer ASKO'
			,  N'Salg apotekvarer'
			, null
			, N'5'
			, 1
			, 0
			, N'41'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --3010 Frimerker salg
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3010
			, N'Frimerker salg'
			, 'Salg frimerker'
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --3030 Justering salg, ikke registrert kasse
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3030
			, N'Justering salg, ikke registrert kasse'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --3055 Salg / retur pant
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3055
			, N'Salg / retur pant'
			, null
			, null
			, null
			, 1
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --3600 Leieinntekter
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3620
			, N'Leieinntekter'
			, 'Leieinntekter'
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

				-- 3700 Provisjon Norsk Tipping er endret fra omvendt provisjon til standard oppsett nærmere blackhawk oppsett.
				-- NG har endret HB Konto på tippevarer gruppe 10 fra å være 3700 til å bli 541319 for Kiwi og 554654 for Meny.
				-- Se oppsett på disse kontoene for info om kontering av gjeld til profilhus for det enkelte profilhus.
				-- 20201119 [mvaprosentprovisjon] endret fra 0 til NULL
				
	insert [Super].[dbo].[KONTERINGSKONTO] --3700 Provisjon Norsk Tipping
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3700
			, N'Provisjon Norsk Tipping'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --3702 Catering
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3702
			, N'Catering'
			, N'Catering'
			, null
			, N'46'
			, 0
			, 0
			, N'46'
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --3705 Telekort
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3705
			, N'Provisjon telekort'
			, N'Telekort'
			, null
			, N'2'
			, 0
			, 1
			, N'32'
			, null
			, null
			, 25
			, 0
			, 1
			, 4300
			, 1)

	insert [Super].[dbo].[KONTERINGSKONTO] --3707 Apoteksvarer
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3707
			, N'Apoteksvarer'
			, N'Salg apotekvarer'
			, null
			, N'5'
			, 1
			, 0
			, N'41'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --3708
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3708
			, N'Andre provisjonsinntekter'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --3708
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3708 --Er ikke lenger i bruk denne kan fjernes etter 13.2.13
			, N'Andre provisjonsinntekter'
			, null
			, null
			, '6'
			, 1 
			, 1 --26.06.2013 endret slik at Ruter nå har provisjonskonteringskonto, ref dok. versjon 7.3 Er ikke lenger i bruk
			, N'42'
			, null
			, null
			, null
			, null
			, 0
			, 2970
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --3708 Catering
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (3708
			, N'Andre provisjonsinntekter'
			, 'Catering'
			, null
			, '46'
			, 1
			, 0
			, N'46'
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (4300
			, N'Varekjøp'
			, N'Telekort'
			, null
			, N'2'
			, 0
			, 1
			, N'32'
			, null
			, null
			, 0
			, null
			, 1
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (4355
			, N'Kjøp / retur pant'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (5988
			, N'Personalrabatt'
			, 'Personalrabatt'
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (7320
			, N'Markedsførings- og Reklamekostnad'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (7770
			, N'Bankomkostninger og gebyrer'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] --5.3.3 Surcharge gebyr, ikke gjort ferdig eller testet!
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]			
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon]
			,[notat])
	values (7770
			, N'Surcharge gebyr'
			, N'Surcharge gebyr'
			, null
			, null
			, 0
			, 1
			, null
			, null			
			, null
			, null
			, 1
			, null
			, 0
			,N'Ikke testet.')

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (7771
			, N'Øredifferanse'
			, N'Øresavrunding'
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, 0
			, null
			, 1
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (513079
			, N'Gjeld til KIWI HK'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
		([KONTONR]
		, [NAVN]
		, [fritekst1]
		, [fritekst2]
		, [fritekst3]
		, [flgegenregel]
		, [flgprovisjonsregel]
		, [vareegenskap]
		, [varetype]
		, [notat]
		, [mvaprosent]
		, [mvaprosentprovisjon]
		, [flgoverstyrmvaprosent]
		, [kontonrprovisjon]
		, [flgomvendtprovisjon])
	values (515470
			, N'Voucher Meny'
			, null
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (519231
			, N'DNB Bank ASA(BIB)'
			, N'BiB Netto bank'
			, N'Antall transaksjoner: '
			, null
			, 1
			, 0
			, null
			, '3,4,5,6'
			, null
			, null
			, null
			, 0
			, null
			, 0)

	--20201119 endret [mvaprosentprovisjon] til null
	insert [Super].[dbo].[KONTERINGSKONTO] ([KONTONR], [NAVN], [fritekst1], [fritekst2], [fritekst3], [flgegenregel], [flgprovisjonsregel]
			, [vareegenskap], [varetype], [notat], [mvaprosent], [mvaprosentprovisjon], [flgoverstyrmvaprosent], [kontonrprovisjon], [flgomvendtprovisjon],[flgoverstyrfritekst1provisjon] ,[overstyrfritekst1Text] )
	values (541319
			, N'Spill i kasse Kiwi'
			, N'Spill i kasse, gjeld til profilhus'
			, null
			, N'8'
			, 0
			, 1
			, null
			, N'10'
			, null
			, null
			, NULL
			, 1
			, 3700
			, 0
			,1
			,N'Spill i kasse, provisjon')

	--20201119 endret [mvaprosentprovisjon] til null			
	insert [Super].[dbo].[KONTERINGSKONTO] ([KONTONR], [NAVN], [fritekst1], [fritekst2], [fritekst3], [flgegenregel], [flgprovisjonsregel], [vareegenskap]
			, [varetype], [notat], [mvaprosent], [mvaprosentprovisjon], [flgoverstyrmvaprosent], [kontonrprovisjon], [flgomvendtprovisjon],[flgoverstyrfritekst1provisjon] ,[overstyrfritekst1Text])
	values (554654
			, N'Spill i kasse Meny'
			, N'Spill i kasse, gjeld til profilhus'
			, null
			, N'8'
			, 0
			, 1
			, null
			, N'10'
			, null
			, null
			, null
			, 1
			, 3700
			, 0
			,1
			,N'Spill i kasse, provisjon')

	-- Spill i kasse KHM
	-- 20201119 endret [mvaprosentprovisjon] til null
	insert [Super].[dbo].[KONTERINGSKONTO] ([KONTONR], [NAVN], [fritekst1], [fritekst2], [fritekst3], [flgegenregel], [flgprovisjonsregel], [vareegenskap]
			, [varetype], [notat], [mvaprosent], [mvaprosentprovisjon], [flgoverstyrmvaprosent], [kontonrprovisjon], [flgomvendtprovisjon],[flgoverstyrfritekst1provisjon] ,[overstyrfritekst1Text])
	values (569589
			, N'Spill i kasse KMH'
			, N'Spill i kasse, gjeld til profilhus'
			, null
			, N'8'
			, 0
			, 1
			, null
			, N'10'
			, null
			, null
			, null
			, 1
			, 3700
			, 0
			,1
			,N'Spill i kasse, provisjon')
			
			 
		--1593 Salg Flax
--	insert [Super].[dbo].[KONTERINGSKONTO] ([KONTONR], [NAVN], [fritekst1], [fritekst2], [fritekst3], [flgegenregel], [flgprovisjonsregel], [vareegenskap]
	--		, [varetype], [notat], [mvaprosent], [mvaprosentprovisjon], [flgoverstyrmvaprosent], [kontonrprovisjon], [flgomvendtprovisjon],[flgoverstyrfritekst1provisjon] ,[overstyrfritekst1Text])
--	values (1593
--			, N'Salg Flax'
--			, N'Salg Flax lodd'
--			, null
--			, N'40'
--			, 0
--			, 1
--			, null
--			, N'11'
--			, null
--			, null
--			, 0
--			, 1
--			, 3700
--			, 0
--			,1
--			,N'Flax, provisjon')			

	-- MBPX
	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (544088
			, N'MBXP Kiwi'
			, N'MBXP'
			, null
			, N'24'
			, 1
			, 1
			, N'43'
			, N'35,36,37'
			, null
			, null
			, 0
			, 1
			, 3708
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (544110
			, N'MBXP KMH'
			, N'MBXP'
			, null
			, N'24'
			, 1
			, 1
			, N'43'
			, N'35,36,37'
			, null
			, null
			, 0
			, 1
			, 3708
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (544242
			, N'MBXP Meny'
			, N'MBXP'
			, null
			, N'24'
			, 1
			, 1
			, N'43'
			, N'35,36,37'
			, null
			, null
			, 0
			, 1
			, 3708
			, 0)

	
/*	--Blackhawk
	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (544088
			, N'Blackhawk Kiwi'
			, N'BlackHawk'
			, null
			, N'10'
			, 0
			, 1
			, null
			, N'35,36,37'
			, null
			, null
			, 0
			, 1
			, 3708
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (544110
			, N'Blackhawk KMH'
			, N'BlackHawk'
			, null
			, N'10'
			, 0
			, 1
			, null
			, N'35,36,37'
			, null
			, null
			, 0
			, 1
			, 3708
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] 
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (544242
			, N'Blackhawk Meny'
			, N'BlackHawk'
			, null
			, N'10'
			, 0
			, 1
			, null
			, N'35,36,37'
			, null
			, null
			, 0
			, 1
			, 3708
			, 0)
*/
	INSERT [Super].[dbo].[KONTERINGSKONTO] --6302 Refusjon parkering
			([KONTONR]
			, [NAVN]
			, [fritekst1]
			, [fritekst2]
			, [fritekst3]
			, [flgegenregel]
			, [flgprovisjonsregel]
			, [vareegenskap]
			, [varetype]
			, [notat]
			, [mvaprosent]
			, [mvaprosentprovisjon]
			, [flgoverstyrmvaprosent]
			, [kontonrprovisjon]
			, [flgomvendtprovisjon])
	values (6302
			, N'Refusjon parkering'
			, N'Refusjon parkering'
			, null
			, N'10'
			, 0
			, 0
			, null
			, null
			, null
			, 0
			, null
			, 1
			, null
			, 0)

	insert [Super].[dbo].[KONTERINGSKONTO] ([KONTONR], [NAVN], [fritekst1], [fritekst2], [fritekst3], [flgegenregel], [flgprovisjonsregel], [vareegenskap]
			, [varetype], [notat], [mvaprosent], [mvaprosentprovisjon], [flgoverstyrmvaprosent], [kontonrprovisjon], [flgomvendtprovisjon],[flgoverstyrfritekst1provisjon] ,[overstyrfritekst1Text])
	values (1594
			, N'Flaxaktivering'
			, N'FlaxAktivering'
			, null
			, N'10'
			, 0
			, 0
			, null
			, null
			, null
			, 0
			, null
			, 1
			, null
			, 0
			, 0
			, N'')

	--Hjemkjøring
	insert [Super].[dbo].[KONTERINGSKONTO] ([KONTONR], [NAVN], [fritekst1], [fritekst2], [fritekst3], [flgegenregel], [flgprovisjonsregel], [vareegenskap]
			, [varetype], [notat], [mvaprosent], [mvaprosentprovisjon], [flgoverstyrmvaprosent], [kontonrprovisjon], [flgomvendtprovisjon],[flgoverstyrfritekst1provisjon] ,[overstyrfritekst1Text])
	values (3980
			, N'Hjemkjøring'
			, N'Hjemkjøring'
			, null
			, null
			, 0
			, 0
			, null
			, null
			, null
			, null
			, null
			, 0
			, NULL 
			, 0
			,0
			,N'');

end try
begin catch
	select error_message()
end catch
go
begin try --§§§§ Parametere
	update SUPER..parametere set verdi=10 where navn='GODKJENTTALLAVVIK';
	update SUPER..parametere set verdi=4 where navn='KONTERINGBEHANDLINGSTID';       
	update SUPER..parametere set verdi=9802 where navn like '%VGRUTPANT%';
	update SUPER..parametere set verdi=9801 where navn like '%VGRINNPANT%';
	update SUPER..parametere set verdi=99 where navn like '%AVDUTPANT%';
	update SUPER..parametere set verdi=99 where navn like '%AVDINNPANT%';	
	



	if not exists(select * from super.dbo.PARAMETERE where navn = 'KONTERINGDEBUG')
	begin 
		insert into super.dbo.PARAMETERE
				( NR ,
				  NAVN ,
				  VERDI ,
				  PARAMETERTYPE ,
				  BESKRIVELSE ,
				  KATEGORI ,
				  LEDETEKST
				)
		values  ( (select max(NR)+1 from super.dbo.PARAMETERE) , -- NR - int
				  'KONTERINGDEBUG' , -- NAVN - varchar(50)
				  'F' , -- VERDI - varchar(200)
				  4 , -- PARAMETERTYPE - int
				  'Setter Kontering i debugmodus. (ekstra logging)' , -- BESKRIVELSE - varchar(50)
				  10 , -- KATEGORI - int
				  'Kontering debugmodus.'  -- LEDETEKST - varchar(50)
				)
	end
end try 
begin catch 
	select error_message()
end catch
go
use VARESALG--§§§§ Bankkort
if not exists(select * from sys.tables t inner join sys.columns c on (t.object_id = c.object_id) where t.name = 'BANKKORT' and c.name = 'PROSJEKTKODE')
begin
	alter table varesalg..BANKKORT add PROSJEKTKODE varchar(20);
end 
GO
use VARESALG--§§§§ Bankkort (Laget ifm med egen regel for håndtering av gebyr til NG Bedriftskort)
if not exists(select * from sys.tables t inner join sys.columns c on (t.object_id = c.object_id) where t.name = 'BANKKORT' and c.name = 'flgGebyrRegel')
begin
	alter table varesalg..BANKKORT add flgGebyrRegel BIT NOT NULL DEFAULT 0;
end 
GO
use VARESALG--§§§§ Bankkort (Laget ifm med egen regel for håndtering av gebyr til NG Bedriftskort)
if not exists(select * from sys.tables t inner join sys.columns c on (t.object_id = c.object_id) where t.name = 'BANKKORT' and c.name = 'GebyrDebetKontoNr')
begin
	alter table varesalg..BANKKORT add GebyrDebetKontoNr INT;
end 
GO
use VARESALG--§§§§ Bankkort (Laget ifm med egen regel for håndtering av gebyr til NG Bedriftskort)
if not exists(select * from sys.tables t inner join sys.columns c on (t.object_id = c.object_id) where t.name = 'BANKKORT' and c.name = 'GebyrFritekst1')
begin
	alter table varesalg..BANKKORT add GebyrFritekst1 VARCHAR(50);
end 
GO
use VARESALG--§§§§ Bankkort (Laget ifm med egen regel for håndtering av gebyr til NG Bedriftskort)
if not exists(select * from sys.tables t inner join sys.columns c on (t.object_id = c.object_id) where t.name = 'BANKKORT' and c.name = 'GebyrFritekst2')
begin
	alter table varesalg..BANKKORT add GebyrFritekst2 VARCHAR(50);
end 
GO
use VARESALG--§§§§ Bankkort (Laget ifm med egen regel for håndtering av gebyr til NG Bedriftskort)
if not exists(select * from sys.tables t inner join sys.columns c on (t.object_id = c.object_id) where t.name = 'BANKKORT' and c.name = 'GebyrFritekst3')
begin
	alter table varesalg..BANKKORT add GebyrFritekst3 VARCHAR(50);
end 
GO
use VARESALG--§§§§ Bankkort (Laget ifm med egen regel for håndtering av gebyr til NG Bedriftskort)
if not exists(select * from sys.tables t inner join sys.columns c on (t.object_id = c.object_id) where t.name = 'BANKKORT' and c.name = 'GebyrProsent')
begin
	alter table varesalg..BANKKORT add GebyrProsent FLOAT;
end 
GO

use VARESALG--§§§§ Bankkort (Laget ifm med egen regel for håndtering av gebyr til NG Bedriftskort)
if not exists(select * from sys.tables t inner join sys.columns c on (t.object_id = c.object_id) where t.name = 'BANKKORT' and c.name = 'GebyrKroner')
begin
	alter table varesalg..BANKKORT add GebyrKroner FLOAT;
end 
GO

USE VARESALG 
if not exists(select * from sys.tables t inner join sys.columns c on (t.object_id = c.object_id) where t.name = 'BANKKORT' and c.name = 'GebyrMva')
begin
	alter table varesalg..BANKKORT add GebyrMva FLOAT;
end 
GO


use VARESALG
if not exists(select t.object_id,t.name,c.name from sys.tables t inner join sys.columns c on t.object_id = c.object_id where t.name = 'bankkort' and c.name = 'fritekst1')
begin
	alter table varesalg..bankkort add fritekst1 varchar(50), fritekst2 varchar(50), debetkontonr int, flgbankkontonrfrasystemoppsett bit default 0
end 
go
if not exists(select * from varesalg..BANKKORT where typenr = 91) begin insert into varesalg..bankkort (typenr,navn,prosjektkode) values (91,'VISA PREPAID','15');end
if not exists(select * from varesalg..BANKKORT where typenr = 73) begin insert into varesalg..bankkort (typenr, navn, prosjektkode) values (73,'BBS SENTERGAVEKORT2',''); end 
update varesalg..bankkort set prosjektkode=17 where typenr in (1,9,20,30,35,36);
update varesalg..bankkort set prosjektkode=15 where typenr=3; 
update varesalg..bankkort set prosjektkode=14 where typenr=4;
update varesalg..bankkort set prosjektkode=13 where typenr=6;
update varesalg..bankkort set prosjektkode=14 where typenr=14;
update varesalg..bankkort set prosjektkode=19 where typenr=19;
update varesalg..bankkort set prosjektkode=20 where typenr=20;
update varesalg..bankkort set prosjektkode=15 where typenr=34; 
update varesalg..bankkort set prosjektkode=36 where typenr=36;

update varesalg..bankkort set prosjektkode=43 where typenr=56;
update varesalg..bankkort set prosjektkode=15 where typenr=55; 
update varesalg..bankkort set prosjektkode=44 where typenr=5;
update varesalg..bankkort set prosjektkode=45 where typenr=73;
update varesalg..BANKKORT set fritekst1='BAX SMARTKORT',debetkontonr=NULL,flgbankkontonrfrasystemoppsett=1 where TYPENR in (1,30);
update varesalg..BANKKORT set debetkontonr=NULL,flgbankkontonrfrasystemoppsett=1 where TYPENR in (35,36,56,73);
update varesalg..BANKKORT set debetkontonr=1515,flgbankkontonrfrasystemoppsett=0 where TYPENR not in (1,30,35,36,56,73,998);

UPDATE varesalg.dbo.BANKKORT SET NAVN = 'NG Bedriftskort', PROSJEKTKODE = 68, flgbankkontonrfrasystemoppsett = 1
	, flgGebyrRegel = 1, GebyrFritekst1 = 'Gebyr NG Bedriftskort (mva 0% avg.k. 8)'
	, fritekst1 = 'NG Bedriftskort', GebyrDebetKontoNr = 7770, GebyrProsent = 1.2
	,GebyrKroner = 0.3, GebyrMva = 0
		WHERE TYPENR = 57;

UPDATE varesalg..BANKKORT set NAVN = 'NG Kjedegavekort', PROSJEKTKODE = 69, flgbankkontonrfrasystemoppsett = 1 
	 ,GebyrMva = 0
	,fritekst1 = 'NG elektronisk gavekort'
WHERE TYPENR = 58;

update varesalg..bankkort set debetkontonr='1515' where navn='VISA PREPAID'

--iGIVE gavekort
UPDATE varesalg..bankkort SET navn='iGIVE Gavekort K', prosjektkode=17,debetkontonr=NULL,flgbankkontonrfrasystemoppsett=1 where typenr=38;
UPDATE varesalg..bankkort SET navn='iGIVE Gavekort S', prosjektkode=17,debetkontonr=NULL,flgbankkontonrfrasystemoppsett=1 where typenr=39;
UPDATE varesalg..bankkort SET navn='iGIVE Kampanje K', prosjektkode=17,debetkontonr=NULL,flgbankkontonrfrasystemoppsett=1 where typenr=40;
UPDATE varesalg..bankkort SET navn='iGIVE Kampanje S', prosjektkode=17,debetkontonr=NULL,flgbankkontonrfrasystemoppsett=1 where typenr=41;
UPDATE varesalg..bankkort SET navn='iGIVE Fordel', prosjektkode=17,debetkontonr=NULL,flgbankkontonrfrasystemoppsett=1 where typenr=42;

--Andre Changes 20201104 from NG: 10.5	28.10.2020	H. Myre	Lagt inn 2 nye betalingskort h.h.v. CUP card med issuer ID 68 og prosjektnummer 48 samt JCB med issuer ID 11 og prosjektnummer 49 
update varesalg..BANKKORT set prosjektkode=48,flgbankkontonrfrasystemoppsett=1 where typenr=68
update varesalg..BANKKORT set prosjektkode=49,flgbankkontonrfrasystemoppsett=1 where typenr=11


insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - Bankkort tabell ble oppdatert.', 0, 1)
go

use varesalg--§§§§ for betalingsmidler
go
if exists(select * from sys.tables where name='betalingsmiddel')
begin
	drop table varesalg..betalingsmiddel
end;
go
create table [Varesalg].[dbo].[BETALINGSMIDDEL](
												[BETALINGSMIDDELNR] [smallint] NOT NULL,
												[DEBETKONTONR] [int] NULL,		
												[KREDITKONTONR] [int] NULL,			
												[FRITEKST1] [varchar](50) NULL,	
												[FRITEKST2] [varchar](50) NULL,	
												[FRITEKST3] [varchar](50) NULL,
												[flgbankkontonrfrasystemoppsett] bit default 0 NOT NULL,
												[flgEgenRegel] bit default 0 NOT NULL,
												[flgDebetRegel] bit default 0 NOT NULL
												constraint [BETALINGSMIDDEL_PKBETALINGSMIDDEL] primary key clustered  
												([BETALINGSMIDDELNR] asc)with 
												(pad_index  = off, statistics_norecompute = OFF, ignore_dup_key = off, allow_row_locks = on, allow_page_locks = on) on [PRIMARY]
) on [PRIMARY] 
go
begin try -- Legger inn betalingsmidler
	insert into varesalg..BETALINGSMIDDEL --1 Kontantomsetning
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (1
			,1900
			,'Kontantomsetning'
			,null
			,null
			,0
			,0)
	insert into varesalg..BETALINGSMIDDEL 
	(BETALINGSMIDDELNR,DEBETKONTONR,FRITEKST1,FRITEKST2,FRITEKST3,flgbankkontonrfrasystemoppsett,flgEgenRegel) 
	values (2
			,1520
			,'Papirgavekort innløsning'
			,null
			,null
			,0
			,0)	
	insert into varesalg..BETALINGSMIDDEL 
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (3
			,null
			,null
			,null
			,null
			,1
			,1)
	insert into varesalg..BETALINGSMIDDEL 
				(BETALINGSMIDDELNR
				,DEBETKONTONR
				,FRITEKST1
				,FRITEKST2
				,FRITEKST3
				,flgbankkontonrfrasystemoppsett
				,flgEgenRegel) 
	 values (4
			,299999
			,'Kreditt'
			,null
			,null
			,0
			,0)
	insert into varesalg..BETALINGSMIDDEL 
				(BETALINGSMIDDELNR
				,DEBETKONTONR
				,FRITEKST1
				,FRITEKST2
				,FRITEKST3
				,flgbankkontonrfrasystemoppsett
				,flgEgenRegel) 
	values (5
			,null
			,null
			,null
			,null
			,1
			,1)
	insert into varesalg..BETALINGSMIDDEL 
				(BETALINGSMIDDELNR
				,DEBETKONTONR
				,FRITEKST1
				,FRITEKST2
				,FRITEKST3
				,flgbankkontonrfrasystemoppsett
				,flgEgenRegel) 
	values (6
			,299999
			,'Kontokreditt'	--,'Netto bevegelse kredittsalg'
			,null
			,null
			,0
			,1)	
	insert into varesalg..BETALINGSMIDDEL --7
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (7
			,2915
			,'Elektroniske gavekort oppgjør'
			,null
			,'36'
			,0
			,0)	
	insert into varesalg..BETALINGSMIDDEL --8
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (8
			,1900
			,'Valuta'
			,null
			,null
			,0
			,1)	
	insert into varesalg..BETALINGSMIDDEL 
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (9
			,1900
			,'Kontantomsetning'
			,null
			,null
			,0
			,0)	
	insert into varesalg..BETALINGSMIDDEL 
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (10
			,1542
			,'Tilgodelapp'
			,null
			,null
			,0
			,0)
	insert into varesalg..BETALINGSMIDDEL --11 Tilgodelapp
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (11
			,1542
			,'Tilgodelapp'
			,null
			,null
			,0
			,0)
	insert into varesalg..BETALINGSMIDDEL --12 Trumf bonus sjekk
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (12
			,1543
			,'Trumf bonus sjekk, innløsning'
			,null
			,null
			,0
			,0)	
	insert into varesalg..BETALINGSMIDDEL --13 Elektronisk gavekort oppgjør
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (13
			,2915
			,'Elektroniske gavekort oppgjør'
			,null
			,'36'
			,0
			,0)
	insert into varesalg..BETALINGSMIDDEL -- 14 Manuell Bank
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (14
			,1900
			,'Manuell Bank'
			,null
			,'17'
			,1
			,0)
	insert into varesalg..BETALINGSMIDDEL --19 Julegavekort innløsning
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (19
			,2915
			,'Julegavekort innløsning'
			,null
			,'41'
			,0
			,0)
	insert into varesalg..BETALINGSMIDDEL --20 Typisk Norsk
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (20
			,1599
			,'Typisk Norsk'
			,null
			,'42'
			,0
			,0)
	insert into varesalg..BETALINGSMIDDEL --21 Typisk Norsk
			(BETALINGSMIDDELNR
			,DEBETKONTONR
			,FRITEKST1
			,FRITEKST2
			,FRITEKST3
			,flgbankkontonrfrasystemoppsett
			,flgEgenRegel) 
	values (21
			,1599
			,'Typisk Norsk'
			,null
			,'42'
			,0
			,0)
	insert into varesalg..BETALINGSMIDDEL --22 MOBIL
	(BETALINGSMIDDELNR,DEBETKONTONR,FRITEKST1,FRITEKST2,FRITEKST3,flgbankkontonrfrasystemoppsett,flgEgenRegel) 
		values (22
				,NULL
				,'MOBIL'
				,null
				,null
				,0
				,0)
	insert into varesalg..BETALINGSMIDDEL --23 KUPONG
	(BETALINGSMIDDELNR,DEBETKONTONR,FRITEKST1,FRITEKST2,FRITEKST3,flgbankkontonrfrasystemoppsett,flgEgenRegel) 
		values (23
				,1543
				,'Trumf bonussjekk, innløsning'
				,null
				,null
				,0
				,0)
	insert into varesalg..BETALINGSMIDDEL --24 RESERVERT
	(BETALINGSMIDDELNR,DEBETKONTONR,FRITEKST1,FRITEKST2,FRITEKST3,flgbankkontonrfrasystemoppsett,flgEgenRegel) /* Hotfix for 5.3.13: update BETALINGSMIDDEL set DEBETKONTONR = 1515, FRITEKST1 = 'Webhandel',FRITEKST3= '47' where BETALINGSMIDDELNR = 24 */
		values (24
				,1515
				,'Webhandel'
				,null
				,'47'
				,0
				,1)
--New Andre 20200826
-- Changed 1900 to 3000 20201026

 	insert into varesalg..BETALINGSMIDDEL --300 RESERVERT
	(BETALINGSMIDDELNR,DEBETKONTONR,FRITEKST1,FRITEKST2,FRITEKST3,flgbankkontonrfrasystemoppsett,flgEgenRegel) /* Hotfix for 5.3.13: update BETALINGSMIDDEL set DEBETKONTONR = 1515, FRITEKST1 = 	'Webhandel',FRITEKST3= '47' where BETALINGSMIDDELNR = 24 */
	values (300
	,3000
	,'Flaxlodd,gevinst '
	,'Innløst gevinst Flaxlodd '
	,'40'
	,0
	,1) 
		
end try
begin catch
	select ERROR_MESSAGE()
end catch
go
use SUPER --§§§§ Konterings View
if exists(select * from sys.views where name = 'KonteringIkkeGodkjent')
drop view KonteringIkkeGodkjent;
go
create view KonteringIkkeGodkjent as
select 
	(select BUTIKKNAVN from dbo.SYSTEMOPPSETT) as Butikknavn
	,k.OPPGJOERFORDATO
	,k.ZNR
	,sum(kl.DEBETBELOEP) as Debetbeloep
	,sum(kl.KREDITBELOEP) as Kreditbeloep
    ,sum(kl.DEBETBELOEP) - sum(kl.KREDITBELOEP) as Diff
from dbo.KONTERINGSOPPGJOER as k 
	inner join dbo.KONTERINGSOPPGJOERLINJE kl on (k.ZNR = kl.ZNR)
where (k.OPPGJOERFORDATO >= GETDATE() - 60) 
	and (k.OPPGJOERFORDATO < GETDATE())
	and (k.GODKJENT IS NULL)
group by k.OPPGJOERFORDATO, k.ZNR
go	
use VARESALG--§§§§ Hjelpefunksjoner, funksjonen "FN_ListTotable"
if not exists(select * from sys.tables where name = 'Numbers')
begin
	create table Varesalg..Numbers
	(Number int  NOT NULL,
		CONSTRAINT PK_Numbers PRIMARY KEY CLUSTERED (Number ASC)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
	) ON [PRIMARY]	
	DECLARE @x int	
	SET @x=0
	WHILE @x<8000
	BEGIN
		SET @x=@x+1
		insert INTO Varesalg..Numbers values (@x)
	end
end
go 
use Varesalg ----Legger inn funksjon for å lage "dataset / liste" fra string som er kommaseparert. 
go
if exists(select * from sys.objects where name ='FN_ListTotable') -- Sjekker om funksjon finnes
begin    
	drop function [dbo].[FN_ListTotable];	
end
go
create function [dbo].[FN_ListTotable] --Legger inn funksjon
(@SplitOn char(1),@List varchar(8000)) 
returns @ParsedList table (ListValue varchar(500))
as
	begin
		insert INTO @ParsedList
					(ListValue)
		select ListValue
		from (select
			  LTRIM(RTRIM(SUBSTRING(List2, number+1, CHARINDEX(@SplitOn, List2, number+1)-number - 1))) AS ListValue
			 from (
					select @SplitOn + @List + @SplitOn AS List2
				   ) AS dt
		INNER JOIN Numbers n ON n.Number < LEN(dt.List2)
		where SUBSTRING(List2, number, 1) = @SplitOn
			) dt2
	where ListValue IS NOT NULL AND ListValue!=''
	
	return
	end 
GO
use SUPER --§§§ Testmodus
if  not exists (select * from SUPER..TIDSSTYRING where PARAMETERE like '%KONTERING%')
begin
	update SUPER..PARAMETERE set VERDI='T' where NAVN='KONTERINGTESTMODUS'
	print('Satt til Testmodus')
end
GO
IF NOT EXISTS(select * from super..parametere where navn='KONTERINGMINDATO')
BEGIN 
	INSERT INTO super..PARAMETERE (nr,NAVN,VERDI,PARAMETERTYPE,BESKRIVELSE,KATEGORI,LEDETEKST) 
	VALUES ((SELECT MAX(NR)+1 from super..PARAMETERE),'KONTERINGMINDATO','2017-08-29',1,'Minste dato for automatisk re-generering Kontering',10,'Minste dato for automatisk re-generering.');
END

--Andre 20201104 Removed
--GO
--Update KONTERINGMINDATO to make new kontering not run for previous dates, comment the line under if a rollout does not want this feature
--UPDATE super..PARAMETERE SET VERDI=(SELECT CONVERT (date, GETDATE())) WHERE NAVN='KONTERINGMINDATO';
--GO


--20210217 Flaxstatistikk
--Remman 20201123 adds matrix reading for 19-FLAXSTATISTIKK 21-KIB_INNSKUDD og 22-KIB_UTTAK
--19-FLAXSTATISTIKK
update super..PARAMETERE
set VERDI = VERDI+';19'
WHERE NAVN = 'DAGSOPPGJOERMATRISELISTE'
	AND VERDI NOT LIKE '%;19%';
--21-KIB_INNSKUDD
update super..PARAMETERE
set VERDI = VERDI+';21'
WHERE NAVN = 'DAGSOPPGJOERMATRISELISTE'
	AND VERDI NOT LIKE '%;21%';
--22-KIB_UTTAK		
update super..PARAMETERE
set VERDI = VERDI+';22'
WHERE NAVN = 'DAGSOPPGJOERMATRISELISTE'
	AND VERDI NOT LIKE '%;22%';																						   
--Andre 20201104 New update due to wrong info on 9820000000005
GO
UPDATE varesalg..EANINFO
SET KREDITKONTONR = NULL,AVDELINGSNR = NULL
WHERE EANNR = 9820000000005
	AND KREDITKONTONR IS NOT NULL
GO

--Andre 20210309 pga gavekort 10 øre fortjeneste gir diff
update KONTERINGSKONTO 
set fritekst1='Andre provisjonsinntekter' 
where kontonr=3708 and fritekst1 is null and fritekst3 is NULL



GO

