use [VBDCM];

IF EXISTS (SELECT * FROM sysobjects WHERE name = N'usp_CBI_1007_ds_PharmacyLoggingNarcotics'  AND xtype = 'P')
DROP PROCEDURE usp_CBI_1007_ds_PharmacyLoggingNarcotics
GO

CREATE procedure [dbo].[usp_CBI_1007_ds_PharmacyLoggingNarcotics](
	@ParArticleID As varchar(30) = '',
	@ParArticleName As varchar(300) = '',
	@ParSupplierArticleID as varchar(50) = '',
	@ParIsNarcotics As varchar(30) = '',
	@ParNarcoticsClass As varchar(300) = 'Alla - Narkotika',
	@parDatumFrom As varchar(30) = '',
	@parDatumto As varchar(30) = '',
	@parStoreNo As varchar(100) = ''
)
as


	DECLARE @sql As nvarchar(max) = ''
	DECLARE @ParamDefinition nvarchar(max)

	set @ParamDefinition = N'@ParArticleID nvarchar(30), @ParArticleName nvarchar(300), @ParSupplierArticleID nvarchar(30),
							@ParIsNarcotics nvarchar(30), @ParNarcoticsClass nvarchar(300), @parDatumFrom nvarchar(30), @parDatumto nvarchar(30), @parStoreNo nvarchar(100)'


	set @sql = @sql + '
	
	SELECT 
		SA.StoreNo, 
		S.StoreName,	
		AA.ArticleId AS ArticleIdentity, 
		AA.SupplierArticleID AS Varunr, 
		AA.ArticleName, 
		SAI.TotalStockQty, 
		ISNULL(SAID.Infovalue,'''') AS StockAvailable,
		CONVERT(VARCHAR ,SA.AdjustmentDate, 120) AS AdjDate, SAT.StockAdjName AS AdjustmentName, 
		SA.AdjustmentQty AS AdjustmentQty, SA.AdjustmentRefNo AS Referens, 
		ISNULL(U.UserId, '''') AS AnvandarID,
		ISNULL(SP1.Infovalue,'''') AS SP1Val, 
		ISNULL(SP2.Infovalue,'''') AS SP2Val, 
		AA.SupplierName, 
		CONVERT(VARCHAR, SAI.LastUpdatedStockCount, 120) AS LastUpdatedStockCount, 
		ISNULL(ISNarco.Infovalue,'''') AS Narcotics, 
		ISNULL(NClass.Infovalue,'''') AS NarcoticsClass
	FROM StockAdjustments AS SA with (nolock)
	INNER JOIN StockAdjustmentTypes AS SAT with (nolock)			ON (SAT.StockAdjType = SA.StockAdjType )
	INNER JOIN AllArticles AS AA with (nolock)						ON AA.ArticleNo = SA.ArticleNo
	INNER JOIN Stores AS S with (nolock)							ON S.StoreNo = SA.StoreNo
	LEFT OUTER JOIN [VBDSYS].[dbo].[VBDUsers] AS U with (nolock)	ON SA.UserNo = U.UserNo 
	LEFT OUTER JOIN StoreArticleInfos AS SAI with (nolock)			ON	SA.StoreNo = SAI.StoreNo AND AA.ArticleNo = SAI.ArticleNo
	LEFT OUTER JOIN StoreArticleInfoDetails AS SAID with (nolock)	ON  SA.StoreNo = SAID.StoreNo AND AA.ArticleNo = SAID.ArticleNo AND SAID.infoid = ''RS_IsStockAvailable''
	LEFT OUTER JOIN ArticleInfos AS ISNarco	with (nolock)			ON  (AA.ArticleNo = ISNarco.ArticleNo and ISNarco.InfoId = ''RS_ISDrugClassified'')
	LEFT OUTER JOIN ArticleInfos AS NClass	with (nolock)			ON  (AA.ArticleNo = NClass.ArticleNo and NClass.InfoId = ''RS_DrugClassification'')
	LEFT OUTER JOIN StoreArticleInfoDetails AS StArticleInfos with (nolock)	ON  SA.StoreNo = StArticleInfos.StoreNo AND AA.articleno = StArticleInfos.ArticleNo  and StArticleInfos.infoid = ''RS_NordicArticleNo''
	LEFT OUTER JOIN StoreArticleInfoDetails AS SP1	with (nolock)	ON  SA.StoreNo = SP1.StoreNo AND AA.ArticleNo = SP1.ArticleNo AND SP1.InfoId = ''RS_ShelfPosition1''
	LEFT OUTER JOIN StoreArticleInfoDetails AS SP2	with (nolock)	ON  SA.StoreNo = SP2.StoreNo AND AA.ArticleNo = SP2.ArticleNo AND SP2.InfoId = ''RS_ShelfPosition2''
	WHERE 1=1 '

	if len(@ParArticleID ) > 0
		set @sql = @sql + '  and AA.ArticleID =  @ParArticleID'

	if len(@ParArticleName ) > 0
		set @sql = @sql + '  and AA.ArticleName Like ''%'' + @ParArticleName + ''%'''

	if len(@ParSupplierArticleID ) > 0
		set @sql = @sql + '  and AA.SupplierArticleID = @ParSupplierArticleID'

	If (@ParIsNarcotics = 'N')
		   set @sql = @sql + '  and ISNarco.Infovalue =''0'''
	Else
		   set @sql = @sql + '  and ISNarco.Infovalue =''1'''

	If (@ParNarcoticsClass not like 'Alla - Narkotika') 
		set @sql = @sql + '  and NClass.Infovalue Like + @ParNarcoticsClass +''%'''

	if len(@parStoreNo) > 0
		set @sql = @sql + ' and SA.StoreNo = @parStoreNo '

	if len(@parDatumFrom) > 0
		set @sql = @sql + '	and SA.AdjustmentDate >= @parDatumFrom '
	
	if len(@parDatumto) > 0
		set @sql = @sql + ' and SA.AdjustmentDate <= @parDatumto + '' 23:59:59'' '


	--print(@sql)

	execute sp_executesql @sql, @ParamDefinition, 
						  @ParArticleID = @ParArticleID, 
						  @ParArticleName = @ParArticleName, 
						  @ParSupplierArticleID = @ParSupplierArticleID, 
						  @ParIsNarcotics = @ParIsNarcotics, 
						  @ParNarcoticsClass = @ParNarcoticsClass, 
						  @parDatumFrom = @parDatumFrom, 
						  @parDatumto = @parDatumto, 
						  @parStoreNo = @parStoreNo



GO







/*

exec usp_CBI_1007_ds_PharmacyLoggingNarcotics --@ParArticleID = '17914', 
											  --@ParArticleName = 'Alvedon',
											  @parStoreNo = '3000', 
											  @parDatumFrom = '2018-01-01',
											  @parDatumto = '2019-05-05',
											  --@ParNarcoticsClass = 'IV - Narkotika',
											  --@ParSupplierArticleID = '145751',
											  @ParIsNarcotics = 'N'

*/

