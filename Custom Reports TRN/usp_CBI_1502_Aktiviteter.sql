USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1502_Aktiviteter]    Script Date: 15.01.2019 14:33:48 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



ALTER PROCEDURE [dbo].[usp_CBI_1502_Aktiviteter] 
(   
    @StoreOrGroupNo AS VARCHAR(MAX),
	@DateFrom AS DATE, 
	@DateTo AS DATE,
	@CampaignNo AS VARCHAR(max)
) 
AS 
BEGIN
SET NOCOUNT ON;


--TRN basket temps
IF OBJECT_ID('tempdb..#KampanjeBonger') IS NOT NULL 
	DROP TABLE #KampanjeBonger

IF OBJECT_ID('tempdb..#SubTotal') IS NOT NULL 
	DROP TABLE #SubTotal

IF OBJECT_ID('tempdb..#Total') IS NOT NULL 
	DROP TABLE #Total

IF OBJECT_ID('tempdb..#Kampanje') IS NOT NULL 
	DROP TABLE #Kampanje

IF OBJECT_ID('tempdb..#BasketTotal') IS NOT NULL 
	DROP TABLE #BasketTotal


IF (@DateFrom IS NULL)
BEGIN
	SELECT TOP(0) 1 -- {RS-34990} initial report load improvement
END
ELSE BEGIN

DECLARE  @DateFromIdx INTEGER  = cast(convert(char(8), @DateFrom, 112) as integer)
DECLARE  @DateToIdx INTEGER  = cast(convert(char(8), @DateTo, 112) as integer)



IF RTRIM(LTRIM(@CampaignNo)) = '' SET @CampaignNo = NULL

DECLARE @Campaign TABLE(
CampaignNo VARCHAR(MAX))

INSERT INTO @Campaign
SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@CampaignNo,',''')


SELECT DISTINCT ds.*	--(RS-27332)
INTO #Stores
FROM RBIM.Dim_Store ds
LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@StoreOrGroupNo,',''')) n  ON n.ParameterValue IN (
						ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
						ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
						ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
						ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
						ds.StoreId) 
WHERE n.ParameterValue IS NOT NULL --AND ds.IsCurrentStore=1 AND ds.isCurrent=1

--SELECT * FROM  #Stores AS S
SELECT DISTINCT FR.ReceiptHeadIdx , FR.CampaignDiscountCombinationIdx
INTO #KampanjeBonger
FROM  RBIM.Fact_Receipt (NOLOCK) AS FR
JOIN #Stores AS S ON S.StoreIdx = FR.StoreIdx 
JOIN RBIM.Dim_Date AS DD ON fr.ReceiptDateIdx=dd.DateIdx
JOIN RBIM.Dim_CampaignDiscountCombination AS DCDC ON DCDC.CampaignDiscountCombinationIdx = FR.CampaignDiscountCombinationIdx
WHERE DD.FullDate BETWEEN @DateFrom AND @DateTo
AND DCDC.CampaignDiscountCombinationId IN (SELECT C.CampaignNo FROM @Campaign AS C)

--SELECT * FROM  #KampanjeBonger AS KB --Denne er tregest, lage en mellom temp før kamp?

SELECT FRRSAR.ReceiptHeadIdx
,FRRSAR.CampaignDiscountCombinationIdx
,S.StoreId
,FRRSAR.SalesAmountExclVat
,FRRSAR.NumberOfReceiptsWithSale
,FRRSAR.QuantityOfArticlesSold
,FRRSAR.DiscountAmount
INTO #SubTotal
FROM RBIM.Fact_ReceiptRowSalesAndReturn (NOLOCK) AS FRRSAR
JOIN #Stores AS S ON S.StoreIdx = FRRSAR.StoreIdx
JOIN #KampanjeBonger AS KB ON KB.ReceiptHeadIdx = FRRSAR.ReceiptHeadIdx
JOIN RBIM.Dim_Date AS DD ON FRRSAR.ReceiptDateIdx=dd.DateIdx
--WHERE FRRSAR.ReceiptDateIdx BETWEEN @DateFromIdx AND @DateToIdx
WHERE DD.FullDate BETWEEN @DateFrom AND @DateTo

--SELECT * FROM  #SubTotal AS ST

SELECT 
	st.ReceiptHeadIdx
	,MAX(st.CampaignDiscountCombinationIdx) AS  CampaignDiscountCombinationIdx
	,st.StoreId
	,SUM(st.SalesAmountExclVat) as SalesRevenue
	,SUM(st.NumberOfReceiptsWithSale) AS NumberOfCustomers
	,SUM(ST.QuantityOfArticlesSold) AS QuantityOfArticlesSold
	,SUM(ST.DiscountAmount) AS DiscountAmount
INTO #Total
FROM #SubTotal AS ST 
GROUP BY st.ReceiptHeadIdx, st.StoreId

--SELECT * FROM #Total

SELECT 
	 T.CampaignDiscountCombinationIdx
	,T.StoreId
	,SUM(T.SalesRevenue) AS SalesRevenue
	,SUM(T.NumberOfCustomers) AS NumberOfCustomers
	,SUM(T.QuantityOfArticlesSold) AS QuantityOfArticlesSold
	,SUM(T.SalesRevenue) / SUM(T.NumberOfCustomers) AS Basket
	,SUM(T.DiscountAmount) AS DiscountAmount
INTO #BasketTotal
FROM  #Total AS T
GROUP BY T.CampaignDiscountCombinationIdx, T.StoreId
ORDER BY 1

--SELECT * FROM  #BasketTotal AS BT

SELECT 
 ACSPH.CampaignDiscountCombinationIdx
,CDC.CampaignId
,CDC.CampaignName
,CDC.CampaignDiscountCombinationName
,S.StoreId
,s.StoreDisplayId
,SUM(ACSPH.NumberOfCustomersPerSelectedArticle) AS NumberOfCampaignCustomers
,SUM(ACSPH.SalesAmountExclVat) / SUM(ACSPH.NumberOfCustomersPerSelectedArticle) AS CampaignBasket
,SUM(ACSPH.NumberOfArticlesSold) AS NumberOfArticlesSold
,SUM(CAST(ACSPH.NumberOfArticlesSold AS DECIMAL(20,4))) / SUM(CAST(ACSPH.NumberOfReceiptsPerSelectedArticle AS DECIMAL(20,4))) AS ItemPrCustomer
,SUM(ACSPH.SalesAmountExclVat) AS SalesAmountExclVat
,SUM(ACSPH.CampaignGrossProfit) AS CampaignGrossProfit
,SUM(ACSPH.DiscountAmount) AS DiscountAmount
INTO #Kampanje
FROM BI_Mart.RBIM.Agg_CampaignSalesPerHour (NOLOCK)  AS ACSPH 
JOIN RBIM.Dim_Date AS DD ON ACSPH.ReceiptDateIdx=dd.DateIdx
JOIN BI_Mart.RBIM.Dim_CampaignDiscountCombination (NOLOCK)  AS CDC ON CDC.CampaignDiscountCombinationIdx = ACSPH.CampaignDiscountCombinationIdx
JOIN #Stores AS S ON S.StoreIdx = ACSPH.StoreIdx
WHERE 1=1
AND NumberOfReceiptsPerSelectedArticle<>0
AND CDC.CampaignId>0
AND DD.FullDate BETWEEN @DateFrom AND @DateTo
AND CDC.CampaignDiscountCombinationId IN (SELECT C.CampaignNo FROM @Campaign AS C)
GROUP BY ACSPH.CampaignDiscountCombinationIdx, CDC.CampaignId, CDC.CampaignName,CDC.CampaignDiscountCombinationName, S.StoreId, s.StoreDisplayId
ORDER BY ACSPH.CampaignDiscountCombinationIdx, CDC.CampaignId, CDC.CampaignName,CDC.CampaignDiscountCombinationName

--SELECT * FROM #Kampanje AS BT

select	K.StoreId as StoreNo
		,K.StoreDisplayId as StoreName
		,CampaignDiscountCombinationName
		,K.NumberOfCampaignCustomers
		,t.SalesRevenue/k.NumberOfArticlesSold AS Basket
		,K.NumberOfArticlesSold
		,CAST(K.ItemPrCustomer AS decimal(13,2)) AS ItemPrCustomer
		,k.SalesAmountExclVat
		,k.DiscountAmount
		,T.QuantityOfArticlesSold
		,cast((Cast((T.QuantityOfArticlesSold) as decimal(13,2))/cast((K.NumberOfCampaignCustomers) as Decimal(13,2))) as decimal(13,2)) as ItemPrCust
		,t.SalesRevenue
From #Kampanje K
--JOIN #Stores AS S ON S.StoreId = K.StoreId
JOIN #BasketTotal AS T ON K.CampaignDiscountCombinationIdx=t.CampaignDiscountCombinationIdx AND T.StoreId=k.StoreId
 

----Ønsker dato fra og til
----butikker velger
----Dynamisk valg abv kampanje for priode over, multi selct
 

--SELECT * FROM  SelectedSales

END 

END



----Query String FOR inp_parameter
--SELECT DISTINCT DCDC.CampaignDiscountCombinationId as CampaignNo, DCDC.CampaignDiscountCombinationName as CampaignName  
--FROM RBIM.Agg_CampaignSalesPerHour AS ACSPH
--JOIN RBIM.Dim_CampaignDiscountCombination AS DCDC ON DCDC.CampaignDiscountCombinationIdx = ACSPH.CampaignDiscountCombinationIdx
--WHERE ACSPH.CampaignDiscountCombinationIdx>0
--ORDER BY 2



GO

