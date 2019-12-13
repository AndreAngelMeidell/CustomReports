USE [BI_Mart]
GO

IF OBJECT_ID('usp_CBI_1014_DeviantBehaviour') IS NOT NULL DROP PROCEDURE [dbo].[usp_CBI_1014_DeviantBehaviour] 
GO

CREATE PROCEDURE [dbo].[usp_CBI_1014_DeviantBehaviour] (
	@FromDate DATETIME = ''
	,@ToDate DATETIME = ''
	,@ReasonTypeId VARCHAR(MAX) = ''
	,@User VARCHAR(MAX) = ''
)
AS

	;WITH receiptP1 AS
	(
	SELECT 
		usr.LoginName AS CashierId
		,usr.FirstName
		,usr.LastName
		,rr.CashRegisterNo
		,Dd.FullDate AS ReceiptDate
		,Dt.TimeDescription AS ReceiptTime
		,ISNULL(st.StoreId, '') AS StoreId
		,ISNULL(st.StoreName,'') AS StoreName
		,ISNULL(st.StoreExternalId,'') AS StoreExternalId
		,rr.ReceiptId
		,art.ArticleId
		,CASE
			WHEN art.ArticleId=-1 THEN ''
			WHEN art.ArticleId<>-1 THEN art.ArticleName
		END AS ArticleName
		,MAX(CASE 
				  WHEN rr.PriceTypeIdx = 29 AND rr.TransTypeIdx = 10101 AND art.ArticleTypeId = 120 AND r.Amount2 > 0 THEN  '1'				-- "1 Manual Prices"			
				  WHEN rr.PriceTypeIdx in (15,16) AND rr.TransTypeIdx = 10501 AND r.Amount2 > 0 THEN '2'									-- "2 ItemDiscount"				
				  WHEN rr.PriceTypeIdx = 15 AND rr.TransTypeIdx = 10501 AND (r.Amount2 = 0 OR r.Amount2 IS NULL) THEN '3'					-- "3 FreeDiscount"				
				  WHEN rr.TransTypeIdx in (90203,90204)  AND r.Amount2 > 0 THEN '4'															-- "4 Correction"
				  WHEN rr.PriceTypeIdx = 14 AND rr.TransTypeIdx = 10202 THEN '5'															-- "5 Article repurchase"		
				  WHEN rr.TransTypeIdx = 20806 AND cashDraw.TransTypeValueTxt2 = 'CashDrawerOpenedMethod: NoSale' THEN '6'					-- "6 CashDrawerOpenings"		
				  ELSE 0 END) AS TransType
		,SUM(CASE 
				  WHEN rr.PriceTypeIdx = 29 AND rr.TransTypeIdx = 10101 AND art.ArticleTypeId = 120 AND r.Amount2 > 0 THEN   rr.Amount 		-- "1 Manual Prices" -- Price override
				  WHEN rr.PriceTypeIdx in(15,16) AND rr.TransTypeIdx = 10501 AND r.Amount2 > 0 THEN rr.DiscountAmount 						-- "2 ItemDiscount" -- AS LineDiscountVarurabatt  -- Manuell rabatt på rad				
				  WHEN rr.PriceTypeIdx = 15 AND rr.TransTypeIdx = 10501 AND (r.Amount2 = 0 OR r.Amount2 IS NULL) THEN rr.DiscountAmount		-- "3 FreeDiscount" -- AS LineDiscountGiBort	  -- Manuell 100% rabatt på rad GI BORT	
				  WHEN rr.TransTypeIdx in (90203,90204)  AND r.Amount2 > 0 THEN  rr.Amount --rr.DiscountAmount								-- "4 Correction"
				  WHEN rr.PriceTypeIdx = 14 AND rr.TransTypeIdx = 10202 THEN  rr.Amount														-- "5 Article repurchase"
				  WHEN rr.TransTypeIdx = 20806 AND cashDraw.TransTypeValueTxt2 = 'CashDrawerOpenedMethod: NoSale' THEN 1					-- "6 CashDrawerOpenings"
				  ELSE 0 END) AS Amount
	--select  rr.PriceTypeIdx, rr.TransTypeIdx, usr.FirstName, usr.userid, *
	FROM RBIM.Fact_Receipt r WITH (NOLOCK)
	JOIN RBIM.Fact_ReceiptRowSalesAndReturn rr WITH (NOLOCK) ON r.ReceiptIdx = rr.ReceiptIdx
	LEFT JOIN BI_MArt.RBIM.Cov_CustomerSalesEvent cashDraw WITH (NOLOCK) ON r.ReceiptHeadIdx = cashDraw.ReceiptHeadIdx
	LEFT JOIN [RBIM].[Dim_User] usr WITH (NOLOCK) ON rr.CashierUserIdx = usr.UserIdx
	LEFT JOIN [RBIM].[Dim_Date] Dd WITH (NOLOCK) ON  rr.ReceiptDateIdx = Dd.DateIdx
	LEFT JOIN [RBIM].[Dim_Time] Dt WITH (NOLOCK) ON rr.ReceiptTimeIdx = Dt.TimeIdx
	LEFT JOIN [RBIM].[Dim_Store] st WITH (NOLOCK) ON rr.StoreIdx = st.StoreIdx
	LEFT JOIN [RBIM].[Dim_Article] art WITH (NOLOCK) ON r.ArticleIdx = art.ArticleIdx
	WHERE st.isCurrent = 1 AND art.isCurrent = 1 
		  AND (rr.PriceTypeIdx IN (29,14,15,16,22)  OR rr.TransTypeIdx IN (10101, 10501, 10501, 90203,90204, 10202, 90406, 20806))
	AND rr.ReceiptDateIdx >= CONVERT(VARCHAR(10),@FromDate, 112) AND rr.ReceiptDateIdx <= CONVERT(VARCHAR(10),@ToDate, 112)
	AND usr.UserId  IN (SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@User,',')) 
	GROUP BY usr.LoginName ,usr.FirstName, usr.LastName, rr.CashRegisterNo, Dd.FullDate, Dt.TimeDescription,ISNULL(st.StoreId, '') ,ISNULL(st.StoreName,''), ISNULL(st.StoreExternalId, ''), rr.ReceiptId
			,art.ArticleId, art.ArticleName
	)


	SELECT 	rcpt.CashierId
			,CONCAT(rcpt.FirstName, ' ', rcpt.LastName) as CashierName
			,rcpt.CashRegisterNo
			,rcpt.ReceiptDate
			,rcpt.ReceiptTime
			,rcpt.StoreId
			,rcpt.StoreName
			,rcpt.StoreExternalId
			,rcpt.ReceiptId
			,rcpt.ArticleId
			,rcpt.ArticleName
			,CASE WHEN rcpt.TransType = 1 THEN 'Manual Prices'
				  WHEN rcpt.TransType = 2 THEN 'Item Discount'
				  WHEN rcpt.TransType = 3 THEN 'Free Discount'
				  WHEN rcpt.TransType = 4 THEN 'Correction'
				  WHEN rcpt.TransType = 5 THEN 'Article repurchase'
				  WHEN rcpt.TransType = 6 THEN 'Cash drawer openings'
				  ELSE ''
			END AS ReasonType --TransType
			,CAST(rcpt.Amount AS decimal(18,2)) AS Amount
	FROM receiptP1 rcpt
	INNER JOIN  [dbo].[ufn_RBI_SplittParameterString](@ReasonTypeId,',') AS tranFiltr ON rcpt.TransType = tranFiltr.ParameterValue
	ORDER BY ReceiptId ASC, ReceiptDate DESC



GO


/*

exec [dbo].[usp_CBI_1014_DeviantBehaviour] 	@FromDate = '2015-01-01 09:00:00.000', @ToDate = '2019-02-21 23:59:00.000', @ReasonTypeId = '1,2,3,4,5,6', @User = '58,59,-1,-2'



*/



