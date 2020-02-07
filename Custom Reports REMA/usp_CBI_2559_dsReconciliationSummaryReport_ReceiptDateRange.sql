USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_ReceiptDateRange]    Script Date: 07.02.2020 10:39:43 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



CREATE   PROCEDURE [dbo].[usp_CBI_2559_dsReconciliationSummaryReport_ReceiptDateRange]     
(	@TotalTypeId AS INT ,
	@StoreId AS VARCHAR(100),
	@Date AS DATETIME )
AS  
BEGIN 

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

SET @TotalTypeId = 2 --RS-45270

	IF (@Date IS NULL)
	BEGIN
		SELECT TOP(0) 1
	END
	ELSE BEGIN
		
		DECLARE @DateIdx int = cast(convert(varchar(8),@Date, 112) as integer) 

		DECLARE @IncludeInReportsCurrentStoreOnly INT = (
		SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
		WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
		);
		SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		

		--------------------------------------- Get reconciliation period ---------------------------------------------
		DECLARE @ReportReconciliationDateFromIdx AS int		
		DECLARE @ReportReconciliationDateToIdx AS int		
		DECLARE @ReportReconciliationTimeFromIdx AS int																			 
		DECLARE @ReportReconciliationTimeToIdx AS int
		DECLARE @FormattedStartDate AS datetime	
		DECLARE @FormattedEndDate AS date																				
		DECLARE @ReceiptDateRange table (
										StoreIdx int,
										FirstTransactionDateIdx int,
										LastTransactionDateidx int,
										FirstTransactionTimeidx int,
										LastTransactionTimeidx int )
				   																														
		INSERT INTO @ReceiptDateRange ( 
										StoreIdx,
										FirstTransactionDateIdx,
										LastTransactionDateidx,
										FirstTransactionTimeidx,
										LastTransactionTimeidx)			
		SELECT  fc.StoreIdx,
				fc.FirstTransactionDateidx,
				fc.LastTransactionDateidx,
				fc.FirstTransactionTimeidx,
				fc.LastTransactionTimeidx						
		FROM RBIM.Fact_ReconciliationSystemTotalPerTender as fc
		LEFT JOIN RBIM.Dim_TotalType TT ON fc.TotalTypeIdx = TT.TotalTypeIdx														
		LEFT JOIN RBIM.Dim_Store AS ds ON fc.StoreIdx = ds.StoreIdx																				
		WHERE fc.ReconciliationDateIdx = @DateIdx																					
		AND TT.TotalTypeId = @TotalTypeId																							
		AND ds.StoreId = @StoreId
		AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
			
		SELECT																													 
			@ReportReconciliationDateFromIdx = MIN(FirstTransactionDateIdx),													
			@ReportReconciliationDateToIdx = MAX(LastTransactionDateIdx) 																		
		FROM @ReceiptDateRange

		SELECT 	
			@ReportReconciliationTimeFromIdx = MIN(FirstTransactionTimeIdx)
		FROM @ReceiptDateRange			
		WHERE FirstTransactionDateIdx = @ReportReconciliationDateFromIdx

		SELECT 	
			@ReportReconciliationTimeToIdx = MAX(LastTransactionTimeIdx)
		FROM @ReceiptDateRange
		WHERE LastTransactionDateIdx = @ReportReconciliationDateToIdx

		SELECT  ds.CurrentStoreName as StoreName,
				min(convert(datetime, convert(varchar(8),rdr.FirstTransactionDateIdx) + ' ' + ftt.TimeDescription + ':00')) as ReconciliationTransactionFirst,
				max(convert(datetime, convert(varchar(8),rdr.LastTransactionDateIdx) + ' ' + ltt.TimeDescription + ':00')) as ReconciliationTransactionLast,
				@ReportReconciliationDateFromIdx as ReportReconciliationDateFromIdx,
				@ReportReconciliationDateToIdx as ReportReconciliationDateToIdx,
				@ReportReconciliationTimeFromIdx as ReportReconciliationTimeFromIdx,
				@ReportReconciliationTimeToIdx as ReportReconciliationTimeToIdx	
		FROM @ReceiptDateRange AS rdr
		LEFT JOIN RBIM.Dim_Time ftt ON rdr.FirstTransactionTimeidx = ftt.TimeIdx 
		LEFT JOIN RBIM.Dim_Time ltt ON rdr.LastTransactionTimeidx = ltt.TimeIdx
		LEFT JOIN RBIM.Dim_Store ds ON ds.StoreIdx = rdr.StoreIdx
		GROUP BY ds.CurrentStoreName
		--------------------------------------------------------------------------------------------------------------
	END
END



		
			



GO

