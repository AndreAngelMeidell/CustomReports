USE [BI_Mart]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1156_dsHourlySalesReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1156_dsHourlySalesReport_data]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Get revenue for a store for selected period.
-- =============================================
CREATE PROCEDURE [dbo].[usp_CBI_1156_dsHourlySalesReport_data] (
	@StoreId					as varchar(100)        
	,@PeriodType				as char(1) 
	,@DateFrom					as datetime 
	,@DateTo					as datetime 
	,@YearToDate				as integer
	,@DateFromPeriod2			as datetime 
	--,@DateToPeriod2			as datetime   
	,@Year						as integer             
	,@Option					as integer
	,@RelativePeriodType		as char(5)      
	,@RelativePeriodStart		as integer  
	,@RelativePeriodDuration	as integer  	
	,@ExcludeBottleDeposit		as integer
	,@ExcludeThirdPartyArticles	as integer
	,@ArticleIdFrom				as varchar(50)
	,@ArticleIdTo				as varchar(50)
	,@GtinFrom					as varchar(50)
	,@GtinTo					as varchar(50)
	,@Monday					as integer
	,@Tuesday					as integer
	,@Wednesday					as integer
	,@Thursday					as integer
	,@Friday					as integer
	,@Saturday					as integer
	,@Sunday					as integer
	,@Comparing					as integer
	,@GroupByDay				as integer
)
AS
BEGIN

-- If [Null] is removed from input control search field (first filter on gtin/articleId and then remove filter), 
-- a empty string is passed instead of a null value
SET @GtinFrom		= CASE WHEN @GtinFrom = ''		THEN NULL ELSE @GtinFrom END;
SET @GtinTo			= CASE WHEN @GtinTo = ''		THEN NULL ELSE @GtinTo END;
SET @ArticleIdFrom	= CASE WHEN @ArticleIdFrom = ''	THEN NULL ELSE @ArticleIdFrom END;
SET @ArticleIdTo	= CASE WHEN @ArticleIdTo = ''	THEN NULL ELSE @ArticleIdTo END;

----------------------------------------------------------------------
--Only Period1 selected and we do not want to compare. 
--For  Period2 messures we will have 0's and will not appear in report
----------------------------------------------------------------------
if @Comparing = 0 
	begin
	select 
		sub.SalesDate
		,sub.[Hour]
		,sum(sub.NumberOfCustomersPeriod1)			as NumberOfCustomersPeriod1
		,0											as NumberOfCustomersPeriod2
		,sum(sub.QuantityOfArticlesSoldPeriod1)		as QuantityOfArticlesSoldPeriod1
		,0											as QuantityOfArticlesSoldPeriod2
		,sum(sub.SalesRevenueExclVatPeriod1)		as SalesRevenueExclVatPeriod1
		,0											as SalesRevenueExclVatPeriod2
		,sum(sub.SalesRevenuePeriod1)				as SalesRevenuePeriod1
		,0											as SalesRevenuePeriod2 
		,sum(sub.SalesVatAmountPeriod1)				as SalesVatAmountPeriod1
		,0											as SalesVatAmountPeriod2 
		,sum(sub.GrossProfitPeriod1)				as GrossProfitPeriod1
		,0											as GrossProfitPeriod2 
		,sum(sub.NetPurchasePricePeriod1)			as NetPurchasePricePeriod1
		,0											as NetPurchasePricePeriod2 
		,case when convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) = 0 then 0 else sum(NumberOfArticlesSoldPeriod1)/convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) end	as AvgArticlesSoldPerCustomerPeriod1
		,0											as AvgArticlesSoldPerCustomerPeriod2 
		,case when convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) = 0 then 0 else sum(SalesRevenuePeriod1)/convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) end			as AvgSalesRevenueInclVatPerCustomerPeriod1
		,0											as AvgSalesRevenueInclVatPerCustomerPeriod2  
		,case when convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) = 0 then 0 else sum(GrossProfitPeriod1)/convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) end			as AvgGrossProfitPerCustomerPeriod1
		,0											as AvgGrossProfitPerCustomerPeriod2                                                                                                                                                                      
	from
		(  
		select 
			ff.SalesDate
			,ff.[Hour]
			--------------------------------------------------------------------
			--NumberOfCustomers (Antall Kunder)
			--------------------------------------------------------------------
			,sum(ff.NumberOfCustomers) as NumberOfCustomersPeriod1
			--------------------------------------------------------------------
			--QuantityOfArticlesSold (Antall Varer)
			--------------------------------------------------------------------
			,sum(ff.QuantityOfArticlesSold - ff.QuantityOfArticlesInReturn) as QuantityOfArticlesSoldPeriod1
			--------------------------------------------------------------------
			--SalesRevenue excl vat (Omsetning u/mva)
			--------------------------------------------------------------------
			,sum(ff.SalesAmountExclVat + ff.ReturnAmountExclVat) as SalesRevenueExclVatPeriod1
			--------------------------------------------------------------------
			--SalesRevenue (Omsetning inkl mva)
			--------------------------------------------------------------------
			,sum(ff.SalesAmount + ff.ReturnAmount) as SalesRevenuePeriod1
			--------------------------------------------------------------------
			--Number of Articles sold 
			--------------------------------------------------------------------
			,sum(ff.QuantityOfArticlesSold - ff.QuantityOfArticlesInReturn) as NumberOfArticlesSoldPeriod1
			--------------------------------------------------------------------
			--GrossProfit (Brutto)
			--------------------------------------------------------------------
			,sum(ff.GrossProfit) as GrossProfitPeriod1
			--------------------------------------------------------------------
			--SalesVatAmount (Mva)
			--------------------------------------------------------------------
			,sum(ff.SalesVatAmount) as SalesVatAmountPeriod1
			--------------------------------------------------------------------
			--NetPurchasePrice (Varekostnad)
			--------------------------------------------------------------------
			,sum(ff.NetPurchasePrice) as NetPurchasePricePeriod1
			--------------------------------------------------------------------
		 from
			(
			select distinct
				case @GroupByDay	when 1 then dd.FullDate else null		end	as 'SalesDate'
				,case @GroupByDay 	when 1 then	null		else dt.[Hour]	end	as 'Hour'
				,f.*
			from
				BI_Mart.RBIM.Agg_SalesAndReturnPerHour f (NOLOCK)
			inner join rbim.Dim_Date				dd	(NOLOCK) ON dd.DateIdx		= f.ReceiptDateIdx 
			inner join rbim.Dim_Time				dt	(NOLOCK) ON dt.TimeIdx		= f.ReceiptTimeIdx
			inner join rbim.Dim_Article				da	(NOLOCK) ON da.ArticleIdx	= f.ArticleIdx 
			inner join rbim.Dim_Store				ds	(NOLOCK) ON ds.StoreIdx		= f.storeidx
			left outer join rbim.Cov_ArticleGtin	a	(NOLOCK) ON f.ArticleIdx	= a.ArticleIdx  
			left outer join rbim.Dim_Gtin        	b	(NOLOCK) ON a.GtinIdx		= b.GtinIdx
			where
					isnull(a.IsDefaultGtin,1) = 1
				--filter on store
				and	@StoreId = ds.StoreId 
				and	ds.StoreIdx >= 0
				and	ds.isCurrentStore = 1   -- make sure you only get the 'current store' (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
				and
					--filter on period1                                                 
						((@PeriodType='D' and dd.FullDate between convert(date,@DateFrom) and convert(date,@DateTo))
					or (@PeriodType='Y' and dd.RelativeYTD = @YearToDate  and dd.Dimlevel=0)
					or (@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek		between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
					or (@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth		between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
					or (@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter	between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
					or (@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear		between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0))
				and dd.Dateidx not in (-1,-2,-3,-4) 
				--filter on weekday    
				and  (  dd.DayNumberOfWeek = (case when @Monday=   1 then 1 else 0 end)
						or dd.DayNumberOfWeek = (case when @Tuesday=  1 then 2 else 0 end)
						or dd.DayNumberOfWeek = (case when @Wednesday=1 then 3 else 0 end)
						or dd.DayNumberOfWeek = (case when @Thursday= 1 then 4 else 0 end)
						or dd.DayNumberOfWeek = (case when @Friday=   1 then 5 else 0 end)
						or dd.DayNumberOfWeek = (case when @Sunday=   1 then 6 else 0 end)
						or dd.DayNumberOfWeek = (case when @Saturday= 1 then 7 else 0 end))
				--filter on articles
				--and da.ArticleIdx > -1 			-- needs to be included if you should exclude LADs etc.  
				and da.ArticleIdx not in (-2,-3)

				--Filter on excluding bottle deposit articles
				and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)

				--Filter on ArticleId	
				and da.ArticleId        >= (case when @ArticleIdFrom    is null then da.ArticleId else       @ArticleIdFrom end)
				and da.ArticleId        <= (case when @ArticleIdTo      is null then da.ArticleId else       @ArticleIdTo   end)

				--filter on barcode
				and isnull(da.Is3rdPartyArticle, 0)	= case when @ExcludeThirdPartyArticles = 1 then  0 else isnull(da.Is3rdPartyArticle,0) end 
				and isnull(b.Gtin,0)	>= cast(case when @GtinFrom is null then isnull(b.Gtin,0) else @GtinFrom end as bigint)				
				and isnull(b.Gtin,0)	<= cast(case when @GtinTo is null then isnull(b.Gtin,0) else @GtinTo end as bigint)					
			) as ff
			group by
				ff.SalesDate
				,ff.[Hour]
		) as sub
		group by
			sub.SalesDate
			,sub.[Hour]

	return 
	end

----------------------------------------------------------------------
--Both Period1 and Period2 selected and we want to compare. 
----------------------------------------------------------------------

-----------------------------------------------------------------
--Date from should be recalculated in case
--we selected period type Y or R
--because we need to know DateFrom  for that period
--to compare it with another period
----------------------------------------------------------------
set @DateFrom = (select  top 1 convert(date,FullDate)
             from RBIM.Dim_Date as dd
             where       --filter on period1 
						((@PeriodType='D' and dd.FullDate = convert(date,@DateFrom))
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
   where   FullDate = convert(date,@DateFrom)

  
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

select
	sub.SalesDate
	,sub.[Hour]
	,sum(sub.NumberOfCustomersPeriod1)		as NumberOfCustomersPeriod1
	,sum(sub.NumberOfCustomersPeriod2)		as NumberOfCustomersPeriod2
	,sum(sub.QuantityOfArticlesSoldPeriod1)	as QuantityOfArticlesSoldPeriod1
	,sum(sub.QuantityOfArticlesSoldPeriod2)	as QuantityOfArticlesSoldPeriod2
	,sum(sub.SalesRevenueExclVatPeriod1)	as SalesRevenueExclVatPeriod1
	,sum(sub.SalesRevenueExclVatPeriod2)	as SalesRevenueExclVatPeriod2
	,sum(sub.SalesRevenuePeriod1)			as SalesRevenuePeriod1
	,sum(sub.SalesRevenuePeriod2)			as SalesRevenuePeriod2 
	,sum(sub.SalesVatAmountPeriod1)			as SalesVatAmountPeriod1
	,sum(sub.SalesVatAmountPeriod2)			as SalesVatAmountPeriod2 
	,sum(sub.GrossProfitPeriod1)			as GrossProfitPeriod1
	,sum(sub.GrossProfitPeriod2)			as GrossProfitPeriod2 
	,sum(sub.NetPurchasePricePeriod1)		as NetPurchasePricePeriod1
	,sum(sub.NetPurchasePricePeriod2)		as NetPurchasePricePeriod2 
	,case when convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) = 0 then 0 else sum(NumberOfArticlesSoldPeriod1)/Convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) end	as AvgArticlesSoldPerCustomerPeriod1
	,case when convert(decimal(19,5), sum(NumberOfCustomersPeriod2)) = 0 then 0 else sum(NumberOfArticlesSoldPeriod2)/Convert(decimal(19,5), sum(NumberOfCustomersPeriod2)) end	as AvgArticlesSoldPerCustomerPeriod2 
	,case when convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) = 0 then 0 else sum(SalesRevenuePeriod1)/Convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) end 		as AvgSalesRevenueInclVatPerCustomerPeriod1
	,case when convert(decimal(19,5), sum(NumberOfCustomersPeriod2)) = 0 then 0 else sum(SalesRevenuePeriod2)/Convert(decimal(19,5), sum(NumberOfCustomersPeriod2)) end 		as AvgSalesRevenueInclVatPerCustomerPeriod2  
	,case when convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) = 0 then 0 else sum(GrossProfitPeriod1)/Convert(decimal(19,5), sum(NumberOfCustomersPeriod1)) end 			as AvgGrossProfitPerCustomerPeriod1
	,case when convert(decimal(19,5), sum(NumberOfCustomersPeriod2)) = 0 then 0 else sum(GrossProfitPeriod2)/Convert(decimal(19,5), sum(NumberOfCustomersPeriod2)) end 			as AvgGrossProfitPerCustomerPeriod2  
 from 
	--------------------------------------------------------------------
	--Data for Period 1
	--------------------------------------------------------------------
	(
	select
		ff.SalesDate
		,ff.[Hour]
		--------------------------------------------------------------------
		--NumberOfCustomers (Antall Kunder)
		--------------------------------------------------------------------
		,sum(ff.[NumberOfCustomers])										as NumberOfCustomersPeriod1
		,0																	as NumberOfCustomersPeriod2
		--------------------------------------------------------------------
		--QuantityOfArticlesSold (Antall Varer)
		--------------------------------------------------------------------
		,sum(ff.[QuantityOfArticlesSold] - ff.QuantityOfArticlesInReturn)	as QuantityOfArticlesSoldPeriod1
		,0																	as QuantityOfArticlesSoldPeriod2
		--------------------------------------------------------------------
		--SalesRevenue excl vat (Omsetning u/mva)
		--------------------------------------------------------------------
		,sum(ff.[SalesAmountExclVat] + ff.[ReturnAmountExclVat])			as SalesRevenueExclVatPeriod1
		,0																	as SalesRevenueExclVatPeriod2
		--------------------------------------------------------------------
		--SalesRevenue (Omsetning inkl mva)
		--------------------------------------------------------------------
		,sum(ff.[SalesAmount] + ff.[ReturnAmount])							as SalesRevenuePeriod1
		,0																	as SalesRevenuePeriod2
		--------------------------------------------------------------------
		--Number of Articles sold 
		--------------------------------------------------------------------
		,sum(ff.[QuantityOfArticlesSold] - ff.QuantityOfArticlesInReturn)	as NumberOfArticlesSoldPeriod1
		,0																	as NumberOfArticlesSoldPeriod2
		--------------------------------------------------------------------
		--GrossProfit (Brutto)
		--------------------------------------------------------------------
		,sum(ff.GrossProfit)												as GrossProfitPeriod1
		,0																	as GrossProfitPeriod2
		--------------------------------------------------------------------
		--SalesVatAmount (Mva)
		--------------------------------------------------------------------
		,sum(ff.SalesVatAmount)												as SalesVatAmountPeriod1
		,0																	as SalesVatAmountPeriod2
		--------------------------------------------------------------------
		--NetPurchasePrice (Varekostnad)
		--------------------------------------------------------------------
		,sum(ff.NetPurchasePrice)											as NetPurchasePricePeriod1
		,0																	as NetPurchasePricePeriod2
		--------------------------------------------------------------------		
	from
		(
		select distinct
			case @GroupByDay	when 1 then dd.FullDate else null		end	as 'SalesDate'
			,case @GroupByDay 	when 1 then	null		else dt.[Hour]	end	as 'Hour'
			,f.*
		from
			BI_Mart.RBIM.Agg_SalesAndReturnPerHour f (NOLOCK)
			inner join rbim.Dim_Date				dd	(NOLOCK) ON dd.DateIdx		= f.ReceiptDateIdx 
			inner join rbim.Dim_Time				dt	(NOLOCK) ON dt.TimeIdx		= f.ReceiptTimeIdx
			inner join rbim.Dim_Article				da	(NOLOCK) ON da.ArticleIdx	= f.ArticleIdx
			--inner join rbim.Dim_UnknownArticle	ua on ua.UnknownArticleIdx = f.ArticleIdx
			inner join rbim.Dim_Store				ds	(NOLOCK) ON ds.StoreIdx		= f.StoreIdx
			left outer join rbim.Cov_ArticleGtin	a	(NOLOCK) ON f.ArticleIdx	= a.ArticleIdx                
			left outer join rbim.Dim_Gtin			b	(NOLOCK) ON a.GtinIdx		= b.GtinIdx
		where
				isnull(a.IsDefaultGtin,1) = 1
			--filter on store
			and	@StoreId = ds.StoreId 
			and	ds.StoreIdx >= 0
			and	ds.isCurrentStore = 1	-- make sure you only get the 'current store' (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
			--filter on period1 
			and	(	(@PeriodType='D' and dd.FullDate between convert(date,@DateFrom) and convert(date,@DateTo))
				or	(@PeriodType='Y' and dd.RelativeYTD = @YearToDate  and dd.Dimlevel=0)
				or	(@PeriodType='R' and @RelativePeriodType = 'W' and dd.RelativeWeek between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
				or	(@PeriodType='R' and @RelativePeriodType = 'M' and dd.RelativeMonth between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
				or	(@PeriodType='R' and @RelativePeriodType = 'Q' and dd.RelativeQuarter between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0)
				or	(@PeriodType='R' and @RelativePeriodType = 'Y' and dd.RelativeYear between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration and dd.Dimlevel=0))
				and dd.Dateidx not in (-1,-2,-3,-4) 
			--filter on weekday
			and	(	dd.DayNumberOfWeek = (case when @Monday=   1 then 1 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Tuesday=  1 then 2 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Wednesday=1 then 3 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Thursday= 1 then 4 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Friday=   1 then 5 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Sunday=   1 then 6 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Saturday= 1 then 7 else 0 end))
			--filter on articles
			and	da.articleidx not in (-2,-3)
					
			--Filter on excluding bottle deposit articles
			and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)
					
					--Filter on ArticleId
			and	da.ArticleId	>= (case when @ArticleIdFrom    is null then da.ArticleId else       @ArticleIdFrom end)
			and	da.ArticleId	<= (case when @ArticleIdTo      is null then da.ArticleId else       @ArticleIdTo   end)

			--Filter on barcode
			and	isnull(da.Is3rdPartyArticle, 0)	= case when @ExcludeThirdPartyArticles = 1 then  0 else isnull(da.Is3rdPartyArticle,0) end 

			--Filter on GTIN
			and	isnull(b.Gtin,0)	>= cast(case when @GtinFrom is null then isnull(b.Gtin,0) else @GtinFrom end as bigint)				
			and isnull(b.Gtin,0)	<= cast(case when @GtinTo is null then isnull(b.Gtin,0) else @GtinTo end as bigint)	
		) as ff
	group by
		ff.SalesDate
		,ff.[Hour]

	union

	--------------------------------------------------------------------
	--Data for Period 2
	--------------------------------------------------------------------
	select 
		ff.SalesDate
		,ff.[Hour]
		--------------------------------------------------------------------
		--NumberOfCustomers (Antall Kunder)
		--------------------------------------------------------------------
		,0																	as NumberOfCustomersPeriod1
		,sum(ff.[NumberOfCustomers])										as NumberOfCustomersPeriod2
		--------------------------------------------------------------------
		--QuantityOfArticlesSold (Antall Varer)
		--------------------------------------------------------------------
		,0																	as QuantityOfArticlesSoldPeriod1
		,sum(ff.[QuantityOfArticlesSold] - ff.QuantityOfArticlesInReturn)	as QuantityOfArticlesSoldPeriod2
		--------------------------------------------------------------------
		--SalesRevenue excl vat (Omsetning u/mva)
		--------------------------------------------------------------------
		,0																	as SalesRevenueExclVatPeriod1
		,sum(ff.[SalesAmountExclVat] + ff.[ReturnAmountExclVat])			as SalesRevenueExclVatPeriod2
		--------------------------------------------------------------------
		--SalesRevenue (Omsetning inkl mva)
		--------------------------------------------------------------------
		,0																	as SalesRevenuePeriod1
		,sum(ff.[SalesAmount] + ff.[ReturnAmount])							as SalesRevenuePeriod2
		--------------------------------------------------------------------
		--Number of Articles sold 
		--------------------------------------------------------------------
		,0																	as NumberOfArticlesSoldPeriod1
		,sum(ff.[QuantityOfArticlesSold] - ff.QuantityOfArticlesInReturn)	as NumberOfArticlesSoldPeriod2
		--------------------------------------------------------------------
		--GrossProfit (Brutto)
		--------------------------------------------------------------------
		,0																	as GrossProfitPeriod1
		,sum(ff.GrossProfit)												as GrossProfitPeriod2
		--------------------------------------------------------------------
		--SalesVatAmount (Mva)
		--------------------------------------------------------------------
		,0																	as SalesVatAmountPeriod1
		,sum(ff.SalesVatAmount)												as SalesVatAmountPeriod2
		--------------------------------------------------------------------
		--NetPurchasePrice (Varekostnad)
		--------------------------------------------------------------------
		,0																	as NetPurchasePricePeriod1
		,sum(ff.NetPurchasePrice)											as NetPurchasePricePeriod2
		--------------------------------------------------------------------	
	from
		(
		select distinct
			case @GroupByDay	when 1 then dd.FullDate else null		end	as 'SalesDate'
			,case @GroupByDay 	when 1 then	null		else dt.[Hour]	end	as 'Hour'
			,f.*
		from
			BI_Mart.RBIM.Agg_SalesAndReturnPerHour f (NOLOCK)
			inner join rbim.Dim_Date				dd	(NOLOCK) ON dd.DateIdx    = f.ReceiptDateIdx 
			inner join rbim.Dim_Time				dt	(NOLOCK) ON dt.TimeIdx    = f.ReceiptTimeIdx
			inner join rbim.Dim_Article				da	(NOLOCK) ON da.ArticleIdx = f.ArticleIdx 
			--inner join rbim.Dim_UnknownArticle ua on ua.UnknownArticleIdx = f.ArticleIdx
			inner join rbim.Dim_Store				ds	(NOLOCK) ON ds.StoreIdx   = f.StoreIdx
			left outer join rbim.Cov_ArticleGtin	a	(NOLOCK) ON f.ArticleIdx  = a.ArticleIdx               
			left outer join rbim.Dim_Gtin			b	(NOLOCK) ON a.GtinIdx     = b.GtinIdx
		where
				isnull(a.IsDefaultGtin,1) = 1
			--filter on store
			and	@StoreId = ds.StoreId 
			and	ds.StoreIdx >= 0
			and	ds.isCurrentStore = 1	-- make sure you only get the 'current store' (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current) 
			--filter on period2
			and	(dd.FullDate between convert(date,@DateFromPeriod2) and convert(date,@DateToPeriod2))
			and	dd.Dateidx not in (-1,-2,-3,-4) 
			--filter on weekday 
			and	(	dd.DayNumberOfWeek = (case when @Monday   =1 then 1 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Tuesday  =1 then 2 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Wednesday=1 then 3 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Thursday =1 then 4 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Friday   =1 then 5 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Sunday   =1 then 6 else 0 end)
				or	dd.DayNumberOfWeek = (case when @Saturday =1 then 7 else 0 end))
			--filter on articles
			and	da.articleidx not in (-2,-3)
			
			--Filter on excluding bottle deposit articles
			and ((@ExcludeBottleDeposit = 1 AND da.ArticleTypeId NOT IN (-98,-99,130,132,133)) OR @ExcludeBottleDeposit = 0)
					
			--Filter on ArticleId
			and da.ArticleId	>= (case when @ArticleIdFrom	is null then da.ArticleId else 	@ArticleIdFrom	end)
			and da.ArticleId	<= (case when @ArticleIdTo		is null then da.ArticleId else	@ArticleIdTo	end)
			--filter on barcode
			and isnull(da.Is3rdPartyArticle, 0)	= case when @ExcludeThirdPartyArticles = 1 then  0 else isnull(da.Is3rdPartyArticle,0) end 
			and isnull(b.Gtin,0) >= cast(case when @GtinFrom is null	then isnull(b.Gtin,0) else @GtinFrom end	as bigint)				
			and isnull(b.Gtin,0) <= cast(case when @GtinTo is null		then isnull(b.Gtin,0) else @GtinTo end		as bigint)	
		) as ff
	group by
		ff.SalesDate
		,ff.[Hour]
	) as sub
group by
	sub.SalesDate
	,sub.[Hour]

END