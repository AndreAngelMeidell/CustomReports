USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1751_OperationReport_Returns]    Script Date: 07.02.2020 10:44:06 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   PROCEDURE [dbo].[usp_CBI_ds1751_OperationReport_Returns]
( @DateFrom as datetime,
  @DateTo as datetime,
  @StoreId varchar(100)) --changed to varchar(100)
AS

BEGIN
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


IF (@DateFrom IS NULL)
BEGIN
	SELECT TOP(0) 1  --{RS-34990}
END
ELSE BEGIN

DECLARE @QueryString NVARCHAR(MAX)


DECLARE @DateFromIdx integer
DECLARE @DateToIdx integer

DECLARE @AggTableToUse varchar(255)

------
SET @DateFromIdx = cast(convert(char(8), @DateFrom, 112) as integer)
SET @DateToIdx = cast(convert(char(8), @DateTo, 112) as integer)
------
DECLARE @IncludeInReportsCurrentStoreOnly INT = (
SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
);
SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		
------{RS-34601}
DECLARE @ParamDefinition NVARCHAR(MAX) = 
			'
			@DateFromIdx integer,
			@DateToIdx integer,
			@StoreId varchar(100),
			@IncludeInReportsCurrentStoreOnly integer'


		SET  @AggTableToUse = ' [RBIM].[Agg_SalesAndReturnPerDay] f '

		DROP TABLE IF EXISTS #Stores

		SELECT ds.StoreIdx
		INTO #Stores
		FROM RBIM.Dim_Store ds
		WHERE ds.StoreId = @StoreId AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
					AND ds.ValidToDate >= @DateFrom --KVT 20191217 12:37
--SELECT * FROM #Stores s

		SET @QueryString ='
SELECT  
 sub.CashierId
,sub.CasierName
,sum(SalesAmount+ReturnAmount)  AS SalesRevenueInclVat --{RS-27230} all returns vs all sales, 3.rd sales included.
,sum(NumberOfReceiptsWithReturn) AS NumberOfReceiptsWithReturn
,sum(NumberOfArticlesInReturn) AS NumberOfArticlesInReturn
,sum(ReturnAmount)*-1 AS ReturnAmount --{RS-27230} positive value in report
,ISNULL(sum(ReturnAmount)*-1/NULLIF(sum(SalesAmount),0),0) AS ReturnPctVsSales,  --{RS-27230} all returns vs all sales, 3.rd sales included; {RS-31241} Division by zero fixed
 sum(NumberOfReceiptsWithGenericGtinInReturn) AS NumberOfReceiptsWithGenericGtinInReturn,
 sum(NumberOfArticlesWithGenericGtinInReturn) AS NumberOfArticlesWithGenericGtinInReturn,
 sum(GenericGtinReturnAmount) AS  GenericGtinReturnAmount,
 0 as VeksleAntallAvbrudd,
 0 as QuantityOfInteruptedCHS
FROM (
----------------------------------------------------------------------------------------------------------------
SELECT
      su.[UserNameID] AS CashierId,
      su.FirstName+'' ''+ISNULL(su.LastName,'''') AS CasierName, 
      SUM(f.[SalesAmount]) AS [SalesAmount],
      0 as Pos3rdPartySalesAmount,
      SUM(f.[ReturnAmount]) AS [ReturnAmount],
      0 AS Pos3rdPartyReturnAmount,
      sum(NumberOfReceiptsWithReturn) as NumberOfReceiptsWithReturn,
      sum(NumberOfArticlesInReturn) as NumberOfArticlesInReturn,
      SUM(f.NumberOfReceiptsWithReturnPerSelectedArticle) AS NumberOfReceiptsWithReturnPerSelectedArticle,
      0 NumberOfReceiptsWithGenericGtinInReturn,
      0 NumberOfArticlesWithGenericGtinInReturn,
      0 GenericGtinReturnAmount

FROM '+@AggTableToUse+' with (nolock)
     join #Stores ds on ds.storeidx = f.storeidx 
     join rbim.Dim_User su on su.UserIdx = f.SystemUserIdx

Where f.ReceiptDateIdx >= @DateFromIdx AND f.ReceiptDateIdx <= @DateToIdx
--and da.ArticleIdx > -1 		-- needs to be included if you should exclude LADs etc.
								-- (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
--and da.Is3rdPartyArticle=0 
GROUP BY
su.[UserNameID],su.FirstName,su.LastName 
---------------------------------------------------------------------------------------
UNION ALL

SELECT
      su.[UserNameID] AS CashierId,
      su.FirstName+'' ''+ISNULL(su.LastName,'''') AS CasierName, 
      0 AS [SalesAmount],
      sum(f.Pos3rdPartySalesAmount) AS Pos3rdPartySalesAmount,
      0 AS [ReturnAmount],
      sum(f.Pos3rdPartyReturnAmount) AS Pos3rdPartyReturnAmount,
      0 as NumberOfReceiptsWithReturn,
      0 as NumberOfArticlesInReturn,
  0 AS NumberOfReceiptsWithReturnPerSelectedArticle,
      SUM(NumberOfReceiptsWithGenericGtinInReturn) AS NumberOfReceiptsWithGenericGtinInReturn,
      SUM(NumberOfArticlesWithGenericGtinInReturn) AS NumberOfArticlesWithGenericGtinInReturn,
      SUM(GenericGtinReturnAmount) ASGenericGtinReturnAmount

FROM [RBIM].[Agg_CashierSalesAndReturnPerHour] f with (nolock)
     join #Stores ds on ds.storeidx = f.storeidx
     join rbim.Dim_User su on su.UserIdx = f.CashierUserIdx

Where f.ReceiptDateIdx >= @DateFromIdx AND f.ReceiptDateIdx <= @DateToIdx
--and da.ArticleIdx > -1 		-- needs to be included if you should exclude LADs etc.
								-- (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
GROUP BY
su.[UserNameID],su.FirstName,su.LastName 

)	sub
GROUP BY
 sub.CashierId
,sub.CasierName
--OPTION (recompile)

'

PRINT @QueryString

		EXEC sp_executesql 
							@QueryString,
							@ParamDefinition,
							@DateFromIdx = @DateFromIdx,
							@DateToIdx = @DateToIdx,
							@StoreId = @StoreId,
							@IncludeInReportsCurrentStoreOnly = @IncludeInReportsCurrentStoreOnly

	DROP TABLE IF EXISTS #Stores

END
END



GO

