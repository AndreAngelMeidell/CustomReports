go
use [VBDCM]
go

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1010_ds_StockValuePerItemGroup')
drop procedure usp_CBI_1010_ds_StockValuePerItemGroup
GO

Create Procedure [dbo].[usp_CBI_1010_ds_StockValuePerItemGroup]
														(														 
															@StoreGroupNos As varchar(8000) = ''
														)
AS
BEGIN 

set nocount on;

--Rapport nr 1010
	declare @sql As nvarchar(max) = ''
------------------------------------------------------------------------------------------------------

	if len(@StoreGroupNos) > 0 
		Begin
			
			set @sql = @sql +  '
			IF OBJECT_ID(''tempdb..#DimStores'') IS NOT NULL DROP TABLE #DimStores
			select StoreNo
			into #DimStores
			from dbo.ufn_CBI_getStoreNoForStoreGroups (@StoreGroupNos) 
			'
		End
	else
		Begin
			SET @sql = @sql +  '
			IF OBJECT_ID(''tempdb..#DimStores'') IS NOT NULL DROP TABLE #DimStores
			select 
			null as StoreNo,
			null as StoreID
			into #DimStores
			'
		End


	DECLARE @StoreIds NVARCHAR(MAX) 
	

	SELECT @StoreIds = COALESCE(@StoreIds + ',', '') + stor.StoreID 
	from 
	(
	select ParameterValue from [dbo].[ufn_RBI_SplittParameterString] (@StoreGroupNos,',')
		union
	select case when len(@StoreGroupNos) > 0 then '0' else null end as ParameterValue 
	) as storC
	inner join stores stor with (nolock) on storC.ParameterValue = stor.StoreNo
	
	set @sql = @sql + '

	Declare @SqlText nvarchar(4000)

	Set @SqlText = ''SELECT * FROM RSItemESDB.[dbo].[fn_CBI_uniqueArticlePrices] (''''' + @StoreIds + ''''')''

	if object_id(''tempdb..#uniqueArticlePrices'') is not null drop table #uniqueArticlePrices
	create table #uniqueArticlePrices (
		storeno  int
		,storeid  varchar(50)
		,articleno  int
		,articleid  varchar(50)
		,SalesPrice  money
		,NetCostPrice  money
	)

	CREATE CLUSTERED INDEX indx_tempUniqueArtPrices on #uniqueArticlePrices (ArticleID, storeid) 

	insert into #uniqueArticlePrices
	EXEC RS17_1.RSItemESDB.dbo.sp_executesql @SqlText

	--select * from #uniqueArticlePrices
	'

	set @sql = @sql + '
	SELECT 
		sto.InternalStoreID, 
		sto.storeName, 
		case when 
				  (cast(GROUPING_ID(sto.InternalStoreID) as varchar(1)) 
				  + cast(GROUPING_ID(sto.storeName)as varchar(1)) 
				  + cast(GROUPING_ID(art.Huvudgrp)as varchar(1)) 
				  + cast(GROUPING_ID(sto.StoreNo)as varchar(1))) = ''1110''
			 then ''Sum But.ID '' +  cast(sto.StoreNo as varchar)
			 when 
				  (cast(GROUPING_ID(sto.InternalStoreID) as varchar(1)) 
				  +  cast(GROUPING_ID(sto.storeName)as varchar(1)) 
				  + cast(GROUPING_ID(art.Huvudgrp)as varchar(1)) 
				  + cast(GROUPING_ID(sto.StoreNo)as varchar(1))) = ''0000''
			 then art.Huvudgrp
			 when 
				  (cast(GROUPING_ID(sto.InternalStoreID) as varchar(1)) 
				  +  cast(GROUPING_ID(sto.storeName)as varchar(1)) 
				  + cast(GROUPING_ID(art.Huvudgrp)as varchar(1)) 
				  + cast(GROUPING_ID(sto.StoreNo)as varchar(1))) = ''1111''
			 then ''Total sum''
			 else 
				art.Huvudgrp
		end as Huvudgrp,
		art.Huvudgrp,
		sto.StoreNo, 
		SUM(IsNull(sai.InStockQty,0)) As InStockQtySalesStock,
		SUM(IsNull(tsai.TotalStockQty,0)) As TotalStockQty,
		SUM(IsNull(sai.StockInOrderQty,0)) as StockInOrderQty,
		SUM(IsNull(tsai.TotalStockAmount,0))  as TotalLagervarde,
		Count(IsNull(sai.InStockQty,0)) As Antal,
		SUM(tsai.TotalStockQty * aaap.salesprice)  as Totaltförspris,
		SUM(tsai.TotalStockQty * coalesce(uapReg.salesprice, uapCentr.salesprice))  as TotalSalesAmount
	FROM StoreArticleInfos sai with (nolock)
	JOIN vw_TotalStoreArticleInfos tsai with (nolock) on tsai.StoreNo = sai.StoreNo AND tsai.ArticleNo = sai.ArticleNo
	JOIN AllArticles alart with (nolock) on sai.articleno = alart.ArticleNo
	JOIN #UniqueArticlePrices uapCentr with (nolock) on ( uapCentr.ArticleID = alart.ArticleID and uapCentr.StoreID = ''0'' )
	JOIN activeallarticleprices aaap with (nolock)  on ( sai.articleno = aaap.articleno and sai.storeno = aaap.storeno )	
	JOIN vw_PharmaHuvudgrp art with (nolock)  on (sai.ArticleNo = art.ArticleNo)
	JOIN Stores sto with (nolock)  on (sai.StoreNo = sto.StoreNo)
	JOIN #DimStores dimSto on (dimSto.StoreNo = sto.StoreNo)
	LEFT JOIN #UniqueArticlePrices uapReg with (nolock)  on ( uapReg.ArticleID = alart.ArticleID and uapReg.StoreID = sto.StoreID and uapReg.StoreID <> ''0'' )
	WHERE tsai.TotalStockQty > 0  
	' 

	set @sql = @sql + ' 
		GROUP BY GROUPING SETS
		(	
			(sto.InternalStoreID, sto.storeName,  art.Huvudgrp, sto.StoreNo),
			(sto.StoreNo),
			()
		)
	'

	--print(@sql)

	exec sp_executesql @sql
					   ,N'@StoreGroupNos nvarchar(max)'
					   ,@StoreGroupNos = @StoreGroupNos



END

GO


/*
exec dbo.usp_CBI_1010_ds_StockValuePerItemGroup @StoreGroupNos = '1152'--,1202,1562,1725'

exec dbo.usp_CBI_1010_ds_StockValuePerItemGroup @StoreGroupNos = '1152,3000,3010,1202,1562,1725'

*/


