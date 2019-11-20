go
USE [VBDCM]
go

if exists(select * from sysobjects where name = N'usp_CBI_1025_ds_Stock_Movements' and xtype = 'P')
drop procedure usp_CBI_1025_ds_Stock_Movements
go

CREATE PROCEDURE [dbo].[usp_CBI_1025_ds_Stock_Movements]
(
	@parStoreNo As varchar(100),
	@parDateFrom As Date,
	@parDateTo As Date,
	@parSupplierNo As varchar(2000) = '',
	@parSupplierArticleID As varchar(200) = '',
	@parArticleNo as varchar(100) = '',
	@parArticleID as varchar(100) = '',
	@parEANNo as varchar(100) = '',
	@parArticleName as varchar(2000) = '',
	@parArticleHierNo As varchar(1000) = ''
)
as
begin


SET NOCOUNT ON 


	if( len(isnull(@parSupplierNo, '')) = 0 and len(isnull(@parSupplierArticleID, '')) = 0 and len(isnull(@parArticleID, '')) = 0 and len(isnull(@parEANNo, '')) = 0 and len(isnull(@parArticleName, '')) = 0)
	begin
		select	null as Ean 
				,null as ArticleID 
				,null as supplierarticleid 
				,null as suppliername 
				,null as articlename
				,null as netprice 
				,null as adjustmentqty
				,null as adjustmentdate
				,null as Stockadjname 
				,null as StoreNo
				,null as stockadjreasonname
				,null as Comment_No
				,null as articlehiernametop	
				,null as articlehiername
				,null as ArticleHierID
				,null as MasterArticle
				,null as Transactioncounter


	end 
	else 
	begin

	declare @sql As nvarchar(max) = ''

	declare @colsFinal as varchar(max)
	declare @colsCreateTable as varchar(max)	-- create table dynamiclly
	declare @colsToInsertTbl as varchar(max)

	declare @ParamDefinition nvarchar(max)
	set @ParamDefinition = N'@parStoreNo nvarchar(100), @parDateFrom nvarchar(30), @parDateTo nvarchar(30), @parSupplierNo nvarchar(max), @parSupplierArticleID nvarchar(200),
							 @parArticleNo nvarchar(100), @parArticleID nvarchar(100), @parEANNo nvarchar(100), @parArticleName nvarchar(2000), @parArticleHierNo nvarchar(1000) '


	-- for testing only, can be removed in production
	if object_id('tempdb..#vwStockAdjustmentsMasterAndChild') is not null drop table #vwStockAdjustmentsMasterAndChild
	--if object_id('tempdb..#vwSummedStockAdjustmentsMasterAndChild') is not null drop table #vwSummedStockAdjustmentsMasterAndChild
	if object_id('tempdb..#vwSummedStockAdjustmentsMasterAndChild_Pharma3') is not null drop table #vwSummedStockAdjustmentsMasterAndChild_Pharma3



/******************************************************************

	vw_StockAdjustmentsMasterAndChild

******************************************************************/

	SELECT StoreNo, StockAdjType, StockAdjReasonNo, NULL AS MasterArticleNo, stad.ArticleNo, stad.AdjustmentDate, stad.AdjustmentQty, 
		   AdjustmentRefNo, AdjustmentNetCostAmount, DerivedNetCostAmount, NetPrice, NULL AS LinkQty, stad.UserNo, stad.AdjustmentLineNo, 
		   stad.TransactionCounter /*20140303 lagt till transactioncounter MW */
		   ,Alla.SupplierNo
	INTO #vwStockAdjustmentsMasterAndChild
	FROM dbo.StockAdjustments stad with (nolock)
	LEFT OUTER JOIN  AllArticles alla with (nolock) ON (stad.Articleno = alla.Articleno)
	where --stde.Adjustmentdate is NULL 
		 stad.storeno IN (@parStoreNo)
		AND (isnull(@parDateFrom,'') = ''		 or stad.AdjustmentDate >= @parDateFrom)
--		AND (isnull(@parDateTo, '') = ''		 or stad.AdjustmentDate <= @parDateTo)
		AND (isnull(@parDateTo, '') = ''		 or CAST(stad.AdjustmentDate AS DATE) <= @parDateTo) -- VPT-1919
		AND (isnull(@parArticleNo, '')=''		 or stad.articleno=@parArticleNo) 
		AND (isnull(@parSupplierArticleID,'')='' or Alla.SupplierArticleId=@parSupplierArticleID)
		AND (isnull(@parSupplierNo,'')=''		 or Alla.SupplierNo in (select ParameterValue from [dbo].[ufn_RBI_SplittParameterString] ( @parSupplierNo, ',')))
		AND (isnull(@parArticleID,'')=''		 or Alla.ArticleId = @parArticleID)
		AND (isnull(@parEANNo,'')=''			 or Alla.EanNo=@parEANNo)


/******************************************************************

	vw_SummedStockAdjustmentsMasterAndChild_Pharma3

******************************************************************/
	select *
	into #vwSummedStockAdjustmentsMasterAndChild_Pharma3
	from
	(
		SELECT storeno, ArticleNo, stockadjtype, adjustmentrefno, MAX(adjustmentlineno) as AdjustmentLineNo,MAX(adjustmentdate) AS AdjustmentDate, NULL AS StockadjReasonNo, 
			NULL AS MasterArticleNo,
			SUM(adjustmentqty) AS AdjustmentQty, 
			SUM(adjustmentnetcostamount) AS AdjustmentNetCostAmount, 
			SUM(DerivedNetCostAmount) AS DerivedNetCostAmount,
			MAX(netprice) AS NetPrice, 
			NULL AS LinkQty,
			MAX(UserNo) as UserNo,
			NULL as TransactionCounter
		FROM #vwStockAdjustmentsMasterAndChild
		WHERE stockadjtype IN (51,52) 
		GROUP BY storeno, articleno, stockadjtype, adjustmentrefno

		UNION all

		SELECT StoreNo,  ArticleNo, StockAdjType, AdjustmentRefNo, adjustmentlineno,AdjustmentDate, StockAdjReasonNo, MasterArticleNo, 
			AdjustmentQty,  
			AdjustmentNetCostAmount, 
			DerivedNetCostAmount,
			NetPrice, 
			LinkQty,
			UserNo,
			TransactionCounter
		FROM #vwStockAdjustmentsMasterAndChild
		WHERE stockadjtype NOT IN (4,5,51,52) 

		UNION ALL
		SELECT storeno, ArticleNo, stockadjtype, adjustmentrefno, MAX(adjustmentlineno) as AdjustmentLineNo,MIN(adjustmentdate) AS AdjustmentDate, NULL AS StockadjReasonNo, 
			NULL AS MasterArticleNo,
			(SELECT top(1) stok.adjustmentqty FROM #vwStockAdjustmentsMasterAndChild AS stok 
			 WHERE #vwStockAdjustmentsMasterAndChild.adjustmentrefno=stok.adjustmentrefno 
				   AND #vwStockAdjustmentsMasterAndChild.articleno=stok.articleno
				   AND stockadjtype = 4  
				   AND UserNo!= 10002) AS AdjustmentQty, 
			NULL AS AdjustmentNetCostAmount, 
			NULL AS DerivedNetCostAmount,
			MAX(netprice) AS NetPrice, 
			NULL AS LinkQty,
			MAX(UserNo) as UserNo,
			NULL as TransactionCounter
		FROM #vwStockAdjustmentsMasterAndChild
		WHERE stockadjtype = 4 and UserNo!= 10002
		GROUP BY storeno,articleno,adjustmentrefno,stockadjtype

		UNION ALL

		SELECT storeno, ArticleNo, stockadjtype, adjustmentrefno, MAX(adjustmentlineno) as AdjustmentLineNo,MAX(adjustmentdate) AS AdjustmentDate, MAX(StockadjReasonNo) AS StockadjReasonNo, 
			NULL AS MasterArticleNo,
			SUM(adjustmentqty) AS AdjustmentQty, 
			SUM(adjustmentnetcostamount) AS AdjustmentNetCostAmount, 
			SUM(DerivedNetCostAmount) AS DerivedNetCostAmount,
			MAX(netprice) AS NetPrice, 
			NULL AS LinkQty,
			MAX(UserNo) as UserNo,
			MAX (TransactionCounter) as TransactionCounter
		FROM #vwStockAdjustmentsMasterAndChild
		WHERE stockadjtype = 5
		GROUP BY storeno, articleno, stockadjtype, adjustmentrefno
	) vw
	--exec(@SQL)
	--select * from  #vwSummedStockAdjustmentsMasterAndChild_Pharma3

	/******************************************************************

		Report

	******************************************************************/


	-- Nedan s�tts en datumbegr�nsning som inneb�r max 450 dgr bak�t
	  IF @parDateFrom < getdate()-450
	  SET @parDateFrom = getdate()-450


	if len(isnull(@parSupplierNo, '') ) > 0 
		set @sql = @sql + '	IF OBJECT_ID(''tempdb..#supplierNoFltrTbl'') IS NOT NULL  DROP TABLE #supplierNoFltrTbl
							select distinct  cast(ParameterValue as int) as supplierNo 
							into #supplierNoFltrTbl
							from [dbo].[ufn_RBI_SplittParameterString](@parSupplierNo,'','') 
							'

	if len(@parArticleHierNo ) > 0
		set @sql = @sql + '	IF OBJECT_ID(''tempdb..#ArticleHierNoFltrTbl'') IS NOT NULL  DROP TABLE #ArticleHierNoFltrTbl
							select distinct  cast(ParameterValue as int) as articlehierno 
							into #ArticleHierNoFltrTbl
							from [dbo].[ufn_RBI_SplittParameterString](@parArticleHierNo,'','') 
		 '

  
	set @sql = @sql + '
	IF OBJECT_ID(''tempdb..#ds_Stock_Movements'') IS NOT NULL DROP TABLE #ds_Stock_Movements
	SELECT 
		stor.InternalStoreID,
		stor.storename,
		alar.Eanno as Ean, 
		alar.ArticleID,
		alar.ArticleNo,
		ltrim(isnull(alar.WholesalerArticleID, alar.SupplierArticleID )) as supplierarticleid,
		isnull(alar.suppliername,'''') as suppliername, 
		alar.articlename, 
		isnull(stad.netprice,0) as netprice, 
		stad.adjustmentqty,
		CONVERT(varchar, stad.adjustmentdate, 120) as adjustmentdate, 
		--sat.StockAdjName,
		case when sat.StockAdjType = 5 then ''Varumottagning''
			 else sat.StockAdjName
		end as Stockadjname,
		stor.StoreNo,   
	-- old CASE when stad.adjustmentqty=0 and stad.StockAdjType=5 then ''''
	-- old     when stad.adjustmentqty<>0 and stad.StockAdjType=5 then ISNULL(strc1.stockadjreasonname,'''')
	-- old  ELSE ISNULL(strc.stockadjreasonname,'''') 
	-- old end as stockadjreasonname,
		CASE when stad.adjustmentqty=0 and stad.StockAdjType=5 then ''''
			 when stad.adjustmentqty<>0 and stad.StockAdjType=5 then ISNULL(strc.stockadjreasonname,'''')
			 ELSE ISNULL(strc.stockadjreasonname,'''') 
		end as stockadjreasonname,

		isnull(stad.adjustmentrefno,'''') as Comment_No,
		alar.articlehiernametop, 
		alar.articlehiername, 
		alar.ArticleHierID,
		master.ArticleName as MasterArticle,
		stad.Transactioncounter
	into #ds_Stock_Movements
	FROM  #vwSummedStockAdjustmentsMasterAndChild_Pharma3 stad with (nolock)
	join Stores stor with (nolock) on (stor.storeno = stad.storeno)
	join allarticles alar with (nolock) on (alar.articleno = stad.articleno)
	'

	if len(@parSupplierNo) > 0
		set @sql = @sql + 'inner join #supplierNoFltrTbl supFltr on alar.supplierno = supFltr.supplierno
		'

	if len(@parArticleHierNo ) > 0
		set @sql = @sql + 'inner join #ArticleHierNoFltrTbl artFltr on alar.articlehierno = artFltr.articlehierno
		'

	set @sql = @sql + '
	left join Articles master with (nolock) on (master.ArticleNo = stad.MasterArticleNo)
	-- left join Stockadjustments sat1 with (nolock) on stad.articleno=sat1.articleno  and stad.Transactioncounter =sat1.transactioncounter and sat1.StockAdjType=5
	-- left join stockadjustmentreasoncodes strc1 with (nolock) on (sat1.stockadjreasonno = strc1.stockadjreasonno)
	left join stockadjustmentreasoncodes strc with (nolock) on (stad.stockadjreasonno = strc.stockadjreasonno)
	join StockAdjustmentTypes sat with (nolock) on (stad.StockAdjType = sat.StockAdjType)
	WHERE  (stad.stockadjtype IN ( 1,2,3,4,5,51,53) ) ' --or (stad.stockadjtype IN (4) and Stad.Userno != 3816)
		 
	if len(@parStoreNo) > 0
		set @sql = @sql + '   and stad.storeno = @parStoreNo'
		 
	if len(@parSupplierArticleID) > 0
	begin
		set @sql = @sql + ' AND alar.ArticleNo IN (SELECT suar.ArticleNo FROM 
							SupplierArticles AS suar WHERE ltrim(suar.SupplierArticleID)  = @parSupplierArticleID '
		set @sql = @sql + ')'
	end

	if len(@parDateFrom) > 0
		set @sql = @sql + ' and stad.AdjustmentDate >= @parDateFrom '
		        
	if len(@parDateTo) > 0
		set @sql = @sql + ' and CAST(stad.AdjustmentDate AS DATE) <= @parDateTo' -- VPT-1919
   


	if len(@parArticleName) > 0 
      	set @sql = @sql + ' AND alar.articleName like ''%''+@parArticleName+''%'''

	if len(@parArticleNo) > 0 
      	set @sql = @sql + ' AND alar.articleNo = @parArticleNo '

	if len(@parEanNo) > 0 
		set @sql = @sql + ' AND alar.Articleno in (select articleno from ean where EANno = @parEanNo ) '

	if len(@parArticleID) > 0 
      	set @sql = @sql + ' AND alar.articleID =  @parArticleID '

	 

	 
---------------------------------------------------------------------------------------------------------------------------	
-- Geting additional article info and adding to final select
---------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------
-- Function ufn_CBI_getDynamicColsStrings available values for parameter @typeOfCols
-- Col types descriptions
-- 1 - Creating string to create temp table with dynamic fields this one forms dynamic fields;	(@colsCreateTable)
-- 2 - Creating string to fill temp table with values insert into #dynamic (-values-);	(@colsToInsertTbl)
-- 3 - Creating string to select Cols from final select;	(@colsFinal)
-- 4 - Creating string to pivot dynamic cols in proc; (@colsPivot)
-- 5 - Creating string to filter pivot in proc. (@colsPivotFilt)
---------------------------------------------------------------------------------------------------------------------------

	select 	@colsCreateTable = dbo.ufn_CBI_getDynamicColsStrings (1)
	select 	@colsToInsertTbl = dbo.ufn_CBI_getDynamicColsStrings (2)
	select 	@colsFinal = dbo.ufn_CBI_getDynamicColsStrings (3)


	-- Creating table dynamically
	set @sql = @sql + '

	IF OBJECT_ID(''tempdb..#DynamicValues'') IS NOT NULL  DROP TABLE #DynamicValues 
	CREATE TABLE #DynamicValues ( articleNo int, articleId varchar(50),
	'+
	@colsCreateTable
	+')
	
	'

	-- In proc selecting from  #ArticleNos and inserting into #DynamicValues
	set @sql = @sql + '

	IF OBJECT_ID(''tempdb..#ArticleNos'') IS NOT NULL DROP TABLE #ArticleNos
	SELECT distinct ArticleNo
	into #ArticleNos 
	FROM #ds_Stock_Movements

	insert into #DynamicValues ( articleNo, articleid, ' + @colsToInsertTbl + ')
	exec CBI_vrsp_GetDynamicValues @StoreNo =  @ParStoreNo , @GetStoreArticleValues = 1
	'


	set @sql = @sql + '
		select a.*,
		'+ @colsFinal
		+'
		from #ds_Stock_Movements a
		left join #DynamicValues b on a.ArticleNo = b.ArticleNo 
		ORDER BY a.adjustmentdate desc
		'

	--print(@sql)
	--exec(@sql)

	exec sp_executesql @sql,
					   @ParamDefinition,
					   @parStoreNo = @parStoreNo,
					   @parDateFrom = @parDateFrom,
					   @parDateTo = @parDateTo,
					   @parSupplierNo = @parSupplierNo,
					   @parSupplierArticleID =  @parSupplierArticleID,
					   @parArticleNo = @parArticleNo,
					   @parArticleID = @parArticleID,
					   @parEANNo = @parEANNo,
					   @parArticleName = @parArticleName,
					   @parArticleHierNo = @parArticleHierNo

						

	end

end

GO



/*


	exec usp_CBI_1025_ds_Stock_Movements	@parStoreNo = '3000' ,
											@parDateFrom =  '2008-01-14',
											@parDateTo = '2018-06-06',
											@parSupplierNo = '28',
											@parSupplierArticleID = '145751' ,
											@parArticleNo = '',
											@parArticleID = '',
											@parEANNo = '',
											@parArticleName = '',
											@parArticleHierNo = '' 




	exec usp_CBI_1025_ds_Stock_Movements
											@parStoreNo = N'3000' ,
											@parDateFrom =  '2008-01-01',
											@parDateTo = '2018-07-12',
											@parSupplierNo = N'28,1,2,3' ,
											@parSupplierArticleID = '', --N'145751',
											@parArticleNo = '',
											@parArticleID = '',
											@parEANNo = null,
											@parArticleName = null,
											@parArticleHierNo = '208,206,207,6,8'                           




*/




