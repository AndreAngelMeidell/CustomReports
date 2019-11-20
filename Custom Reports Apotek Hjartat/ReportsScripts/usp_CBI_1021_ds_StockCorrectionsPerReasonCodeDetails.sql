go
use [VBDCM]
go

if exists(select * from sysobjects WHERE name = N'usp_CBI_1021_ds_StockCorrectionsPerReasonCodeDetails'  AND xtype = 'P' )
drop procedure usp_CBI_1021_ds_StockCorrectionsPerReasonCodeDetails
go


CREATE PROCEDURE [dbo].[usp_CBI_1021_ds_StockCorrectionsPerReasonCodeDetails] (
	@parDateFrom As varchar(40) = '',
	@parDateTo As varchar(40) = '',
	@parStoreNo As varchar(4000) = '',
	@parStockAdjReasonNo AS SMALLINT = ''
)
as

	SET NOCOUNT ON;


	DECLARE @SQL NVARCHAR(MAX)
			
	
	SET @SQL =  'SELECT 
		MAX(stor.InternalStoreID) AS InternalStoreID,
		MAX(stor.storename) AS StoreName,
		MAX(alar.Eanno) AS Ean, 
		MAX(alar.ArticleID) AS ArticleID, 
		MAX(alar.supplierarticleid) AS SupplierArticleID, 
		MAX(alar.suppliername) AS SupplierName, 
		MAX(alar.articlename) AS ArticleName, 
		SUM(stad.adjustmentqty) AS CorrectionQty,
		SUM(ISNULL(stad.adjustmentnetcostamount,0)) AS AdjustmentNetCostAmount, 
		SUM(ISNULL(stad.adjustmentsalesamount,0)) AS AdjustmentSalesAmount, 
		MAX(alar.articlehiernametop)  AS ArticleHierNameTop,
		MAX(alar.articlehiername) AS ArticleHierName,  
		ISNULL(max(ArticleHierID), MAX(ArticleHierNo)) AS ArticleHierNo,
		ISNULL(max(ArticleHierIDTop), MAX(ArticleHierNoTop)) AS ArticleHierNoTop,
		COUNT(*) AS NUMOFADJUSTMENTS
		FROM  stockadjustments stad
		JOIN Stores stor on (stor.storeno = stad.storeno) 
		JOIN allarticles alar on (alar.articleno = stad.articleno) 
		WHERE  stad.stockadjtype in (2,30,31,34)'

     IF LEN(@parStoreNo) > 0
       SET @SQL = @SQL + '   and stad.storeno in ( @parStoreNo )'

     IF LEN(@parStockAdjReasonNo) > 0
       SET @SQL = @SQL + ' and stad.stockadjreasonno in ( @parStockAdjReasonNo )'

     IF LEN(@parDateFrom) > 0
       SET @SQL = @SQL + ' and stad.adjustmentdate >=  @parDateFrom + '' 00:00:00'' '

     IF LEN(@parDateTo) > 0
       SET @SQL = @SQL + ' and stad.adjustmentdate <=  @parDateTo + '' 23:59:59'' '


	 SET @SQL = @SQL + ' 
	 GROUP BY stor.storeno, alar.ArticleNo'

	  --PRINT(@SQL)

	  EXEC sp_executesql @SQL,
						@params = N'@parDateFrom AS NVARCHAR(40), @parDateTo AS NVARCHAR(40), @parStoreNo AS NVARCHAR(4000), @parStockAdjReasonNo AS SMALLINT', 
						@parDateFrom = @parDateFrom,
						@parDateTo = @parDateTo,
						@parStoreNo = @parStoreNo,
						@parStockAdjReasonNo = @parStockAdjReasonNo

GO


