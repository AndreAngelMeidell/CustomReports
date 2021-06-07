USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1565_AgeControl_Master]    Script Date: 13.11.2020 08:42:10 ******/
DROP PROCEDURE [dbo].[usp_CBI_1565_AgeControl_Master]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1565_AgeControl_Master]    Script Date: 13.11.2020 08:42:10 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_1565_AgeControl_Master]
(   
    @StoreId AS VARCHAR(100),
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME
	--@ReasonCode AS BIGINT
) 
AS  
BEGIN

	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;  

------------------------------------------------------------------------------------------------------
	IF (@DateFrom IS NULL)
	BEGIN
		SELECT TOP(0) 1
	END
	ELSE BEGIN		

		DECLARE @DateFromIdx integer
		DECLARE @DateToIdx integer
		
		SET @DateFromIdx = cast(convert(varchar(8), @DateFrom, 112) as integer)
		SET @DateToIdx = cast(convert(varchar(8), @DateTo, 112) as integer)

		
-- For test:
--		DECLARE @StoreId AS VARCHAR(100),
--	@DateFrom AS DATETIME, 
--	@DateTo AS DATETIME,
--	@ReasonCode AS BIGINT

--SET @StoreId ='14777'
--SET @DateFrom = '2019-09-01'
--SET @DateTo = '2019-12-30'
--SET @ReasonCode = '50'

SELECT du.UserId,(du.FirstName+' '+du.LastName) AS Name, f.ReceiptHeadIdx
INTO #Approved
FROM  RBIM.Fact_ReceiptRowSalesAndReturn AS F WITH (NOLOCK)
LEFT JOIN RBIM.Dim_Gtin AS dg ON dg.GtinIdx = F.GtinIdx
JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = F.StoreIdx
JOIN RBIM.Dim_Date AS dd ON f.ReceiptDateIdx=dd.DateIdx
JOIN RBIM.Dim_Time AS dt ON f.ReceiptTimeIdx=dt.TimeIdx
JOIN RBIM.Dim_User AS du ON f.CashierUserIdx=du.UserIdx
JOIN RBIM.Dim_Article AS da ON da.ArticleIdx = F.ArticleIdx
JOIN RBIM.Out_ArticleExtraInfo AS oaei ON oaei.ArticleExtraInfoIdx = da.ArticleExtraInfoIdx
JOIN [BI_Stage].[RBIS].[sArtsXmlRestrictionValidations1] AS Stage ON Stage.sArtsXmlReceiptHeadIdx=f.ReceiptHeadIdx   AND Stage.RowNumber = RIGHT(f.ReceiptIdx,3)
WHERE isnull(oaei.Value_AgeControl,0)>0
AND f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
AND ds.StoreId = @StoreId
AND Stage.ValidationFlag = '1'
GROUP BY du.UserId, (du.FirstName+' '+du.LastName), f.ReceiptHeadIdx


SELECT du.UserId, (du.FirstName+' '+du.LastName) AS Name, saxrh.sArtsXmlReceiptHeadIdx
INTO #Refused
FROM  BI_Stage.RBIS.sArtsXmlReceiptHead1 AS saxrh WITH (NOLOCK)
LEFT JOIN BI_Stage.RBIS.sArtsXmlRestrictionValidations1 AS Stage ON Stage.sArtsXmlReceiptHeadIdx = saxrh.sArtsXmlReceiptHeadIdx
LEFT JOIN BI_Stage.RBIS.sUsersXML_RS AS U ON u.UserName = saxrh.AssociateId AND U.isCurrent=1
LEFT JOIN RBIM.Dim_User AS du ON du.UserId = U.UserId
JOIN BI_Stage.RBIS.sArtsXmlReceiptSaleitemRow1 AS saxrsr ON Stage.sArtsXmlReceiptHeadIdx = saxrsr.sArtsXmlReceiptHeadIdx
JOIN  (select distinct ds.StoreId from BI_Mart.RBIM.Dim_Store AS ds) AS ds2  ON saxrh.UnitId = ds2.StoreId
JOIN RBIM.Dim_Article AS da ON da.ArticleId = saxrsr.ArticleId
JOIN RBIM.Out_ArticleExtraInfo AS oaei ON oaei.ArticleExtraInfoIdx = da.ArticleExtraInfoIdx
WHERE Stage.ValidationFlag= '0'
AND saxrsr.LineType ='Sale'
AND ds2.StoreId = @StoreId
AND saxrsr.RowSaleDateTime BETWEEN @DateFrom AND @DateTo+1
AND isnull(oaei.Value_AgeControl,0)>0
GROUP BY du.UserId, (du.FirstName+' '+du.LastName), saxrh.sArtsXmlReceiptHeadIdx

SELECT  du.UserId AS UserId
INTO #Total
FROM  RBIM.Fact_ReceiptRowSalesAndReturn AS F WITH (NOLOCK)
LEFT JOIN RBIM.Dim_Gtin AS dg ON dg.GtinIdx = F.GtinIdx
JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = F.StoreIdx
--JOIN RBIM.Dim_Date AS dd ON f.ReceiptDateIdx=dd.DateIdx
--JOIN RBIM.Dim_Time AS dt ON f.ReceiptTimeIdx=dt.TimeIdx
JOIN RBIM.Dim_User AS du ON f.CashierUserIdx=du.UserIdx
JOIN RBIM.Dim_Article AS da ON da.ArticleIdx = F.ArticleIdx
JOIN RBIM.Out_ArticleExtraInfo AS oaei ON oaei.ArticleExtraInfoIdx = da.ArticleExtraInfoIdx
WHERE isnull(oaei.Value_AgeControl,0)>0
AND ds.StoreId= @StoreId
AND f.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx+1
GROUP BY du.UserId


--Datasett
--Del av tallet / Det hele tallet * 100 = (x) %
SELECT du.UserId, (du.FirstName+' '+du.LastName) AS Name
, CONVERT(DECIMAL(16,2),ISNULL(count(A.UserId),0)) AS ApprovedNo
, CONVERT(DECIMAL(16,2),ISNULL(count(distinct R.sArtsXmlReceiptHeadIdx),0)) AS RefusedNo
, CONVERT(DECIMAL(16,2),ISNULL(count(A.UserId)+COUNT(distinct R.sArtsXmlReceiptHeadIdx),0)) AS TotalNo 
, isnull(CONVERT(DECIMAL(16,2), CONVERT(DECIMAL(16,2),ISNULL(count(A.UserId),0)) / NULLIF((CONVERT(DECIMAL(16,2),ISNULL(count(T.UserId),0))),0)),0)*100.00 AS ApprovedPart
, isnull(CONVERT(DECIMAL(16,2), CONVERT(DECIMAL(16,2),ISNULL(count(distinct R.sArtsXmlReceiptHeadIdx),0)) / NULLIF((CONVERT(DECIMAL(16,2),ISNULL(count(A.UserId)+count(distinct R.sArtsXmlReceiptHeadIdx),0))),0)),0)*100.00 AS RefusedPart
FROM  RBIM.Dim_User  AS du WITH (NOLOCK)
LEFT JOIN #Total AS T ON du.UserId = T.UserId
LEFT JOIN #Approved AS A ON du.UserId = A.UserId
LEFT JOIN #Refused AS R ON du.UserId = R.UserId
where coalesce(T.UserId,A.UserId, R.UserId) is not NULL
GROUP BY du.UserId, (du.FirstName+' '+du.LastName)
ORDER BY du.UserId


DROP TABLE IF EXISTS #Approved
DROP TABLE IF EXISTS #Refused
DROP TABLE IF EXISTS #Total






	END

END



GO

