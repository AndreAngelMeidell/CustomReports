USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_RBI_dsAccountingReport]    Script Date: 06.05.2021 09:34:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

 
CREATE PROCEDURE [dbo].[usp_RBI_dsAccountingReport]    
(
	@StoreId as varchar(100),
	@PeriodType as char(1), 
	@DateFrom as datetime, 
	@YearToDate as integer, 
	@RelativePeriodType as char(5), 
	@RelativePeriodStart as integer, 
	@RelativePeriodDuration as integer)
AS  
BEGIN
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
   
IF (@DateFrom IS NULL)
BEGIN
	SELECT TOP(0) 1 -- {RS-34990} initial report load improvement
END
ELSE BEGIN    
	DECLARE  @AccountingExportSetupVersion varchar(5) = 2 /*default*/
	SET @AccountingExportSetupVersion = (SELECT TOP 1 Value FROM  [BI_Export].[RBIE].AccountingExportParameters WHERE ParameterName='AccountingExportSetupVersion')

	IF (@AccountingExportSetupVersion = 1)
	SELECT 
		-- Accounting V1 configuration based select 
	    -- Mandatory -------------------------------------------------------------------------------------------------
		 ds.StoreId, ds.StoreName 
		,dd.Year, dd.YearHalfYear, dd.YearQuarter, dd.YearMonthNumber, dd.YearWeekNumber, dd.FullDate 
		,dt.HourPeriod
		--------------------------------------------------------------------------------------------------------------
		,acl.SettlementDate			AS Date						-- KONTERINGSOPPGJOERLINJE.DATO
		,acl.SalesLocationNumber	AS SalesLocationNumber		-- KONTERINGSOPPGJOERLINJE.UTSALGSSTEDNR
		,sl.CardName				AS SalesLocationName		-- UTSALGSSTED.UTSALGSSTEDNAVN
		,acl.DepartmentNumber		AS DepartmentNumber			-- KONTERINGSOPPGJOERLINJE.AVDELINGSNR
		,''							AS DepartmentName			-- AVDELING.AVDELINGSNAVN
		,acl.DebitAccountNumber		AS DebitAccount				-- KONTERINGSOPPGJOERLINJE.DEBETKONTONR
		,adb.AccountName			AS DebitAccountName			-- KONTERINGSKONTO.NAVN
		,acl.DebitAmount			AS DebitAmount				-- KONTERINGSOPPGJOERLINJE.DEBETBELOEP
		,acl.CreditAccountNumber	AS CreditAccount			-- KONTERINGSOPPGJOERLINJE.KREDITKONTONR
		,acr.AccountName			AS CreditAccountName		-- KONTERINGSKONTO.NAVN
		,acl.CreditAmount			AS CreditAmount				-- KONTERINGSOPPGJOERLINJE.KREDITBELOEP
		,acl.VatRate				AS VatRate					-- KONTERINGSOPPGJOERLINJE.MVAPROSENT
		,acl.Dimension1				AS FreeText1				-- KONTERINGSOPPGJOERLINJE.FRITEKST1
		,acl.Dimension2				AS FreeText2				-- KONTERINGSOPPGJOERLINJE.FRITEKST2
		,acl.Dimension3				AS FreeText3				-- KONTERINGSOPPGJOERLINJE.FRITEKST3
		--parameters--------------------------------------------------------------------------------------------------
		,acc.FirstSaleDateTime		AS FirstReconciliationTransaction	-- KONTERINGSOPPGJOER.FOERSTESALG
		,acc.LastSaleDateTime		AS LastReconciliationTransaction	-- KONTERINGSOPPGJOER.SISTESALG
		,ss.PublicOrganizationNumber AS OrganizationNumber				-- SYSTEMOPPSETT.FORETAKSNR
		,ss.LegalName                AS OrganizationName				-- 
		,acc.ZNR                    AS ReconciliationNumber				-- Information stage
		,acc.SettlementDate         AS ReconciliationTime				-- Information stage
		,ss.StoreId					AS StoreNumber						-- SYSTEMOPPSETT.BUTIKKNR
		,ss.GlobalLocationNo		AS LocationNumber					-- SYSTEMOPPSETT.EANLOKASJONSNR

	FROM BI_Export.rbie.Leg_AccountingSettlement as Acc -- KONTERINGSOPPGJOER
	INNER JOIN BI_Export.rbie.Leg_AccountingSettlementLine as Acl ON Acl.StoreId = Acc.StoreId AND Acl.ZNR = Acc.ZNR -- KONTERINGSOPPGJOERLINJE
	INNER JOIN BI_Export.rbie.Leg_StoreSetup as ss ON ss.StoreId = Acc.StoreId -- SYSTEMOPPSETT
	--LEFT JOIN BI_Export.rbie.Leg_AccountingAccount as acr ON acr.StoreId = acl.StoreId and acr.AccountNumber = acl.CreditAccountNumber --KONTERINGSKONTO
	LEFT JOIN (
		select StoreId, AccountNumber, MAX(AccountName) as AccountName 
		from BI_Export.rbie.Leg_AccountingAccount 
		group by StoreId, AccountNumber) as acr ON (acr.StoreId = acl.StoreId or acr.StoreId = -1) and acr.AccountNumber = acl.CreditAccountNumber
	--LEFT JOIN BI_Export.rbie.Leg_AccountingAccount as adb ON adb.StoreId = acl.StoreId and adb.AccountNumber = acl.DebitAccountNumber  --
	LEFT JOIN (
		select StoreId, AccountNumber, MAX(AccountName) as AccountName 
		from BI_Export.rbie.Leg_AccountingAccount 
		group by StoreId, AccountNumber) as adb ON (adb.StoreId = acl.StoreId or adb.StoreId = -1) and adb.AccountNumber = acl.DebitAccountNumber
	LEFT JOIN BI_Export.rbie.Leg_SalesLocation AS sl ON sl.StoreId = Acc.StoreId -- UTSALGSSTED
	-- AVDELING
	JOIN rbim.Dim_Date dd on dd.FullDate = CAST(acl.SettlementDate AS DATE) -- Mandatory
	JOIN rbim.Dim_Time dt on dt.TimeDescription = LEFT(CAST(CAST(acl.SettlementDate AS TIME(0)) AS VARCHAR(10)), 5) -- Mandatory if @RelativePeriodType = 'H'
	JOIN rbim.Dim_Store ds on ds.storeid = ss.storeid and ds.iscurrent = 1 -- Mandatory
	-- MANDATORY filter on store or storegroup
	WHERE ss.StoreId = @StoreId
	-- MANDATORY filter on period
	AND (
		(@PeriodType='D' AND dd.FullDate = @DateFrom)
		OR (@PeriodType='R' AND @RelativePeriodType = 'D' AND dd.RelativeDay = @RelativePeriodStart)
		)
	AND ds.isCurrentStore = 1  
	-- Accounting V2 Configuration based select 
	ELSE IF (@AccountingExportSetupVersion = 2)
	SELECT 
	    -- Mandatory --------------------------------------------------------------------------------------------
		 ds.StoreId, ds.StoreName -- 
		,dd.Year, dd.YearHalfYear, dd.YearQuarter, dd.YearMonthNumber, dd.YearWeekNumber, dd.FullDate 
		,dt.HourPeriod
		----------------------------------------------------------------------------------------------------------
		,acl.SettlementDate			AS [Date]					-- KONTERINGSOPPGJOERLINJE.DATO
		,acl.SalesLocationNumber    AS SalesLocationNumber	    -- KONTERINGSOPPGJOERLINJE.UTSALGSSTEDNR
		,dv.DimensionValueName	    AS SalesLocationName		-- UTSALGSSTED.UTSALGSSTEDNAVN
		,acl.DepartmentNumber		AS DepartmentNumber			-- KONTERINGSOPPGJOERLINJE.AVDELINGSNR
		,''						    AS DepartmentName			-- AVDELING.AVDELINGSNAVN
		,acl.DebitAccountNumber		AS DebitAccount				-- KONTERINGSOPPGJOERLINJE.DEBETKONTONR
		,adb.AccountName			AS DebitAccountName			-- KONTERINGSKONTO.NAVN
		,SUM(acl.DebitAmountLCY)	AS DebitAmount				-- KONTERINGSOPPGJOERLINJE.DEBETBELOEP
		,acl.CreditAccountNumber	AS CreditAccount			-- KONTERINGSOPPGJOERLINJE.KREDITKONTONR
		,acr.AccountName			AS CreditAccountName		-- KONTERINGSKONTO.NAVN
		,SUM(acl.CreditAmountLCY)	AS CreditAmount				-- KONTERINGSOPPGJOERLINJE.KREDITBELOEP
		,acl.VatRate				AS VatRate					-- KONTERINGSOPPGJOERLINJE.MVAPROSENT
		,acl.FreeText1				AS FreeText1				-- KONTERINGSOPPGJOERLINJE.FRITEKST1
		,acl.FreeText2				AS FreeText2				-- KONTERINGSOPPGJOERLINJE.FRITEKST2
		,acl.FreeText3				AS FreeText3				-- KONTERINGSOPPGJOERLINJE.FRITEKST3
		--parameters---------------------------------------------------------------------------------------------
		,acc.FirstSaleDateTime		  AS FirstReconciliationTransaction	-- KONTERINGSOPPGJOER.FOERSTESALG
		,acc.LastSaleDateTime	      AS LastReconciliationTransaction	-- KONTERINGSOPPGJOER.SISTESALG
		,acl.PublicOrganizationNumber AS OrganizationNumber				-- SYSTEMOPPSETT.FORETAKSNR
		,ss.StoreId+'-'+ss.StoreName  AS OrganizationName				-- 
		,acc.ZNR                      AS ReconciliationNumber			-- Information stage
		,acc.SettlementDate           AS ReconciliationTime				-- Information stage
		,ss.StoreId					  AS StoreNumber					-- SYSTEMOPPSETT.BUTIKKNR
		,acl.GlobalLocationNumber	  AS LocationNumber					-- SYSTEMOPPSETT.EANLOKASJONSNR
	FROM [BI_Export].[RBIE].[Leg_AccountingSettlement] as Acc 
		JOIN [BI_Export].[CBIE].[RBI_AccountingExportDataInterface] as Acl ON Acl.StoreId = Acc.StoreId AND Acl.ZNR = Acc.ZNR 
		JOIN [RBIM].[Dim_Store] as ss ON ss.StoreIdx = Acl.StoreIdx 
		LEFT  JOIN  [BI_Export].[dbo].[AccountingAccounts] acr ON acr.[AccountId]=cast(acl.CreditAccountNumber as varchar(50))
		LEFT  JOIN  [BI_Export].[dbo].[AccountingAccounts] adb ON adb.[AccountId]=cast(acl.DebitAccountNumber as varchar(50))
		LEFT  JOIN  [BI_Export].[dbo].[DimensionValues] dv ON dv.[DimensionValueId]=acl.[SalesLocationNumber] AND [DimensionTypeNo]=1 /*SalesLocation*/
		JOIN [RBIM].Dim_Date dd on dd.FullDate = CAST(acl.SettlementDate AS DATE) 
		JOIN [RBIM].Dim_Time dt on dt.TimeDescription = LEFT(CAST(CAST(acl.SettlementDate AS TIME(0)) AS VARCHAR(10)), 5) 
    	JOIN [RBIM].Dim_Store ds on ds.storeid = ss.storeid and ds.iscurrent = 1 
	WHERE ss.StoreId = @StoreId
	AND (
		(@PeriodType='D' AND dd.FullDate = @DateFrom)
		OR (@PeriodType='R' AND @RelativePeriodType = 'D' AND dd.RelativeDay = @RelativePeriodStart)
		)
	AND ds.isCurrentStore = 1  
	GROUP BY
		 ds.StoreId, ds.StoreName ,dd.Year, dd.YearHalfYear, dd.YearQuarter, dd.YearMonthNumber, dd.YearWeekNumber, dd.FullDate 
		,dt.HourPeriod
		,acl.SettlementDate			
		,acl.SalesLocationNumber	   
		,dv.DimensionValueName	     
		,acl.DepartmentNumber		
		,acl.DebitAccountNumber		
		,adb.AccountName			
		,acl.CreditAccountNumber	
		,acr.AccountName			
		,acl.VatRate				
		,acl.FreeText1				
		,acl.FreeText2				
		,acl.FreeText3				
		,acc.FirstSaleDateTime		
		,acc.LastSaleDateTime	     
		,acl.PublicOrganizationNumber 
		,ss.StoreId
		,ss.StoreName  
		,acc.ZNR                      
		,acc.SettlementDate          
		,ss.StoreId					
		,acl.GlobalLocationNumber
END
END

GO

