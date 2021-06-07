USE [PickAndCollectDB]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1164_dsPickAndCollectArticlesSubReport_data]    Script Date: 25.09.2020 12:13:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_1164_dsPickAndCollectArticlesSubReport_data](
    @StoreId INT,  
	 @DateFrom DATE,
	 @DateTo DATE,  
    @ArticleId VARCHAR(1000)  
)
AS
BEGIN


/*DECLARE  @StoreId INT = 10096 ,  
	 @DateFrom DATE = '2016-01-14',
	 @DateTo DATE = '2016-08-10',  
    @ArticleId VARCHAR(1000) = '2000422224501'
*/

SELECT  
	dco.StoreName
	, dcol.ArticleName
	, dco.OrderID
	, c.CustomerNo
	, (ISNULL(c.FirstName,'') + ' ' + ISNULL(c.MiddleName,'') + ' ' + ISNULL(c.LastName,'')) AS Customer
	, dco.CollectStartTime
	, dco.CollectEndTime
	, dcol.OrderedQty
	, dcol.ArticleUnit
	, (SELECT COUNT(*) FROM dbo.DeliveryCustomerOrderLines 
									WHERE LineNumber = dcol.LineNumber
									AND SubstitutionForEan = dcol.ArticleEan
									AND CustomerOrderNo = dcol.CustomerOrderNo
									) AS HasSubstitution
FROM DeliveryCustomerOrders dco
JOIN dbo.DeliveryCustomerOrderLines dcol ON dcol.CustomerOrderNo = dco.CustomerOrderNo
JOIN dbo.CustomerOrderLineStates col ON col.CustomerOrderLineStatus = dcol.CustomerOrderLineStatus
JOIN dbo.Customers c ON c.CustomerNo = dco.CustomerNo
WHERE 
	dco.StoreNo = @StoreId
	AND (CAST(dco.CollectStartTime AS DATE) BETWEEN @DateFrom AND @DateTo)
	AND dcol.ArticleID = @ArticleId
	AND dcol.CustomerOrderLineStatus = 10 -- only articles that have not been picked
ORDER BY dcol.ArticleStorageType, dcol.ArticleName

END


GO

