USE RSItemESDb
GO

--
-- Function to get allarticles info from RSItemESDB db
--
-- This function should be implemented into RSItemESDB.

IF OBJECT_ID('fn_CBI_uniqueArticlePrices', 'IF') IS NOT NULL DROP FUNCTION fn_CBI_uniqueArticlePrices
GO

CREATE FUNCTION [dbo].[fn_CBI_uniqueArticlePrices]
(
    @storeId nvarchar(max)

)
RETURNS TABLE AS RETURN
(
	select	sgl.StoreNo,
			stor.storeid,
			ap.articleno,
			a.articleid, 
			cast(ap.SalesPrice * DefaultCurrencyExchangeRate as money) as SalesPrice, 
			ISNULL(oap.NetCostPriceInSystemCurrency, oap.NetCostPrice) as NetCostPrice
	--into #UniqueArticlePrices
	from RSItemESDB.dbo.articlePrices ap
	inner join (
				select ArticleNo, PriceProfileNo, MAX(ModifiedDate) as maxModifiedDate
				from RSItemESDB.dbo.articlePrices with (nolock)
				where ArticlePriceStatusNo <> 9
				group by ArticleNo, PriceProfileNo
				) artMaxDate on artMaxDate.ArticleNo = ap.ArticleNo and artMaxDate.PriceProfileNo = ap.PriceProfileNo and ap.ModifiedDate = artMaxDate.maxModifiedDate
	inner join RSItemESDB.dbo.priceprofiles pp on ap.PriceProfileNo = pp.priceProfileNo
	inner join RSItemESDB.dbo.storegrouplinks sgl on pp.StoreGroupNo = sgl.storegroupno
	inner join RSItemESDB.dbo.articles a on ap.ArticleNo = a.articleNo
	inner join RSItemESDB.dbo.Stores stor with (nolock) on stor.storeno = sgl.Storeno
	--inner join (
	--									select vbdcmSto.StoreNo, vbdcmSto.StoreID
	--									from #DimStores dimSt
	--									inner join stores vbdcmSto with (nolock) on vbdcmSto.storeno = dimSt.Storeno
	--									union
	--									select 0 as StoreNo, 0 as StoreID
	--									) dimStr on stor.StoreID = dimStr.StoreID
	inner join [dbo].[ufn_RBI_SplittParameterString] (@storeId,',') stVbdcm on stVbdcm.ParameterValue = stor.StoreID
	left join RSItemESDB.dbo.supplierarticles sa on  sa.SupplierArticleNo = a.DefaultSupplierArticleNo
	left join RSItemESDB.dbo.orderingAlternatives oa on oa.OrderingAlternativeNo = sa.DefaultOrderingAlternativeNo
	left join RSItemESDB.dbo.CurrentOrderingAlternativePrices coap on oa.OrderingAlternativeNo = coap.OrderingAlternativeNo and coap.PriceProfileNo = pp.PriceProfileNo
	left join RSItemESDB.dbo.OrderingAlternativePrices oap on coap.OrderingAlternativePriceNo =  oap.OrderingAlternativePriceNo
	left join RSItemESDB.dbo.Currencies cur on ap.SalesPriceCurrencyNo = cur.CurrencyNo
	where ap.ArticlePriceStatusNo = 1	--and ap.ArticlePriceTypeNo = 1
	--and stor.StoreID = @storeId
)

GO

