USE [VBDCM]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_4502_Nedjusteringer]    Script Date: 15.09.2019 10.56.58 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_4502_Nedjusteringer]
(

		@StoreId AS VARCHAR(100),
		@DateFrom AS DATETIME, 
		@DateTo AS DATETIME

)
AS  
BEGIN 

--Vita Nedjusteringer til Jasper
--SET DATEFORMAT DMY
declare @sql as varchar(MAX)
declare @parExpiredateFrom as varchar(20) = @DateFrom
declare @parExpiredateTo as varchar(20) = @DateTo

IF OBJECT_ID('tempdb..#Order') IS NOT NULL 
	DROP TABLE #Order


SET @sql = ' ;WITH SelectedOrder AS (
	select stor.InternalStoreID, COL.OrderNo, alar.ArticleNo, COL.ConfirmedQty, COL.ConfirmedOrderLineStatus,COL.ConfirmedDeliveryDate, MAX(COL.RecordCreated) AS RecordCreated
	FROM ConfirmedOrderLines AS COL
	JOIN AllArticles alar (nolock) on alar.ArticleNo = COL.ArticleNo
	JOIN Stores stor ON stor.StoreNo = COL.StoreNo
	JOIN StockAdjustmentReasonCodes AS SARC ON SARC.StockAdjReasonNo = COL.StockAdjReasonNo
	JOIN OrderConfirmationStates AS OCS ON OCS.OrderConfirmationStatus = COL.OrderConfirmationStatus
	WHERE  1=1
	AND stor.storetypeno = 7 '

	IF LEN(@DateFrom) > 0 
		SET @SQL = @SQL + ' AND (COL.RecordCreated >= ''' + @parExpiredateFrom + ''')'
	IF LEN(@DateTo) > 0 
		SET @SQL = @SQL + ' AND (COL.RecordCreated <= ''' + @parExpiredateTo + ''')'
	IF LEN(@StoreId) > 0
		SET @sql = @sql + ' and stor.internalstoreid in (' + @StoreId + ')'
SET @sql = @sql + '
	GROUP BY stor.InternalStoreID, COL.OrderNo, alar.ArticleNo, COL.ConfirmedQty, COL.ConfirmedOrderLineStatus,COL.ConfirmedDeliveryDate
	)
	select 
	stor.internalstoreid, 
	stor.storename,
	col.OrderNo,
	--alar.ArticleNo,
	alar.ArticleName, 
	alar.EANNo,
	COL.ConfirmedDeliveryDate,
	OrderQty = (SELECT SUM(vp.PACKAGES) FROM dbo.VBD_PURCHASEORDERS vp WHERE VP.ORDERNO = COL.OrderNo AND VP.STORENO = stor.InternalStoreID AND VP.ARTICLENO = COL.ArticleNo AND vp.ORDERLINESTATUS<99),
	COL.ConfirmedQty,
	alar.articleno,
	alar.supplierarticleid, 
	--alar.EANNo, 
	SARC.StockAdjReasonName,
	OCS.OrderConfirmationStatusName,
	COL.RecordCreated AS RecordCreated
	FROM ConfirmedOrderLines AS COL (NOLOCK)
	JOIN AllArticles alar (nolock) on alar.ArticleNo = COL.ArticleNo
	JOIN Stores stor (NOLOCK) ON stor.StoreNo = COL.StoreNo
	JOIN StockAdjustmentReasonCodes AS SARC ON SARC.StockAdjReasonNo = COL.StockAdjReasonNo
	JOIN OrderConfirmationStates AS OCS ON OCS.OrderConfirmationStatus = COL.OrderConfirmationStatus
	JOIN SelectedOrder AS O ON		O.ArticleNo = alar.ArticleNo AND O.ConfirmedDeliveryDate = COL.ConfirmedDeliveryDate 
						AND O.ConfirmedOrderLineStatus = COL.ConfirmedOrderLineStatus 
						AND O.InternalStoreID = stor.InternalStoreID AND O.InternalStoreID = stor.InternalStoreID AND O.OrderNo = COL.OrderNo
						AND O.RecordCreated = COL.RecordCreated --181
	WHERE  1=1
	AND stor.storetypeno = 7 '
	IF LEN(@DateFrom) > 0 
		SET @SQL = @SQL + ' AND (COL.RecordCreated >= ''' + @parExpiredateFrom + ''')'
	IF LEN(@DateTo) > 0 
		SET @SQL = @SQL + ' AND (COL.RecordCreated <= ''' + @parExpiredateTo + ''')'
	IF LEN(@StoreId) > 0
		SET @sql = @sql + ' and stor.internalstoreid in (' + @StoreId + ')'


	SET @sql = @sql + ' 
	ORDER BY stor.InternalStoreID,  COL.RecordCreated desc
	 '
    

EXEC (@sql)
--PRINT(@sql)


END 



GO

