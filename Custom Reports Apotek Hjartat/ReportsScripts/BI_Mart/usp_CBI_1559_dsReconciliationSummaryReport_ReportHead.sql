USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_ReportHead]    Script Date: 10/3/2019 11:27:22 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE   PROCEDURE [dbo].[usp_CBI_1559_dsReconciliationSummaryReport_ReportHead] 
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
	-- 18.09.2016: Returns details about reconciliation that have been counted
	--					Not counted reconciliations is not present in the DWH now.
	  -----------------------------------------
		DECLARE @DateIdx int = cast(convert(varchar(8),@Date, 112) as integer)

	   	DECLARE @IncludeInReportsCurrentStoreOnly INT = (
		SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
		WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
		);
		SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); 
		
		DECLARE @StoreIdx int
		SET @StoreIdx = (SELECT StoreIdx 
							FROM RBIM.Dim_Store
							WHERE StoreId = @StoreId 
							AND (@IncludeInReportsCurrentStoreOnly=0 OR (@IncludeInReportsCurrentStoreOnly=1 AND IsCurrentStore = 1)))


		DECLARE @ZNR VARCHAR(200)
		SELECT @ZNR = COALESCE(@ZNR + ', ', '') + CONVERT(VARCHAR(10), r.ZNR)
		FROM (SELECT DISTINCT ZNR
			FROM RBIM.Fact_ReconciliationSystemTotalPerTender AS fc
			WHERE fc.ReconciliationDateIdx = @DateIdx
			AND fc.StoreIdx = @StoreIdx
			) r

		DECLARE @CashRegisters VARCHAR(200)
		SELECT @CashRegisters = COALESCE(@CashRegisters + ', ', '') + CONVERT(VARCHAR(10), r.CashRegisterId)
		FROM (SELECT DISTINCT cr.CashRegisterId
			FROM RBIM.Fact_ReconciliationSystemTotalPerTender AS fc
			LEFT JOIN RBIM.Dim_CashRegister cr ON fc.CashRegisterIdx = cr.CashRegisterIdx
			WHERE fc.ReconciliationDateIdx = @DateIdx
			AND fc.StoreIdx = @StoreIdx
			) r


		SELECT  
			ds.StoreId
			,ds.CurrentStoreName as StoreName
			,@ZNR AS ZNR
			,@CashRegisters AS CashRegisters
			,min(convert(VARCHAR(10), fd.FullDate) + ' ' + ftt.TimeDescription) as ReconciliationTransactionFirst
			,max(convert(VARCHAR(10), ld.FullDate) + ' ' + ltt.TimeDescription) as ReconciliationTransactionLast
		FROM RBIM.Fact_ReconciliationSystemTotalPerTender AS fc
		LEFT JOIN RBIM.Dim_Store ds ON fc.StoreIdx = ds.StoreIdx																				
		LEFT JOIN RBIM.Dim_Time ftt ON fc.FirstTransactionTimeidx = ftt.TimeIdx 
		LEFT JOIN RBIM.Dim_Time ltt ON fc.LastTransactionTimeidx = ltt.TimeIdx
		LEFT JOIN RBIM.Dim_Date fd ON fc.FirstTransactionDateidx = fd.DateIdx 
		LEFT JOIN RBIM.Dim_Date ld ON fc.LastTransactionDateidx = ld.DateIdx	
		WHERE fc.ReconciliationDateIdx = @DateIdx
		AND fc.StoreIdx = @StoreIdx
		GROUP BY 
			ds.StoreId
			,ds.CurrentStoreName
	  	
	END
END 
GO


