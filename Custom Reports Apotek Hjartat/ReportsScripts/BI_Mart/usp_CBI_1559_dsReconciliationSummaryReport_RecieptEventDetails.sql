USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_RecieptEventDetails]    Script Date: 10/3/2019 11:36:49 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE   PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_RecieptEventDetails] 
(
	@StoreId AS VARCHAR(100),
	@Date AS DATETIME )
AS  
BEGIN

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


	IF (@Date IS NULL)
	BEGIN
		SELECT TOP(0) 1 -- {RS-34990} initial load report improvement
	END
	ELSE BEGIN  
	-- 19.02.2016: Returns details about reconciliation that have been counted
	--					Not counted reconciliations is not present in the DWH now.
	  -----------------------------------------
		DECLARE @DateIdx int = cast(convert(varchar(8),@Date, 112) as integer)

	   	DECLARE @IncludeInReportsCurrentStoreOnly INT = (
		SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
		WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
		);
		SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); 
		
		-- Gather stores into temp table based on @IncludeInReportsCurrentStoreOnly parameter
		DROP TABLE IF EXISTS #Stores
			SELECT StoreIdx
			INTO #Stores
			FROM RBIM.Dim_Store
			WHERE StoreId = @StoreId AND (@IncludeInReportsCurrentStoreOnly=0 OR (@IncludeInReportsCurrentStoreOnly=1 AND IsCurrentStore = 1))


		-- Kassalådeöppningar
		SELECT 
			ach.ReceiptDateIdx AS Datum
			,ach.StoreIdx
			,'Kassalådeöppningar' AS InformationType
			,SUM(ISNULL(ach.NumberOfDrawerOpenings, 0)) AS Quantity
			,0 AS Amount
		FROM RBIM.Agg_CashierSalesAndReturnPerHour ach
		INNER JOIN #Stores ds ON ds.StoreIdx = ach.StoreIdx 
		WHERE ach.ReceiptDateIdx = @DateIdx 
		GROUP BY ach.ReceiptDateIdx ,ach.StoreIdx

		UNION

		-- Manuell rabatt och Återköp butik
		-- 6 = Discount (Manuell rabatt)
		-- 11 = Return (Återköp butik)
		SELECT 
			fa.ReconciliationDateIdx AS Datum
			,fa.StoreIdx
			,CASE WHEN fa.AccumulationTypeIdx = 6
				THEN 'Manuell rabatt' 
				WHEN fa.AccumulationTypeIdx = 11
				THEN 'Återköp butik'
			END AS InformationType
			,SUM(ISNULL(fa.[Count], 0)) AS Quantity
			,SUM(ISNULL(fa.Amount, 0)) AS Amount
		FROM RBIM.Fact_ReconciliationSystemTotalPerAccumulationType fa
		INNER JOIN #Stores ds ON ds.StoreIdx = fa.StoreIdx 
		WHERE fa.ReconciliationDateIdx = @DateIdx
			AND fa.AccumulationTypeIdx IN (6, 11) 
		GROUP BY 
			fa.ReconciliationDateIdx
			,fa.StoreIdx
			,fa.AccumulationTypeIdx

		UNION

		-- Återköp e-handel
		SELECT 
			asd.ReceiptDateIdx AS Datum
			,asd.StoreIdx
			,'Återköp e-handel' AS InformationType
			,SUM(ISNULL(asd.NumberOfReceiptsWithReturn, 0)) AS Quantity
			,SUM(ISNULL(-asd.ReturnAmount, 0)) AS Amount
		FROM RBIM.Agg_SalesAndReturnPerDay asd
		INNER JOIN #Stores ds ON ds.StoreIdx = asd.StoreIdx 
		WHERE asd.ReceiptDateIdx = @DateIdx
			AND asd.CustomerIdx = 10
		GROUP BY 
			asd.ReceiptDateIdx, 
			asd.StoreIdx

		UNION

		-- Makulerade kvitton och Rättelser
		SELECT 
			fr.ReceiptDateIdx AS Datum
			,fr.StoreIdx
			,CASE WHEN fr.ArticleCorrectedByCashier = 0
				THEN 'Makulerade kvitton' 
				ELSE 'Rättelser'
			END AS InformationType
			,COUNT(fr.ArticleCorrectedByCashier) AS Quantity
			,SUM(ISNULL(fr.Amount, 0)) AS Amount
		FROM RBIM.Fact_Receipt fr
		INNER JOIN #Stores ds ON ds.StoreIdx = fr.StoreIdx 
		WHERE fr.ReceiptDateIdx = @DateIdx
			AND fr.ReceiptStatusIdx = 2 -- 2 = Avbruten
			AND fr.PriceTypeIdx <> -1 -- 1 = N/A
		GROUP BY 
			fr.ReceiptDateIdx
			,fr.StoreIdx
			,fr.ArticleCorrectedByCashier

		
		-- Clean temp table cache after general dataset is selected 
		DROP TABLE IF EXISTS #Stores
	  	
	END
END 
GO


