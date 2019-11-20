GO
USE [VBDCM]
GO


IF EXISTS(SELECT * FROM SYSOBJECTS WHERE name = N'usp_CBI_1022_ds_StockAdjustmentTransactionDetails'  AND xtype = 'P' )
DROP PROCEDURE usp_CBI_1022_ds_StockAdjustmentTransactionDetails
GO


CREATE PROCEDURE [dbo].[usp_CBI_1022_ds_StockAdjustmentTransactionDetails] (
				@parStoreNo As varchar(4000) = '',
				@parDateFrom As varchar(1000) = '',
				@parDateTo As varchar(1000) = '',
				@parStockAdjReasonNo As varchar(2000) = '',
				@parArticleDepartmentNo As varchar(2000) = '',
				@parSupplierNo As varchar(4000) = '',
				@parEanNo As varchar(1000) = '',
				@parSupplierArticleID As varchar(2000) = '',
				@parArticleName As varchar(1000) = '',
				@parOrderBy as varchar(4000) = '',
				@parStockType as varchar(100) = ''
)
as

	SET NOCOUNT ON;


	DECLARE @SQL AS NVARCHAR(4000)
	DECLARE @ParmDefinition AS NVARCHAR(2000)


	SET @SQL =  'SELECT stor.InternalStoreID as InternalStoreID,
						stor.storename as storename,
						isnull(alar.Eanno,0) as Eanno, 
						alar.ArticleID, 
						isnull(alar.supplierarticleid,'''') as supplierarticleid, 
						isnull(alar.suppliername,'''') as suppliername, 
						saty.stockadjName,
						alar.articlename as articlename, 
						isnull(stad.netprice,0) as netprice, 
						isnull(stad.salesprice,0) as salesprice, 
						stad.adjustmentqty as adjustmentqty,
						isnull(stad.adjustmentnetcostamount,0) as adjustmentnetcostamount, 
						isnull(stad.adjustmentsalesamount,0) as adjustmentsalesamount, 
						IsNull(alar.ArticleDepartmentName, '''') as ArticleDepartmentName,
						isnull(strc.stockadjreasonname,'''') as stockadjreasonname, 
						stad.adjustmentdate, 
						isnull(stad.adjustmentrefno,'''') as adjustmentrefno,
						isnull(users.userfirstname,'''') as username,
						alar.articlehiernametop as articlehiernametop,
						alar.articlehiername as articlehiername,  
						ISNULL(alar.ArticlehierID, alar.ArticleHierNo) as ArticleHierNo,
						ISNULL(alar.ArticlehierIDTop, alar.ArticleHierNoTop) as ArticleHierNoTop
	'  
    
    SET @sql = @sql + ' 
	FROM  stockadjustments stad
    join Stores stor on (stor.storeno = stad.storeno) 
    join  allarticles alar on (alar.articleno = stad.articleno) 
    join stockadjustmentreasoncodes strc on (stad.stockadjreasonno = strc.stockadjreasonno)
    join stockadjustmentTypes saty on (saty.stockadjtype = stad.stockadjtype )
    left outer join  vwsys_vbdusers users on (users.userno = stad.userno)
	'
     
	SET @sql = @sql + '     WHERE  stad.stockadjtype in (2,30,31,34)'
     
	IF LEN(@parStoreNo) > 0
		SET @sql = @sql + '   and stad.storeno = @parStoreNo '
     
	IF LEN(@parStockType) > 0
		SET @sql = @sql + '   and saty.StockTypeNo in  ( @parStockType )'
     
	IF LEN(@parEanNo) > 0
		SET @sql = @sql + ' and alar.articleno in ( select articleno from ean where eanno in ( @parEanNo ))'
     
	IF LEN(@parSupplierArticleID) > 0
		SET @sql = @sql + ' AND alar.ArticleNo IN (SELECT sai.ArticleNo FROM SupplierArticles AS sai WHERE sai.SupplierArticleID LIKE ''%''+ @parSupplierArticleID +''%'')'

	IF LEN(@parArticleName) > 0
		SET @sql = @sql + ' and alar.articlename like  (''%''+ @parArticleName +''%'')'

	IF LEN(@parArticleDepartmentNo) > 0
		SET @sql = @sql + ' and alar.articledepartmentno in (@parArticleDepartmentNo)'
     
	IF LEN(@parStockAdjReasonNo) > 0
		SET @sql = @sql + ' and stad.stockadjreasonno in (@parStockAdjReasonNo)'
     
	IF LEN(@parDateFrom) > 0
		SET @sql = @sql + ' and stad.adjustmentdate >= @parDateFrom + '' 00:00:00'' '
     
	IF LEN(@parDateTo) > 0
		SET @sql = @sql + ' and stad.adjustmentdate <= @parDateTo + '' 23:59:59'' '
     
	IF LEN(@parSupplierNo) > 0
		SET @sql = @sql + ' and alar.supplierno in (@parSupplierNo)'


	IF @parOrderBy = 'Leverandør'
		SET @SQL = @SQL + ' ORDER BY alar.SupplierName, stor.storeno, alar.eanno, stad.adjustmentdate'
	ELSE IF @parOrderBy = 'Varegruppe'
		SET @SQL = @SQL + ' ORDER BY alar.ArticleHierName, stor.storeno, alar.eanno, stad.adjustmentdate'
	ELSE IF @parOrderBy = 'Varenavn'
		SET @SQL = @SQL + ' ORDER BY alar.ArticleName, stor.storeno, alar.eanno, stad.adjustmentdate'
	ELSE IF @parOrderBy = 'Innverdi'
		SET @SQL = @SQL + ' ORDER BY stad.AdjustmentNetCostAmount, stor.storeno, alar.eanno, stad.adjustmentdate'
	ELSE IF @parOrderBy = 'Antall'
		SET @SQL = @SQL + ' ORDER BY stad.adjustmentqty, stor.storeno, alar.eanno, stad.adjustmentdate'
	ELSE IF @parOrderBy = 'Årsakskode'
		SET @SQL = @SQL + ' ORDER BY strc.stockadjreasonname, stor.storeno, alar.eanno, stad.adjustmentdate'
	ELSE 
		SET @SQL = @SQL + ' ORDER BY stor.storeno, alar.eanno, stad.adjustmentdate'


	EXECUTE sp_executesql @SQL,
						  @ParmDefinition = N'@parStoreNo AS NVARCHAR(4000), @parDateFrom AS NVARCHAR(1000),  @parDateTo AS NVARCHAR(1000), @parStockAdjReasonNo AS NVARCHAR(2000), @parArticleDepartmentNo AS NVARCHAR(2000)
											  , @parSupplierNo AS NVARCHAR(4000), @parEanNo AS NVARCHAR(1000), @parSupplierArticleID  AS NVARCHAR(2000), @parArticleName AS NVARCHAR(1000), @parOrderBy AS NVARCHAR(4000)
											  , @parStockType AS NVARCHAR(100) ',
											@parStoreNo				= @parStoreNo,
											@parDateFrom			= @parDateFrom,
											@parDateTo				= @parDateTo,
											@parStockAdjReasonNo	= @parStockAdjReasonNo,
											@parArticleDepartmentNo = @parArticleDepartmentNo,
											@parSupplierNo			= @parSupplierNo,
											@parEanNo				= @parEanNo,
											@parSupplierArticleID	= @parSupplierArticleID,
											@parArticleName			= @parArticleName,
											@parOrderBy				= @parOrderBy,
											@parStockType			= @parStockType


GO



/*
	EXEC [dbo].[usp_CBI_1022_ds_StockAdjustmentTransactionDetails]	@parStoreNo = '3000'
																	,@parDateFrom = '2010-01-01'
																	,@parDateTo = '2019-05-27'
																	,@parStockAdjReasonNo = ''--'60'
																	,@parArticleDepartmentNo= ''
																	,@parSupplierNo = ''--'28'
																	,@parEanNo = '' --'3582910086185'
																	,@parSupplierArticleID = '' --'145532'
																	,@parArticleName = '' --'Alvedon® forte Filmdragerad tablett 1g Plastburk, '
																	,@parOrderBy = '' --'Leverandør'
																	,@parStockType = '' --'1'


*/

