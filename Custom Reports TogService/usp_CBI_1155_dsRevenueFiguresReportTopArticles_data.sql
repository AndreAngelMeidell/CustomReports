USE [BI_Mart]
GO

if (object_id('dbo.usp_CBI_1155_dsRevenueFiguresReportTopArticles_data') is not null)
	drop procedure dbo.usp_CBI_1155_dsRevenueFiguresReportTopArticles_data
go

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



create procedure dbo.usp_CBI_1155_dsRevenueFiguresReportTopArticles_data 
(	 
	@StoreOrGroupNo				as varchar(max)
    ,@PeriodType                as char(1) 
	,@DateFrom                  as datetime 
	,@DateTo                    as datetime 
	,@YearToDate                as integer 
	,@RelativePeriodType        as char(5)      
	,@RelativePeriodStart       as integer  
	,@RelativePeriodDuration    as integer  
	,@ExcludeBottleDeposit      as integer
	,@ExcludeThirdPartyArticles as integer
	,@ArticleIdFrom             as varchar(50) = NULL 
	,@ArticleIdTo               as varchar(50) = NULL 
    ,@GtinFrom                  as varchar(50) = NULL 
	,@GtinTo                    as varchar(50) = NULL 
	,@Top                       as integer    
)
as 
begin

set @ArticleIdFrom	= case when rtrim(ltrim(@ArticleIdFrom)) = ''	then null else @ArticleIdFrom end;
set @ArticleIdTo	= case when rtrim(ltrim(@ArticleIdTo)) = ''		then null else @ArticleIdTo end;
set @GtinFrom		= case when rtrim(ltrim(@GtinFrom)) = ''		then null else @GtinFrom end;
set @GtinTo			= case when rtrim(ltrim(@GtinTo)) = ''			then null else @GtinTo end; 
------------------------------------------------------------------------
--If @Top as top article number was selected as negative value
--we need to make sure script will not break
--so reassigning it to 0
if (@Top < 0) set @Top = 0
------------------------------------------------------------------------

-----------------------------------------------------------------
--Date from should be recalculated in case
--we selected period type Y or R
--because we need to know DateFrom for those periods
--to compare it with another period
----------------------------------------------------------------
set @DateFrom =	(
				select
					top 1 FullDate 
				from
					RBIM.Dim_Date	dd
				where       --filter on period1 
						(
							(@PeriodType='D' and dd.FullDate = @DateFrom )
						  or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate and dd.Dimlevel=0)
						  or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay		= @RelativePeriodStart and dd.Dimlevel=0)
						  or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek		= @RelativePeriodStart and dd.Dimlevel=0)
						  or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth	= @RelativePeriodStart and dd.Dimlevel=0)
						  or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter	= @RelativePeriodStart and dd.Dimlevel=0)
						  or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear		= @RelativePeriodStart and dd.Dimlevel=0)
						)
					and Dateidx not in (-1,-2,-3,-4)
				)

----------------------------------------------------------------------

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
	select top (@Top)
		case when da.ArticleIdx = -4 then ua.UnknownArticleName else da.ArticleName end			as ArticleName
		,isnull(b.Gtin, '')																		as Gtin
		,convert(char(8),MIN(f.FirstTimeOfSale))												as FirstTimeOfSale
		,convert(char(8),MAX(f.LastTimeOfSale))													as LastTimeOfSale
		,SUM(f.NumberOfCustomersPerSelectedArticle)												as NumberOfCustomersPerSelectedArticle
		,SUM(f.SalesAmount)																		as SalesAmount
		,SUM(f.ReturnAmount)																	as ReturnAmount
		,SUM(f.SalesAmountExclVat)+ SUM(f.ReturnAmountExclVat)									as RevenueAmount
		,SUM(f.GrossProfit)																		as TotalGrossProfit
		,SUM(f.CostOfGoods)																		as TotalCostOfGoodsSold
	from
		BI_Mart.rbim.Agg_SalesAndReturnPerDay f
	join rbim.Dim_Date           dd on dd.DateIdx    = f.ReceiptDateIdx 
	join rbim.Dim_Article        da on da.ArticleIdx = f.ArticleIdx 
	join rbim.Dim_UnknownArticle ua on ua.UnknownArticleIdx = f.UnknownArticleIdx 
	left join rbim.Dim_Gtin            B	on f.GtinIdx     = B.GtinIdx
	join Stores ds on ds.StoreIdx = f.StoreIdx
	Where  
			(
				(@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
			or	(@PeriodType='Y' and dd.RelativeYTD = @YearToDate  and dd.Dimlevel=0)
			or 	(@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek		between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
			or	(@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth		between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
			or	(@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter	between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
			or	(@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear		between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
			)
		and Dateidx not in (-1,-2,-3,-4)  
		--Filter on ArticleIdx
		and da.ArticleIdx > -1 -- needs to be included if you should exclude LADs etc.  
		--Filter on excluding third party articles
		and ((@ExcludeThirdPartyArticles = 1 and isnull(da.Is3rdPartyArticle,0) = 0) or @ExcludeThirdPartyArticles = 0) 
		--Filter on excluding bottle deposit articles
		and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)
		--Filter on ArticleId		
		and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) >= CAST(CASE WHEN @ArticleIdFrom	IS NULL AND ISNUMERIC(@ArticleIdFrom) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE	@ArticleIdFrom END AS BIGINT)
		and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) <= CAST(CASE WHEN @ArticleIdTo		IS NULL AND ISNUMERIC(@ArticleIdTo) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE	@ArticleIdTo END AS BIGINT) 
		--Filter on GTIN
		and (@GtinFrom IS NULL OR CAST(ISNULL(B.Gtin,@GtinFrom) AS BIGINT) >= CAST(@GtinFrom AS BIGINT)) and (@GtinTo IS NULL OR CAST(ISNULL(B.Gtin,@GtinTo) AS BIGINT) <= CAST(@GtinTo AS BIGINT))	
	group by
		da.ArticleIdx
		,da.ArticleName
		,ua.UnknownArticleIdx
		,ua.UnknownArticleName
		,b.gtin
	order by
		sum(f.SalesAmountExclVat)+sum(f.ReturnAmountExclVat) desc
	)

select * from SelectedSales

end

go
