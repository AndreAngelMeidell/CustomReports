USE [BI_Mart]
GO

if (object_id('dbo.usp_CBI_ds1751_OperationReport_AgeControl') is not null)
	drop procedure dbo.usp_CBI_ds1751_OperationReport_AgeControl
go

set ansi_nulls on
go

set quoted_identifier on
go


create procedure [dbo].[usp_CBI_ds1751_OperationReport_AgeControl]
	(
	@PeriodType					char(1)
	,@DateFrom					datetime
	,@DateTo					datetime
	,@YearToDate				integer
	,@RelativePeriodType		char(5)
	,@RelativePeriodStart		integer 
	,@RelativePeriodDuration	integer
	,@StoreOrGroupNo			varchar(max)
	)
as
begin

	;with Stores as
		(
		select
			distinct ds.*
		from
			RBIM.Dim_Store ds
		left join ( select ParameterValue from dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  on n.ParameterValue in (
								ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
								ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
								ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
								ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
								ds.StoreId) 
		where
				n.ParameterValue is not null
			and ds.IsCurrentStore=1		--to ensure we only get historical changes for the same store (defined by same GLN and same ORG number)
		) 
	,SelectedSales as
		(
		SELECT a.CashierId, a.CasierName, b.NumberOfArticlesSoldWithAgeControl
		,a.NumberOfAgeControlsClearlyOldEnough
		,a.TotalNumberOfAgeControlsApproved
		,a.TotalNumberOfAgeControlsNotApproved
		,a.NumberOfAgeControlsApprovedByFingerprints
		,a.NumberOfAgeControlsNotApprovedByFingerprints
		FROM
		(
			SELECT
				  su.UserNameID AS CashierId,
				  su.FirstName+' '+ISNULL(su.LastName,'') AS CasierName, 
				  --SUM(NumberOfArticlesSoldWithAgeControl) AS NumberOfArticlesSoldWithAgeControl,
				  SUM(NumberOfAgeControlsClearlyOldEnough) AS NumberOfAgeControlsClearlyOldEnough,
				  SUM(TotalNumberOfAgeControlsApproved) AS TotalNumberOfAgeControlsApproved,
				  SUM(TotalNumberOfAgeControlsNotApproved) AS TotalNumberOfAgeControlsNotApproved,
				  ---Additional columns ----------------------
				  SUM(NumberOfAgeControlsApprovedByFingerprints) AS NumberOfAgeControlsApprovedByFingerprints,
				  SUM(NumberOfAgeControlsNotApprovedByFingerprints) AS NumberOfAgeControlsNotApprovedByFingerprints
			FROM
				[BI_Mart].[RBIM].[Agg_CashierSalesAndReturnPerHour] f
				join rbim.Dim_Date dd on dd.DateIdx = f.ReceiptDateIdx -- Mandatory
				inner join Stores ds on ds.StoreIdx = f.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
				join rbim.Dim_User su on su.UserIdx = f.CashierUserIdx
			Where (
				(@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
				or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate)
				or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				)
			GROUP BY
				su.UserNameID
				,su.FirstName
				,su.LastName 
			) a
		INNER JOIN
			(
			select       
				su.[UserNameID] AS CashierId,
				su.FirstName+' '+ISNULL(su.LastName,'') AS CasierName,
				--a.articleid, a.ArticleName, f.QuantityOfArticlesSold, ae.Value_AgeLimit
				sum(case when (ae.Value_AgeLimit <> 'NaN' and convert(int, ae.Value_AgeLimit) > 0) then 1 else 0 end) as NumberOfArticlesSoldWithAgeControl
				--0 as NumberOfArticlesSoldWithAgeControl
				  --SUM(0) AS NumberOfAgeControlsClearlyOldEnough,
				  --SUM(0) AS TotalNumberOfAgeControlsApproved,
				  --SUM(0) AS TotalNumberOfAgeControlsNotApproved,
				  -----Additional columns ----------------------
				  --SUM(0) AS NumberOfAgeControlsApprovedByFingerprints,
				  --SUM(0) AS NumberOfAgeControlsNotApprovedByFingerprints
				from rbim.Agg_SalesAndReturnPerDay f
				join rbim.Dim_Article a on a.ArticleIdx = f.ArticleIdx AND LEN(a.ArticleId) < 19
				join rbim.Out_ArticleExtraInfo ae on ae.ArticleExtraInfoIdx = a.ArticleExtraInfoIdx
				join rbim.Dim_Date dd on dd.dateidx = f.ReceiptDateIdx
				inner join Stores ds on ds.StoreIdx = f.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
				join rbim.Dim_User su on su.UserIdx = f.SystemUserIdx

			Where (
				(@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
				or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate)
				or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1)
				)
			group by su.UserNameID,su.FirstName,su.LastName
			 ) b
		ON a.CashierId = b.CashierId and a.CasierName = b.CasierName
		where b.NumberOfArticlesSoldWithAgeControl > 0
		)
		
	select * from SelectedSales order by CashierId

end


GO
