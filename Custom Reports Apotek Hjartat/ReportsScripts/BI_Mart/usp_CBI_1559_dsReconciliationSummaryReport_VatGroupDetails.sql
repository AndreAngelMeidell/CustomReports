USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_VatGroupDetails]    Script Date: 10/3/2019 11:35:55 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE  PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_VatGroupDetails] 
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


	DECLARE @StoreIdx int
	SET @StoreIdx = (SELECT StoreIdx 
						FROM RBIM.Dim_Store
						WHERE StoreId = @StoreId 
						AND (@IncludeInReportsCurrentStoreOnly=0 OR (@IncludeInReportsCurrentStoreOnly=1 AND IsCurrentStore = 1))
						AND isCurrent = 1
						)

	DECLARE @DateIdx int = cast(convert(varchar(8),@Date, 112) as int)

	BEGIN			 
	-- 19.09.2019: Returns details about reconciliation that have been counted
	--					Not counted reconciliations is not present in the DWH now.
		-----------------------------------------
	SELECT 
		CASE 
			WHEN agg.VatGroup = 0 THEN '0 %'
			WHEN agg.VatGroup = 6 THEN '6 %'
			WHEN agg.VatGroup = 12 THEN '12 %'
			WHEN agg.VatGroup = 25 THEN '25 %'
		END AS TypeName
		,SUM(agg.SalesAmount + agg.ReturnAmount) AS SalesAmount
		,SUM(agg.SalesVatAmount + agg.ReturnVatAmount) AS SalesVatAmount
		,SUM(agg.SalesAmountExclVat + agg.ReturnAmountExclVat) AS SalesAmountExclVat
	FROM RBIM.Agg_VatGroupSalesAndReturnPerDay agg
	WHERE	
		agg.ReceiptDateIdx = @DateIdx
		AND agg.StoreIdx = @StoreIdx
	GROUP BY agg.VatGroup

	UNION
	
	SELECT 
		'Avrundning' AS TypeName
		,SUM(RoundingAmount) AS SalesAmount
		,NULL AS SalesVatAmount
		,NULL AS SalesAmountExclVat
	FROM RBIM.Agg_VatGroupSalesAndReturnPerDay agg
	WHERE	
		agg.ReceiptDateIdx = @DateIdx
		AND agg.StoreIdx = @StoreIdx

	ORDER BY 1

	END
END 


