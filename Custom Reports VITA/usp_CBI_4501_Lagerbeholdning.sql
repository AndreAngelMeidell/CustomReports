USE [VBDCM]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_4501_Lagerbeholdning]    Script Date: 15.09.2019 10.56.45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



--Lagerbeholdning utgåtte varer 12108 fra CIM


CREATE PROCEDURE [dbo].[usp_CBI_4501_Lagerbeholdning]
(

		@StoreId AS VARCHAR(100),
		@DateFrom AS DATETIME, 
		@DateTo AS DATETIME, 
		@parIncludeNegative  as varchar(1) ='Y',
		@parOnlyDeleted  as varchar(1) ='Y'

)
AS  
BEGIN 

--SET DATEFORMAT DMY
declare @sql as varchar(MAX)
declare @parExpiredateFrom as varchar(20) = @DateFrom
declare @parExpiredateTo as varchar(20) = @DateTo

set @sql = 'select '
if len(@StoreId ) > 0 and (select charindex(',', @StoreId ) ) > 0 or len(@StoreId ) = 0 
  set @sql = @sql + ' stor.internalstoreid, stor.storename, '

set @sql = @sql + '
alar.articleno,
	alar.supplierarticleid, 
	alar.EANNo, 
	alar.ArticleName, 
	alar.articlehierID as ArticleHierID,
	alar.articlehiername, 
	alar.suppliername,
	ISNULL(sai.InStockQty,0) as InStockQtySalesStock,
	ISNULL(tsai.TotalStockAmount,0) as TotalNetCostAmount,
	ISNULL(tsai.TotalStockQty,0) as TotalStockQty,
	CASE WHEN ISNULL(sai.InStockQty,0) > 0
		THEN CASE WHEN sai.AverageSalesQty = 0 or sai.AverageSalesQty IS NULL
				THEN sai.InStockQty * 28 
				ELSE ISNULL(sai.InStockQty/NULLIF(sai.AverageSalesQty/6, 0),0)
			 END
		ELSE 0
	END as RemainingDaysInStock,
	sai.LastUpdatedStockCount ,
	--alar.DeletedDate, 
	--A.DiscontinuedDate as ExpireDate
	a.DeletedDate, 
	A.ExpiryDate as ExpireDate
	FROM allarticles alar
	JOIN StoreArticleInfos sai on alar.ArticleNo = sai.ArticleNo
	JOIN vw_TotalStoreArticleInfosNEW tsai on tsai.StoreNo = sai.StoreNo AND tsai.ArticleNo = sai.ArticleNo 
	JOIN Stores stor on  stor.StoreNo = sai.StoreNo
	JOIN RSItemESDb..Articles AS A ON A.ArticleId = alar.ArticleID
	WHERE  stor.storetypeno = 7
	AND sai.InStockQty '
IF @parIncludeNegative = 'Y'
	set @Sql = @Sql + ' <' 
set @Sql = @Sql + ' >0'

IF @parOnlyDeleted = 'Y'
	set @Sql = @Sql + ' AND a.ArticleStatusNo >= 8 ' 

if len(@DateFrom) > 0 
		set @SQL = @SQL + ' AND (A.ExpiryDate IS NULL OR A.ExpiryDate >= ''' + @parExpiredateFrom + ''')'
if len(@DateTo) > 0 
		set @SQL = @SQL + ' AND (A.ExpiryDate IS NULL OR A.ExpiryDate <= ''' + @parExpiredateTo + ''')'


if len(@StoreId) > 0
  set @sql = @sql + ' and stor.storeno in (' + @StoreId + ')'
set @sql = @sql + ' Order by alar.ArticleName, stor.internalstoreid'


EXEC (@sql)
--PRINT(@sql)


END 


GO

