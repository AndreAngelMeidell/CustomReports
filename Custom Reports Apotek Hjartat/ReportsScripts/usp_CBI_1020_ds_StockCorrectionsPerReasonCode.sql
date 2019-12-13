go
use [VBDCM]
go

if exists(select * from sysobjects WHERE name = N'usp_CBI_1020_ds_StockCorrectionsPerReasonCode'  AND xtype = 'P' )
drop procedure usp_CBI_1020_ds_StockCorrectionsPerReasonCode
go


create procedure [dbo].[usp_CBI_1020_ds_StockCorrectionsPerReasonCode] (
	@parDateFrom As varchar(40) = '',
	@parDateTo As varchar(40) = '',
	@StoreGroupNos As varchar(8000) = '',
	@parSupplierArticleID As varchar(2000) = '',
	@parStockAdjReasonNo as varchar(8000) = ''
)
as


	--Rapport nr 1020
	SET NOCOUNT ON 
	SET ANSI_WARNINGS OFF
	SET ARITHABORT OFF

	declare @sql As nvarchar(max)
	set @sql = ''
------------------------------------------------------------------------------------------------------
	
	set @sql = @sql +  '
	IF OBJECT_ID(''tempdb..#ds_StockMinAndMaxStorage'') IS NOT NULL  DROP TABLE #ds_StockMinAndMaxStorage '


	if len(@parStockAdjReasonNo ) > 0
		set @sql = @sql + '	IF OBJECT_ID(''tempdb..#StockAdjReasonNoFltrTbl'') IS NOT NULL  DROP TABLE #StockAdjReasonNoFltrTbl
							select distinct cast(ParameterValue as smallint) as StockAdjReasonNo 
							into #StockAdjReasonNoFltrTbl
							from [dbo].[ufn_RBI_SplittParameterString](@parStockAdjReasonNo,'','') 
		 '


	if len(@StoreGroupNos) > 0 
		Begin
			
			SET @sql = @sql +  '
			;WITH DimStores AS (
			select StoreNo
			from dbo.ufn_CBI_getStoreNoForStoreGroups (@StoreGroupNos) 
			)
			'
		End
	else
		Begin
			SET @sql = @sql +  '
			;WITH DimStores AS (
			select null as StoreNo
			)
			'
		End


	set @sql = @sql + '
	SELECT 
		sa.StoreNo as Butik_Id, 
		--max(s.InternalStoreID)  as InternalStoreID,  
		s.StoreName as Butiksnamn, 
		sa.StockAdjReasonNo, 
		sarc.StockAdjReasonName as Orsaks_Namn,
		COUNT(sa.TransactionCounter) AS Antal_Korrigeringar, 
		SUM(sa.AdjustmentQty) AS Korrigerat_Antal, 
		ROUND(SUM(sa.AdjustmentNetCostAmount),0) AS Korrigerat_Värde,
		ROUND(SUM(sa.AdjustmentSalesAmount),0) AS Försäljningsvärde
	FROM Stores AS s WITH (NOLOCK)
	INNER JOIN DimStores as dimStr on s.StoreNo = dimStr.StoreNo
	INNER JOIN StockAdjustments AS sa ON s.storeno=sa.storeno
	and (CONVERT(CHAR(10),sa.adjustmentdate,120) 
		between  
				CONVERT(CHAR(10),@parDateFrom,120)
			and CONVERT(CHAR(10),@parDateTo,120))
	INNER JOIN StockAdjustmentReasonCodes AS sarc ON (sa.StockAdjReasonNo = sarc.StockAdjReasonNo) 
	'

	if len(@parStockAdjReasonNo ) > 0
		set @sql = @sql + 'INNER JOIN #StockAdjReasonNoFltrTbl as stcAdjFltr on sa.StockAdjReasonNo = stcAdjFltr.StockAdjReasonNo
		'
	
	set @sql = @sql + '	WHERE sa.StockAdjType  in (2,30,31,34)
	'

	IF Len(@parSupplierArticleID) > 0
		set @sql = @sql + ' AND sa.ArticleNo IN 
		(SELECT sai.ArticleNo FROM SupplierArticles AS sai 
		WHERE sai.SupplierArticleID LIKE ''%'' +@parSupplierArticleID+ ''%'')'



	set @sql = @sql + '
	GROUP BY sa.StoreNo, s.StoreName, sa.StockAdjReasonNo, sarc.StockAdjReasonName
	'

	set @sql = @sql + ' ORDER BY s.StoreName, sa.StockAdjReasonNo'

	--print(@sql)

	exec sp_executesql @sql,
					   N'@parDateFrom nvarchar(40), @parDateTo nvarchar(40), @StoreGroupNos nvarchar(max), @parSupplierArticleID nvarchar(2000), @parStockAdjReasonNo nvarchar(max)',
					   @parDateFrom  = @parDateFrom,
					   @parDateTo = @parDateTo,
					   @StoreGroupNos = @StoreGroupNos,
					   @parSupplierArticleID = @parSupplierArticleID,
					   @parStockAdjReasonNo = @parStockAdjReasonNo



GO




/*

exec usp_CBI_1020_ds_StockCorrectionsPerReasonCode	@parDateFrom  = '2008-01-01',
														@parDateTo = '2018-07-18',
														@StoreGroupNos = '3000,3010,1725',
														@parSupplierArticleID  = '', -- '2',
														@parStockAdjReasonNo = ''--'10,40,50,60'--,70,90,110,120,130,150,250,10,40'



*/

