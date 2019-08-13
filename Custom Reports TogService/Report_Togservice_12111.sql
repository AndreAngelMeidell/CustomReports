-- ****************************************************************************************************
-- * INSERT-statement for VBDReportSQL 12111
-- * (Extracted from Togservice at 7/1/2017)


-- Remove unwanted results
Set NoCount On


-- Remove foreign keys

ALTER TABLE VBDSYS.dbo.VBDReportSqlsCategories DROP CONSTRAINT VBDReportSQLs_VBDReportSqlsCategories_FK 

GO

ALTER TABLE VBDSYS.dbo.VBDReportCustomers DROP CONSTRAINT VBDReportSQLs_VBDReportCustomers_FK 

GO

ALTER TABLE VBDSYS.dbo.VBDReportAccess DROP CONSTRAINT VBDReportSQLs_VBDReportAccess_FK 

GO





-- First, remove any potential ReportLinkColumns...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportLinkColumns WHERE ReportNo = 12111 OR ReportLinkNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the link columns of Report 12111'
Else
Print '* SUCCESS: Link columns of Report 12111 was deleted successfully'




-- Second, remove any potential ReportLinks...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportLinks WHERE ReportNo = 12111 OR ReportLinkNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the links of Report 12111'
Else
Print '* SUCCESS: Links of Report 12111 was deleted successfully'




-- Second, remove any potential ReportColumns with this particular number...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportColumns WHERE ReportNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was deleted successfully'




-- Second, remove any potential ReportCustomers...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportCustomers WHERE ReportNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the customers of Report 12111'
Else
Print '* SUCCESS: Customers of Report 12111 was deleted successfully'




-- Second, remove any potential ReportAccess...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportAccess WHERE ReportNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the access of Report 12111'
Else
Print '* SUCCESS: Access of Report 12111 was deleted successfully'




-- Second, remove any potential ReportSqlCategories...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportSqlsCategories WHERE ReportNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the categories of Report 12111'
Else
Print '* SUCCESS: Categories of Report 12111 was deleted successfully'




-- Second, remove any potential ReportJobArguments...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportJobArguments WHERE ReportNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the job arguments of Report 12111'
Else
Print '* SUCCESS: Job arguments of Report 12111 was deleted successfully'




-- Second, remove any potential ReportJobs...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportJobs WHERE ReportNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the jobs of Report 12111'
Else
Print '* SUCCESS: Jobs of Report 12111 was deleted successfully'




-- Second, remove any potential ReportLinkColumns...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportLinkColumns WHERE ReportNo = 12111 OR ReportLinkNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the link columns of Report 12111'
Else
Print '* SUCCESS: Link columns of Report 12111 was deleted successfully'




-- Second, remove any potential ReportLinks...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportLinks WHERE ReportNo = 12111 OR ReportLinkNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the links of Report 12111'
Else
Print '* SUCCESS: Links of Report 12111 was deleted successfully'




-- Second, remove any potential report arguments...
--------------------------------------------------
DELETE FROM VBDSYS.dbo.VBDReportArguments WHERE ReportNo = 12111
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while deleting the arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was deleted successfully'




-- Third, remove any potential Reports with this particular number... REMOVED! IF exists -> Update!
--------------------------------------------------


Print ''
-- Fourth, insert/update the new Report...
--------------------------------------------------
IF (EXISTS(SELECT * FROM VBDSYS.dbo.VBDReportSQLs WHERE ReportNo = 12111))
  UPDATE	VBDSYS.dbo.VBDReportSQLs
  SET		ReportOrderNo = 12111,
		    ReportName = ' Lagerbevegelser (inkl utført av)',
		    ReportDescription = 'Viser alle lagerbevegelser. Inkluderer kolonne Utført av.',
		    ReportSQL = '--Rapport nr 12111
SET NOCOUNT ON 
set dateformat dmy

DECLARE @parStoreNo As varchar(8000)
DECLARE @parDateFrom As varchar(1000)
DECLARE @parDateTo As varchar(1000)
DECLARE @parSupplierArticleID As varchar(2000)
DECLARE @parSupplierNo As varchar(2000)
DECLARE @parArticleHierNo As varchar(1000)
DECLARE @parArticleNo as varchar(1000)
DECLARE @parArticleID as varchar(1000)
DECLARE @parEANNo as varchar(1000)
DECLARE @parArticleName as varchar(8000)

DECLARE @SQL As varchar(8000)

SET @parStoreNo = ''1''
SET @parDateFrom = ''11-may-2009''
SET @parDateTo = ''11-jun-2009''
SET @parSupplierNo = ''''
SET @parSupplierArticleID = ''''
SET @parArticleHierNo= ''''
SET @parArticleNo = ''''
SET @parArticleID = ''''
SET @parEANNo = ''''
SET @parArticleName = ''''
IF LEN(@parDateFrom) > 10
  SET @parDateFrom = (SELECT SUBSTRING(@parDateFrom,1,11))
  
IF LEN(@parDateTo) > 10
  SET @parDateTo = (SELECT SUBSTRING(@parDateTo,1,11))
  
SET @SQL =  ''SELECT ''
if len(@parStoreNo ) > 0 and (select charindex('','', @parStoreNo ) ) > 0 or len(@parStoreNo ) = 0 
set @sql = @sql + ''
    stor.InternalStoreID,
    stor.storename,''
set @sql = @sql + ''
    isnull(alar.Eanno,0) as Ean, 
    alar.ArticleID,
    ltrim(isnull(alar.WholesalerArticleID, alar.SupplierArticleID )) as supplierarticleid,
    COALESCE(alar.WholesalerName,alar.suppliername, '''''''') as suppliername, 
    alar.articlename, 
    isnull(stad.netprice,0) as netprice, 
    stad.adjustmentqty,
    stad.adjustmentdate, 
    sat.StockAdjName,
    stor.StoreNo,
    ISNULL(strc.stockadjreasonname, 0) as stockadjreasonname,
    isnull(stad.adjustmentrefno,'''''''') as Comment_No,
    alar.articlehiernametop, 
    alar.articlehiername, 
   alar.ArticleHierID,
	master.ArticleName as MasterArticle , 
	userid AS username
	, stad.userNo
    FROM  vbdcm.dbo.vw_SummedStockAdjustmentsMasterAndChild_Report12111 stad
	 JOIN VBDSYS.dbo.VBDUsers u ON u.UserNo = stad.userNo

    join Stores stor on (stor.storeno = stad.storeno) 
    join  allarticles alar on (alar.articleno = stad.articleno) 
	left join Articles master on (master.ArticleNo = stad.MasterArticleNo)
	left join stockadjustmentreasoncodes strc on (stad.stockadjreasonno = strc.stockadjreasonno)
    join StockAdjustmentTypes sat on (stad.StockAdjType = sat.StockAdjType)
    WHERE  stad.stockadjtype IN ( 1,2,3,4,51,53)''
     if len(@parStoreNo) > 0
       set @sql = @sql + ''   and stad.storeno in ('' + @parStoreNo + '')''
     if len(@parSupplierArticleID) > 0
     begin
	SET @SQL = @SQL + '' AND alar.ArticleNo IN (SELECT suar.ArticleNo FROM 
                             SupplierArticles AS suar WHERE ltrim(suar.SupplierArticleID)  = ''''''  + @parSupplierArticleID + ''''''''
                SET @SQL = @SQL + '')''
     end
    if len(@parDateFrom) > 0
         set @sql = @sql + '' and stad.adjustmentdate >=  ''''''  + @parDateFrom + '' 00:00:00''''''
    if len(@parDateTo) > 0
       set @sql = @sql + '' and stad.adjustmentdate <=  ''''''  + @parDateTo + '' 23:59:59''''''
    if len(@parSupplierNo) > 0
        set @sql = @sql + '' and (alar.supplierno in (''  + @parSupplierNo + '') or alar.WholesalerNo in (''  + @parSupplierNo + ''))''
    if len(@parArticleHierNo ) > 0
             set @SQL = @SQL + '' and alar.articlehierno in ('' + @parArticleHierNo+ '')''
    if len(@parArticleName) > 0 
      	set @SQL = @SQL + '' AND alar.articleName like ''''%''  + @parArticleName + ''%''''''
    if len(@parArticleNo) > 0 
      	set @SQL = @SQL + '' AND alar.articleNo = '' + @parArticleNo 
	if len(@parEanNo) > 0 
				SET @sql = @sql + '' AND alar.Articleno in (select articleno from ean where EANno IN ('' + @parEanNo + ''))''
	if len(@parArticleID) > 0 
      		set @sql = @sql + '' AND alar.articleID = ''''''  + @parArticleID + ''''''''

 SET @SQL = @SQL + '' ORDER BY stad.adjustmentdate desc''                

Execute (@SQL)


',
			ReportACL = '',
			DatabaseName = 'VBDCM',
			ReportStatus = 1,
			ReportTypeNo = 10,
			ReportTemplateFileName = '',
			ViewGroupSums = 1,
			ViewTotalSum = 1,
			CommonReport = 1,
			ViewInMainList = 1
	WHERE	ReportNo = 12111 
ELSE 
INSERT INTO VBDSYS.dbo.VBDReportSQLs (ReportNo, ReportOrderNo, ReportName, 
  ReportDescription, ReportSQL, ReportACL, DatabaseName, 
  ReportStatus, ReportTypeNo, ReportTemplateFileName, ViewGroupSums, ViewTotalSum, CommonReport, ViewInMainList) 
VALUES (
12111,12111,
' Lagerbevegelser (inkl utført av)',
'Viser alle lagerbevegelser. Inkluderer kolonne Utført av.',
'--Rapport nr 12111
SET NOCOUNT ON 
set dateformat dmy

DECLARE @parStoreNo As varchar(8000)
DECLARE @parDateFrom As varchar(1000)
DECLARE @parDateTo As varchar(1000)
DECLARE @parSupplierArticleID As varchar(2000)
DECLARE @parSupplierNo As varchar(2000)
DECLARE @parArticleHierNo As varchar(1000)
DECLARE @parArticleNo as varchar(1000)
DECLARE @parArticleID as varchar(1000)
DECLARE @parEANNo as varchar(1000)
DECLARE @parArticleName as varchar(8000)

DECLARE @SQL As varchar(8000)

SET @parStoreNo = ''1''
SET @parDateFrom = ''11-may-2009''
SET @parDateTo = ''11-jun-2009''
SET @parSupplierNo = ''''
SET @parSupplierArticleID = ''''
SET @parArticleHierNo= ''''
SET @parArticleNo = ''''
SET @parArticleID = ''''
SET @parEANNo = ''''
SET @parArticleName = ''''
IF LEN(@parDateFrom) > 10
  SET @parDateFrom = (SELECT SUBSTRING(@parDateFrom,1,11))
  
IF LEN(@parDateTo) > 10
  SET @parDateTo = (SELECT SUBSTRING(@parDateTo,1,11))
  
SET @SQL =  ''SELECT ''
if len(@parStoreNo ) > 0 and (select charindex('','', @parStoreNo ) ) > 0 or len(@parStoreNo ) = 0 
set @sql = @sql + ''
    stor.InternalStoreID,
    stor.storename,''
set @sql = @sql + ''
    isnull(alar.Eanno,0) as Ean, 
    alar.ArticleID,
    ltrim(isnull(alar.WholesalerArticleID, alar.SupplierArticleID )) as supplierarticleid,
    COALESCE(alar.WholesalerName,alar.suppliername, '''''''') as suppliername, 
    alar.articlename, 
    isnull(stad.netprice,0) as netprice, 
    stad.adjustmentqty,
    stad.adjustmentdate, 
    sat.StockAdjName,
    stor.StoreNo,
    ISNULL(strc.stockadjreasonname, 0) as stockadjreasonname,
    isnull(stad.adjustmentrefno,'''''''') as Comment_No,
    alar.articlehiernametop, 
    alar.articlehiername, 
   alar.ArticleHierID,
	master.ArticleName as MasterArticle , 
	userid AS username
	, stad.userNo
    FROM  vbdcm.dbo.vw_SummedStockAdjustmentsMasterAndChild_Report12111 stad
	 JOIN VBDSYS.dbo.VBDUsers u ON u.UserNo = stad.userNo

    join Stores stor on (stor.storeno = stad.storeno) 
    join  allarticles alar on (alar.articleno = stad.articleno) 
	left join Articles master on (master.ArticleNo = stad.MasterArticleNo)
	left join stockadjustmentreasoncodes strc on (stad.stockadjreasonno = strc.stockadjreasonno)
    join StockAdjustmentTypes sat on (stad.StockAdjType = sat.StockAdjType)
    WHERE  stad.stockadjtype IN ( 1,2,3,4,51,53)''
     if len(@parStoreNo) > 0
       set @sql = @sql + ''   and stad.storeno in ('' + @parStoreNo + '')''
     if len(@parSupplierArticleID) > 0
     begin
	SET @SQL = @SQL + '' AND alar.ArticleNo IN (SELECT suar.ArticleNo FROM 
                             SupplierArticles AS suar WHERE ltrim(suar.SupplierArticleID)  = ''''''  + @parSupplierArticleID + ''''''''
                SET @SQL = @SQL + '')''
     end
    if len(@parDateFrom) > 0
         set @sql = @sql + '' and stad.adjustmentdate >=  ''''''  + @parDateFrom + '' 00:00:00''''''
    if len(@parDateTo) > 0
       set @sql = @sql + '' and stad.adjustmentdate <=  ''''''  + @parDateTo + '' 23:59:59''''''
    if len(@parSupplierNo) > 0
        set @sql = @sql + '' and (alar.supplierno in (''  + @parSupplierNo + '') or alar.WholesalerNo in (''  + @parSupplierNo + ''))''
    if len(@parArticleHierNo ) > 0
             set @SQL = @SQL + '' and alar.articlehierno in ('' + @parArticleHierNo+ '')''
    if len(@parArticleName) > 0 
      	set @SQL = @SQL + '' AND alar.articleName like ''''%''  + @parArticleName + ''%''''''
    if len(@parArticleNo) > 0 
      	set @SQL = @SQL + '' AND alar.articleNo = '' + @parArticleNo 
	if len(@parEanNo) > 0 
				SET @sql = @sql + '' AND alar.Articleno in (select articleno from ean where EANno IN ('' + @parEanNo + ''))''
	if len(@parArticleID) > 0 
      		set @sql = @sql + '' AND alar.articleID = ''''''  + @parArticleID + ''''''''

 SET @SQL = @SQL + '' ORDER BY stad.adjustmentdate desc''                

Execute (@SQL)


',
'',
'VBDCM',
1,
10,
'',
1,
1,
1,
1
)
Go

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting Report 12111'
Else
Print '* SUCCESS: Report 12111 was inserted/updated successfully'



-- Fifth, insert the new ReportColumns
--------------------------------------------------
INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
1,
'InternalStoreID',
'But nr',
'',
800,
'0',
'',
Null,
'',
1,
1,
0,
1,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
2,
'storename',
'Butikk',
'',
2600,
'0',
'',
1,
'',
1,
1,
0,
2,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
28,
'ArticleID',
'Varenr',
'',
800,
'0',
'',
Null,
'',
1,
1,
0,
3,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
8,
'supplierarticleid',
'Bestnr',
'',
1300,
'0',
'',
Null,
'',
1,
1,
0,
4,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
11,
'articlename',
'Varenavn',
'',
2600,
'0',
'',
Null,
'',
1,
1,
0,
5,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
10,
'suppliername',
'Leverandør',
'',
2000,
'0',
'',
Null,
'',
1,
1,
0,
6,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
19,
'netprice',
'Innpris',
'',
800,
'0',
'',
Null,
'',
1,
1,
0,
7,
'# ### ### ##0.00',
'RIGHT',
'',
Null,
Null,
2,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
3,
'adjustmentqty',
'Antall',
'',
800,
'0',
'SUM',
Null,
'',
1,
1,
0,
8,
'# ### ### ##0.00',
'RIGHT',
'',
Null,
Null,
2,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
6,
'adjustmentdate',
'Dato',
'',
1900,
'0',
'',
Null,
'',
1,
1,
0,
9,
'dd.MM.yyyy hh:mm:ss',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
21,
'STOCKADJNAME',
'Transaksjonstype',
'',
800,
'0',
'',
Null,
'',
1,
1,
0,
10,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
23,
'STOCKADJREASONNAME',
'Årsakskode',
'',
800,
'0',
'',
Null,
'',
1,
1,
0,
11,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
27,
'MasterArticle',
'Kjøpsvare',
'',
800,
'0',
'',
Null,
'',
1,
1,
0,
12,
'',
'CENTER',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
16,
'Comment_No',
'Kommentar/Nr',
'',
1400,
'0',
'',
Null,
'',
1,
1,
0,
13,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
7,
'Ean',
'Ean',
'',
1300,
'0',
'',
Null,
'',
1,
1,
0,
14,
'#',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
29,
'ArticleHierID',
'Varegrp',
'',
800,
'0',
'',
Null,
'',
1,
1,
0,
15,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
17,
'articlehiernametop',
'Hovedgruppe',
'',
2000,
'0',
'',
Null,
'',
0,
1,
0,
18,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
18,
'articlehiername',
'Varegruppe',
'',
2000,
'0',
'',
Null,
'',
0,
1,
0,
19,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
22,
'STORENO',
'Internt but nr',
'',
800,
'0',
'',
Null,
'',
0,
1,
0,
21,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportColumns (ReportNo, ColumnNo, ColumnName, ColumnCaption, ColumnDescription,
ColumnWidth, ColumnWidthType, SumOperation, GroupSumLevel, GroupSumFormula, ColumnVisible, ColumnIncluded, Barcode, 
ColumnOrderNo, ColumnFormat, ColumnAlignment, OnClickEvent, Highlight, PagebreakLevel, NumberOfDecimals, ColumnWidthWeb)
VALUES (
12111,
30,
'UserName',
'',
'',
800,
'0',
'',
Null,
'',
1,
1,
0,
30,
'',
'LEFT',
'',
Null,
Null,
0,
Null
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Columns of Report 12111'
Else
Print '* SUCCESS: Columns of Report 12111 was inserted successfully'




-- Sixth, insert the new ReportArguments
--------------------------------------------------
INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
2,
'parDateFrom',
'VBDCM',
'Dato fom',
'',
Null,
40,
Null,
Null,
Null,
Null,
'TODAY-28',
Null,
'',
1,
1,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
3,
'parDateTo',
'VBDCM',
'Dato tom',
'',
Null,
40,
Null,
Null,
Null,
Null,
'TODAY',
Null,
'',
1,
2,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
1,
'parStoreNo',
'VBDCM',
'Butikk',
'Blank er lik alle butikker',
Null,
61,
Null,
Null,
Null,
Null,
'',
14,
'',
1,
3,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
14,
'parSupplierNo',
'VBDCM',
'Leverandør',
'Velg en eller flere leverandører. Blank er lik alle leverandører',
Null,
61,
Null,
Null,
Null,
Null,
' ',
Null,
'select supplierno, suppliername from supplierorgs where (supplierno in (select supplierno from supplierarticles) AND suppliertype = 1) OR (supplierno in (select supplierno from supplierarticles) AND SupplierType = 2) order by suppliername',
2,
4,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
15,
'parArticleHierNo',
'VBDCM',
'Varegruppe',
' ',
Null,
61,
Null,
Null,
Null,
Null,
' ',
9,
'',
2,
5,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
18,
'parSortCode',
'VBDCM',
'Sortimentskode',
' ',
Null,
61,
Null,
Null,
Null,
Null,
' ',
41,
'',
0,
6,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
17,
'parArticleName',
'VBDCM',
'Varenavn',
' ',
Null,
10,
Null,
Null,
Null,
Null,
'',
Null,
'',
2,
7,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
13,
'parSupplierArticleID',
'VBDCM',
'Bestillingsnr',
' ',
Null,
10,
Null,
Null,
Null,
Null,
' ',
Null,
' ',
2,
8,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
20,
'parEanNo',
'VBDCM',
'Ean',
' ',
Null,
10,
Null,
Null,
Null,
Null,
' ',
Null,
' ',
2,
9,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
21,
'parArticleID',
'VBDCM',
'Varenr',
' ',
Null,
10,
Null,
Null,
Null,
Null,
' ',
Null,
' ',
2,
10,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportArguments (ReportNo, ArgumentNo, ArgumentName, DatabaseName,
ArgumentCaption, ArgumentDescription, VariableTypeNo, ArgumentType, ArgumentTop, ArgumentLeft,
ArgumentWidth, ArgumentHeight, ArgumentDefault, ArgumentValueNo, ArgumentValues, ArgumentRequired, ArgumentOrderNo, ArgumentVisible)
VALUES (
12111,
19,
'parArticleNo',
'VBDCM',
'Internt varenr',
' ',
Null,
10,
Null,
Null,
Null,
Null,
' ',
Null,
' ',
0,
19,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the Arguments of Report 12111'
Else
Print '* SUCCESS: Arguments of Report 12111 was inserted successfully'




-- 7, insert the categories
--------------------------------------------------
INSERT INTO VBDSYS.dbo.VBDReportSqlsCategories (ReportNo, ReportCategoryNo) 
VALUES (
12111,
50
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the categories of Report 12111'
Else
Print '* SUCCESS: Categories of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportSqlsCategories (ReportNo, ReportCategoryNo) 
VALUES (
12111,
51
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the categories of Report 12111'
Else
Print '* SUCCESS: Categories of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportSqlsCategories (ReportNo, ReportCategoryNo) 
VALUES (
12111,
61
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the categories of Report 12111'
Else
Print '* SUCCESS: Categories of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportSqlsCategories (ReportNo, ReportCategoryNo) 
VALUES (
12111,
100
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the categories of Report 12111'
Else
Print '* SUCCESS: Categories of Report 12111 was inserted successfully'




-- 8, insert the customers
--------------------------------------------------



-- 9, insert the access rights
--------------------------------------------------
INSERT INTO VBDSYS.dbo.VBDReportAccess (ReportNo, UserTypeNo) 
VALUES (
12111,
1
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the access rights of Report 12111'
Else
Print '* SUCCESS: Access rights of Report 12111 was inserted successfully'

INSERT INTO VBDSYS.dbo.VBDReportAccess (ReportNo, UserTypeNo) 
VALUES (
12111,
2
)

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the access rights of Report 12111'
Else
Print '* SUCCESS: Access rights of Report 12111 was inserted successfully'




-- 10, insert the report jobs
--------------------------------------------------



-- 11, insert the report job arguments
--------------------------------------------------
-- Add foreign keys

ALTER TABLE VBDSYS.dbo.VBDReportSqlsCategories ADD CONSTRAINT

	VBDReportSQLs_VBDReportSqlsCategories_FK FOREIGN KEY (ReportNo) REFERENCES VBDReportSQLs(ReportNo)

GO

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the foreign key'
ALTER TABLE VBDSYS.dbo.VBDReportCustomers ADD CONSTRAINT

	VBDReportSQLs_VBDReportCustomers_FK FOREIGN KEY (ReportNo) REFERENCES VBDReportSQLs(ReportNo)

GO

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the foreign key'
ALTER TABLE VBDSYS.dbo.VBDReportAccess ADD CONSTRAINT

	VBDReportSQLs_VBDReportAccess_FK FOREIGN KEY (ReportNo) REFERENCES VBDReportSQLs(ReportNo)

GO

If (@@ERROR <> 0)
Print '* ERROR: An error occured while inserting the foreign key'
Print '********************************************************************************'
Print ''


-- * Report 12111 finished
-- ****************************************************************************************************











--------------------------------------------------
-- insert the report links
--------------------------------------------------



--------------------------------------------------
-- insert the report link columns
--------------------------------------------------
Print '********************************************************************************'
Print ''


