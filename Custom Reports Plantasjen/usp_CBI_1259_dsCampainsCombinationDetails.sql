USE [RSItemESDb]
GO

if exists (select 1 from sys.objects where name = 'usp_CBI_1259_dsCampainsCombinationDetails' and [type] = 'P')
DROP Procedure [dbo].[usp_CBI_1259_dsCampainsCombinationDetails]
GO

CREATE PROCEDURE [dbo].[usp_CBI_1259_dsCampainsCombinationDetails] (    
	@StoreId NVARCHAR(256),
	@DateFrom AS DATE, 
	@DateTo AS DATE,
	@GetDataForStart AS BIT,	-- 1 - Start date, 0 - end date
	@Combination AS BIT,			-- 1 - Campaigns combinations, 0 - Campaigns
	@IncludeArticles AS BIT = 1
	 )
AS
BEGIN

DECLARE @sql as NVARCHAR(MAX) = ''

-- Campaigns combinations
	SET @sql =  @sql + '
			;WITH CampaignsCombinationHead AS (
				SELECT DISTINCT C.CampaignNo, C.CampaignId, C.CampaignName , ISNULL(C.CampaignDescription, '''') AS CampaignDescription
					   ,C.FromDate AS FromDate, C.ToDate AS ToDate
				FROM [RSItemESDb].[dbo].[Campaigns] AS C
				INNER JOIN [RSItemESDb].[dbo].CampaignStoreGroups AS CSG ON C.CampaignNo = CSG.CampaignNo
				INNER JOIN [RSItemESDb].[dbo].StoreGroups SG ON SG.StoreGroupNo = CSG.StoreGroupNo
				'
	-- Getting data for start or for end
	IF(@GetDataForStart = 0) -- end date
	SET @sql =  @sql + 'WHERE C.ToDate   >= @DateFrom AND C.ToDate   <= @DateTo
	'
	ELSE					 -- from date
	SET @sql =  @sql + 'WHERE C.FromDate >= @DateFrom AND C.FromDate <= @DateTo
	'

	SET @sql =  @sql + '
				AND (SG.StoreGroupExternalId = @StoreId OR SG.StoreGroupExternalId = CONCAT(''-'', @StoreId))
				--AND C.CampaignNo = @CampaignNo
				'
	-- Getting Combinatinos or only Campaigns
	IF(@Combination = 1) -- end date
	SET @sql =  @sql + 'AND EXISTS( SELECT 1 FROM [RSItemESDb].[dbo].CampaignDiscountCombinations AS CDC WHERE C.CampaignNo = CDC.CampaignNo)
	'
	ELSE
	SET @sql =  @sql + 'AND NOT EXISTS( SELECT 1 FROM [RSItemESDb].[dbo].CampaignDiscountCombinations AS CDC WHERE C.CampaignNo = CDC.CampaignNo)
	'

	SET @sql =  @sql + '
			),
			CampaignsCombinationDetails AS (
				SELECT DISTINCT C.CampaignId, AR.ArticleId, AR.ArticleName, BC.Barcode AS EAN
				FROM  CampaignsCombinationHead C
				INNER JOIN [RSItemESDb].[dbo].CampaignArticles CA ON C.CampaignNo = CA.CampaignNo
				LEFT JOIN [RSItemESDb].[dbo].Articles AS AR ON CA.ArticleNo = AR.ArticleNo
				LEFT JOIN ArticleBarcodes BC ON AR.DefaultArticleBarcodeNo = BC.ArticleBarcodeNo
			),
			CampainsCombinationAll AS (
				SELECT ''1'' AS RowType, CampaignId, NULL AS ArticleId, CampaignName, CampaignDescription, FromDate, ToDate, NULL AS EAN
				FROM CampaignsCombinationHead
			'
	IF(@IncludeArticles = 1)
	SET @sql =  @sql + '
				UNION ALL
				SELECT ''2'' AS RowType, CampaignId, ArticleId ,  ArticleName AS  CampaignName, NULL AS CampaignDescription, NULL AS FromDate, NULL AS ToDate, EAN
				FROM CampaignsCombinationDetails
				'

	SET @sql =  @sql + '	
			)

			SELECT *
			FROM CampainsCombinationAll
			ORDER BY CampaignId,  RowType 
			'

		print @sql
		EXEC sys.sp_executesql @sql
							   ,N'@StoreId AS NVARCHAR(256), @DateFrom AS DATE, @DateTo AS DATE'
							   ,@StoreId = @StoreId 
							   ,@DateFrom = @DateFrom
							   ,@DateTo = @DateTo

	
END	
GO



/*

	-- Works
	EXEC usp_CBI_1259_dsCampainsCombinationDetails @StoreId = '10003', @DateFrom = '2016-04-05', @DateTo = '2019-04-19', @GetDataForStart = 0, @Combination = 0
	EXEC usp_CBI_1259_dsCampainsCombinationDetails @StoreId = '10003', @DateFrom = '2016-04-05', @DateTo = '2019-04-19', @GetDataForStart = 0, @Combination = 1

	EXEC usp_CBI_1259_dsCampainsCombinationDetails @StoreId = '10003', @DateFrom = '2016-04-05', @DateTo = '2019-04-19', @GetDataForStart = 1, @Combination = 0
	EXEC usp_CBI_1259_dsCampainsCombinationDetails @StoreId = '10003', @DateFrom = '2016-04-05', @DateTo = '2019-04-19', @GetDataForStart = 1, @Combination = 1



--*/

