USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1751_OperationReport_AgeControl]    Script Date: 07.02.2020 10:42:22 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------



CREATE   PROCEDURE [dbo].[usp_CBI_ds1751_OperationReport_AgeControl]
( --@PeriodType as char(1), 
  @DateFrom as datetime,
  @DateTo as datetime,
  --@YearToDate as integer, 
  --@RelativePeriodType as char(5),
  --@RelativePeriodStart as integer, 
  --@RelativePeriodDuration as integer ,
  @StoreId as varchar(100) --changed to varchar as it is on Dim_Store
  )
AS

BEGIN
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

IF (@DateFrom IS NULL OR @DateFrom = '') --{RS-34990}
BEGIN
	SELECT TOP(0) 1
END
ELSE BEGIN

DECLARE @QueryStringPart1 NVARCHAR(MAX)
DECLARE @QueryStringPart2 NVARCHAR (MAX)
DECLARE @QueryString NVARCHAR (MAX)

DECLARE @DateIdxBegin integer
DECLARE @DateIdxEnd integer

DECLARE @DateFromIdx integer
DECLARE @DateToIdx integer

DECLARE @out_Agg char(1)

DECLARE @AggTableToUse varchar(255)
DECLARE @DateFilter varchar(255)

------
SET @DateFromIdx = cast(convert(char(8), @DateFrom, 112) as integer)
SET @DateToIdx = cast(convert(char(8), @DateTo, 112) as integer)
------
DECLARE @IncludeInReportsCurrentStoreOnly INT
 = (
SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
);
SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		
DROP TABLE IF EXISTS #Stores

SELECT StoreIdx
INTO #Stores
FROM RBIM.Dim_Store ds
WHERE ds.StoreId = @StoreId AND ds.IsCurrentStore = 1	

		
--{RS-34601}
DECLARE @ParamDefinition NVARCHAR(MAX) = 
			'
			@DateIdxBegin integer,
			@DateIdxEnd integer,
			@DateFromIdx integer,
			@DateToIdx integer,
			@StoreId varchar(100),
			@IncludeInReportsCurrentStoreOnly integer'


		SET  @DateFilter = ' f.ReceiptDateIdx >= @DateFromIdx AND f.ReceiptDateIdx <= @DateToIdx '

		SET  @AggTableToUse = ' [RBIM].[Agg_SalesAndReturnPerDay] f '


		SET @QueryStringPart1 = 
		'
			SELECT
				  su.UserNameID AS CashierId,  --Obsolete
				  su.LoginName,                --Unique use for join because it is not empty {RS-33305}
				  su.FirstName+'' ''+ISNULL(su.LastName,'''') AS CasierName, 
				  SUM(NumberOfAgeControlsClearlyOldEnough) AS NumberOfAgeControlsClearlyOldEnough,
				  SUM(TotalNumberOfAgeControlsApproved) AS TotalNumberOfAgeControlsApproved,
				  SUM(TotalNumberOfAgeControlsNotApproved) AS TotalNumberOfAgeControlsNotApproved,
				  ---Additional columns ----------------------
				  SUM(NumberOfAgeControlsApprovedByFingerprints) AS NumberOfAgeControlsApprovedByFingerprints,
				  SUM(NumberOfAgeControlsNotApprovedByFingerprints) AS NumberOfAgeControlsNotApprovedByFingerprints
			FROM [RBIM].[Agg_CashierSalesAndReturnPerHour] f
				 join #Stores ds on ds.storeidx = f.storeidx
				 join rbim.Dim_User su on su.UserIdx = f.CashierUserIdx
			WHERE
				  f.ReceiptDateIdx >= @DateFromIdx AND f.ReceiptDateIdx <= @DateToIdx
			GROUP BY
				  su.UserNameID,su.FirstName,su.LastName,su.LoginName 
		'


		SET @QueryStringPart2 = 
		'
			SELECT       
				su.[UserNameID] AS CashierId, --Obsolete
				su.LoginName,                 --Unique use for join because it is not empty {RS-33305}
				su.FirstName+'' ''+ISNULL(su.LastName,'''') AS CasierName,
				sum(case when (ae.Value_AgeLimit <> ''NaN'' and convert(int, ae.Value_AgeLimit) > 0) then 1 else 0 end) as NumberOfArticlesSoldWithAgeControl
			FROM '+ @AggTableToUse+'
				join rbim.Dim_Article a on a.ArticleIdx = f.ArticleIdx AND LEN(a.ArticleId) < 19
				join rbim.Out_ArticleExtraInfo ae on ae.ArticleExtraInfoIdx = a.ArticleExtraInfoIdx
				join #Stores ds on ds.storeidx = f.storeidx
				join rbim.Dim_User su on su.UserIdx = f.SystemUserIdx
			Where 
				'+ @DateFilter+'
			group by su.UserNameID,su.FirstName,su.LastName,su.LoginName
		'

		SET @QueryString = 
		'
			SELECT 
			  a.CashierId
			, a.CasierName
			, b.NumberOfArticlesSoldWithAgeControl
			, a.NumberOfAgeControlsClearlyOldEnough
			, a.TotalNumberOfAgeControlsApproved
			, a.TotalNumberOfAgeControlsNotApproved
			, a.NumberOfAgeControlsApprovedByFingerprints
			, a.NumberOfAgeControlsNotApprovedByFingerprints
			FROM
				('+@QueryStringPart1+ ') as a
				INNER JOIN
				('+@QueryStringPart2+ ') as b
			ON a.LoginName = b.LoginName  --a.CashierId = b.CashierId and a.CasierName = b.CasierName 
			WHERE (b.NumberOfArticlesSoldWithAgeControl > 0 OR a.TotalNumberOfAgeControlsNotApproved > 0)
			ORDER BY a.CasierName --a.CashierId 
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

		DROP TABLE IF EXISTS #Stores

END
END



GO

