USE [BI_Mart]
GO

DROP PROCEDURE [dbo].[usp_CBI_1156_dsHourlySalesReport_topArticles]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_1156_dsHourlySalesReport_topArticles] 
(	 
	@StoreOrGroupNo				as varchar(max)
	--@StoreId                   as varchar(100)         
    ,@PeriodType                as char(1) 
	,@DateFrom                  as datetime 
	,@DateTo                    as datetime 
	,@YearToDate                as integer 
    ,@DateFromPeriod2           as datetime 
  --,@DateToPeriod2             as datetime   
	,@Year                      as integer             
	,@Option                    as integer
	,@RelativePeriodType        as char(5)      
	,@RelativePeriodStart       as integer  
	,@RelativePeriodDuration    as integer  
	,@ExcludeBottleDeposit      as integer
	,@ExcludeThirdPartyArticles as integer
	,@ArticleIdFrom             as varchar(50) = NULL 
	,@ArticleIdTo               as varchar(50) = NULL 
    ,@GtinFrom                  as varchar(50) = NULL 
	,@GtinTo                    as varchar(50) = NULL 
	,@Monday                    as integer
	,@Tuesday                   as integer
	,@Wednesday                 as integer
	,@Thursday                  as integer
	,@Friday                    as integer
	,@Saturday                  as integer
	,@Sunday                    as integer
	,@Top                       as integer    
	,@Period                    as integer
	,@Report_Subreport          as integer
)
AS 
BEGIN

SET @ArticleIdFrom = CASE WHEN RTRIM(LTRIM(@ArticleIdFrom)) = '' THEN NULL ELSE @ArticleIdFrom END;
SET @ArticleIdTo = CASE WHEN RTRIM(LTRIM(@ArticleIdTo)) = '' THEN NULL ELSE @ArticleIdTo END;
SET @GtinFrom = CASE WHEN RTRIM(LTRIM(@GtinFrom)) = '' THEN NULL ELSE @GtinFrom END;
SET @GtinTo = CASE WHEN RTRIM(LTRIM(@GtinTo)) = '' THEN NULL ELSE @GtinTo END; 
------------------------------------------------------------------------
--If @Top as top article number was selected as negative value
--we need to make sure script will not break
--so reassigning it to 0
if @Top<0 set @Top = 0
------------------------------------------------------------------------
if @Report_Subreport=1 and @Top>20 set @Top=20

-----------------------------------------------------------------
--Date from should be recalculated in case
--we selected period type Y or R
--because we need to know DateFrom for those periods
--to compare it with another period
----------------------------------------------------------------
set @DateFrom = (select  top 1 FullDate 
             from RBIM.Dim_Date as dd
             where       --filter on period1 
                        ((@PeriodType='D' and dd.FullDate = @DateFrom )
			          or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate and dd.Dimlevel=0)
			          or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay   = @RelativePeriodStart and dd.Dimlevel=0)
			          or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek  =  @RelativePeriodStart and dd.Dimlevel=0)
			          or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth = @RelativePeriodStart  and dd.Dimlevel=0)
			          or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter  =  @RelativePeriodStart and dd.Dimlevel=0)
			          or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear = @RelativePeriodStart and dd.Dimlevel=0))
                      and Dateidx not in (-1,-2,-3,-4)
			  )

----------------------------------------------------------------------
--Calculate DateToPeriod2. Period 2 should have same length as period 1.
--
DECLARE @DateToPeriod2 DATETIME
DECLARE @Datediff INT
SET @Datediff  = DATEDIFF(DAY, @DateFrom, @DateTo)
SET @DateToPeriod2 = DATEADD(DAY, @Datediff, @DateFromPeriod2)



------------------------------------------------------------------------
--Restriction to selecting top articles (max 20)
--*if it is report @Report_Subreport=1 
-- then only max top 20 articles will be shown
--*if it is subreport  @Report_Subreport=2
-- there will be no restrictions for max top articles
------------------------------------------------------------------------
if @Report_Subreport=1 and @Top>20 set @Top=20


----------------------------------------------------------------------
--Same Week and day number option (Option = 1)
--We want to compare Period1 DateFrom (@DateFrom) with the day that has
--the same day and week number like this day only for selected Year (@Year)  
--
--Same date option (Option = 2)
--We want to compare Period1 DateFrom (@DateFrom) with the day that has
--the same date only for selected Year (@Year) 
--
--Comparing periods option (Option = 3)
--We have DateFrom-DateTo for both perdiods (for period1 we also 
--have ability to chose between period type(D,R,Y)) and we want to 
--compare those periods
----------------------------------------------------------------------

----------------------------------------------------------------------
--Same date option (Option = 1)
--Instructions from gDrive:
--Go back x years in the Dim_Date and find the DayNumberOfYear
--based on the same WeekNumberOfYear and DayNumberOfWeek given by the from date in the period. 
----------------------------------------------------------------------
if @Option = 1 
begin 
   set @DateTo = (select @DateFrom)   --only one day (dayfrom) of period1
   declare @WeekNumberOfYearPeriod1 integer
   declare @DayNumberOfWeekPeriod1 integer
   
   select  @WeekNumberOfYearPeriod1=WeekNumberOfYear,
           @DayNumberOfWeekPeriod1 =DayNumberOfWeek
   from    rbim.Dim_Date
   where   FullDate = @DateFrom  
  
   select @DateFromPeriod2=FullDate
   from   rbim.Dim_Date 
   where  RelativeYear = (select (@Year-Year(@DateFrom)))   --x years back
	      and
		  DayNumberOfWeek = @DayNumberOfWeekPeriod1
		  and
		  WeekNumberOfYear=@WeekNumberOfYearPeriod1

   set @DateToPeriod2=(select @DateFromPeriod2)   --only one day of period2   
end

----------------------------------------------------------------------
--Same Week and day number option (Option = 2)
----------------------------------------------------------------------
if @Option = 2 
begin
	set     @DateTo = (select @DateFrom) --only one day (dayfrom) of period1
	declare @DateFromPeriod2nvarchar nvarchar(10) = cast(Day(@DateFrom) as nvarchar(2))+'/'+cast(Month(@DateFrom) as nvarchar(2))+'/'+ cast(@Year as nvarchar(4))  --same day and month, different year
	set     @DateFromPeriod2=convert(datetime,@DateFromPeriod2nvarchar,103 )
	set     @DateToPeriod2=(select @DateFromPeriod2) --only one day of period2              
end  


	;with Stores as
		(
		select
			distinct ds.*	--(RS-27332)
		from
			RBIM.Dim_Store ds
		left join ( select ParameterValue from [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  on n.ParameterValue in (
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
		   case when da.ArticleIdx = -4 then ua.UnknownArticleName else da.ArticleName end as ArticleName,
			ISNULL(b.Gtin, '')																					as Gtin,
		   CONVERT(char(8),MIN(f.FirstTimeOfSale))                                         as FirstTimeOfSale, 
		   convert(char(8),MAX(f.LastTimeOfSale))                                          as LastTimeOfSale,
	       SUM(f.NumberOfCustomersPerSelectedArticle)                                      as NumberOfCustomersPerSelectedArticle,
	       SUM(f.SalesAmount)                                                              as SalesAmount,                        
	       SUM(f.ReturnAmount)                                                             as ReturnAmount,	                 
	       SUM(f.SalesAmountExclVat)+ SUM(f.ReturnAmountExclVat)                           as RevenueAmount, 
	      /* RS-27090
		   SUM(f.TotalGrossProfit)                                                         as TotalGrossProfit,
	       SUM(f.TotalCostOfGoodsSold)                                                     as TotalCostOfGoodsSold
		  */
		   SUM(f.GrossProfit)                                                         as TotalGrossProfit,       -- RS-27090  ps.Incorect NamingConventions left
	       SUM(f.CostOfGoods)                                                         as TotalCostOfGoodsSold    -- RS-27090  ps.Incorect NamingConventions left
            ,MIN(f.UseDerivedNetPrice)								as UseDerivedNetPrice
			,MIN(f.IsDerivedNetPriceUsed)                           as MINIsDerivedNetPriceUsed
			,MAX(f.IsDerivedNetPriceUsed)                           as MAXIsDerivedNetPriceUsed
			,MIN(f.UseDerivedNetPrice)+	    MIN(f.IsDerivedNetPriceUsed) +MAX(f.IsDerivedNetPriceUsed)   as Config
		from BI_Mart.rbim.Agg_SalesAndReturnPerDay f
		join rbim.Dim_Date           dd on dd.DateIdx    = f.ReceiptDateIdx 
		join rbim.Dim_Article        da on da.ArticleIdx = f.ArticleIdx 
		join rbim.Dim_UnknownArticle ua on ua.UnknownArticleIdx = f.UnknownArticleIdx 
		--join rbim.Dim_Store          ds on ds.storeidx   = f.storeidx
		--LEFT JOIN rbim.Cov_ArticleGtin     A on f.ArticleIdx  = A.ArticleIdx               
		LEFT JOIN rbim.Dim_Gtin            B	on f.GtinIdx     = B.GtinIdx
		join Stores ds on ds.StoreIdx = f.StoreIdx
		Where  
			/*RS-20790 Removing this because we do not use join with Cov_ArticleGtin. We use Dim_Gtin instead and this is not required to use those filters
					  Total Values will not be included so count of customers or number of receipt will always be zero.
	                  ISNULL(f.IsDefaultGtin,1) = 1
                    */
			--filter on store
			--@StoreId = ds.StoreId 
			--and ds.StoreIdx >= 0
			--and ds.isCurrentStore = 1   -- make sure you only get the 'current store' (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
			--and
			--filter on period1 if it is @Period=1
			(
			  ((@Period = 1 and @PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
			or (@Period = 1 and @PeriodType='Y' and dd.RelativeYTD = @YearToDate  and dd.Dimlevel=0)
			or (@Period = 1 and @PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
			or (@Period = 1 and @PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
			or (@Period = 1 and @PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
			or (@Period = 1 and @PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0))
			or
			--filter on period2 if it is @Period=2
			( @Period = 2 and dd.FullDate between @DateFromPeriod2 and @DateToPeriod2)
			)
			and Dateidx not in (-1,-2,-3,-4)  
			--filter on weekday  
			and (   dd.DayNumberOfWeek = (case when @Monday=   1 then 1 else 0 end)
			     or dd.DayNumberOfWeek = (case when @Tuesday=  1 then 2 else 0 end)
			     or dd.DayNumberOfWeek = (case when @Wednesday=1 then 3 else 0 end)
			     or dd.DayNumberOfWeek = (case when @Thursday= 1 then 4 else 0 end)
			     or dd.DayNumberOfWeek = (case when @Friday=   1 then 5 else 0 end)
			     or dd.DayNumberOfWeek = (case when @Sunday=   1 then 6 else 0 end)
			     or dd.DayNumberOfWeek = (case when @Saturday= 1 then 7 else 0 end))
			
			--Filter on ArticleIdx
			and da.ArticleIdx > -1 -- needs to be included if you should exclude LADs etc.  

			--Filter on excluding third party articles
			and ((@ExcludeThirdPartyArticles = 1 AND ISNULL(da.Is3rdPartyArticle,0) = 0) OR @ExcludeThirdPartyArticles = 0) 
			
			--Filter on excluding bottle deposit articles
			and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)
			
			--Filter on ArticleId		
			and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) >= CAST(CASE WHEN @ArticleIdFrom           IS NULL AND ISNUMERIC(@ArticleIdFrom) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE         @ArticleIdFrom END AS BIGINT) /*RS-29208*/
			and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) <= CAST(CASE WHEN @ArticleIdTo           IS NULL AND ISNUMERIC(@ArticleIdTo) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE         @ArticleIdTo END AS BIGINT) 

			--Filter on GTIN
			and (@GtinFrom IS NULL OR CAST(ISNULL(B.Gtin,@GtinFrom) AS BIGINT) >= CAST(@GtinFrom AS BIGINT)) and (@GtinTo IS NULL OR CAST(ISNULL(B.Gtin,@GtinTo) AS BIGINT) <= CAST(@GtinTo AS BIGINT))	
		group by da.ArticleIdx,da.ArticleName,ua.UnknownArticleIdx,ua.UnknownArticleName, b.gtin
		order by SUM(f.SalesAmountExclVat)+ SUM(f.ReturnAmountExclVat) desc
	)

	select * from SelectedSales

END





GO


