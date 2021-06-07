USE [PickAndCollectDB]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1169_dsPickAndCollectOrderOverview]    Script Date: 25.09.2020 11:45:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_1169_dsPickAndCollectOrderOverview](
     @StoreId INT,  
	 @DateFrom DATE,
	 @DateTo DATE
)
AS
BEGIN

--test
--DECLARE @StoreId AS INT = 10446
--DECLARE @DateFrom AS DATE = '2017-12-13'
--DECLARE @DateTo AS DATE = '2019-12-14'

SELECT dco.StoreNo,dco.StoreName, dco.OrderID, cos.CustomerOrderStatusName, dco.CustomerId, vc.FirstName, vc.MiddleName, vc.LastName
,CAST(CAST(dco.CollectStartTime as TIME) AS VARCHAR(5))+'-'+CAST(CAST(dco.CollectEndTime as TIME) AS VARCHAR(5))  AS 'PicUpTime'
,'______________' AS PickedBy
,SUM(dcol.OrderedQty) AS AntallVarer, COUNT(*) AS AntallLinjer
FROM dbo.DeliveryCustomerOrders AS dco
JOIN dbo.DeliveryCustomerOrderLines dcol ON dcol.CustomerOrderNo = dco.CustomerOrderNo
JOIN dbo.CustomerOrderStates AS cos ON cos.CustomerOrderStatus=dco.OrderStatus
JOIN dbo.CustomersView  AS vc ON vc.CustomerID = dco.CustomerId
WHERE 
	dco.StoreNo = @StoreId
	AND cos.CustomerOrderStatus=20
	and (cast(dco.CollectStartTime as date) between @DateFrom and @DateTo)
GROUP BY
	dco.StoreNo,dco.StoreName, dco.OrderID, cos.CustomerOrderStatusName, dco.CustomerId, vc.FirstName, vc.MiddleName, vc.LastName, dco.CollectStartTime, dco.CollectEndTime
ORDER BY 
	9


END


GO

