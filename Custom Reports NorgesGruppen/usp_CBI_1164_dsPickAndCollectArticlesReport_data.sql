USE [PickAndCollectDB]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1164_dsPickAndCollectArticlesReport_data]    Script Date: 25.09.2020 11:44:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_1164_dsPickAndCollectArticlesReport_data](
    @StoreId INT,  
	 @DateFrom DATE,
	 @DateTo DATE,  
    @Category VARCHAR(1000)  
)
AS
BEGIN


/*DECLARE  @StoreId INT = 10096 ,  
	 @DateFrom DATE = '2016-01-14',
	 @DateTo DATE = '2016-08-10',  
    @Category VARCHAR(1000) = null
*/

SELECT  
	dco.StoreName
	, dcol.ArticleID
	, dcol.ArticleStorageType
	, SUM(dcol.OrderedQty) AS OrderedQty
	, dcol.ArticleUnit
	, (dcol.ArticleName + ' ' + isnull(dcol.ArticleInfo,'')) AS ArticleName
	, dcol.ArticleEan
	, dcol.PlanogramGroupName
FROM DeliveryCustomerOrders dco
JOIN dbo.DeliveryCustomerOrderLines dcol ON dcol.CustomerOrderNo = dco.CustomerOrderNo
JOIN dbo.CustomerOrderLineStates col ON col.CustomerOrderLineStatus = dcol.CustomerOrderLineStatus
WHERE 
	dco.StoreNo = @StoreId
	AND dco.OrderStatus IN (10, 20) --  include only the relevant orders
	AND (CAST(dco.CollectStartTime AS DATE) BETWEEN @DateFrom AND @DateTo)
	AND (@Category IS NULL OR dcol.ArticleStorageType = @Category)
	AND dcol.CustomerOrderLineStatus = 10 -- only articles that have not been picked	
GROUP BY
dco.StoreName, dcol.ArticleID, dcol.ArticleStorageType, dcol.ArticleUnit, dcol.ArticleName, dcol.ArticleEan, dcol.PlanogramGroupName, ArticleInfo
ORDER BY dcol.ArticleStorageType, dcol.ArticleName

END

GO

