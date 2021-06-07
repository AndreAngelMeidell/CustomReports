USE [VRNOMisc]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GenusReportsSalesAccWeek]    Script Date: 25.03.2021 09:22:19 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

  

----    Description:    Export sales data to Genus DWH            
----    Requirements:   xp_cmdshell must be enabled
----                    EXEC sp_configure 'show advanced options', 1
----                    RECONFIGURE
----                    EXEC sp_configure 'xp_cmdshell', 1
----                    RECONFIGURE
       

--  20200312 Endringer : Oppryddlig, fjerner alt som er kommentert
--  20200312 Endringer : Salg ink mva endres til ex mva, pant inluderes med articleid<0 og kunde teller i UTU endres
--  20200312 Endringer : Oppryddlig, fjerner alt som er kommentert
--  20200325 Endringer . fjerner pricetypeidx 19 kriterie
--  20200330 Endringer - Hardkoder pant til 9800000000007
--  20200401 Endringer i Antall_Alternativ for pant og vekt
--  20210207 Endringer i behandling av uker ved årskifte og week til ISO_WEEK 
  
CREATE PROCEDURE [dbo].[usp_CBI_GenusReportsSalesAccWeek]
(
    @InParamReportTypeId AS INT
    ,@InParamChainCodeId AS INT
    ,@InParamDate AS DATETIME
    ,@InParamGln VARCHAR(256)
    ,@EnvironmentId INT
    ,@LogonInfo VARCHAR(100)
    ,@Server VARCHAR(100)
    ,@FolderRootPart VARCHAR(100)
    ,@IsDebugOn INT
    ,@LevChainGroupNo INT
    ,@SubPath VARCHAR(100)
    ,@InParamFromDate AS DATETIME = null
    ,@InParamToDate AS DATETIME = null

)
AS
BEGIN  

    DECLARE @true AS INT = 1
    DECLARE @false AS INT = 0
  
	SET DATEFIRST 1 -- Sets First day of week to Monday 20200129
  
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT '[usp_CBI_GenusReportsSales]DebugInfo:Start'
        SELECT '@InParamReportTypeId :' + CAST(@InParamReportTypeId AS CHAR)
        SELECT '@InParamChainCodeId :' + CAST(@InParamChainCodeId AS CHAR)
        SELECT '@InParamDate :' + CAST(@InParamDate AS CHAR)
        SELECT '@InParamGln :' + CAST(@InParamGln AS CHAR)
        SELECT '@EnvironmentId :' + CAST(@EnvironmentId AS CHAR)
        SELECT '@LogonInfo :' + CAST(@LogonInfo AS CHAR)
        SELECT '@Server :' + CAST(@Server AS CHAR)
        SELECT '@FolderRootPart :' + CAST(@FolderRootPart AS CHAR)
        SELECT '@IsDebugOn :' + CAST(@IsDebugOn AS CHAR)
        SELECT '@LevChainGroupNo :' + CAST(@LevChainGroupNo AS CHAR)
        SELECT '@SubPath :' + CAST(@SubPath AS CHAR)
  
        SELECT '[usp_CBI_GenusReportsSales]DebugInfo:End'
    END
    DECLARE @sql AS VARCHAR(200)
    SET DATEFIRST 1
    DECLARE @sqlStr VARCHAR(4000)
    DECLARE @cmdStr VARCHAR(4000)
    DECLARE @fileName VARCHAR(1000)
    DECLARE @DateFromIdx INT
    DECLARE @DateToIdx INT
    declare @ArticleBundlePriceType as int = 10
    DECLARE @StoreId AS VARCHAR(5)
    DECLARE @Value_NG_INTERNAL_STORE_ID AS VARCHAR(5)
    DECLARE @template AS VARCHAR(5) = '00000'
  
    select @StoreId = StoreId from BI_Mart.RBIM.Dim_Store where GlobalLocationNo = @InParamGln AND iscurrent =1
  
    SELECT '@StoreId(a) : ' + CAST(@StoreId AS VARCHAR(20))
  
    SELECT @storeid = LEFT(@template,len(@template) - len(@Storeid)) + @Storeid
  
    SELECT '@StoreId(b) : ' + CAST(@StoreId AS VARCHAR(20))
      
	DECLARE @SelectionDate DATETIME = @InParamDate --Changed cause of wrong weekno when job is runed in other day manualy AM 20200131

    SELECT '@SelectionDate : ' + CAST(@SelectionDate AS VARCHAR(20))
  
    DECLARE @ProfilHus VARCHAR(10)
  
    SELECT @ProfilHus = DS.Lev2RegionGroupName FROM  BI_Mart.RBIM.Dim_Store AS DS WHERE DS.GlobalLocationNo=@InParamGln AND DS.IsCurrentStore=1
	
	DECLARE @DateLine VARCHAR(10) --New
	 
    --SET @fileName =
    --    'OMS_' + @ProfilHus +'_'+
    --    RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),4)  +
    --    RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
    --    RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)+
    --    RIGHT('0' + CAST(DATEPART(iso_WEEK,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)+
    --    '_'+
    --    @InParamGln + '.csv'
  
IF (DATEPART(iso_WEEK,@SelectionDate) = 53 AND DATEPART(WEEK,@SelectionDate) = 53)
	BEGIN
	SET @fileName =
        'OMS_' + @ProfilHus +'_'+
        RIGHT('0' + CAST(DATEPART(YEAR,@SelectionDate) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,@SelectionDate) AS VARCHAR),2) +
        '31'+
		'52'+
        '_'+
        @InParamGln + '.csv'
		
		SET @DateLine = 
		RIGHT('0' + CAST(DATEPART(YEAR,@SelectionDate) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,@SelectionDate) AS VARCHAR),2) +
        '31'+
		'52'
		
	END

IF (DATEPART(iso_WEEK,@SelectionDate) = 53 AND DATEPART(WEEK,@SelectionDate) = 1)
	BEGIN
	SET @fileName =
        'OMS_' + @ProfilHus +'_'+
        RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
		'01'+
        '_'+
        @InParamGln + '.csv'
		
		SET @DateLine = 
		RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
		'01'
	END
    
IF DATEPART(iso_WEEK,@SelectionDate) <> 53 
	BEGIN	
	SET @fileName =
        'OMS_' + @ProfilHus +'_'+
        RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)+
        RIGHT('0' + CAST(DATEPART(iso_WEEK,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)+
         '_'+
        @InParamGln + '.csv'
		
		SET @DateLine = 
		RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)+
        RIGHT('0' + CAST(DATEPART(iso_WEEK,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)
		
	END
          
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT @fileName
    end
          
    DELETE FROM GenusSalesData
    DELETE FROM GenusSalesData_Check
  
  
    --Sjekk om det finnes salg, igjen?
    DECLARE @count AS INT
    DECLARE @ExsportDataForThisStoreThisDate AS INT
    SELECT @count =COUNT(*)
    FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay sales
        INNER JOIN BI_Mart.RBIM.Dim_Date tdate ON sales.ReceiptDateIdx = tdate.DateIdx
        INNER JOIN BI_Mart.RBIM.Dim_Store store ON sales.StoreIdx = store.StoreIdx
    WHERE tdate.WeekNumberOfYear = DATEPART(iso_WEEK,@InParamDate) AND tdate.Year = DATEPART(YEAR,@InParamDate) AND tdate.FullDate IS NOT NULL
    AND store.GlobalLocationNo = @InParamGln
          
    IF @count>0
    BEGIN
        SET @ExsportDataForThisStoreThisDate = @true
        PRINT 'Data for this period, do export'
    END
    ELSE
    BEGIN
        SET @ExsportDataForThisStoreThisDate = @false
        PRINT 'No Data for this period, do not export'
    END
  
    IF @ExsportDataForThisStoreThisDate = @true
    BEGIN
          
        IF OBJECT_ID('tempdb..##GenusSalesReport') IS NOT NULL
        DROP TABLE ##GenusSalesReport
          
        --DELETE  from GenusSalesReport
          
        ;with SalgslinjerRenset AS
        (
            SELECT
                'OVUN_RAW' as 'Rapport_Kode',
                store.GlobalLocationNo as 'Filial',
                Dato = @DateLine,--dbo.GetGenusVaresalgDatoValue(tdate.fulldate),
                AID_Kode = CASE
                        WHEN LEN(CAST(ISNULL(gtin.Gtin,0) AS VARCHAR)) > 6 THEN 'E'
                        WHEN LEN(CAST(ISNULL(gtin.Gtin,0) AS VARCHAR)) <= 6 THEN 'P'
                        ELSE ''
                    END ,
                CASE when article.ArticleIdx=-98 THEN '9800000000007' ELSE gtin.Gtin END   as 'Nummer', --9800000000007
                sales.SalesRevenue AS 'Netto_omsetning',
                    Kostpris = case
                        when sales.PosNetPurchasePrice<> 0  --endret fra > til <>
                        then sales.PosNetPurchasePrice
                        else sales.CostOfGoodsSold --NY endret fra PurchasePrice
                    end,
               Antall_Alternativ =  CASE 
						WHEN article.UnitOfMeasureId = 'L'          THEN sales.WeighedUnitOfMeasureAmount * article.UnitOfMeasurementAmount
						WHEN article.ArticleTypeId IN (130,133)     THEN sales.NumberOfArticlesSold-sales.NumberOfArticlesInReturn
						ELSE sales.WeighedSalesAmount-sales.WeighedReturnAmount
					END , 
                /*sales.NumberOfCustomersPerSelectedArticle as 'Kunder',*/
                Kunder = case
                        when price.PriceTypeNo = @ArticleBundlePriceType then 0
                        else sales.NumberOfCustomersPerSelectedArticle
                    end,
                sales.SalesRevenueVat as 'Mva',
                sales.TotalGrossProfit as 'Rabatt',
                --ISNULL(NULLIF(supp.SupplierId,-1),ds.SupplierId) as 'Leverandør',
				ISNULL(ISNULL(NULLIF(supp.SupplierId,-1),ds.SupplierId),'-98') as 'Leverandør',
                'N/A' as 'Grossist',
                article.Lev5ArticleHierarchyId as 'Varegruppe',
                ArtExtIn.Value_Department as 'Avdeling',
                article.ArticleName as 'Vartek',
                sales.ReceiptDateIdx,
                sales.ArticleIdx,
                article.ArticleNo,
                sales.StoreIdx,
                store.StoreId,
                sales.GtinIdx,
                gtin.Gtin
            FROM
                BI_Mart.RBIM.Agg_SalesAndReturnPerDay sales
                INNER JOIN BI_Mart.RBIM.Dim_Date tdate ON sales.ReceiptDateIdx = tdate.DateIdx
                INNER JOIN BI_Mart.rbim.Dim_Article article ON sales.ArticleIdx = article.ArticleIdx
                INNER JOIN BI_Mart.RBIM.Dim_Store store ON sales.StoreIdx = store.StoreIdx
                INNER JOIN BI_Mart.RBIM.Dim_Gtin gtin ON sales.GtinIdx = gtin.GtinIdx
                inner join BI_Mart.rbim.Dim_PriceType price on sales.PriceTypeIdx = price.PriceTypeIdx
                left join BI_Mart.RBIM.Dim_Supplier supp on supp.SupplierIdx = sales.SupplierIdx
                LEFT JOIN BI_Mart.RBIM.Out_ArticleExtraInfo ArtExtIn on ArtExtIn.ArticleId = article.ArticleId
				LEFT JOIN BI_Mart.RBIM.Cov_SupplierArticle AS CSA ON CSA.ArticleIdx = sales.ArticleIdx AND CSA.SupplierIdx = supp.SupplierIdx and CSA.IsPrimarySupplier=1
                LEFT JOIN BI_Mart.RBIM.Dim_Supplier AS DS ON DS.SupplierIdx = CSA.SupplierIdx
            WHERE
                tdate.WeekNumberOfYear = DATEPART(iso_WEEK,@InParamDate) AND tdate.Year = DATEPART(YEAR,@InParamDate) AND tdate.FullDate IS NOT NULL
                AND sales.SalesPrice=sales.SalesAmount -- dvs normalpris
                AND store.GlobalLocationNo = @InParamGln
                AND article.Lev4ArticleHierarchyId <> '-4'
                --and sales.PriceTypeIdx <> 19 -- ikke ta med overføring mellom butikk
        )
        , Tilbudslinjer as
        (
            SELECT
                'OVUT-RAW' as 'Rapport_Kode',
                store.GlobalLocationNo as 'Filial',
                Dato = @DateLine, -- dbo.GetGenusVaresalgDatoValue(tdate.fulldate),
                AID_Kode = CASE
                        WHEN LEN(CAST(ISNULL(gtin.Gtin,0) AS VARCHAR)) > 6 THEN 'E'
                        WHEN LEN(CAST(ISNULL(gtin.Gtin,0) AS VARCHAR)) <= 6 THEN 'P'
                        ELSE ''
                    END ,
                --gtin.Gtin as 'Nummer',
				CASE when article.ArticleIdx=-98 THEN '9800000000007' ELSE gtin.Gtin END   as 'Nummer', --9800000000007
				sales.SalesRevenue AS 'Netto_omsetning',
                Kostpris = case
                    when sales.PosNetPurchasePrice<> 0 
                    then sales.PosNetPurchasePrice
                    else sales.CostOfGoodsSold --NY endret fra PurchasePrice
                end,
                Antall_Alternativ =  CASE 
						WHEN article.UnitOfMeasureId = 'L'          THEN sales.WeighedUnitOfMeasureAmount * article.UnitOfMeasurementAmount
						WHEN article.ArticleTypeId IN (130,133)     THEN sales.NumberOfArticlesSold-sales.NumberOfArticlesInReturn
						ELSE sales.WeighedSalesAmount-sales.WeighedReturnAmount
					END , 
                /*sales.NumberOfCustomersPerSelectedArticle as 'Kunder',*/
                Kunder = case
                        when price.PriceTypeNo = @ArticleBundlePriceType then 0
                        else sales.NumberOfCustomersPerSelectedArticle
                    end,
                sales.SalesRevenueVat as 'Mva',
                sales.TotalGrossProfit as 'Rabatt',
                --ISNULL(NULLIF(supp.SupplierId,-1),ds.SupplierId) as 'Leverandør',
				ISNULL(ISNULL(NULLIF(supp.SupplierId,-1),ds.SupplierId),'-98') as 'Leverandør',
                'N/A' as 'Grossist',
                article.Lev5ArticleHierarchyId as 'Varegruppe',
                ArtExtIn.Value_Department as 'Avdeling',
                article.ArticleName as 'Vartek',
                sales.ReceiptDateIdx,
                sales.ArticleIdx,
                article.ArticleNo,
                sales.StoreIdx,
                store.StoreId,
                sales.GtinIdx,
                gtin.Gtin
            FROM
                --Common
                BI_Mart.RBIM.Agg_SalesAndReturnPerDay sales
                INNER JOIN BI_Mart.RBIM.Dim_Date tdate ON sales.ReceiptDateIdx = tdate.DateIdx
                INNER JOIN BI_Mart.rbim.Dim_Article article ON sales.ArticleIdx = article.ArticleIdx
                INNER JOIN BI_Mart.RBIM.Dim_Store store ON sales.StoreIdx = store.StoreIdx
                INNER JOIN BI_Mart.RBIM.Dim_Gtin gtin ON sales.GtinIdx = gtin.GtinIdx
                inner join BI_Mart.rbim.Dim_PriceType price on sales.PriceTypeIdx = price.PriceTypeIdx
                LEFT JOIN BI_Mart.RBIM.Out_ArticleExtraInfo ArtExtIn on ArtExtIn.ArticleId = article.ArticleId
                left join BI_Mart.RBIM.Dim_Supplier supp on supp.SupplierIdx = sales.SupplierIdx
				LEFT JOIN BI_Mart.RBIM.Cov_SupplierArticle AS CSA ON CSA.ArticleIdx = sales.ArticleIdx AND CSA.SupplierIdx = supp.SupplierIdx and CSA.IsPrimarySupplier=1
                LEFT JOIN BI_Mart.RBIM.Dim_Supplier AS DS ON DS.SupplierIdx = CSA.SupplierIdx
            WHERE
                tdate.WeekNumberOfYear = DATEPART(iso_WEEK,@InParamDate) AND tdate.Year = DATEPART(YEAR,@InParamDate) AND tdate.FullDate IS NOT NULL
                AND sales.SalesPrice<>sales.SalesAmount -- dvs tilbudspris
                AND store.GlobalLocationNo = @InParamGln
				AND article.Lev4ArticleHierarchyId <> '-4'
                --and sales.PriceTypeIdx <> 19 -- ikke ta med overføring mellom butikk
        )
        ,ovun as
        (
            select 'OVUN' as 'Rapport_Kode', Filial, Dato, AID_Kode, Nummer, sum(Netto_omsetning) as 'Netto_Omsetning' ,
            sum(Kostpris) as 'Kostpris',sum(Antall_Alternativ) as 'Antall_Alternativ',sum(Kunder) as 'Kunder',sum(Mva) as 'Mva',
            sum(Rabatt) as 'Rabatt',Leverandør,Grossist,Varegruppe,Avdeling,Vartek,'' as 'ReceiptDateIdx',
            '' as 'ArticleIdx','' as 'articleno','' as 'StoreIdx',
            --'' as 'StoreNo',
            '' as 'StoreId',
            '' as 'GtinIdx',''  as 'Gtin'
            from SalgslinjerRenset
            /*group by Rapport_Kode,Filial,dato, AID_Kode, Nummer, leverandør,Grossist,Varegruppe,avdeling,Vartek,/*ReceiptDateIdx,ArticleIdx,*/ArticleNo,StoreIdx,StoreNo,GtinIdx,Gtin*/
            group by Rapport_Kode,Filial,dato, AID_Kode, Nummer, leverandør,Grossist,Varegruppe,avdeling,Vartek,/*ReceiptDateIdx,ArticleIdx,*/ArticleNo,/*StoreIdx,*/
            StoreId,
            GtinIdx,Gtin
        )
        ,ovut as
        (
            select 'OVUT' as 'Rapport_Kode', Filial, Dato, AID_Kode, Nummer, sum(Netto_omsetning) as 'Netto_Omsetning' ,
            sum(Kostpris) as 'Kostpris',sum(Antall_Alternativ) as 'Antall_Alternativ',sum(Kunder) as 'Kunder',sum(Mva) as 'Mva',
            sum(Rabatt) as 'Rabatt',Leverandør,Grossist,Varegruppe,Avdeling,Vartek,'' as 'ReceiptDateIdx',
            '' as 'ArticleIdx','' as 'articleno','' as 'StoreIdx',
            --'' as 'StoreNo',
            '' as 'StoreId',
            '' as 'GtinIdx',''  as 'Gtin'
            from Tilbudslinjer
            /*group by Rapport_Kode,Filial,dato, AID_Kode, Nummer, leverandør,Grossist,Varegruppe,avdeling,Vartek,/*ReceiptDateIdx,ArticleIdx,*/ArticleNo,StoreIdx,StoreNo,GtinIdx,Gtin*/
            group by Rapport_Kode,Filial,dato, AID_Kode, Nummer, leverandør,Grossist,Varegruppe,avdeling,Vartek,/*ReceiptDateIdx,ArticleIdx,*/ArticleNo,/*StoreIdx,*/
            StoreId,
            GtinIdx,Gtin
        )
        ,
        otu as
        (
            select 'OTU' as 'Rapport_Kode', a.Filial,a.Dato
            ,
                sum(Netto_Omsetning) as 'Netto_Omsetning',
                sum(Kostpris) as 'Kostpris' ,
                sum(Antall_Alternativ) as 'Antall_Alternativ' ,
				kunder= (SELECT SUM(sales.NumberOfReceipts)  FROM
                BI_Mart.RBIM.Agg_SalesAndReturnPerDay sales
                INNER JOIN BI_Mart.RBIM.Dim_Date tdate ON sales.ReceiptDateIdx = tdate.DateIdx
                INNER JOIN BI_Mart.rbim.Dim_Article article ON sales.ArticleIdx = article.ArticleIdx
                INNER JOIN BI_Mart.RBIM.Dim_Store store ON sales.StoreIdx = store.StoreIdx
                INNER JOIN BI_Mart.RBIM.Dim_Gtin gtin ON sales.GtinIdx = gtin.GtinIdx
                INNER JOIN BI_Mart.rbim.Dim_PriceType price ON sales.PriceTypeIdx = price.PriceTypeIdx
                LEFT JOIN BI_Mart.RBIM.Dim_Supplier supp ON supp.SupplierIdx = sales.SupplierIdx
                LEFT JOIN BI_Mart.RBIM.Out_ArticleExtraInfo ArtExtIn ON ArtExtIn.ArticleId = article.ArticleId
				LEFT JOIN BI_Mart.RBIM.Cov_SupplierArticle AS CSA ON CSA.ArticleIdx = sales.ArticleIdx AND CSA.SupplierIdx = supp.SupplierIdx AND CSA.IsPrimarySupplier=1
                LEFT JOIN BI_Mart.RBIM.Dim_Supplier AS DS ON DS.SupplierIdx = CSA.SupplierIdx
				WHERE
                tdate.WeekNumberOfYear = DATEPART(iso_WEEK,@InParamDate) AND tdate.Year = DATEPART(YEAR,@InParamDate) AND tdate.FullDate IS NOT NULL
                AND store.GlobalLocationNo = @InParamGln
                AND sales.ArticleIdx < 0
				AND sales.NumberOfReceipts <> 0
                --AND sales.PriceTypeIdx <> 19 
				),
                sum(Mva) as 'Mva'
            from (select * from ovut union all select * from ovun) as a
            group by Filial,dato
        )
        ,report as(
            select a.*  from (
                select 'RIGAL95,6.0' as 'a'
                union all
                select
                    dbo.GetGenusReportOVUxValue
                    (
                        k.Rapport_Kode,k.Filial,k.Dato,k.AID_Kode,
                        k.Nummer ,k.Netto_Omsetning,k.Kostpris,k.Antall_Alternativ,
                        k.Kunder,k.Mva,k.Rabatt,k.Leverandør,
                        k.Grossist,k.Varegruppe,k.Avdeling,k.Vartek
                    ) from ovut k
                union all
                select dbo.GetGenusReportOVUxValue
                    (
                        k.Rapport_Kode,k.Filial,k.Dato,k.AID_Kode,
                        k.Nummer,k.Netto_Omsetning,k.Kostpris,k.Antall_Alternativ,
                        k.Kunder,k.Mva,k.Rabatt,k.Leverandør,
                        k.Grossist,k.Varegruppe,k.Avdeling,k.Vartek
                    ) from ovun k
                union all
                select dbo.GetGenusReportOVUxValue
                    (
                        k.Rapport_Kode,k.Filial,k.Dato,
                        '', --k.AID_Kode,
                        '', --k.Nummer,
                        k.Netto_Omsetning,
                        k.Kostpris,
                        k.Antall_Alternativ,
                        k.Kunder,
                        k.Mva,
                        '',--k.Rabatt,
                        '',--k.Leverandør,
                        '',--k.Grossist,
                        '',--k.Varegruppe,
                        '',--k.Avdeling,
                        ''--k.Vartek
                    ) from otu k
            ) as a
        )
  
  
          
        --INSERT into dbo.GenusSalesReport(DataRowVal) select a.a from report a
        --SELECT *  FROM report
  
        SELECT *
        INTO ##GenusSalesReport
        FROM report
          
        --for test legg til linjen under for å lagre i backup, test med å ha to filer?
        --SET @FolderRootPart = 'd:\genusftp\backup\'
  
        SET @sqlStr ='select * from ##GenusSalesReport order by 1 desc'
  
  
        --Orginal plassering

        SET @cmdStr = 'bcp "' + @sqlStr + '" queryout "' + @FolderRootPart + @SubPath + @fileName + '" -c -CACP -t" " ' + @LogonInfo + ' -S ' + @Server + ' -d VRNOMisc'
        IF(@IsDebugOn=@true)
        BEGIN
            SELECT @cmdStr
        END
  
        EXEC xp_cmdshell @cmdStr
  
  
  
        --BACKUP AM:
        SET @FolderRootPart = 'd:\genusftp\backup\'
        SET @sqlStr ='select * from ##GenusSalesReport order by 1 desc'
        SET @cmdStr = 'bcp "' + @sqlStr + '" queryout "' + @FolderRootPart + @SubPath + @fileName + '" -c -CACP -t" " ' + @LogonInfo + ' -S ' + @Server + ' -d VRNOMisc'
        EXEC xp_cmdshell @cmdStr
        --BACKUP SLUTT
  
  
        --SELECT *  FROM report
    END
   
END
GO

