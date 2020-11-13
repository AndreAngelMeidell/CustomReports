USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1565_AgeControl_Approved]    Script Date: 13.11.2020 08:42:23 ******/
DROP PROCEDURE [dbo].[usp_CBI_1565_AgeControl_Approved]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1565_AgeControl_Approved]    Script Date: 13.11.2020 08:42:23 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_1565_AgeControl_Approved]
(   
    @StoreId AS VARCHAR(100),
	@DateFrom AS DATETIME, 
	@DateTo AS DATETIME,
	@ReasonCode AS BIGINT
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
--	DECLARE @StoreId AS VARCHAR(100),
--	@DateFrom AS DATETIME, 
--	@DateTo AS DATETIME,
--	@ReasonCode AS BIGINT

--SET @StoreId ='14777'
--SET @DateFrom = '2019-09-01'
--SET @DateTo = '2019-12-30'
--SET @ReasonCode = '50'


SELECT distinct frrsar.ReceiptId,  Stage.RuleID AS ReasonCode
INTO #Approved_not_null
FROM  RBIM.Fact_ReceiptRowSalesAndReturn  AS frrsar
LEFT  JOIN RBIM.Dim_Gtin AS dg ON dg.GtinIdx = frrsar.GtinIdx
JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = frrsar.StoreIdx
JOIN RBIM.Dim_Date AS dd ON frrsar.ReceiptDateIdx=dd.DateIdx
JOIN RBIM.Dim_Time AS dt ON frrsar.ReceiptTimeIdx=dt.TimeIdx
JOIN RBIM.Dim_User AS du ON frrsar.CashierUserIdx=du.UserIdx
JOIN RBIM.Dim_Article AS da ON da.ArticleIdx = frrsar.ArticleIdx
JOIN RBIM.Out_ArticleExtraInfo AS oaei ON oaei.ArticleExtraInfoIdx = da.ArticleExtraInfoIdx
--JOIN [BI_Stage].[RBIS].[sArtsXmlRestrictionValidations1] Stage ON Stage.sArtsXmlReceiptHeadIdx=frrsar.ReceiptHeadIdx 
JOIN BI_Stage.RBIS.sArtsXmlRestrictionValidations1 Stage ON Stage.sArtsXmlReceiptHeadIdx = frrsar.ReceiptHeadIdx AND Stage.RowNumber = RIGHT(frrsar.ReceiptIdx,3)
WHERE isnull(oaei.Value_AgeControl,0)>0
AND frrsar.SalesRevenueInclVat>0
AND Stage.ValidationFlag = '1'
AND Stage.RuleID <> ''


SELECT ds.StoreId, dd.FullDate, dt.TimeDescription,(du.FirstName+' '+du.LastName) AS Name, frrsar.CashRegisterNo,frrsar.ReceiptId, RIGHT(frrsar.ReceiptIdx,3) AS Line
,dg.Gtin, da.ArticleName, frrsar.SalesRevenueInclVat, ann.ReasonCode,
CASE
WHEN ann.ReasonCode = '1' then 'Obviously Over Age'   
WHEN ann.ReasonCode = '2' then 'National ID card'   
WHEN ann.ReasonCode = '3' then 'Citizen Card'   
WHEN ann.ReasonCode = '4' then 'Drivers license'   
WHEN ann.ReasonCode = '5' then 'Passport'   
WHEN ann.ReasonCode = '6' then 'Validate UK card'   
WHEN ann.ReasonCode = '7' then 'Fingerprint ID'   
WHEN ann.ReasonCode = '8' then 'Pass cards'   
END AS ReasonCodeName 
,0 AS ReasonCodeIdx
FROM  RBIM.Fact_ReceiptRowSalesAndReturn  AS frrsar
LEFT  JOIN RBIM.Dim_Gtin AS dg ON dg.GtinIdx = frrsar.GtinIdx
JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = frrsar.StoreIdx
JOIN RBIM.Dim_Date AS dd ON frrsar.ReceiptDateIdx=dd.DateIdx
JOIN RBIM.Dim_Time AS dt ON frrsar.ReceiptTimeIdx=dt.TimeIdx
JOIN RBIM.Dim_User AS du ON frrsar.CashierUserIdx=du.UserIdx
JOIN RBIM.Dim_Article AS da ON da.ArticleIdx = frrsar.ArticleIdx
JOIN RBIM.Out_ArticleExtraInfo AS oaei ON oaei.ArticleExtraInfoIdx = da.ArticleExtraInfoIdx
--JOIN [BI_Stage].[RBIS].[sArtsXmlRestrictionValidations1] Stage ON Stage.sArtsXmlReceiptHeadIdx=frrsar.ReceiptHeadIdx 
JOIN BI_Stage.RBIS.sArtsXmlRestrictionValidations1 Stage ON Stage.sArtsXmlReceiptHeadIdx = frrsar.ReceiptHeadIdx AND Stage.RowNumber = RIGHT(frrsar.ReceiptIdx,3)
left JOIN #Approved_not_null ann ON frrsar.ReceiptId = ann.ReceiptId --if records with no approve in bucket should be excluded just change "left join" to "join"
WHERE isnull(oaei.Value_AgeControl,0)>0
AND frrsar.SalesRevenueInclVat>0
AND ds.StoreId= @StoreId
AND frrsar.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx+1
AND Stage.ValidationFlag = '1'
-- and drc.ReasonNo BETWEEN 21 AND 28 --is approved


	END
END



GO

