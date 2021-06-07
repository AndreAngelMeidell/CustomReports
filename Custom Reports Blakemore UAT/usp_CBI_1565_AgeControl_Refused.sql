USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1565_AgeControl_Refused]    Script Date: 13.11.2020 08:41:57 ******/
DROP PROCEDURE [dbo].[usp_CBI_1565_AgeControl_Refused]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1565_AgeControl_Refused]    Script Date: 13.11.2020 08:41:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE PROCEDURE [dbo].[usp_CBI_1565_AgeControl_Refused]
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

----ds.StoreId, dd.FullDate, dt.TimeDescription,(du.FirstName+' '+du.LastName) AS Name, frrsar.CashRegisterNo,frrsar.ReceiptId, RIGHT(frrsar.ReceiptIdx,3) AS Line
--,dg.Gtin, da.ArticleName, frrsar.SalesRevenueInclVat, END AS ReasonName 
--,frrsar.ReasonCodeIdx

SELECT ds2.StoreId,cast(cast(saxrsr.RowSaleDateTime AS datetime2) AS date) AS FullDate, cast(cast(saxrsr.RowSaleDateTime AS datetime2) AS time(0))  AS TimeDescription,
(du.FirstName+' '+du.LastName) AS Name, saxrh.WorkstationId AS CashRegisterNo, saxrh.SequenceNumber AS ReceiptId, saxrsr.RowNumber AS Line,
dg.Gtin, da.ArticleName, saxrsr.SuggestedPrice AS SalesRevenueInclVat, Stage.RuleID AS ReasonCode,
CASE	
WHEN Stage.RuleId = '50' then 'No ID'   
WHEN Stage.RuleId = '51' then 'Fake ID' 
WHEN Stage.RuleId = '52' then 'Believe To Be Suppliying Under Age' 
WHEN Stage.RuleId = '53' then 'Excluded or Banned' 
WHEN Stage.RuleId = '54' then 'Out of Licensing Hours' 
WHEN Stage.RuleId = '55' then 'Customer appears to be Intoxicated' 
WHEN Stage.RuleId = '56' then 'Police In Uniforms' 
WHEN Stage.RuleId = '57' then 'Under Age Alcohol' 
WHEN Stage.RuleId = '58' then 'Under Age Lottery' 
WHEN Stage.RuleId = '59' then 'Under Age Cigarettes & Tobacco' 
WHEN Stage.RuleId = '60' then 'Under Age Video Rental' 
WHEN Stage.RuleId = '61' then 'Under Age Other' 
END AS ReasonCodeName 
,0 AS ReasonCodeIdx
FROM  BI_Stage.RBIS.sArtsXmlReceiptHead1 AS saxrh WITH (NOLOCK)
LEFT JOIN BI_Stage.RBIS.sArtsXmlRestrictionValidations1 AS Stage ON Stage.sArtsXmlReceiptHeadIdx = saxrh.sArtsXmlReceiptHeadIdx
LEFT JOIN BI_Stage.RBIS.sUsersXML_RS AS U ON u.UserName = saxrh.AssociateId AND U.isCurrent=1
LEFT JOIN RBIM.Dim_User AS du ON du.UserId = U.UserId
JOIN BI_Stage.RBIS.sArtsXmlReceiptSaleitemRow1 AS saxrsr ON Stage.sArtsXmlReceiptHeadIdx = saxrsr.sArtsXmlReceiptHeadIdx
JOIN  (select distinct ds.StoreId from BI_Mart.RBIM.Dim_Store AS ds) AS ds2  ON saxrh.UnitId = ds2.StoreId
JOIN RBIM.Dim_Article AS da ON da.ArticleId = saxrsr.ArticleId
JOIN RBIM.Out_ArticleExtraInfo AS oaei ON oaei.ArticleExtraInfoIdx = da.ArticleExtraInfoIdx
JOIN RBIM.Dim_Gtin AS dg ON saxrsr.Gtin = dg.Gtin
WHERE Stage.ValidationFlag= '0'
AND saxrsr.LineType ='Sale'
AND ds2.StoreId = @StoreId
AND saxrsr.RowSaleDateTime BETWEEN @DateFrom AND @DateTo+1
AND isnull(oaei.Value_AgeControl,0)>0
GROUP BY ds2.StoreId,saxrsr.RowSaleDateTime, saxrsr.RowSaleDateTime   ,
(du.FirstName+' '+du.LastName) , saxrh.WorkstationId , saxrh.SequenceNumber  , saxrsr.RowNumber,
dg.Gtin, da.ArticleName, Stage.RuleID, saxrsr.SuggestedPrice

	END
END



GO

