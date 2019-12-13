USE [RSItemESDb]
GO

if exists (select 1 from sys.objects where name = 'usp_CBI_1259_dsArticlePricesDetails' and [type] = 'P')
DROP Procedure [dbo].[usp_CBI_1259_dsArticlePricesDetails]
GO

	
CREATE PROCEDURE [dbo].[usp_CBI_1259_dsArticlePricesDetails] (@StoreId VARCHAR(50), 
													 @DaysFromToday INT = 0)
AS
/*
	DECLARE @DateFrom AS DATE = '2016-02-05'
	DECLARE @DateTo AS DATE = '2019-04-19'
	
	DECLARE @StoreId varchar(50) = '14708'
	DECLARE @DaysFromToday INT = 365
--*/

	IF OBJECT_ID('tempdb..#ArticlePrices') IS NOT NULL DROP TABLE #ArticlePrices

	;WITH AllStoreGroups AS (
		SELECT StoreGroupNo, StoreGroupLinkNo
		FROM StoreGroups SG
		WHERE StoreGroupExternalId = @StoreId OR StoreGroupExternalId = CONCAT('-', @StoreId)
		AND StoreGroupTypeNo = 6
		UNION ALL
		SELECT SG.StoreGroupNo, SG.StoreGroupLinkNo
		FROM StoreGroups SG
		INNER JOIN AllStoreGroups CT ON SG.StoreGroupNo = CT.StoreGroupLinkNo

	)

	,ProfileFromSG AS (
		SELECT PriceProfileNo
		FROM [RSItemESDb].[dbo].[PriceProfiles] PP WITH (NOLOCK)
		INNER JOIN AllStoreGroups SG WITH (NOLOCK) ON PP.StoreGroupNo = SG.StoreGroupNo
		WHERE PriceProfileStatusNo = 1
	)



	SELECT 
		a.ArticleId, ArticleName, abc.Barcode, ap.SalesPrice
		,ap.ArticlePriceTypeNo
		, ass.ArticleStatusName AS 'Status'
		, AP.FromDate AS StartDate
		, AP.ModifiedDate
		, AP.SalesPriceCurrencyNo
		, C.CurrencyName
		,AP.PriceProfileNo
	INTO #ArticlePrices
	--select  AP.*
	FROM [dbo].[Articles] AS A WITH (NOLOCK)
	INNER JOIN ArticlePrices as AP on a.ArticleNo = ap.ArticleNo AND ArticlePriceStatusNo = 1
	INNER JOIN ProfileFromSG AS PSG ON AP.PriceProfileNo = PSG.PriceProfileNo					-- Only filters data by profileno (before in CTE we took storeno and all higher storegroups in which it is)
	LEFT JOIN ArticleBarcodes ABC ON A.DefaultArticleBarcodeNo = ABC.ArticleBarcodeNo
	LEFT JOIN Currencies as C on c.CurrencyNo = AP.SalesPriceCurrencyNo
	LEFT JOIN ArticleStatuses as ASS on a.ArticleStatusNo = ASS.ArticleStatusNo
	WHERE AP.ArticlePriceTypeNo IN (1, 2)
		  AND AP.FromDate <= GETDATE()


	SELECT 
			APT1.ArticleId
		   ,APT1.ArticleName
		   ,APT1.Barcode
		   ,APT1.SalesPrice AS Pris
		   ,CASE
				WHEN APT1.ArticlePriceTypeNo  = 1 THEN 'Ord pris'
				WHEN APT1.ArticlePriceTypeNo  = 2 THEN 'Extra pris'
				ELSE ''
			END AS 'Pristyp'
		   ,APT1.StartDate
		   ,APT2.SalesPrice AS OrdPris
	FROM #ArticlePrices APT1
	OUTER APPLY --#ArticlePrices
	(
		SELECT TOP 1 ArticleId, ArticleName, ArticlePriceTypeNo, StartDate, ModifiedDate, SalesPrice
		FROM #ArticlePrices AP
		WHERE AP.StartDate < APT1.StartDate 
			  AND ArticlePriceTypeNo = 1
			  AND AP.ArticleId = APT1.ArticleId 
		ORDER BY AP.StartDate DESC 
	) AS APT2
	WHERE APT1.ModifiedDate >= DATEADD(DAY, -@DaysFromToday, GETDATE())
		  AND APT1.SalesPrice <> APT2.SalesPrice
	ORDER BY APT1.ArticleId ASC, APT1.StartDate asc



	


GO


