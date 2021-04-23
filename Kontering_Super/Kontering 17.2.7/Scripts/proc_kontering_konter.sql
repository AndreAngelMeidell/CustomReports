use VARESALG
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
if exists(select * from sys.procedures where name = 'Kontering_konter')
begin 
	drop procedure Kontering_konter;	
end
go
-- =============================================
-- Author:			ER Konsulent 
-- Create date: 	06 2013
-- Version:			17.2.7
-- Description:		Prosedyre som samler 
--					alle konteringsrelger(prosedyrer)
--					og godkjenningsprosedyre			
--Changes: 			14.04.2021 Andre Meidell NG-2227
-- =============================================
CREATE PROCEDURE [dbo].[Kontering_konter]	
	 @dato AS DATE
	,@override AS BIT = 0
AS
BEGIN	
	set nocount on;
	begin try --Parametere + logging 
		declare @Loggmelding varchar(300)
		, @Regelversjon varchar(15)
		, @Butikknavn varchar(50)
		, @Bankkontonr varchar(25)
		, @foerstesalg datetime
		, @sistesalg datetime
		, @revisjon int
		, @legginnoppgjoer bit
		, @znr int
		, @virkid int
		, @Dognforskyvning int
		, @fradato datetime
		, @tildato datetime
		, @debug bit;
		
		set @virkid = (select max(egenid) from super..systemoppsett);		
		set @Dognforskyvning = (select top 1 cast(verdi as int) from super..PARAMETERE where navn = 'DOGNFORSKYVNING');		
		set @fradato = @dato;
		set @fradato = dateadd(hour,@Dognforskyvning,@fradato);
		set @tildato = @fradato+1;		
		set @Regelversjon = (select max(cast(verdi as varchar(15))) from super..PARAMETERE where navn = 'KONTERINGVERSJON');
		set @Butikknavn = (select max(butikknavn) from super..systemoppsett);
		set @Bankkontonr = (select max(cast(bankkontonr as varchar(15))) from super..SYSTEMOPPSETT);		
		set @foerstesalg = (select min(datotid) 
							from bong 
							where datotid>=@fradato 
								and datotid<@tildato
								and bongid in(
									select --Utlukker bonger hvor det kun er korr.sist eller korr tidl.
										bongid
									from varesalg..bong
									where datotid>=@fradato
										and datotid<@tildato
									group by bongid having ((sum(isnull(salgbeloep,0))!=0) or (sum(isnull(innbetalt,0))!=0) or (sum(isnull(utbetalt,0))!=0) or (sum(mvabeloep)>0)))
									);
		set @sistesalg = (	select 
								max(datotid) 
							from varesalg..bong 
							where datotid>=@fradato 
								and datotid<@tildato);	
		set @debug = (select 
						case VERDI
							when 'F' 
							THEN 0
							else 1
						end
					from super..PARAMETERE where NAVN = 'KONTERINGDEBUG');

		---Logg: Starter kontering + Regelversjon
		set @Loggmelding = (select 'Kontering startet for dato '+ convert(varchar, @dato , 104) +'.');
		exec varesalg.dbo.Super_Logg @Melding =  @Loggmelding, @debug = 1;
		set @Loggmelding=(select 'Regelversjon '+ @Regelversjon + ' og HB kontonr: ' + isnull(@Bankkontonr, 0) + '. ' + @Butikknavn+'.');
		exec Super_Logg @Melding=@Loggmelding;
	END TRY 
	BEGIN CATCH
		set @Loggmelding = (select 'Kontering feilet steg. ' + error_message());
		exec varesalg.dbo.Super_Logg @Melding =  @Loggmelding, @debug = 1;
	END CATCH --Ferdig parametere + logg.
    
	--Kontroll on det er noe FlaxAktivering NG-2227 20210415
	if (@foerstesalg is null) 
	begin --Sjekker om det finnes FlaxAktivering når det ikke er noen bonger.
				
		SET @foerstesalg=(	SELECT min(RR.DATO) 
							from Rapporter..FLAXSTATISTIKK RR 
							where RR.DATO>=@fradato and RR.DATO<@tildato)

		set @sistesalg=(	SELECT max(RR.DATO) 
							from Rapporter..FLAXSTATISTIKK RR 
							where RR.DATO>=@fradato and RR.DATO<@tildato);
		
	END 
	
	
	IF (@foerstesalg IS NULL) 
		begin --Sjekker om det finnes bonger i angitt periode 
			set @Loggmelding = (select 'Ingen bonger for dato '+ convert(varchar, @dato , 104) +'.')
			exec varesalg.dbo.Super_Logg @Melding =  @Loggmelding, @debug = 1; -- nvarchar(max)		
		END --Stopper kontering dersom det ikke finnes salg i angitt periode.
	ELSE IF((@Bankkontonr IS NULL) OR (@Bankkontonr = '')) 
		begin --Sjekker om det bankkontonr er satt i systemoppsett
			set @Loggmelding =(select 'Kontering: Feilet grunnet at Bankkontonr mangler i Systemoppsett');
			exec Super_Logg @Melding=@Loggmelding, @debug = 1;
		END	--Stopper kontering dersom det ikke finnes Bankkontonr
	ELSE IF ((@virkid IS NULL) OR (@virkid = ''))	
		begin --Sjekker om Virksomhets ID er satt i systemoppsett
			set @Loggmelding =(select 'Kontering: Feilet grunnet at Virskomhets ID mangler i Systemoppsett');
			exec Super_Logg @Melding=@Loggmelding, @debug = 1;
		END --Stopper kontering dersom det Virksomhets ID ikke er satt i Systemoppsett tabellen.             
	ELSE 
		BEGIN --Starter kontering!
			if exists(select * from sys.tables where name = 'temp_konteringslinje') --Logikk for slette temp tabell dersom den finnes fra før.
				begin try --sletter temp_konteringslinje dersom den finnes fra før.
					drop table temp_konteringslinje; 
				END TRY
				BEGIN CATCH
					set @Loggmelding =(select 'Kontering: '+ ERROR_MESSAGE());
					exec Super_Logg @Melding=@Loggmelding, @debug = 1;
				END CATCH                			
			
			begin --Regler kjøring	
				begin try--Oppretter temp tabell
					create table temp_konteringslinje 
						( 
							[konteringsoppgjoerlinjeid] [INT] IDENTITY(1, 1) NOT NULL, 
							[utsalgsstednr]             [INT] NULL, 
							[avdelingsnr]               [INT] NULL, 
							[debetkontonr]              [INT] NULL, 
							[debetbeloep]               [DECIMAL](15, 2) NULL, 
							[kreditkontonr]             [INT] NULL, 
							[kreditbeloep]              [DECIMAL](15, 2) NULL, 
							[mvaprosent]                [DECIMAL](15, 4) NULL, 
							[fritekst1]                 [VARCHAR](50) NULL, 
							[fritekst2]                 [VARCHAR](50) NULL, 
							[fritekst3]                 [VARCHAR](50) NULL 
						) ;
				END TRY
				BEGIN CATCH
					set @Loggmelding=(select 'Kontering: '+ERROR_MESSAGE());
					exec Super_Logg @Melding=@Loggmelding, @debug = 1;
				END CATCH
				
				begin try --Kontering Varesalg
					insert into temp_konteringslinje 
					exec Kontering_varesalg @fradato, @tildato; 
					set @Loggmelding=(select 'Prosedyre Kontering_varesalg la inn: ' +  Cast(@@ROWCOUNT AS VARCHAR(2)) + ' linjer for dato:' + convert(varchar, @dato , 104))
					exec Super_Logg @Melding=@Loggmelding, @debug=@debug;
				END TRY
				BEGIN CATCH 
					set @Loggmelding=(select 'Feilet på prosedyre: Kontering_varesalg. ' + ERROR_MESSAGE());
					exec Super_Logg @Melding=@Loggmelding, @debug = 1;		
				END CATCH 
		
				begin try --Kontering Pant
					insert into temp_konteringslinje 
					exec Kontering_pant @fradato, @tildato 
					set @Loggmelding=(select 'Prosedyre Kontering_pant la inn: '  + Cast(@@ROWCOUNT AS VARCHAR(2)) + ' linjer for dato:' + convert(varchar, @dato , 104))
					exec Super_Logg @Melding=@Loggmelding, @debug=@debug;
				END TRY
				BEGIN CATCH 
					set @Loggmelding=(select 'Feilet på prosedyre: Kontering_pant. ' + ERROR_MESSAGE());
					exec Super_Logg @Melding=@Loggmelding, @debug = 1;		
				END CATCH 

				begin try --Kontering Provisjon
					insert into temp_konteringslinje 
					exec Kontering_provisjon @fradato, @tildato 
					set @Loggmelding=(select 'Prosedyre Kontering_provisjon la inn: '  + Cast(@@ROWCOUNT AS VARCHAR(2)) + ' linjer for dato:' + convert(varchar, @dato , 104))
					exec Super_Logg @Melding=@Loggmelding, @debug=@debug;
				END TRY
				BEGIN CATCH 
					set @Loggmelding=(select 'Feilet på prosedyre: Kontering_provisjon. ' + ERROR_MESSAGE());
					exec Super_Logg @Melding=@Loggmelding, @debug = 1;		
				END CATCH 

				begin try --Kontering BIB
					insert into temp_konteringslinje 
					exec Kontering_bib @fradato, @tildato 
					set @Loggmelding=(select 'Prosedyre Kontering_bib la inn: '  + Cast(@@ROWCOUNT AS VARCHAR(2)) + ' linjer for dato:' + convert(varchar, @dato , 104))
					exec Super_Logg @Melding=@Loggmelding;
				END TRY 
				BEGIN CATCH 
					set @Loggmelding=(select 'Feilet på prosedyre: Kontering_bib. ' + ERROR_MESSAGE());
					exec Super_Logg @Melding=@Loggmelding, @debug = 1;
				END CATCH 

				begin try --Konteirng betalingsmidler
					insert into temp_konteringslinje 
					exec Kontering_betalingsmidler @fradato, @tildato 
					set @Loggmelding=(select 'Prosedyre Kontering_betalingsmidler la inn: '  + Cast(@@ROWCOUNT AS VARCHAR(2)) + ' linjer for dato:' + convert(varchar, @dato , 104))
					exec Super_Logg @Melding=@Loggmelding, @debug=@debug;
				END TRY 
				BEGIN CATCH 
					set @Loggmelding=(select 'Feilet på prosedyre: Kontering_betalingsmidler. ' + ERROR_MESSAGE());
					exec Super_Logg @Melding=@Loggmelding, @debug = 1;
				END CATCH 					

				begin try --Kontering øreavrunding
					insert into temp_konteringslinje 
					exec Kontering_oreavrunding @fradato,@tildato			
					set @Loggmelding=(select 'Prosedyre Kontering_oreavrunding la inn: '  + Cast(@@ROWCOUNT AS VARCHAR(2)) + ' linjer for dato:' + convert(varchar, @dato , 104))
					exec Super_Logg @Melding=@Loggmelding, @debug=@debug;
				END TRY
				BEGIN CATCH 
					set @Loggmelding=(select 'Feilet på prosedyre: Kontering_oreavrunding. ' + ERROR_MESSAGE());
					exec Super_Logg @Melding=@Loggmelding, @debug = 1;
				END CATCH 

				begin try --Kontering kundegarantier
					insert into temp_konteringslinje 
					exec Kontering_kundegarantier @fradato,@tildato
					set @Loggmelding=(select 'Prosedyre Kontering_kundegarantier la inn: '  + Cast(@@ROWCOUNT AS VARCHAR(2)) + ' linjer for dato:' + convert(varchar, @dato , 104))
					exec Super_Logg @Melding=@Loggmelding, @debug=@debug;
				END TRY
				BEGIN CATCH
					set @Loggmelding=(select 'Feilet på prosedyre: Kontering_kundegarantier. ' + ERROR_MESSAGE());
					exec Super_Logg @Melding=@Loggmelding, @debug = 1;
				END CATCH

				BEGIN TRY --Kontering FlaxAktivering
					insert into temp_konteringslinje 
					exec Kontering_FlaxAktivering @fradato,@tildato
					set @Loggmelding=(select 'Prosedyre Kontering_FlaxAktivering la inn: '  + Cast(@@ROWCOUNT AS VARCHAR(2)) + ' linjer for dato:' + convert(varchar, @dato , 104))
					exec Super_Logg @Melding=@Loggmelding, @debug=@debug;
				END TRY
				BEGIN CATCH
					set @Loggmelding=(select 'Feilet på prosedyre: Kontering_FlaxAktivering. ' + ERROR_MESSAGE());
					exec Super_Logg @Melding=@Loggmelding, @debug = 1;
				END CATCH

                
			END --Ferdig med regelkjøring (SQL Prosedyrer!)

			set @znr = (	select 
								max(znr) 
							from super..konteringsoppgjoer 
							where OPPGJOERFORDATO=@dato 
								and SLETTET is null);
			set @revisjon = 1;
			set @legginnoppgjoer = 0;
						
			if (@znr is not null) -- sjekker om det finnes et oppgjør for angitt dag.
				begin -- sammenliger temp_konteringsoppgjoerlinje med KONTERINGSOPPGJOERLINJE
					set @Loggmelding=(select 'Oppgjør finnes fra før på følgende znr: '+cast(@znr as varchar));
					exec Super_Logg @Melding=@Loggmelding, @debug=@debug;

					set @Loggmelding=(select 'Sammenligner oppgjør (Debet og Kredit) med eksisterende oppgjør.');
					exec Super_Logg @Melding=@Loggmelding, @debug=@debug;
					
					declare @sjekkKREDITBELOEP as int;
					declare @sjekkDEBETBELOEP as int;

					set @sjekkKREDITBELOEP = (select count(*) as KREDITBELOEP
												from (
													select isnull(KREDITBELOEP, 0) as KREDITBELOEP from temp_konteringslinje 
													except
													select isnull(KREDITBELOEP, 0) as KREDITBELOEP from super..KONTERINGSOPPGJOERLINJE where ZNR = @znr
													) as T);
					
					set @sjekkDEBETBELOEP = (select count(*) as DEBETBELOEP
												from (
													select isnull(DEBETBELOEP, 0) as DEBETBELOEP from temp_konteringslinje 
													except
													select isnull(DEBETBELOEP, 0) as DEBETBELOEP from super..KONTERINGSOPPGJOERLINJE where ZNR = @znr
													) as T);

					IF (((@sjekkKREDITBELOEP > 0) OR (@sjekkDEBETBELOEP > 0)) OR (@override = 1))
					begin -- det er et endringsoppgjør, logger de gamle dataene og så sletter de gamle dataene
						set @revisjon = (	select 
												isnull(revisjon, 1) + 1 
											from super..konteringsoppgjoer 
											where OPPGJOERFORDATO=@dato 
												and SLETTET is null)

						set @Loggmelding=(select 'Differanser funnet mellom eksisterende oppgjør og nåværende oppgjøre!');
						exec Super_Logg @Melding=@Loggmelding, @debug=@debug;
					
						set @Loggmelding=(select 'Forsøker å legge inn eksisterende oppgjør i KONTERINGSOPPGJOERLINJELOGG tabell.');
						exec Super_Logg @Melding=@Loggmelding, @debug=@debug;
						
						begin try	-- Forsøker å legge inn eksisterende oppgjør i logg tabell.
							insert into super..KONTERINGSOPPGJOERLINJELOGG
										(ZNR
										,UTSALGSSTEDNR  
										,AVDELINGSNR  
										,DEBETKONTONR  
										,DEBETBELOEP  
										,KREDITKONTONR  
										,KREDITBELOEP  
										,MVAPROSENT
										,FRITEKST1
										,FRITEKST2
										,FRITEKST3
										,DATO 
										,REVISJON)
									select
										ZNR
										,UTSALGSSTEDNR  
										,AVDELINGSNR  
										,DEBETKONTONR  
										,DEBETBELOEP  
										,KREDITKONTONR  
										,KREDITBELOEP  
										,MVAPROSENT
										,FRITEKST1
										,FRITEKST2
										,FRITEKST3
										,DATO 
										,@revisjon
									from super..KONTERINGSOPPGJOERLINJE where znr=@znr
						END TRY
						BEGIN CATCH
							set @Loggmelding=(select 'Feilet ved innleggelse i logg tabell. Feilmelding: ' + ERROR_MESSAGE());
							exec Super_Logg @Melding=@Loggmelding, @debug = 1;						
						END CATCH
                        
						BEGIN TRY --Sletter oppgjør dersom det finnes fra før.
							delete from super..konteringsoppgjoer WHERE znr = @znr; 
							set @legginnoppgjoer = 1
						END TRY
						BEGIN CATCH
							set @Loggmelding=(select 'Feilet ved sletting av gammelt konteringsoppgjoer ' + ERROR_MESSAGE());
							exec Super_Logg @Melding=@Loggmelding, @debug = 1;
						END CATCH								
					END	--Ferdig med å legge inn endringsoppgjør
					ELSE
					BEGIN --Ingen endring i oppgjør
						set @Loggmelding=(select 'Ingen endring i oppgjør');
						exec Super_Logg @Melding=@Loggmelding, @debug=@debug;					
					END 
				END--Ferdig med  sjekk og lagt inn endringsoppgjør(ved endring)				  
			ELSE --Henter ZNR og setter @legginnoppgjoer til 1
				BEGIN 
					set @legginnoppgjoer = 1
					IF NOT EXISTS(SELECT * FROM super..konteringsoppgjoer) --Setter znr = 1 dersom det aldri er blitt generert et oppgjør.
						begin
							set @znr = 1;
						END          
					ELSE
						BEGIN 
							set @znr = (select isnull(max(znr), 0) + 1 from super..konteringsoppgjoer); 
						END
				END
						
			IF (@legginnoppgjoer = 1) 
				BEGIN -- skal kun legge inn oppgjør dersom det er et nytt oppgjør eller det er et endringsoppgjør
					begin try --Forsøker å legge inn konteringsoppgjoer og konteirngsoppgjoerlinje.
						insert into Super..KONTERINGSOPPGJOER --Legger inn konteringsoppgjoer
									( ZNR 
									, OPPGJOERFORETATT 
									, OPPGJOERFORDATO 
									, FOERSTESALG 
									, SISTESALG 
									, VIRKSOMHETSID 
									, OPPRETTET 
									, ENDRET 
									, XMLGENERERT 
									, GODKJENT 
									, SLETTET
									, REVISJON)
						values  ( @ZNR
									, CURRENT_TIMESTAMP
									, @dato
									, @foerstesalg 
									, @sistesalg 
									, @virkid 
									, CURRENT_TIMESTAMP
									, CURRENT_TIMESTAMP
									, NULL
									, NULL
									, NULL
									, @revisjon );					
						insert into super..KONTERINGSOPPGJOERLINJE --Legger inn konteringsoppgjoerlinje
									( ZNR 
									, UTSALGSSTEDNR 
									, AVDELINGSNR 
									, DEBETKONTONR 
									, DEBETBELOEP 
									, KREDITKONTONR 
									, KREDITBELOEP 
									, MVAPROSENT 
									, FRITEKST1 
									, FRITEKST2 
									, FRITEKST3 
									, DATO)
						select		@znr 
									, UTSALGSSTEDNR 
									, AVDELINGSNR 
									, DEBETKONTONR 
									, DEBETBELOEP 
									, KREDITKONTONR 
									, KREDITBELOEP 
									, MVAPROSENT 
									, FRITEKST1 
									, FRITEKST2 
									, FRITEKST3 
									, @dato
							from temp_konteringslinje;
						set @Loggmelding=(select 'Lagt inn '+ (select cast(count(*) as varchar(10)) from super..KONTERINGSOPPGJOERLINJE where znr = @znr) + ' linjer for konteringsoppgjor med znr:'+ Cast(@znr AS VARCHAR(20))); 
						exec Super_Logg @Melding=@Loggmelding;
					END TRY
					BEGIN  CATCH
						set @Loggmelding=(select 'Kontering feilet ' + error_message());
						exec Super_Logg @Melding=@Loggmelding, @debug = 1;      
					END CATCH
							                          
					BEGIN TRY --Forsøker å legge inn Kontering GENFELT data.											
						declare @UTSALGSSTEDNR as int;
						declare @BONG_KASSENR as int;
						declare @BONG_KASSERERNR as int;
						declare @BONGBETMIDSUM as int;
						declare @BETMIDOPPGJOERSUM as int;
						/*
							3100 = BONG.UTSALGSSTEDNR
							3101 = BONG.KASSENR
							3102 = BONG.KASSERERNR
							3103 = BONGBETMID.SUM(BELOEP)
							3104 = BETMIDOPPGJOER.SUM(BELOEP)

							3100, 3101 og 3102 brukes i XML / rapport
						*/								
						--Legger inn 3100 utsalgsstednr
						declare utsalgssteder cursor read_only fast_forward for select 
							distinct [utsalgsstednr]
						from temp_konteringslinje

						open utsalgssteder
						fetch next from utsalgssteder into @UTSALGSSTEDNR

						while (@@FETCH_STATUS = 0 )
							begin
								begin try
									insert into super..KONTERINGSOPPGJOERGENFELT
											( KONTERINGSOPPGJOERGENFELTID ,
												FELTNR ,
												ZNR ,
												VERDI1 ,
												FELTDATA1 ,
												FELTDATA2
											)
									values  ( (select isnull(max(KONTERINGSOPPGJOERGENFELTID), 0) + 1 from super..KONTERINGSOPPGJOERGENFELT) , -- KONTERINGSOPPGJOERGENFELTID - int
												3100, -- FELTNR - int 3100 til 31004
												@znr , -- ZNR - int
												cast(@UTSALGSSTEDNR as decimal) , -- VERDI1 - decimal
												(select cast(cast(gln as bigint) as varchar(13)) from super..UTSALGSSTED where UTSALGSSTEDNR = @UTSALGSSTEDNR) , -- FELTDATA1 - varchar(50)
												''  -- FELTDATA2 - varchar(50)
											)
								END TRY
								BEGIN CATCH
									set @Loggmelding = (select 'Kontering feilet ' + error_message());
									exec Super_Logg @Melding = @Loggmelding, @debug = 1;                 
								END CATCH                                      
								FETCH NEXT FROM utsalgssteder INTO @UTSALGSSTEDNR
							END 
						close utsalgssteder
						deallocate utsalgssteder
						
						--Legger inn 3101 Kassenr
						declare kassenr cursor read_only fast_forward
							for
								select distinct kassenr 
								from varesalg..bong 
								where datotid >= @fradato
									and datotid < @tildato
						open kassenr 
						fetch next from kassenr into @BONG_KASSENR

						while ( @@fetch_status = 0 )
							begin 
								begin try
									insert into super..KONTERINGSOPPGJOERGENFELT
											( KONTERINGSOPPGJOERGENFELTID ,
												FELTNR ,
												ZNR ,
												VERDI1 ,
												FELTDATA1 ,
												FELTDATA2
											)
									values  ( (select isnull(max(KONTERINGSOPPGJOERGENFELTID), 0) + 1 from super..KONTERINGSOPPGJOERGENFELT) , -- KONTERINGSOPPGJOERGENFELTID - int
												3101, -- FELTNR - int 3100 til 31004
												@znr , -- ZNR - int
												cast(@BONG_KASSENR as decimal) , -- VERDI1 - decimal
												cast(@BONG_KASSENR as varchar(5)) , -- FELTDATA1 - varchar(50)
												''  -- FELTDATA2 - varchar(50)
											)
								END TRY
								BEGIN CATCH
									set @Loggmelding = (select 'Kontering feilet ' + error_message());
									exec Super_Logg @Melding = @Loggmelding, @debug = 1;                 
								END CATCH
								FETCH NEXT FROM kassenr INTO @BONG_KASSENR                                      
							END
								
						close kassenr
						deallocate kassenr
								
						--Legger inne kasserernr 3102 @BONG_KASSERERNR                                 

						declare kasserernr cursor read_only fast_forward
							for
								select distinct kasserernr 
								from varesalg..bong 
								where DATOTID >= @fradato
									and DATOTID < @tildato								
						open kasserernr
						fetch next from kasserernr into @BONG_KASSERERNR
								
						while ( @@FETCH_STATUS = 0 )
							begin
								begin try
									insert into super..KONTERINGSOPPGJOERGENFELT
											( KONTERINGSOPPGJOERGENFELTID ,
												FELTNR ,
												ZNR ,
												VERDI1 ,
												FELTDATA1 ,
												FELTDATA2)
									values  ( (select isnull(max(KONTERINGSOPPGJOERGENFELTID), 0) + 1 from super..KONTERINGSOPPGJOERGENFELT) , -- KONTERINGSOPPGJOERGENFELTID - int
												3102, -- FELTNR - int 3100 til 31004
												@znr , -- ZNR - int
												cast(@BONG_KASSERERNR as decimal) , -- VERDI1 - decimal
												cast(@BONG_KASSERERNR as varchar(5)) , -- FELTDATA1 - varchar(50)
												''  -- FELTDATA2 - varchar(50)
											)                                      
								END TRY
								BEGIN CATCH
									set @Loggmelding=(select 'Kontering feilet ' + error_message());
									exec Super_Logg @Melding = @Loggmelding, @debug = 1;                                        
								END CATCH
								FETCH NEXT FROM kasserernr INTO @BONG_KASSERERNR                                      
							END
								
						close kasserernr
						deallocate kasserernr

						--Legger inn 3103 BONGBETMID.SUM(BELOEP)
						BEGIN TRY
							set @BONGBETMIDSUM = (select sum(bb.BELOEP) from varesalg..BONG b
													inner join varesalg..BONGBETMID bb
														on b.BONGID = bb.BONGID 
															and b.DATOTID >= @fradato
															and b.DATOTID < @tildato )
							insert into super..KONTERINGSOPPGJOERGENFELT
										( KONTERINGSOPPGJOERGENFELTID ,
											FELTNR ,
											ZNR ,
											VERDI1 ,
											FELTDATA1 ,
											FELTDATA2)
								values  ( (select isnull(max(KONTERINGSOPPGJOERGENFELTID), 0) + 1 from super..KONTERINGSOPPGJOERGENFELT) , -- KONTERINGSOPPGJOERGENFELTID - int
											3103, -- FELTNR - int 3100 til 31004
											@znr , -- ZNR - int
											cast(@BONGBETMIDSUM as decimal) , -- VERDI1 - decimal
											cast(@BONGBETMIDSUM as varchar(50)) , -- FELTDATA1 - varchar(50)
											''  -- FELTDATA2 - varchar(50)
										)                              
						END TRY
						BEGIN CATCH
							set @Loggmelding=(select 'Kontering feilet ' + error_message());
							exec Super_Logg @Melding=@Loggmelding, @debug = 1;
						END CATCH
								
						--Legger inn 3104 BONGBETMID.SUM(BELOEP) @BETMIDOPPGJOERSUM
						BEGIN TRY
							SET @BETMIDOPPGJOERSUM = (	SELECT SUM(OMSETNING) 
														FROM super..BETMIDOPPGJOER 
														WHERE znr IN(
															SELECT znr 
															FROM super..KASSEREROPPGJOER 
															WHERE OPPGJOERFORDATO = CAST(@fradato AS DATE)))

							INSERT INTO super..KONTERINGSOPPGJOERGENFELT
										( KONTERINGSOPPGJOERGENFELTID ,
											FELTNR ,
											ZNR ,
											VERDI1 ,
											FELTDATA1 ,
											FELTDATA2)
								VALUES  ( (SELECT ISNULL(MAX(KONTERINGSOPPGJOERGENFELTID), 0) + 1 FROM super..KONTERINGSOPPGJOERGENFELT) , -- KONTERINGSOPPGJOERGENFELTID - int
											3104, -- FELTNR - int 3100 til 31004
											@znr , -- ZNR - int
											CAST(@BETMIDOPPGJOERSUM AS DECIMAL) , -- VERDI1 - decimal
											CAST(@BETMIDOPPGJOERSUM AS VARCHAR(50)) , -- FELTDATA1 - varchar(50)
											''  -- FELTDATA2 - varchar(50)
										)                              
						END TRY
						BEGIN CATCH
							SET @Loggmelding=(SELECT 'Kontering feilet ' + ERROR_MESSAGE());
							EXEC Super_Logg @Melding=@Loggmelding, @debug = 1;   
						END CATCH                         
					END TRY
					BEGIN CATCH
						SET @Loggmelding=(SELECT 'Kontering feilet ' + ERROR_MESSAGE() + '. Klarte ikke å legge inn data i KONTERINGSOPPGJOERGENFELT tabellen.');
						EXEC Super_Logg @Melding=@Loggmelding, @debug = 1;
					END CATCH 
			
				END --Ferdig med å legge inn oppgjoer.
				
			--§§§ Godkjenning				
			EXEC varesalg..Kontering_Godkjenning @znr = @znr;					
			SET @Loggmelding=(SELECT 'Kontering ferdig for dato: ' + CONVERT(VARCHAR, @dato , 104) + ' med znr=' + CAST(@znr AS VARCHAR(20))); 
			EXEC Super_Logg @Melding=@Loggmelding, @debug = 1;
			
		END --Ferdig med kontering

	SELECT * FROM super..KONTERINGSOPPGJOERLINJE WHERE znr = @znr; --Viser konteringsoppgjøret	
    
END

GO


