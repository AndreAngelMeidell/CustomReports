USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1189_dsPickAndCollectQuantityFiguresReport_data]    Script Date: 24.01.2017 15:22:51 ******/
DROP PROCEDURE [dbo].[usp_CBI_1189_dsPickAndCollectQuantityFiguresReport_data]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1189_dsPickAndCollectQuantityFiguresReport_data]    Script Date: 24.01.2017 15:22:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[usp_CBI_1189_dsPickAndCollectQuantityFiguresReport_data]
(   
	@StoreId	varchar(100),
	@DateFrom	datetime, 
	@DateTo		datetime,
	@ReportType smallint,	-- 0 all flights, 1 departure, 2 arrival--, 3 extra
	@WhichSales	smallint	-- 0 all sales, 1 Pick And Collect, 2 all sales except Pick And Collect
) 
as  
begin

set nocount on  

declare @DateFromIdx int = cast(convert(varchar(8),@DateFrom, 112) as integer)
declare @DateToIdx int = cast(convert(varchar(8),@DateTo, 112) as integer)

if (@WhichSales=0)	-- 0=all sales
begin
	select
		case when NumOfHierarchyLevels >= 2 then sales.Lev2ArticleHierarchyId
			else case when NumOfHierarchyLevels = 1 then sales.ArticleHierarchyId 
						else 'Ukjent' end 
				end				as ArticleHierarchyId, 
		case when NumOfHierarchyLevels >= 2 then  sales.Lev2ArticleHierarchyName
			else case when	NumOfHierarchyLevels = 1 then sales.ArticleHierarchyName
					else 'Ukjent' end 
			end 				as ArticleHierarchyName,
		sum(NoOfArticlesSold)	as NoOfArticlesSold,
		sum(UnitsSold)			as UnitsSold,
		sum(Revenue)			as Revenue,
		sum(RevenueInclVat)		as RevenueInclVat
	from
		(
		select
			ds.StoreId
			,ds.StoreName
			,floor(se.ReceiptIdx/1000)	as ReceiptHeadIdx
			,case se.TransTypeValueTxt4
				when 'D' then	se.TransTypeValueTxt1 + ' - ' + se.TransTypeValueTxt3 
				when 'A' then	se.TransTypeValueTxt1 + ' - ' + se.TransTypeValueTxt2	
				else 			transtypevaluetxt1	
			end as 'FlightNo'
			,case se.TransTypeValueTxt4
				when 'D' then	'Avgang'
				when 'A' then	'Ankomst'
				when ''  then	'Ekstra	'
				else 			''	
			end	as 'FlightType'
		from
			RBIM.Cov_customersalesevent se	(nolock)
		inner join RBIM.Dim_TransType tt	(nolock)  on tt.TransTypeIdx = Se.TransTypeIdx
		inner join RBIM.Dim_store ds		(nolock)  on ds.StoreIdx=se.StoreIdx
		where
				ds.StoreId=@StoreId
			and	ds.isCurrent=1
			and tt.transtypeId = 90403	-- 	90403=Air Travel
			and se.ReceiptDateIdx between @DateFromIdx AND @DateToIdx	
			and (
					@ReportType = 0										-- all flights
				OR (@ReportType = 1 AND se.TransTypeValueTxt4 = 'D')	-- departure flights
				OR (@ReportType = 2 AND se.TransTypeValueTxt4 = 'A')	-- arrival flights
				OR (@ReportType = 3 AND se.TransTypeValueTxt4 = '')		-- extra flights
				)
		) flight
	inner join
		(
		select 
			floor(f.ReceiptIdx/1000)									as ReceiptHeadIdx
			,da.Lev1ArticleHierarchyId									as ArticleHierarchyId
			,da.Lev1ArticleHierarchyName								as ArticleHierarchyName
			,da.Lev2ArticleHierarchyId									as Lev2ArticleHierarchyId
			,da.Lev2ArticleHierarchyName								as Lev2ArticleHierarchyName
			,da.NumOfHierarchyLevels									as NumOfHierarchyLevels
			,sum(f.QuantityOfArticlesSold - f.QuantityOfArticlesInReturn)									as NoOfArticlesSold
			,sum((f.QuantityOfArticlesSold - f.QuantityOfArticlesInReturn) * da.UnitOfMeasurementAmount)	as UnitsSold
			,sum(f.SalesAmountExclVat + f.ReturnAmountExclVat)			as Revenue
			,sum(f.SalesAmount + f.ReturnAmount)						as RevenueInclVat
		from
			RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
		inner join RBIM.Dim_Article da (NOLOCK)	on da.ArticleIdx	= f.ArticleIdx
		inner join RBIM.Dim_store ds (NOLOCK)	on ds.storeidx		= f.storeidx
		where
				f.ReceiptDateIdx between @DateFromIdx and @DateToIdx
			and	ds.StoreId = @StoreId and ds.isCurrent<>0							
		group by
			floor(f.ReceiptIdx/1000)
			,da.Lev1ArticleHierarchyId
			,da.Lev1ArticleHierarchyName
			,da.Lev2ArticleHierarchyId
			,da.Lev2ArticleHierarchyName
			,da.NumOfHierarchyLevels
		) sales
	on flight.ReceiptHeadIdx = sales.ReceiptHeadIdx 
	group by 
		case when NumOfHierarchyLevels >= 2 then  sales.Lev2ArticleHierarchyId
				else case when	NumOfHierarchyLevels = 1 then sales.ArticleHierarchyId 
						else 'Ukjent' end 
				end,
		case when NumOfHierarchyLevels >= 2 then  sales.Lev2ArticleHierarchyName
				else case when	NumOfHierarchyLevels = 1 then sales.ArticleHierarchyName
						else 'Ukjent' end 
				end
		having
			sum(RevenueInclVat) <> 0
		order by
			ArticleHierarchyId 
end
else if (@WhichSales=1)	-- 1=PickAndCollect
begin
	select
		case when da.NumOfHierarchyLevels >= 2 then  da.Lev2ArticleHierarchyId
				else case when	da.NumOfHierarchyLevels = 1 then da.Lev1ArticleHierarchyId 
						else 'Ukjent' end 
				end							as ArticleHierarchyId
		,case when da.NumOfHierarchyLevels >= 2 then  da.Lev2ArticleHierarchyName
				else case when	da.NumOfHierarchyLevels = 1 then da.Lev1ArticleHierarchyName
						else 'Ukjent' end 
				end												as ArticleHierarchyName
		,sum(apcol.ReceivedQty)									as NoOfArticlesSold
		,sum(apcol.ReceivedQty * da.UnitOfMeasurementAmount)	as UnitsSold
		,sum(apcol.ArticleDeliveredPrice)						as Revenue
		,sum(apcol.ArticleDeliveredPrice)						as RevenueInclVat
	from
		CBIM.Agg_PickAndCollectOrders apco
	inner join CBIM.Agg_PickAndCollectOrderLines apcol (nolock)	on apcol.OrderID=apco.OrderID
	inner join RBIM.Dim_Gtin dg (nolock)						on dg.Gtin=apcol.ArticleEan and dg.StatusId=1	--1=Aktiv,9=Slettet ...
	inner join RBIM.Cov_ArticleGtin ag (nolock)					on ag.GtinIdx=dg.GtinIdx
	inner join RBIM.Dim_Article da (nolock)						on da.ArticleIdx=ag.ArticleIdx and da.isCurrent=1
	inner join RBIM.Dim_store ds (nolock)						on ds.Storeid=apco.StoreId
	where
			ds.StoreId = @StoreId and ds.isCurrent<>0							
		and	convert(date,apco.PaymentSuccessTimeStamp,103) between convert(date,@DateFrom,103) and convert(date,@DateTo,103)
		and (
				@ReportType=0								-- all flights
			OR (@ReportType=1 AND apco.FlightDirection='D')	-- departure flights
			OR (@ReportType=2 AND apco.FlightDirection='A')	-- arrival flights
			OR (@ReportType=3 AND apco.FlightDirection='')	-- extra flights
			)
	group by 
		case when da.NumOfHierarchyLevels >= 2 then  da.Lev2ArticleHierarchyId
				else case when	da.NumOfHierarchyLevels = 1 then da.Lev1ArticleHierarchyId 
						else 'Ukjent' end 
				end
		,case when da.NumOfHierarchyLevels >= 2 then  da.Lev2ArticleHierarchyName
				else case when	da.NumOfHierarchyLevels = 1 then da.Lev1ArticleHierarchyName
						else 'Ukjent' end 
				end
		having
			sum(apcol.ArticleDeliveredPrice) <> 0
		order by
			ArticleHierarchyId 
end
if (@WhichSales=2)	-- 2=all sales except pick and collect
begin
	select
		AllSale.ArticleHierarchyId											as ArticleHierarchyId, 
		AllSale.ArticleHierarchyName										as ArticleHierarchyName,
		AllSale.NoOfArticlesSold		- isnull(PandC.NoOfArticlesSold,0)	as NoOfArticlesSold,
		AllSale.UnitsSold				- isnull(PandC.UnitsSold,0)			as UnitsSold,
		AllSale.Revenue					- isnull(PandC.Revenue,0)			as Revenue,
		AllSale.RevenueInclVat			- isnull(PandC.RevenueInclVat,0)	as RevenueInclVat
	from
		(
		select
			case when NumOfHierarchyLevels >= 2 then sales.Lev2ArticleHierarchyId
				else case when NumOfHierarchyLevels = 1 then sales.ArticleHierarchyId 
							else 'Ukjent' end 
					end				as ArticleHierarchyId, 
			case when NumOfHierarchyLevels >= 2 then  sales.Lev2ArticleHierarchyName
				else case when	NumOfHierarchyLevels = 1 then sales.ArticleHierarchyName
						else 'Ukjent' end 
				end 				as ArticleHierarchyName,
			sum(sales.NoOfArticlesSold)	as NoOfArticlesSold,
			sum(sales.UnitsSold)		as UnitsSold,
			sum(sales.Revenue)			as Revenue,
			sum(sales.RevenueInclVat)	as RevenueInclVat
		from
			(
			select
				ds.StoreId
				,ds.StoreName
				,floor(se.ReceiptIdx/1000)	as ReceiptHeadIdx
				,case se.TransTypeValueTxt4
					when 'D' then	se.TransTypeValueTxt1 + ' - ' + se.TransTypeValueTxt3 
					when 'A' then	se.TransTypeValueTxt1 + ' - ' + se.TransTypeValueTxt2	
					else 			transtypevaluetxt1	
				end as 'FlightNo'
				,case se.TransTypeValueTxt4
					when 'D' then	'Avgang'
					when 'A' then	'Ankomst'
					when ''  then	'Ekstra	'
					else 			''	
				end	as 'FlightType'
			from
				RBIM.Cov_customersalesevent se	(nolock)
			inner join RBIM.Dim_TransType tt	(nolock)  on tt.TransTypeIdx = Se.TransTypeIdx
			inner join RBIM.Dim_store ds		(nolock)  on ds.StoreIdx=se.StoreIdx
			where
					ds.StoreId=@StoreId
				and	ds.isCurrent=1
				and tt.transtypeId = 90403	-- 	90403=Air Travel
				and se.ReceiptDateIdx between @DateFromIdx AND @DateToIdx	
				and (
						@ReportType = 0										-- all flights
					OR (@ReportType = 1 AND se.TransTypeValueTxt4 = 'D')	-- departure flights
					OR (@ReportType = 2 AND se.TransTypeValueTxt4 = 'A')	-- arrival flights
					OR (@ReportType = 3 AND se.TransTypeValueTxt4 = '')		-- extra flights
					)
			) flight
		inner join
			(
			select 
				floor(f.ReceiptIdx/1000)									as ReceiptHeadIdx
				,da.Lev1ArticleHierarchyId									as ArticleHierarchyId
				,da.Lev1ArticleHierarchyName								as ArticleHierarchyName
				,da.Lev2ArticleHierarchyId									as Lev2ArticleHierarchyId
				,da.Lev2ArticleHierarchyName								as Lev2ArticleHierarchyName
				,da.NumOfHierarchyLevels									as NumOfHierarchyLevels
				,sum(f.QuantityOfArticlesSold - f.QuantityOfArticlesInReturn)									as NoOfArticlesSold
				,sum((f.QuantityOfArticlesSold - f.QuantityOfArticlesInReturn) * da.UnitOfMeasurementAmount)	as UnitsSold
				,sum(f.SalesAmountExclVat + f.ReturnAmountExclVat)			as Revenue
				,sum(f.SalesAmount + f.ReturnAmount)						as RevenueInclVat
			from
				RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
			inner join RBIM.Dim_Article da (NOLOCK)	on da.ArticleIdx	= f.ArticleIdx
			inner join RBIM.Dim_store ds (NOLOCK)	on ds.storeidx		= f.storeidx
			where
					f.ReceiptDateIdx between @DateFromIdx and @DateToIdx
				and	ds.StoreId = @StoreId and ds.isCurrent<>0							
			group by
				floor(f.ReceiptIdx/1000)
				,da.Lev1ArticleHierarchyId
				,da.Lev1ArticleHierarchyName
				,da.Lev2ArticleHierarchyId
				,da.Lev2ArticleHierarchyName
				,da.NumOfHierarchyLevels
			) sales	on sales.ReceiptHeadIdx  = flight.ReceiptHeadIdx
		group by 
			case when NumOfHierarchyLevels >= 2 then  SALES.Lev2ArticleHierarchyId
					else case when	NumOfHierarchyLevels = 1 then SALES.ArticleHierarchyId 
							else 'Ukjent' end 
					end,
			case when NumOfHierarchyLevels >= 2 then  SALES.Lev2ArticleHierarchyName
					else case when	NumOfHierarchyLevels = 1 then SALES.ArticleHierarchyName
							else 'Ukjent' end 
					end
			having
				sum(RevenueInclVat) <> 0
		) AllSale
	left outer join
		(
		select
			case when da.NumOfHierarchyLevels >= 2 then  da.Lev2ArticleHierarchyId
					else case when	da.NumOfHierarchyLevels = 1 then da.Lev1ArticleHierarchyId 
							else 'Ukjent' end 
					end							as ArticleHierarchyId
			,case when da.NumOfHierarchyLevels >= 2 then  da.Lev2ArticleHierarchyName
					else case when	da.NumOfHierarchyLevels = 1 then da.Lev1ArticleHierarchyName
							else 'Ukjent' end 
					end												as ArticleHierarchyName
			,sum(apcol.ReceivedQty)									as NoOfArticlesSold
			,sum(apcol.ReceivedQty * da.UnitOfMeasurementAmount)	as UnitsSold
			,sum(apcol.ArticleDeliveredPrice)						as Revenue
			,sum(apcol.ArticleDeliveredPrice)						as RevenueInclVat
		from
			CBIM.Agg_PickAndCollectOrders apco
		inner join CBIM.Agg_PickAndCollectOrderLines apcol (nolock)	on apcol.OrderID=apco.OrderID
		inner join RBIM.Dim_Gtin dg (nolock)						on dg.Gtin=apcol.ArticleEan and dg.StatusId=1	--1=Aktiv,9=Slettet ...
		inner join RBIM.Cov_ArticleGtin ag (nolock)					on ag.GtinIdx=dg.GtinIdx
		inner join RBIM.Dim_Article da (nolock)						on da.ArticleIdx=ag.ArticleIdx and da.isCurrent=1
		inner join RBIM.Dim_store ds (nolock)						on ds.Storeid=apco.StoreId
		where
				ds.StoreId = @StoreId and ds.isCurrent<>0							
			and	convert(date,apco.PaymentSuccessTimeStamp,103) between convert(date,@DateFrom,103) and convert(date,@DateTo,103)
			and (
					@ReportType=0								-- all flights
				OR (@ReportType=1 AND apco.FlightDirection='D')	-- departure flights
				OR (@ReportType=2 AND apco.FlightDirection='A')	-- arrival flights
				OR (@ReportType=3 AND apco.FlightDirection='')	-- extra flights
				)
		group by 
			case when da.NumOfHierarchyLevels >= 2 then  da.Lev2ArticleHierarchyId
					else case when	da.NumOfHierarchyLevels = 1 then da.Lev1ArticleHierarchyId 
							else 'Ukjent' end 
					end
			,case when da.NumOfHierarchyLevels >= 2 then  da.Lev2ArticleHierarchyName
					else case when	da.NumOfHierarchyLevels = 1 then da.Lev1ArticleHierarchyName
							else 'Ukjent' end 
					end
			having
				sum(apcol.ArticleDeliveredPrice) <> 0
		) PandC on PandC.ArticleHierarchyId  = AllSale.ArticleHierarchyId 
end


end


--select * from [CBIM].[Agg_PickAndCollectOrders]
--select * from [CBIM].[Agg_PickAndCollectOrderLines]




GO


