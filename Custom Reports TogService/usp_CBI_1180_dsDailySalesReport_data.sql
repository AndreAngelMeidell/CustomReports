USE BI_Mart
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.usp_CBI_1180_dsDailySalesReport_data') AND type in (N'P', N'PC'))
	DROP PROCEDURE dbo.usp_CBI_1180_dsDailySalesReport_data
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE dbo.usp_CBI_1180_dsDailySalesReport_data
(
	@StoreOrGroupNo					varchar(max)
	,@PeriodType					char(1) 
	,@DateFrom						datetime 
	,@DateTo						datetime 
	,@YearToDate					integer
    ,@DateFromPeriod2				datetime 
	,@Year							integer             
	,@Option						integer
	,@RelativePeriodType			char(5)      
	,@RelativePeriodStart			integer  
	,@RelativePeriodDuration		integer  	
	,@ExcludeBottleDeposit			integer
	,@ExcludeThirdPartyArticles		integer
	,@ArticleIdFrom					varchar(50) = NULL
	,@ArticleIdTo					varchar(50) = NULL
    ,@GtinFrom						varchar(50) = NULL
	,@GtinTo						varchar(50) = NULL
	,@Monday						integer
	,@Tuesday						integer
	,@Wednesday						integer
	,@Thursday						integer
	,@Friday						integer
	,@Saturday						integer
	,@Sunday						integer
	,@Comparing						integer
)
as
begin

SET @ArticleIdFrom = CASE WHEN RTRIM(LTRIM(@ArticleIdFrom)) = '' THEN NULL ELSE @ArticleIdFrom END;
SET @ArticleIdTo = CASE WHEN RTRIM(LTRIM(@ArticleIdTo)) = '' THEN NULL ELSE @ArticleIdTo END;
SET @GtinFrom = CASE WHEN RTRIM(LTRIM(@GtinFrom)) = '' THEN NULL ELSE @GtinFrom END;
SET @GtinTo = CASE WHEN RTRIM(LTRIM(@GtinTo)) = '' THEN NULL ELSE @GtinTo END; 

----------------------------------------------------------------------
--Only Period1 selected and we do not want to compare. 
--For  Period2 messures we will have 0's and will not appear in report
----------------------------------------------------------------------
if @Comparing = 0 
	begin
	-- CTE contains stores that meets filtering requirements and flag IsCurrentStore=1
	;with Stores as
		(
		select
			distinct ds.*	--(RS-27332)
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
		select 
			sub.FullDate,
			sum(sub.NumberOfCustomersPeriod1)		AS NumberOfCustomersPeriod1,
			0										AS NumberOfCustomersPeriod2,
			sum(sub.QuantityOfArticlesSoldPeriod1)	AS QuantityOfArticlesSoldPeriod1,
			0										AS QuantityOfArticlesSoldPeriod2,
			sum(sub.SalesRevenueExclVatPeriod1)     AS SalesRevenueExclVatPeriod1,
			0										AS SalesRevenueExclVatPeriod2,
			sum(sub.SalesRevenuePeriod1)			AS SalesRevenueInclVatPeriod1,  -- ps. INCORRECT NAMING CONVENTION in sub, SalesRevenue is by default excl. VAT. this is incl.
			0										AS SalesRevenueInclVatPeriod2,  -- ps. INCORRECT NAMING CONVENTION in sub, SalesRevenue is by default excl. VAT. this is incl
			sum(sub.SalesVatAmountPeriod1)			AS SalesVatAmountPeriod1,
			0										AS SalesVatAmountPeriod2,
			sum(sub.GrossProfitPeriod1)				AS GrossProfitPeriod1,
			0										AS GrossProfitPeriod2,
			sum(sub.NetPurchasePricePeriod1)		AS NetPurchasePricePeriod1,
			0										AS NetPurchasePricePeriod2 ,
			case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) = 0 then 0 else round(SUM(NumberOfArticlesSoldPeriod1)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)),2) end
													AS AvgArticlesSoldPerCustomerPeriod1,
			0                                       AS AvgArticlesSoldPerCustomerPeriod2,
			case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) = 0 then 0 else SUM(SalesRevenueExclVatPeriod1)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) end 
													AS AvgSalesRevenueExclVatPerCustomerPeriod1,
			0	  									AS AvgSalesRevenueExclVatPerCustomerPeriod2,
			case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) = 0 then 0 else SUM(SalesRevenuePeriod1)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) end 
													AS AvgSalesRevenueInclVatPerCustomerPeriod1, 
			0                                       AS AvgSalesRevenueInclVatPerCustomerPeriod2,  
			case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) = 0 then 0 else SUM(GrossProfitPeriod1)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) end 
													AS AvgGrossProfitPerCustomerPeriod1,
			0                                       AS AvgGrossProfitPerCustomerPeriod2 
			,MIN(sub.UseDerivedNetPrice)			as UseDerivedNetPrice
			,MIN(sub.MINIsDerivedNetPriceUsed)      as MINIsDerivedNetPriceUsed
			,MAX(sub.MAXIsDerivedNetPriceUsed)      as MAXIsDerivedNetPriceUsed  
			,MIN(sub.UseDerivedNetPrice)+MIN(sub.MINIsDerivedNetPriceUsed) +MAX(sub.MAXIsDerivedNetPriceUsed)   as Config                                                                                                                                                                 
		from 
			(   
			select 
				f.FullDate
				,CASE WHEN @ArticleIdFrom IS NOT NULL OR @ArticleIdTo IS NOT NULL OR @GtinFrom IS NOT NULL OR @GtinTo IS NOT NULL THEN SUM(f.NumberOfCustomersPerSelectedArticle) ELSE SUM(f.NumberOfCustomers) END as NumberOfCustomersPeriod1
				,SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn)							as QuantityOfArticlesSoldPeriod1 --Trekker fra antall som er returnert, CGE, 26.04.2018
				,SUM(f.SalesAmountExclVat + f.ReturnAmountExclVat)									as SalesRevenueExclVatPeriod1
				,SUM(f.SalesAmount + f.ReturnAmount)												as SalesRevenuePeriod1
				,SUM(f.NumberOfArticlesSold-f.NumberOfArticlesInReturn)								as NumberOfArticlesSoldPeriod1
				,SUM(f.GrossProfit)																	as GrossProfitPeriod1 -- brutto
				,SUM(f.SalesVatAmount + f.ReturnAmount - f.ReturnAmountExclVat)						as SalesVatAmountPeriod1
				,SUM(f.NetPurchasePrice)															as NetPurchasePricePeriod1 -- varekost
				,MIN(CASE WHEN f.ArticleIdx > 0 THEN f.UseDerivedNetPrice ELSE NULL END)			as UseDerivedNetPrice
				,MIN(CASE WHEN f.ArticleIdx > 0 THEN f.IsDerivedNetPriceUsed ELSE NULL END)			as MINIsDerivedNetPriceUsed
				,MAX(CASE WHEN f.ArticleIdx > 0 THEN f.IsDerivedNetPriceUsed ELSE NULL END)			as MAXIsDerivedNetPriceUsed
			 from
				(
				select
					distinct dd.FullDate
					, f.*	                                                           
				from
					BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
				join rbim.Dim_Date       dd on dd.DateIdx    = f.ReceiptDateIdx 
				join rbim.Dim_Article    da on da.ArticleIdx = f.ArticleIdx 
				left join rbim.Dim_Gtin B on f.GtinIdx = B.GtinIdx --(RS-31431) Join with Gtin tables fixed
				join Stores ds on ds.StoreIdx = f.StoreIdx
				where
				--filter on period1                                                 
					  ((@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
					or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate  and dd.Dimlevel=0)
					or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
					or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
					or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
					or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0))
					and dd.Dateidx not in (-1,-2,-3,-4) 
					--filter on weekday    
					and  (  dd.DayNumberOfWeek = (case when @Monday=   1 then 1 else 0 end)
						 or dd.DayNumberOfWeek = (case when @Tuesday=  1 then 2 else 0 end)
						 or dd.DayNumberOfWeek = (case when @Wednesday=1 then 3 else 0 end)
						 or dd.DayNumberOfWeek = (case when @Thursday= 1 then 4 else 0 end)
						 or dd.DayNumberOfWeek = (case when @Friday=   1 then 5 else 0 end)
						 or dd.DayNumberOfWeek = (case when @Sunday=   1 then 6 else 0 end)
						 or dd.DayNumberOfWeek = (case when @Saturday= 1 then 7 else 0 end))
					--Filter on excluding third party articles
					and ((@ExcludeThirdPartyArticles = 1  AND ISNULL(da.Is3rdPartyArticle,0) = 0) OR  @ExcludeThirdPartyArticles = 0) 
					
					--Filter on excluding bottle deposit articles
					and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)
					--Filter on ArticleId	
					and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) >= CAST(CASE WHEN @ArticleIdFrom IS NULL AND ISNUMERIC(@ArticleIdFrom) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE @ArticleIdFrom END AS BIGINT) 
					and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) <= CAST(CASE WHEN @ArticleIdTo IS NULL AND ISNUMERIC(@ArticleIdTo) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE @ArticleIdTo END AS BIGINT) 
					--Filter on GTIN
					and (@GtinFrom IS NULL OR CAST(ISNULL(B.Gtin,@GtinFrom) AS BIGINT) >= CAST(@GtinFrom AS BIGINT)) and (@GtinTo IS NULL OR CAST(ISNULL(B.Gtin,@GtinTo) AS BIGINT) <= CAST(@GtinTo AS BIGINT))	
				) as f
				group by
					f.FullDate
			) as sub
		group by
			sub.FullDate
		)
		
	select * from SelectedSales order by FullDate asc
	return 
	end		-- if @Comparing = 0

----------------------------------------------------------------------
--Both Period1 and Period2 selected and we want to compare. 
----------------------------------------------------------------------

-----------------------------------------------------------------
--Date from should be recalculated in case
--we selected period type Y or R
--because we need to know DateFrom  for that period
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
	select
		sub.FullDate
		,sum(sub.NumberOfCustomersPeriod1)			AS NumberOfCustomersPeriod1
		,sum(sub.NumberOfCustomersPeriod2)			AS NumberOfCustomersPeriod2
		,sum(sub.QuantityOfArticlesSoldPeriod1)		AS QuantityOfArticlesSoldPeriod1
		,sum(sub.QuantityOfArticlesSoldPeriod2)		AS QuantityOfArticlesSoldPeriod2
		,sum(sub.SalesRevenueExclVatPeriod1)		AS SalesRevenueExclVatPeriod1 
		,sum(sub.SalesRevenueExclVatPeriod2) 		AS SalesRevenueExclVatPeriod2
		,sum(sub.SalesRevenuePeriod1)				AS SalesRevenueInclVatPeriod1 -- ps. INCORRECT NAMING CONVENTION in sub, SalesRevenue is by default excl. VAT.
		,sum(sub.SalesRevenuePeriod2)				AS SalesRevenueInclVatPeriod2 -- ps. INCORRECT NAMING CONVENTION in sub, SalesRevenue is by default excl. VAT.
		,sum(sub.SalesVatAmountPeriod1)				AS SalesVatAmountPeriod1
		,sum(sub.SalesVatAmountPeriod2)				AS SalesVatAmountPeriod2 
		,sum(sub.GrossProfitPeriod1)				AS GrossProfitPeriod1
		,sum(sub.GrossProfitPeriod2)				AS GrossProfitPeriod2 
		,sum(sub.NetPurchasePricePeriod1)			AS NetPurchasePricePeriod1
		,sum(sub.NetPurchasePricePeriod2)			AS NetPurchasePricePeriod2 
		,case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) = 0 then 0 else SUM(NumberOfArticlesSoldPeriod1)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) end AS AvgArticlesSoldPerCustomerPeriod1
		,case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod2)) = 0 then 0 else SUM(NumberOfArticlesSoldPeriod2)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod2)) end AS AvgArticlesSoldPerCustomerPeriod2 
		,case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) = 0 then 0 else SUM(SalesRevenueExclVatPeriod1)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) end AS AvgSalesRevenueExclVatPerCustomerPeriod1
		,case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod2)) = 0 then 0 else SUM(SalesRevenueExclVatPeriod2)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod2)) end AS AvgSalesRevenueExclVatPerCustomerPeriod2  
		,case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) = 0 then 0 else SUM(SalesRevenuePeriod1)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) end 
		AS AvgSalesRevenueInclVatPerCustomerPeriod1
		,case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod2)) = 0 then 0 else SUM(SalesRevenuePeriod2)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod2)) end 
		AS AvgSalesRevenueInclVatPerCustomerPeriod2  
		,case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) = 0 then 0 else SUM(GrossProfitPeriod1)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod1)) end AS AvgGrossProfitPerCustomerPeriod1
		,case when Convert(decimal(19,5), SUM(NumberOfCustomersPeriod2)) = 0 then 0 else SUM(GrossProfitPeriod2)/Convert(decimal(19,5), SUM(NumberOfCustomersPeriod2)) end AS AvgGrossProfitPerCustomerPeriod2  
		,MIN(sub.UseDerivedNetPrice)																		as UseDerivedNetPrice
		,MIN(sub.MINIsDerivedNetPriceUsed)																	as MINIsDerivedNetPriceUsed
		,MAX(sub.MAXIsDerivedNetPriceUsed)																	as MAXIsDerivedNetPriceUsed
		,MIN(sub.UseDerivedNetPrice)+MIN(sub.MINIsDerivedNetPriceUsed)+MAX(sub.MAXIsDerivedNetPriceUsed)	as CONFIG   
	from 

		--------------------------------------------------------------------
		--Data for Period 1
		--------------------------------------------------------------------
		(
		SELECT 
			f.FullDate
			,CASE WHEN @ArticleIdFrom IS NOT NULL OR @ArticleIdTo IS NOT NULL OR @GtinFrom IS NOT NULL OR @GtinTo IS NOT NULL THEN SUM(f.NumberOfCustomersPerSelectedArticle) ELSE SUM(f.NumberOfCustomers) END AS NumberOfCustomersPeriod1
			,0 as NumberOfCustomersPeriod2
			,SUM(f.QuantityOfArticlesSold - f.QuantityOfArticlesInReturn) as QuantityOfArticlesSoldPeriod1 -- antall varer, ikke distinct. CGE:26.04.2018 trekker fra antall returnert
			,0 as QuantityOfArticlesSoldPeriod2
			,SUM(f.SalesAmountExclVat + f.ReturnAmountExclVat)  as SalesRevenueExclVatPeriod1
			,0 as SalesRevenueExclVatPeriod2
			,SUM(f.SalesAmount + f.ReturnAmount) as SalesRevenuePeriod1 -- omsetning inkl. VAT
			,0 as SalesRevenuePeriod2										-- ps. INCORRECT NAMING CONVENTION, SalesRevenue is by default excl. VAT.
			,SUM(f.NumberOfArticlesSold-f.NumberOfArticlesInReturn) AS NumberOfArticlesSoldPeriod1
			,0 as NumberOfArticlesSoldPeriod2
			,SUM(f.GrossProfit) as GrossProfitPeriod1 -- brutto
			,0 as GrossProfitPeriod2
			,SUM(f.SalesVatAmount + f.ReturnAmount - f.ReturnAmountExclVat) as SalesVatAmountPeriod1
			,0 as SalesVatAmountPeriod2
			,SUM(f.NetPurchasePrice) as NetPurchasePricePeriod1 -- varekost
			,0 as NetPurchasePricePeriod2
			,MIN(CASE WHEN f.ArticleIdx > 0 THEN f.UseDerivedNetPrice ELSE NULL END)								as UseDerivedNetPrice
			,MIN(CASE WHEN f.ArticleIdx > 0 THEN f.IsDerivedNetPriceUsed ELSE NULL END)                           as MINIsDerivedNetPriceUsed
			,MAX(CASE WHEN f.ArticleIdx > 0 THEN f.IsDerivedNetPriceUsed ELSE NULL END)                           as MAXIsDerivedNetPriceUsed
			--------------------------------------------------------------------		
		FROM
			(
			SELECT DISTINCT
				dd.FullDate
				,f.*
			FROM
				BI_Mart.RBIM.Agg_SalesAndReturnPerHour f 
			join rbim.Dim_Date			dd on dd.DateIdx    = f.ReceiptDateIdx 
			join rbim.Dim_Article		da on da.ArticleIdx = f.ArticleIdx 
			left join rbim.Dim_Gtin		B on f.GtinIdx = B.GtinIdx
			join Stores ds on ds.StoreIdx = f.StoreIdx
			WHERE
				--filter on period1 
					((@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
				or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate  and dd.Dimlevel=0)
				or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
				or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
				or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
				or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0))
				and dd.Dateidx not in (-1,-2,-3,-4) 
				--filter on weekday  
				and (   dd.DayNumberOfWeek = (case when @Monday=   1 then 1 else 0 end)
					  or dd.DayNumberOfWeek = (case when @Tuesday=  1 then 2 else 0 end)
					  or dd.DayNumberOfWeek = (case when @Wednesday=1 then 3 else 0 end)
					  or dd.DayNumberOfWeek = (case when @Thursday= 1 then 4 else 0 end)
					  or dd.DayNumberOfWeek = (case when @Friday=   1 then 5 else 0 end)
					  or dd.DayNumberOfWeek = (case when @Sunday=   1 then 6 else 0 end)
					  or dd.DayNumberOfWeek = (case when @Saturday= 1 then 7 else 0 end))

				--Filter on excluding third party articles
				and ((@ExcludeThirdPartyArticles = 1 AND ISNULL(da.Is3rdPartyArticle,0) = 0) OR @ExcludeThirdPartyArticles = 0) 

				--Filter on excluding bottle deposit articles
				and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)

				--Filter on ArticleId
				and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) >= CAST(CASE WHEN @ArticleIdFrom           IS NULL AND ISNUMERIC(@ArticleIdFrom) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE         @ArticleIdFrom END AS BIGINT) 
				and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) <= CAST(CASE WHEN @ArticleIdTo           IS NULL AND ISNUMERIC(@ArticleIdTo) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE         @ArticleIdTo END AS BIGINT) 

				--Filter on GTIN
				and (@GtinFrom IS NULL OR CAST(ISNULL(B.Gtin,@GtinFrom) AS BIGINT) >= CAST(@GtinFrom AS BIGINT)) and (@GtinTo IS NULL OR CAST(ISNULL(B.Gtin,@GtinTo) AS BIGINT) <= CAST(@GtinTo AS BIGINT))	
			) AS f
		GROUP BY
			f.FullDate
		
		UNION
		
		--------------------------------------------------------------------
		--Data for Period 2
		--------------------------------------------------------------------
		SELECT 
			f.FullDate
			,0 as NumberOfCustomersPeriod1
			,CASE WHEN @ArticleIdFrom IS NOT NULL OR @ArticleIdTo IS NOT NULL OR @GtinFrom IS NOT NULL OR @GtinTo IS NOT NULL THEN SUM(f.NumberOfCustomersPerSelectedArticle) ELSE SUM(f.NumberOfCustomers) END AS NumberOfCustomersPeriod2
			,0																				as QuantityOfArticlesSoldPeriod1
			,SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) as QuantityOfArticlesSoldPeriod2
			,0																				as SalesRevenueExclVatPeriod1
			,SUM(f.SalesAmountExclVat + f.ReturnAmountExclVat)								as SalesRevenueExclVatPeriod2
			,0																				as SalesRevenuePeriod1 -- ps. INCORRECT NAMING CONVENTION, SalesRevenue is by default excl. VAT.
			,SUM(f.SalesAmount + f.ReturnAmount) as SalesRevenuePeriod2
			,0																				as NumberOfArticlesSoldPeriod1
			,SUM(f.NumberOfArticlesSold-f.NumberOfArticlesInReturn) AS NumberOfArticlesSoldPeriod2
			,0																				as GrossProfitPeriod1
			,SUM(f.GrossProfit) as GrossProfitPeriod2 -- brutto
			,0																				as SalesVatAmountPeriod1
			,SUM(f.SalesVatAmount + f.ReturnAmount - f.ReturnAmountExclVat)					as SalesVatAmountPeriod2
			,0																				as NetPurchasePricePeriod1
			,SUM(f.NetPurchasePrice)														as NetPurchasePricePeriod2 -- varekost
			,MIN(CASE WHEN f.ArticleIdx > 0 THEN f.UseDerivedNetPrice ELSE NULL END)		as UseDerivedNetPrice
			,MIN(CASE WHEN f.ArticleIdx > 0 THEN f.IsDerivedNetPriceUsed ELSE NULL END)		as MINIsDerivedNetPriceUsed
			,MAX(CASE WHEN f.ArticleIdx > 0 THEN f.IsDerivedNetPriceUsed ELSE NULL END)		as MAXIsDerivedNetPriceUsed
		FROM
			(
			SELECT DISTINCT
				dd.FullDate
				,f.*
			from
				BI_Mart.RBIM.Agg_SalesAndReturnPerDay f 
			join rbim.Dim_Date       dd on dd.DateIdx    = f.ReceiptDateIdx 
			join rbim.Dim_Article    da on da.ArticleIdx = f.ArticleIdx 
			join rbim.Dim_Store      ds on ds.StoreIdx   = f.StoreIdx
			LEFT join rbim.Dim_Gtin B on f.GtinIdx = B.GtinIdx --(RS-31431) Join with Gtin tables fixed
			join Stores ds2 on ds2.StoreIdx = f.StoreIdx
			WHERE
				--filter on period2
				(dd.FullDate between @DateFromPeriod2 and @DateToPeriod2)
				and dd.Dateidx not in (-1,-2,-3,-4) 
				--filter on weekday 
				and (  dd.DayNumberOfWeek = (case when @Monday   =1 then 1 else 0 end)
					or dd.DayNumberOfWeek = (case when @Tuesday  =1 then 2 else 0 end)
					or dd.DayNumberOfWeek = (case when @Wednesday=1 then 3 else 0 end)
					or dd.DayNumberOfWeek = (case when @Thursday =1 then 4 else 0 end)
					or dd.DayNumberOfWeek = (case when @Friday   =1 then 5 else 0 end)
					or dd.DayNumberOfWeek = (case when @Sunday   =1 then 6 else 0 end)
					or dd.DayNumberOfWeek = (case when @Saturday =1 then 7 else 0 end))
				--Filter on excluding third party articles
				and ((@ExcludeThirdPartyArticles = 1 AND ISNULL(da.Is3rdPartyArticle,0) = 0) OR  @ExcludeThirdPartyArticles = 0) 
				--Filter on excluding bottle deposit articles
				and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)
				--Filter on ArticleId
				and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) >= CAST(CASE WHEN @ArticleIdFrom           IS NULL AND ISNUMERIC(@ArticleIdFrom) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE         @ArticleIdFrom END AS BIGINT) 
				and CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) <= CAST(CASE WHEN @ArticleIdTo           IS NULL AND ISNUMERIC(@ArticleIdTo) = 0 THEN CAST(CASE WHEN ISNUMERIC(da.ArticleId) = 0 THEN CAST(-1 as bigint) ELSE da.ArticleId END AS BIGINT) ELSE         @ArticleIdTo END AS BIGINT) 

				--Filter on GTIN
				and (@GtinFrom IS NULL OR CAST(ISNULL(B.Gtin,@GtinFrom) AS BIGINT) >= CAST(@GtinFrom AS BIGINT)) and (@GtinTo IS NULL OR CAST(ISNULL(B.Gtin,@GtinTo) AS BIGINT) <= CAST(@GtinTo AS BIGINT))	
			) AS f
			GROUP BY
				f.FullDate
		) AS sub
		GROUP BY
			FullDate
	)

	select * from SelectedSales order by FullDate asc

END


GO


