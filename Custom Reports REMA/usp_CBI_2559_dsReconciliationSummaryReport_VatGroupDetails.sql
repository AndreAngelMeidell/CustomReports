USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_VatGroupDetails]    Script Date: 07.02.2020 10:39:53 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   PROCEDURE [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_VatGroupDetails]     
(
@StoreId AS VARCHAR(100),
@Date AS DATETIME 
)
AS  
BEGIN 

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	IF (@Date IS NULL)
	BEGIN
		SELECT TOP(0) 1 
	END

	DECLARE @IncludeInReportsCurrentStoreOnly INT =	(
		SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
		WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
		);
	SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); 

	Declare @StoreIdx int


	-- Gather stores into temp table based on @IncludeInReportsCurrentStoreOnly parameter
	DROP TABLE IF EXISTS #Stores
		SELECT StoreIdx			-- RS-40526
		INTO #Stores
		FROM RBIM.Dim_Store
		WHERE (StoreId = @StoreId AND (@IncludeInReportsCurrentStoreOnly = 0 OR (@IncludeInReportsCurrentStoreOnly = 1 AND IsCurrentStore = 1)))

	DECLARE @DateIdx int = cast(convert(varchar(8),@Date, 112) as int)

	IF NOT EXISTS (
					SELECT TOP 1 RowIdx FROM RBIM.Fact_ReconciliationSystemTotalPerAccumulationType a
						JOIN #Stores ds ON a.StoreIdx = ds.StoreIdx
					WHERE 
						ReconciliationDateIdx = @DateIdx				
					)
	BEGIN
		SELECT TOP(0) 1 -- {RS-36795} no need to show vat information, because there are no approved reconciliations for that day
	END
	ELSE BEGIN			 
	-- 19.02.2016: Returns details about reconciliation that have been counted
	--					Not counted reconciliations is not present in the DWH now.
		-----------------------------------------
	
	IF(select count(distinct StoreIdx) from RBIM.Agg_VatGroupSalesAndReturnPerDay where StoreIdx in (select StoreIdx from #Stores) and ReceiptDateIdx = @DateIdx) = 1
		BEGIN
			set @StoreIdx = (select distinct StoreIdx from RBIM.Agg_VatGroupSalesAndReturnPerDay where StoreIdx in (select StoreIdx from #Stores) and ReceiptDateIdx = @DateIdx)
			SELECT 
				agg.VatGroup
				,SUM(agg.SalesAmount + agg.ReturnAmount) AS SalesAmount
				,SUM(agg.SalesVatAmount + agg.ReturnVatAmount) AS SalesVatAmount
				,SUM(agg.SalesAmountExclVat + agg.ReturnAmountExclVat) AS SalesAmountExclVat
			FROM RBIM.Agg_VatGroupSalesAndReturnPerDay agg
			WHERE	
				agg.StoreIdx = @StoreIdx
				AND	agg.ReceiptDateIdx = @DateIdx
			GROUP BY agg.VatGroup
		END
	ELSE
		BEGIN
			SELECT 
				agg.VatGroup
				,SUM(agg.SalesAmount + agg.ReturnAmount) AS SalesAmount
				,SUM(agg.SalesVatAmount + agg.ReturnVatAmount) AS SalesVatAmount
				,SUM(agg.SalesAmountExclVat + agg.ReturnAmountExclVat) AS SalesAmountExclVat
			FROM RBIM.Agg_VatGroupSalesAndReturnPerDay agg
			INNER JOIN #Stores ds ON ds.StoreIdx = agg.StoreIdx
			WHERE	
				agg.ReceiptDateIdx = @DateIdx
			GROUP BY agg.VatGroup
		END


	
	END

	-- Clean temp table cache after general dataset is selected 

	DROP TABLE IF EXISTS #Stores

END 



GO

