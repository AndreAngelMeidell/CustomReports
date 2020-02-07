USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1751_OperationReport_BottleDeposit]    Script Date: 07.02.2020 10:43:03 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



CREATE    PROCEDURE [dbo].[usp_CBI_ds1751_OperationReport_BottleDeposit] (
--@PeriodType AS char(1),
@DateFrom AS datetime,
@DateTo AS datetime,
--@YearToDate AS integer,
--@RelativePeriodType AS char(5),
--@RelativePeriodStart AS integer,
--@RelativePeriodDuration AS integer,
@StoreId varchar(100)) -- changed varchar to 100 as it is on dim_store
AS

BEGIN
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

	IF (@DateFrom IS NULL OR @DateFrom = '') 
	BEGIN
		SELECT TOP(0) 1
	END
	ELSE BEGIN

		DECLARE @QueryString NVARCHAR(MAX)

		DECLARE @DateIdxBegin integer
		DECLARE @DateIdxEnd integer

		DECLARE @DateFromIdx integer
		DECLARE @DateToIdx integer

		DECLARE @out_Agg char(1)


		DECLARE @AggTableToUse varchar(255)
		DECLARE @AggRvmTableToUse nvarchar(255) = ' RBIM.Agg_RvmReceiptPerDay as f '

		DECLARE @DateFilter varchar(255)
		DECLARE @DateFilterRVM NVARCHAR(255)

		DECLARE @IncludeInReportsCurrentStoreOnly INT 
		= (
		SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
		WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
		);
		SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1);
		
		------
		SET @DateFromIdx = cast(convert(char(8), @DateFrom, 112) as integer)
		SET @DateToIdx = cast(convert(char(8), @DateTo, 112) as integer)
		------

		
		DECLARE @ParamDefinition NVARCHAR(MAX) = 
					'
					@DateIdxBegin integer,
					@DateIdxEnd integer,
					@DateFromIdx integer,
					@DateToIdx integer,
					@StoreId varchar(100),
					@IncludeInReportsCurrentStoreOnly integer'


				SET  @DateFilter = ' agg.ReceiptDateIdx >= @DateFromIdx AND agg.ReceiptDateIdx <= @DateToIdx '
				SET  @DateFilterRVM = ' f.DateIdx >= @DateFromIdx AND f.DateIdx <= @DateToIdx  '
			


		SET  @AggTableToUse = ' [RBIM].[Agg_SalesAndReturnPerDay] agg '


		SET @QueryString =
		'			
		  SELECT
				CashierId,
				CasierName,
				SalesRevenueInclVat,  
				BottleDepositSalesAmount,
				BottleDepositSalePctVsRegSales,
				BottleDepositReturnAmount,
				BottleArticleReturnAmount,
				BottleDepositManualReturnQty,
				BottleDepositManualReturnAmount,
				LotteryReceiptRedeemed
		  FROM (
					(SELECT
						a.CashierId,
						a.CasierName,
						a.SalesAmount + a.ReturnAmount AS SalesRevenueInclVat,
						a.BottleDepositSalesAmount + ISNULL(b.BottleDepositReturnAmt, 0) AS BottleDepositSalesAmount,
						ISNULL((a.BottleDepositSalesAmount + ISNULL(b.BottleDepositReturnAmt, 0)) / NULLIF((a.SalesAmount + a.ReturnAmount),0),0) AS BottleDepositSalePctVsRegSales, 
						a.BottleDepositReturnAmount AS BottleDepositReturnAmount,
						ISNULL(b.BottleDepositReturnAmt, 0) AS BottleArticleReturnAmount,
						a.BottleDepositManualReturnQty,
						a.BottleDepositManualReturnAmount AS BottleDepositManualReturnAmount,
						0 AS LotteryReceiptRedeemed
						FROM (
								SELECT
								ISNULL(su.UserNameID,'''') AS CashierId,
								su.FirstName + '' '' + ISNULL(su.LastName, '''') AS CasierName,
								SUM(f.SalesAmount) AS SalesAmount,
								SUM(f.ReturnAmount) AS ReturnAmount,
								SUM(f.BottleDepositSalesAmount) AS BottleDepositSalesAmount,
								SUM(f.BottleDepositReturnAmount) AS BottleDepositReturnAmount,
								SUM(f.NumberOfReceiptsWithBottleDepositManualReturn) AS BottleDepositManualReturnQty,
								SUM(f.BottleDepositManualReturnAmount) AS BottleDepositManualReturnAmount
								FROM RBIM.Agg_CashierSalesAndReturnPerHour AS f								
								INNER JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = f.StoreIdx AND ds.StoreId = @StoreId AND IsCurrentStore = 1
								INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.CashierUserIdx
								WHERE  f.ReceiptDateIdx >= @DateFromIdx AND f.ReceiptDateIdx <= @DateToIdx 
								GROUP BY su.UserNameID,su.FirstName,su.LastName
							) a
					  LEFT JOIN (
								  SELECT	ISNULL(su.UserNameID,'''') AS CashierId,
												su.FirstName + '' '' + ISNULL(su.LastName, '''') AS CasierName,
												SUM(CASE WHEN a.ArticleTypeId = 130 THEN agg.ReturnAmount  ELSE 0 END) AS BottleDepositReturnAmt
								  FROM '+@AggTableToUse+'								  
								  INNER JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = agg.StoreIdx AND ds.StoreId = @StoreId AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) 
								  INNER JOIN RBIM.Dim_Article AS a  ON a.ArticleIdx = agg.ArticleIdx
								  INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = agg.SystemUserIdx
								  WHERE a.ArticleTypeId = 130 AND agg.ReturnAmount != 0
								  AND  '+@DateFilter+'
								  GROUP BY su.UserNameID,su.FirstName,su.LastName
								  ) b ON a.CashierId = b.CashierId AND a.CasierName = b.CasierName
					)

			  UNION ALL

			  SELECT
					ISNULL(su.UserNameID,'''') AS CashierId,
					su.FirstName + '' '' + ISNULL(su.LastName, '''') AS CasierName,
					0 AS SalesRevenueInclVat,
					0 AS BottleDepositSalesAmount,
					0 AS BottleDepositSalePctVsRegSales,
					0 AS BottleDepositReturnAmount,
					0 AS BottleArticleReturnAmount,
					0 AS BottleDepositManualReturnQty,
					0 AS BottleDepositManualReturnAmount,
					SUM(f.TotalAmount) AS LotteryReceiptRedeemed
			  FROM '+@AggRvmTableToUse+'
			  INNER JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = f.StoreIdx
												AND ds.StoreId = @StoreId AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) 
			  INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.CashierUserIdx
			  INNER JOIN RBIM.Dim_TransType AS tt ON tt.TransTypeIdx = f.TransTypeIdx
			  WHERE '+@DateFilterRVM+'
			  AND (tt.TransTypeId = 90307)
			  GROUP BY su.UserNameID,su.FirstName,su.LastName
			) AS sub
		  '


				EXEC sp_executesql
									@QueryString,
									@ParamDefinition,
									@DateIdxBegin = @DateIdxBegin,
									@DateIdxEnd = @DateIdxEnd,
									@DateFromIdx = @DateFromIdx,
									@DateToIdx = @DateToIdx,
									@StoreId = @StoreId,
									@IncludeInReportsCurrentStoreOnly = @IncludeInReportsCurrentStoreOnly


	END
END



GO

