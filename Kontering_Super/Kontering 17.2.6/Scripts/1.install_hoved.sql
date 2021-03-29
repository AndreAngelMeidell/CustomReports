/*
	Skript for installasjon av kontering

	Denne må kjøres i SQLCMD Mode! (Startes fra kontering.exe -LESINNOPPSETT)

	NB! Kontering.exe leser konteringsversjon nr under
	og sjekker versjonensnr mot parametere tabellen sin
	KONTERINGVERSJON og kjører kun dersom  KONTERINGVERSJON <= konteringsversjon.
	parametere tabell versjons oppdateres i bunnen av dette scriptet.
	
	konteringsversjon = 17.2.6

*/
		:setvar version '17.2.6'
		:setvar path "C:\Super\Konteringsoppgjoer\Scripts"
		--:setvar path "C:\tfs\VRNO\RetailSuite\Main\Kontering\Kontering.Super\Scripts"
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon Starter.', 0, 1)
		:r $(path)\proc_super_logg.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_super_logg ble lagt inn.', 0, 1)		
		--§§§§ Parametere & --§§§§ Konteringskonto
		:r $(path)\kontering_oppsett.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - Oppsett.sql Skript fil ble kjørt.', 0, 1)
		--§§§§ Prosedyrer		
		:r $(path)\proc_kontering_godkjenning.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering_godkjenning ble lagt inn.', 0, 1)
		:r $(path)\proc_kontering_konter.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering_konter ble lagt inn.', 0, 1)
		:r $(path)\proc_kontering.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering ble lagt inn.', 0, 1)
		:r $(path)\proc_kontering_konter_betalingsmidler.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering_konter_betalingsmidler ble lagt inn.', 0, 1)
		:r $(path)\proc_kontering_konter_bib.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering_konter_bib ble lagt inn.', 0, 1)
		:r $(path)\proc_kontering_konter_oreavrunding.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering_konter_oreavrunding ble lagt inn.', 0, 1)
		:r $(path)\proc_kontering_konter_pant.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering_konter_pant ble lagt inn.', 0, 1)
		:r $(path)\proc_kontering_konter_provision.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering_konter_provision ble lagt inn.', 0, 1)
		:r $(path)\proc_kontering_konter_varesalg.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering_konter_varesalg ble lagt inn.', 0, 1)
		:r $(path)\proc_kontering_konter_kundegarantier.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering_konter_kundegarantier ble lagt inn.', 0, 1)	
		:r $(path)\proc_kontering_konter_FlaxAktivering.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - proc_kontering_konter_FlaxAktivering ble lagt inn.', 0, 1)	
		:r $(path)\kontering_oppsett.sql
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon - Oppsett.sql Skript fil ble kjørt.', 0, 1)
		
		--Setter ny versjon
		update super..PARAMETERE set VERDI = $(version) where navn='KONTERINGVERSJON';
		insert into super..logg  values (1, Getdate(), 28, 'Kontering Installasjon: Instalert versjon ' + $(version), 0, 1)	
		
go