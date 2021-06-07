USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1535_PayPointSales]    Script Date: 13.11.2020 08:43:16 ******/
DROP PROCEDURE [dbo].[usp_CBI_1535_PayPointSales]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1535_PayPointSales]    Script Date: 13.11.2020 08:43:16 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_1535_PayPointSales]
(   
    @StoreId AS VARCHAR(100),	
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME
) 
AS  
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  


	
--DECLARE   @StoreId AS VARCHAR(MAX) = '20097' -- varchar(max)
--DECLARE   @DateFrom AS DATE = '2019-09-23' -- datetime
--DECLARE   @DateTo AS DATE = '2019-09-24' -- datetime

--20191129 Changes fr.Amount>0  to fr.Amount<>0 
--20191129 Changes RSI.LineType='Sale' to (RSI.LineType='Sale' OR RSI.LineType='Return') 


--75
SELECT  
ds.StoreId, ds.StoreName, fr.CashRegisterNo, fr.ReceiptId, fr.ReceiptDateIdx, fr.ReceiptTimeIdx
,da.Lev3ArticleHierarchyDisplayId, da.Lev3ArticleHierarchyName, RSI.ShortDescription, RSI.Quantity
,fr.Amount AS Value,RSI.PayPointTransactionId, RSI.SchemeId,
CASE WHEN fr.Amount<>0  THEN 'Success' ELSE 'Failure' END AS Status
FROM [BI_Stage].[RBIS].[sArtsXmlReceiptSaleitemRow1] RSI
JOIN BI_Mart.RBIM.Fact_Receipt AS fr ON RSI.sArtsXmlReceiptHeadIdx+RSI.RowNumber=fr.ReceiptIdx
JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = fr.StoreIdx
JOIN RBIM.Dim_Date AS dd ON dd.DateIdx=fr.ReceiptDateIdx
JOIN RBIM.Dim_Article AS da ON da.ArticleId = RSI.ArticleId AND da.isCurrent=1
WHERE (RSI.LineType='Sale' OR RSI.LineType='Return')
AND da.Lev3ArticleHierarchyDisplayId=30084
AND RSI.CancelFlag=0
AND ds.StoreId=@StoreId
AND RSI.PayPointTransactionId<>0 
AND dd.FullDate BETWEEN @DateFrom AND @DateTo
ORDER BY ds.StoreId, ds.StoreName, fr.ReceiptDateIdx, fr.ReceiptTimeIdx, RSI.PayPointTransactionId



END



GO

