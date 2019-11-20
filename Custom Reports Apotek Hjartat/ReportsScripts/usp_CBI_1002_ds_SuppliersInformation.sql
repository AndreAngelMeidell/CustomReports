go
use [VBDCM]
go

if exists(select * from sysobjects WHERE name = N'usp_CBI_1002_ds_SuppliersInformation'  AND xtype = 'P' )
drop procedure usp_CBI_1002_ds_SuppliersInformation
go


CREATE PROCEDURE[dbo].[usp_CBI_1002_ds_SuppliersInformation] (
	@ParStoreNo As varchar(8000) = '',
	@parDateFrom As varchar(40) = '',
	@parDateTo As varchar(40) = '',
	@parDeliveryCompany As varchar(2000) = '',
	@parDeliveryNoteNo as varchar(8000) = '',
	@parExternalDeliveryNoteId_hidden as varchar(8000) = ''
)
AS
	SET NOCOUNT ON 

	DECLARE @sql AS NVARCHAR(MAX)

	IF LEN(@ParStoreNo) > 0 AND @ParStoreNo <> '-1'
	BEGIN

	SET @sql = 'SELECT  
					CONVERT(CHAR(10),DDL.ActualDeliveryDate,120) AS ActualDeliveryDate,
					MAX(ddl.PackageId) AS Back,
					MAX(A.ArticleID) AS ArtID,
					MAX(dl.SupplierArticleID) AS Varunr,
					MAX(A.ArticleName) AS VaruNamn,
					(SELECT InfoValue FROM StoreArticleInfoDetails AS SAI WHERE  SAI.ArticleNo = A.ArticleNo AND  SAI.InfoID = ''RS_DischargingZone'' AND SAI.StoreNO = S.storeNo) AS ST_AR_Zone,
					(SELECT InfoValue FROM StoreArticleInfoDetails AS SAI WHERE  SAI.ArticleNo = A.ArticleNo AND  SAI.InfoID = ''RS_ShelfPosition1'' AND SAI.StoreNO = S.storeNo) AS ST_AR_Hyllplats_1,
					(SELECT InfoValue FROM StoreArticleInfoDetails AS SAI WHERE  SAI.ArticleNo = A.ArticleNo AND  SAI.InfoID = ''RS_ShelfPosition2'' AND SAI.StoreNO = S.storeNo) AS ST_AR_Hyllplats_2,
					(SELECT CONVERT(CHAR(10),InfoValue,120) FROM StoreArticleInfoDetails AS SAI WITH (NOLOCK) WHERE SAI.ArticleNo = A.ArticleNo AND SAI.InfoID = ''RS_ExpireDate'' AND SAI.StoreNO = S.storeNo) AS Utgangsdatum,		
					MAX(dl.NetPrice) AS NetPrice ,
					SUM (ddl.deliveredqty) todayDeliveredQty,
					D.DeliveryNoteText, MAX(CO.CustomerOrderSellerText) AS KundorderId
				FROM dbo.stores AS S
				JOIN dbo.Deliveries D ON (D.StoreNo = S.StoreNo)  
				JOIN dbo.DeliveryLines DL ON (DL.DeliveryNoteNo = D.DeliveryNoteNo)  
				JOIN dbo.Articles A on (DL.ArticleNo = A.ArticleNo)  
				JOIN dbo.DeliveredLines DDL ON (DDL.DeliveryNoteNo = DL.DeliveryNoteNo and DDL.DeliveryLineNo = DL.DeliveryLineNo)  
				JOIN dbo.DeliveredLineStates DLS ON (DLS.DeliveredLineStatus = DDL.DeliveredLineStatus)
				LEFT JOIN dbo.CustomerOrderLineDeliveryNoteLines COLDNL ON COLDNL.DeliveryLineNo = DDL.DeliveryLineNo
				LEFT JOIN dbo.CustomerOrders CO ON COLDNL.CustomerOrderNo = CO.CustomerOrderNo
				WHERE 1 = 1
				AND DDL.deliveredlinestatus IN (30,80)
				AND DDL.deliveredqty > 0
				AND S.storeNo = @ParStoreNo '



	IF LEN(@parExternalDeliveryNoteId_hidden) > 0 			 
		SET @sql = @sql + ' AND ddl.ExternalDeliveryNoteId =  @parExternalDeliveryNoteId_hidden '
	ELSE IF LEN(@parDeliveryNoteNo) > 0 
		SET @sql = @sql + ' AND DL.DeliveryNoteNo IN (SELECT value
													  FROM STRING_SPLIT(@parDeliveryNoteNo,'',''))
													  '
	ELSE IF LEN(@parDateFrom) > ''
		SET @sql = @sql + '  AND CONVERT(CHAR(10),DDL.ActualDeliveryDate,120) BETWEEN  
						 CONVERT(CHAR(10), @parDateFrom, 120)
						 AND CONVERT(CHAR(10), @parDateTo, 120) 
						 '


	IF LEN(@parDeliveryCompany) > 0
		SET @sql = @sql + '  AND D.SupplierNo = @parDeliveryCompany '




	SET @sql = @sql + 'GROUP BY
	ddl.externaldeliverynoteid, CONVERT(CHAR(10),DDL.ActualDeliveryDate,120), 
	a.articleid, s.storeno, a.articleno, d.DeliveryNoteText

	ORDER BY VaruNamn ASC'


	--print @sql;

	exec sp_executesql  @sql,
						N'@parDateFrom NVARCHAR(40), @parDateTo NVARCHAR(40), @ParStoreNo NVARCHAR(MAX), @parDeliveryCompany NVARCHAR(MAX), @parDeliveryNoteNo NVARCHAR(MAX)
						  ,@parExternalDeliveryNoteId_hidden NVARCHAR(MAX)',
						@parDateFrom = @parDateFrom,
						@parDateTo = @parDateTo,
						@ParStoreNo = @ParStoreNo,
						@parDeliveryCompany = @parDeliveryCompany,
						@parDeliveryNoteNo = @parDeliveryNoteNo,
						@parExternalDeliveryNoteId_hidden = @parExternalDeliveryNoteId_hidden

	END
	ELSE
	BEGIN
		SELECT  
					NULL AS ActualDeliveryDate,
					NULL AS Back,
					NULL AS ArtID,
					NULL AS Varunr,
					NULL AS VaruNamn,
					NULL AS ST_AR_Zone,
					NULL AS ST_AR_Hyllplats_1,
					NULL AS ST_AR_Hyllplats_2,
					NULL AS Utgangsdatum,		
					NULL AS NetPrice ,
					NULL AS todayDeliveredQty,
					NULL AS KundorderId
	END

GO



/*

EXEC dbo.[usp_CBI_1002_ds_SuppliersInformation] @ParStoreNo = '3000'
												,@parDateFrom = '2019-01-01'
												,@parDateTo = '2019-10-09'
												,@parDeliveryCompany = ''
												--,@parDeliveryNoteNo	 = '14102'
												,@parExternalDeliveryNoteId_hidden = 'EE02677'

		
exec  usp_CBI_SelectedStoreInfo	@StoreId = ''		
								
*/




