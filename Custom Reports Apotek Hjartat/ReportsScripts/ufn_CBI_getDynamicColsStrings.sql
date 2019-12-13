GO
USE [VBDCM]
GO

IF EXISTS (SELECT * FROM sysobjects WHERE name = N'ufn_CBI_getDynamicColsStrings'  AND xtype = 'FN')
DROP FUNCTION dbo.ufn_CBI_getDynamicColsStrings
GO


CREATE FUNCTION [dbo].[ufn_CBI_getDynamicColsStrings]
(
    @typeOfCols nvarchar(max)
)
RETURNS varchar(max) -- or whatever length you need
AS
BEGIN
/* ------------------------------------------------------------------------------------------------------------------------

 -- Col types descriptions
 --1 - Creating string to create temp table with dynamic fields this one forms dynamic fields;	(@colsCreateTable)
 --2 - Creating string to fill temp table with values insert into #dynamic (-values-);	(@colsToInsertTbl)
 --3 - Creating string to select Cols from final select;	(@colsFinal)
 --4 - Creating string to pivot dynamic cols in proc; (@colsPivot)
 --5 - Creating string to filter pivot in proc. (@colsPivotFilt) e. g.: ''ATC-KOD''
 --6 - Creating string to filter pivot in proc. (@colsPivotFilt) e. g.: 'ATC-KOD'
  ------------------------------------------------------------------------------------------------------------------------*/

	declare @cols as varchar(max)

	if @typeOfCols = 1
	 Begin

		-- Get infovalues for article and storearticles (InfoCategoryNo = 45 OR InfoCategoryNo = 92)
		-- Cols to create table (@colsCreateTable)
		SELECT  @cols = COALESCE(@cols + ' ,[' + ISNULL(REPLACE(a.InfoIDCaption,' ','_'),REPLACE(a.InfoIDName,' ','_')) + '] varchar(200)',
								'[' + ISNULL(REPLACE(a.InfoIDCaption,' ','_'),REPLACE(a.InfoIDName,' ','_')) + ']  varchar(200)')
		FROM    infogroups a with (nolock)
		JOIN InfoGroupCategories b with (nolock) ON a.InfoID = b.InfoID WHERE InfoCategoryNo = 45 OR InfoCategoryNo = 92	
		ORDER BY a.infoid asc -- DESC

	 End
	else if @typeOfCols = 2
	 begin 
		
		-- Cols to insert into table
		SELECT  @cols =	COALESCE(@cols + ' ,[' + ISNULL(REPLACE(a.InfoIDCaption,' ','_'),REPLACE(a.InfoIDName,' ','_')) + ']',
								'[' + ISNULL(REPLACE(a.InfoIDCaption,' ','_'),REPLACE(a.InfoIDName,' ','_')) + ']')
		FROM    infogroups a with (nolock)
		JOIN InfoGroupCategories b with (nolock) ON a.InfoID = b.InfoID WHERE InfoCategoryNo = 45 OR InfoCategoryNo = 92	
		ORDER BY a.infoid asc -- DESC

	 end
	else if @typeOfCols = 3
	 begin 
		
			-- Cols to select from final select
			SELECT  @cols =  COALESCE(@cols + ',b.[' + ISNULL(REPLACE(a.InfoIDCaption,' ','_'),REPLACE(a.InfoIDName,' ','_')) + ']',
									'b.[' + ISNULL(REPLACE(a.InfoIDCaption,' ','_'),REPLACE(a.InfoIDName,' ','_')) + ']')
			FROM    infogroups a with (nolock)
			JOIN InfoGroupCategories b with (nolock) ON a.InfoID = b.InfoID WHERE InfoCategoryNo = 45 OR InfoCategoryNo = 92	
			ORDER BY a.infoid

	 end
	else if @typeOfCols = 4
	 begin 
		
		-- Cols to pivot in proc, passing this to proc
		SELECT  @cols = COALESCE(@cols + ',[@' + ISNULL(a.InfoIDCaption, a.InfoIDName) + ']',
								 '[@' + ISNULL(a.InfoIDCaption, a.InfoIDName) + ']')
		FROM    infogroups a with (nolock)
		JOIN InfoGroupCategories b with (nolock) ON a.InfoID = b.InfoID WHERE InfoCategoryNo = 45 OR InfoCategoryNo = 92	
		ORDER BY a.infoid asc -- DESC

	 end
	else if @typeOfCols = 5
	 begin 
		
		-- Cols to filter pivot in proc, passing this to proc
		SELECT  @cols = COALESCE(@cols + ',''''@' + ISNULL(a.InfoIDCaption, a.InfoIDName) + '''''',
								 '''''@' + ISNULL(a.InfoIDCaption, a.InfoIDName) + '''''')
		FROM    infogroups a with (nolock)
		JOIN InfoGroupCategories b with (nolock) ON a.InfoID = b.InfoID WHERE InfoCategoryNo = 45 OR InfoCategoryNo = 92	
		ORDER BY a.infoid asc -- DESC

	 end
	 else if @typeOfCols = 6
	 begin 

		SELECT  @cols = COALESCE(@cols + ',''@' + ISNULL(a.InfoIDCaption, a.InfoIDName) + '''',
								 '''@' + ISNULL(a.InfoIDCaption, a.InfoIDName) + '''')
		FROM    infogroups a with (nolock)
		JOIN InfoGroupCategories b with (nolock) ON a.InfoID = b.InfoID WHERE InfoCategoryNo = 45 OR InfoCategoryNo = 92	
		ORDER BY a.infoid asc -- DESC

	 end
	 else if @typeOfCols = 7
	 begin
			-- Will return pattern LTRIM(ISNULL(b.[Batch_auto_close_stock_threshold], '')) AS [Batch_auto_close_stock_threshold],..
			SELECT  @cols =  	COALESCE(@cols + ',LTRIM(ISNULL(b.[' + ISNULL(REPLACE(a.InfoIDCaption,' ','_'),REPLACE(a.InfoIDName,' ','_')) + '], '''')) AS ' + '[' + ISNULL(REPLACE(a.InfoIDCaption,' ','_'),REPLACE(a.InfoIDName,' ','_')) + ']',
								'LTRIM(ISNULL(b.[' + ISNULL(REPLACE(a.InfoIDCaption,' ','_'),REPLACE(a.InfoIDName,' ','_')) + '], '''')) AS '+ '[' + ISNULL(REPLACE(a.InfoIDCaption,' ','_'),REPLACE(a.InfoIDName,' ','_')) + ']' )
			FROM    infogroups a with (nolock)
			JOIN InfoGroupCategories b with (nolock) ON a.InfoID = b.InfoID WHERE InfoCategoryNo = 45 OR InfoCategoryNo = 92	
			ORDER BY a.infoid
	 end
	
    RETURN  @cols

END
GO


