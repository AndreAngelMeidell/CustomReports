
GO
USE [VBDCM]
GO

IF EXISTS (SELECT * FROM sysobjects WHERE name = N'CBI_vrsp_GetDynamicValues'  AND xtype = 'P')
DROP PROCEDURE CBI_vrsp_GetDynamicValues
GO


CREATE PROCEDURE [dbo].[CBI_vrsp_GetDynamicValues] 
	@StoreNo INT,					--The StoreNo to get StoreArticleInfoDetails for.
	@GetStoreArticleValues INT--,		--0 = Only ArticleInfos, 1 = Both ArticleInfos and StoreArticleInfoDetails.  
AS
DECLARE		
	@iErrorCode integer,
	@sErrorMessage as varchar(1000)

Declare @ProcedureName as varchar(100)
--DECLARE @cols VARCHAR(8000)

BEGIN

	set nocount on 
	set @ProcedureName = 'CBI_vrsp_GetDynamicValues'
	set @iErrorCode = 0	
	IF @StoreNo IS NULL
		SET @StoreNo = 0
	IF @StoreNo = 0
		SET @GetStoreArticleValues = 0
	IF @GetStoreArticleValues IS NULL
		SET @GetStoreArticleValues = 0
	IF @GetStoreArticleValues = 0
		SET @StoreNo = 0
	
---------------------------------------------------------------------------------------------------------------------------
-- Function ufn_CBI_getDynamicColsStrings available values for parameter @typeOfCols
 -- Col types descriptions
 --1 - Creating string to create temp table with dynamic fields this one forms dynamic fields;	(@colsCreateTable)
 --2 - Creating string to fill temp table with values insert into #dynamic (-values-);	(@colsToInsertTbl)
 --3 - Creating string to select Cols from final select;	(@colsFinal)
 --4 - Creating string to pivot dynamic cols in proc; (@colsPivot)
 --5 - Creating string to filter pivot in proc. (@colsPivotFilt) e. g.: ''ATC-KOD''
 --6 - Creating string to filter pivot in proc. (@colsPivotFilt) e. g.: 'ATC-KOD'
---------------------------------------------------------------------------------------------------------------------------
	declare @cols as varchar(max)
	declare @colsPivotFilt as varchar(max)

	select 	@cols = dbo.ufn_CBI_getDynamicColsStrings (4)
	select 	@colsPivotFilt = dbo.ufn_CBI_getDynamicColsStrings (6)
	
begin transaction

	DECLARE @query VARCHAR(8000)
	SET @query = N'
	SELECT  adv.*, '+
	@cols +'
	FROM 
	(SELECT  t1.articleno, ''@'' + ISNULL(ig.InfoIDCaption, ig.InfoIDName) as InfoIDCaption, infovalue
	FROM    articleinfos AS t1 with (nolock)
	INNER JOIN #ArticleNos a ON t1.articleno = a.ArticleNo
	INNER JOIN InfoGroups ig with (nolock) ON t1.InfoID = ig.InfoID
	WHERE ''@'' + ISNULL(ig.InfoIDCaption, ig.InfoIDName) in (' + @colsPivotFilt + ')
	'
	IF @GetStoreArticleValues = 0
		SET @query=@query+')'
	ELSE IF @GetStoreArticleValues = 1
	BEGIN
		SET @query=@query+'
		union 

		SELECT  t1.articleno, ''@'' + ISNULL(ig.InfoIDCaption, ig.InfoIDName) as InfoIDCaption, infovalue 
		FROM    storearticleinfodetails AS t1 with (nolock) 
		INNER JOIN #ArticleNos a ON t1.articleno = a.ArticleNo
		INNER JOIN InfoGroups ig with (nolock) ON t1.InfoID = ig.InfoID
		WHERE storeno = '+ CAST(@StoreNo AS VARCHAR(10)) +'
		and ''@'' + ISNULL(ig.InfoIDCaption, ig.InfoIDName) in (' + @colsPivotFilt + ')
		)
		'
	END

	SET @query = @query + '
	p  
	PIVOT
	(
	MAX([infovalue])
	FOR InfoIDCaption IN
	( '+
	@cols +' )
	) AS pvt
	join vw_ArticleDynamicValues adv on pvt.articleno = adv.articleno'


	print (@query)
	EXECUTE(@query)
	
DROP TABLE #ArticleNos

ErrorHandler:


  IF (@iErrorCode <> 0)
  begin
    rollback
    set @sErrorMessage = (select description from master..sysmessages where error = @iErrorCode)
    exec vbdcm.dbo.vbdspSYS_insert_vbderror @iErrorCode, @sErrorMessage, 
				@ProcedureName, 'Stored Procedure', '', ''
  end
  else
  begin
    commit	
    EXEC vbdcm.dbo.vbdspSYS_Insert_VBDtrace '1', 'Ferdig prosedyre', '',  @ProcedureName, 'Stored Procedure'
  end


  return @iErrorCode

END
 



GO


