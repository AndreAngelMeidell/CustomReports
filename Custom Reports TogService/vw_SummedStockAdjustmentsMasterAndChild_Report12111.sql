USE [VBDCM]
GO

/****** Object:  View [dbo].[vw_SummedStockAdjustmentsMasterAndChild_Report12111]    Script Date: 01.07.2017 14:44:03 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[vw_SummedStockAdjustmentsMasterAndChild_Report12111]
AS 


SELECT storeno, ArticleNo, stockadjtype, adjustmentrefno, MAX(adjustmentdate) AS AdjustmentDate, NULL AS StockadjReasonNo, NULL AS MasterArticleNo,  
 SUM(adjustmentqty) AS AdjustmentQty, 
 SUM(adjustmentnetcostamount) AS AdjustmentNetCostAmount, 
 SUM(DerivedNetCostAmount) AS DerivedNetCostAmount,
 MAX(netprice) AS NetPrice, 
 NULL AS LinkQty,
 userNo
FROM vw_StockAdjustmentsMasterAndChild
WHERE stockadjtype IN (51,52)
GROUP BY storeno, articleno, stockadjtype, adjustmentrefno, userNo

UNION ALL

SELECT StoreNo,  ArticleNo, StockAdjType, AdjustmentRefNo, AdjustmentDate, StockAdjReasonNo, MasterArticleNo, 
AdjustmentQty,  
AdjustmentNetCostAmount, 
DerivedNetCostAmount,
NetPrice, 
LinkQty ,
Userno
FROM vw_StockAdjustmentsMasterAndChild
WHERE stockadjtype NOT IN (51,52)





GO


