USE [VBDCM]
GO

DROP PROCEDURE IF EXISTS [dbo].[usp_CBI_1032_ds_StockCount_StockCountProposal_ReturnInputValues];
GO

CREATE PROCEDURE [dbo].[usp_CBI_1032_ds_StockCount_StockCountProposal_ReturnInputValues]
														(														 
															 @StoreGroupNos As varchar(8000) = ''
															, @parArticleHierNo as varchar(8000) = ''
															, @parArticleHierNoSubGroups as varchar(8000) = ''
															, @parArticleName as varchar(500) = ''
															, @ParHylla1 as varchar(50) = ''
															, @ParHylla2 as varchar(50) = ''
															, @parNotCountedInXDays As varchar(100) = ''
														)
AS
BEGIN 

	DECLARE @InputStoreNames VARCHAR(2000)
	DECLARE @InputArticleHierIDs VARCHAR(2000)

	IF len(isnull(@parArticleHierNo,'')) > 0  AND len(isnull(@parArticleHierNoSubGroups,'')) = 0
	BEGIN
		;WITH ArticleHierNoFilter as (
		select distinct ah2.ArticleHierNo
		from ArticleHierarchys ah1 with (nolock) 
		LEFT JOIN ArticleHierarchys ah2 with (nolock) on ah2.ArticleHierLinkNo = ah1.ArticleHierNo 
			and ah2.ArticleHierLevelNo > 1
			and ah2.ArticleHierNo > 0
			and ah2.ArticleHierNo is not null
			and ah2.ArticleHierName <> 'XX'
			and ah2.ArticleHierName not like '%Opprettet fra%' 
			and ah2.ArticleHierName <> 'Systemgenerert' 
			and ah2.ArticleHierNo in (select ArticleHierNo from Articles with (nolock))
		INNER JOIN [dbo].[ufn_RBI_SplittParameterString](@parArticleHierNo,',') as ArtHierNoFiltr on ah1.ArticleHierNo = ArtHierNoFiltr.ParameterValue
		where ah1.ArticleHierNo > 0
		and ah1.ArticleHierName <> 'XX'
		and ah1.ArticleHierName not like '%Opprettet fra%'
		and ah1.ArticleHierName <> 'Systemgenerert'
		)

	SELECT @InputArticleHierIDs = COALESCE(@InputArticleHierIDs + ', ', '') + ah.ArticleHierID 
			FROM ArticleHierarchys ah
			INNER JOIN ArticleHierNoFilter ahf ON ah.ArticleHierNo = ahf.ArticleHierNo
	END

	IF len(isnull(@parArticleHierNo,'')) >= 0  AND len(isnull(@parArticleHierNoSubGroups,'')) > 0
	BEGIN
		;WITH ArticleHierNoFilter as (
							select distinct cast(ParameterValue as int) as ArticleHierNo
							from [dbo].[ufn_RBI_SplittParameterString](@parArticleHierNoSubGroups,',')
						  )

	SELECT @InputArticleHierIDs = COALESCE(@InputArticleHierIDs + ', ', '') + ah.ArticleHierID 
			FROM ArticleHierarchys ah
			INNER JOIN ArticleHierNoFilter ahf ON ah.ArticleHierNo = ahf.ArticleHierNo
	END


	SELECT @InputStoreNames = COALESCE(@InputStoreNames + ', ', '') + s.StoreID + ' ' + s.StoreName 
	FROM dbo.ufn_CBI_getStoreNoForStoreGroups (@StoreGroupNos) ufn
	join Stores s ON ufn.StoreNo = s.StoreNo


	SELECT @InputStoreNames AS InputStoreNames
		,@InputArticleHierIDs AS InputArticleHierIDs
		,@parArticleName AS InputArticleName
		,@ParHylla1 AS InputHyllplats1
		,@ParHylla2 AS InputHyllplats2
		,@parNotCountedInXDays AS InputNotCountedInXDays

END
GO


