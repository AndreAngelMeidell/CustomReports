use VARESALG
set ansi_nulls on
go
set quoted_identifier on
go
-- =============================================
-- Author:		VR Konsulent
-- Create date: 	06 2013
-- Version:		17.2.6
-- Description:		Prosedyre for å godkjenning av konteringsoppgjør - Input ZNR.
-- =============================================

if exists(select * from sys.procedures where name = 'Kontering_godkjenning')
begin 
	drop procedure Kontering_godkjenning;	
end
go

create procedure Kontering_godkjenning	
	@znr as int
as
begin	
	set nocount on;

	declare @Loggmelding as varchar(300);	
	declare @godkjent as int; --Sjekker om oppgjøret godkjent fra før.
		
	set @godkjent = (select count(*) from super..konteringsoppgjoer where znr = @znr and GODKJENT is null);
				
	if (@godkjent > 0) 
		begin --Starter logikk for å godkjenne oppgjør.
			
			--§§§ Dognforskyvning håndtering
			begin try --#Region for Dognforskyvning logikk. 
				declare @Dognforskyvning as int; 
				declare @dato as date;	
				declare @fradato as datetime;
				declare @tildato as datetime;

				set @Dognforskyvning = (select cast(isnull(verdi,0) as int) from super..PARAMETERE where navn = 'DOGNFORSKYVNING');
				set @dato = (select cast(OPPGJOERFORDATO as date) from super..KONTERINGSOPPGJOER where znr = @znr);			
				set @fradato = @dato;
				set @fradato = dateadd(hour,@Dognforskyvning,@fradato);			
				set @tildato = @fradato + 1;
			end try
			begin catch
				set @Loggmelding=(select 'Kontering feilet ' + error_message());
				exec Super_Logg @Melding=@Loggmelding, @debug = 1; 
			end catch --#Region Slutt.
			
			begin try --Region for Utregninger og sjekker 
				declare @diffKontering as decimal (18 ,2) 			
				declare @diffBongOppgjor decimal (18 ,2)
				declare @sjekkKassereroppgjoer as decimal (18 ,2);
				declare @sjekkFritekst1 as int;

				set @diffKontering = (	select 
											sum(isnull(debetbeloep,0)) - sum(isnull(kreditbeloep,0)) as diff
										from super..KONTERINGSOPPGJOERLINJE 
										where znr=@znr)

				--§§§ sjekk om summen av betalingsmidler i bong og kassereroppgjør er lik					
				set @diffBongOppgjor = ((	select 
												sum(isnull(beloep,0))
											from BONGBETMID bb 
											inner join BONG b on (bb.BONGID=b.BONGID 
												and b.DATOTID>=@fradato 
												and b.DATOTID<@tildato))
										- (select 
												sum(isnull(BELOEP,0))
											from Super..BETMIDOPPGJOER kb 
											inner join super..kassereroppgjoer k on (k.ZNR=kb.znr
												and k.OPPGJOERFORDATO=@dato))
										);					
				set @sjekkKassereroppgjoer = (	select 
													sum(isnull(BELOEP,0))
												from Super..BETMIDOPPGJOER kb 
												inner join super..kassereroppgjoer k on k.ZNR=kb.znr 
													and k.OPPGJOERFORDATO=@dato)			
				/*
					--§§§ Logikk for å sjekke at alle konteringslinjer har "Fritekst1"
					-- grunnet at vi nå har linket fritekst1 feltet mot konteringskonto tabellen
					-- og hvis vi da har feil oppsett så sender vi blank fritekst1 og da igjen vil 
					-- oppgjør bli avvis på bongrampa. 
				*/
				set @sjekkFritekst1 = (select count(*) from super..konteringsoppgjoerlinje where znr = @znr and fritekst1 is null);			

			end try
			begin catch
				set @Loggmelding=(select 'Kontering feilet ' + error_message());
				exec Super_Logg @Melding=@Loggmelding, @debug = 1; 
			end catch --#Region slutt.
			          
			if ((@diffKontering  = 0.00) and (@diffBongOppgjor = 0.00) and (@sjekkFritekst1 = 0))
				begin --Godkjenner oppgjør!
					begin try
						update Super..KONTERINGSOPPGJOER set GODKJENT = getdate() where znr=@znr;
						set @Loggmelding = (select 'Konteringsoppgjoer ble godkjent.');
						exec dbo.Super_Logg @Melding = @Loggmelding, @debug = 1;				
					end try
					begin catch
						set @Loggmelding=(select 'Kontering feilet. Feilmelding: ' + error_message());
						exec Super_Logg @Melding=@Loggmelding, @debug = 1;                   
					end catch                  
				end				
			else 
				begin --Oppgjoer ikke godkjent. 
					if (@diffKontering  != 0.00)
						begin 				
							set @Loggmelding = (select 'Konteringsoppgjoer ble IKKE godkjent. Diff = '+ cast(@diffKontering  as varchar(10)) + '. (Debet - Kredit)');
							exec dbo.Super_Logg @Melding = @Loggmelding, @debug = 1;
						end
					else if (@diffBongOppgjor != 0.00) 
						begin 
							set @Loggmelding = (select 'Konteringsoppgjoer ble IKKE godkjent. Bong og Kassereroppgjør er ikke like. Diff = '+ cast(@diffBongOppgjor as varchar(10)) + '. BONG - OPPGJOER');
							exec dbo.Super_Logg @Melding = @Loggmelding, @debug = 1;
						end
					else if (@sjekkFritekst1 != 0)
						begin 
							declare @kontonr_mangler_fritekst1 as varchar(20);
							set @kontonr_mangler_fritekst1 = (select case	
																		when max(debetkontonr) is null then max(kreditkontonr)
																		else max(debetkontonr)
																	end as kontonr
																from super..konteringsoppgjoerlinje
																where znr = @znr
																	and fritekst1 is null)
							set @Loggmelding = (select 'Konteringsoppgjoer ble IKKE godkjent da kontonr ' + @kontonr_mangler_fritekst1 + ' mangler fritekst1');
							exec dbo.Super_Logg @Melding = @Loggmelding, @debug = 1;
						end
					else if (@sjekkKassereroppgjoer is null)--Kasserer oppgjør mangler
						begin
							set @Loggmelding = (select 'Konteringsoppgjoer ble IKKE godkjent grunnet at kassereroppgjoer mangler.');
							exec dbo.Super_Logg @Melding = @Loggmelding, @debug = 1;
						end					                      
					else
						begin
							set @Loggmelding = (select 'Konteringsoppgjoer ble IKKE godkjent. Ukjent grunn.');
							exec dbo.Super_Logg @Melding = @Loggmelding, @debug = 1;                          
						end                      
				end	--Finner hvilken sjekk som feiler og logger til Super LOGG tabell
		end	--Ferdig med logikk for å godkjenne oppgjør.
	else
		begin --Oppgjoer allerede godkjent.
			set @Loggmelding=(select 'Oppgjoer allerede godkjent. ZNR='+cast(@znr as varchar(20))); 
			exec Super_Logg @Melding=@Loggmelding;
		end	--Logger til Super LOGG tabell.	
end
go
