USE [VRNOMisc]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GenusReportsSalesAccWeek]    Script Date: 07.02.2020 13:06:21 ******/
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
       
----
----    ToDo:           Hardcoded path, server address and userinfo must be changed according to production settings
----
----
----    Modifications history:
----                    20190220 - Andre Meidell - Fjerner and campaign.SalesAmount = sales.SalesAmount pga problemer med ikke lik pris
----                    20190220 - Andre Meidell - Mulig denne i tillegg IKKE UTFØRT: AND campaign.PriceTypeIdx = price.PriceTypeIdx -- kanskje denne i tillegg
----                    20190220 - Andre Meidell - sales.SalesRevenueInclVat, sales.SalesRevenueVat
----                    20190301 - Andre Meidell -  IF OBJECT_ID('tempdb..#GenusSalesReport') IS NOT NULL
----                                                DROP TABLE #GenusSalesReport
----                                                SELECT *
----                                                INTO #GenusSalesReport
----                                                FROM report
----                                                SET @sqlStr ='select * from #GenusSalesReport order by 1 desc'
----                                DECLARE @SelectionDate DATETIME = @InParamDate
----                                WHERE  @SelectionDate = tdate.FullDate
  
----                    20190423 Andre Meidell - DECLARE @StoreId AS VARCHAR(4) to 5
----                    20190423 Andre Meidell - DECLARE @Value_NG_INTERNAL_STORE_ID AS VARCHAR(4) to 5
----                    20190423 Andre Meidell - DECLARE @template AS VARCHAR(5) = '00000' from 6

----                    20190522 Andre Meidell -Endrer til ukes prosedyre, øker tidsintervaller, test
---- RIGHT('0' + CAST(DATEPART(year,@SelectionDate) AS VARCHAR),2) +
---- RIGHT('0' + CAST(DATEPART(MONTH,@SelectionDate) AS VARCHAR),2) +
---- RIGHT('0' + CAST(DATEPART(WEEK,@SelectionDate) AS VARCHAR),2) +
---- JOIN BI_Mart.RBIM.Dim_Date AS DD ON sales.ReceiptDateIdx=dd.DateIdx
---- WHERE DD.WeekNumberOfYear = DATEPART(WEEK,@InParamDate) AND DD.Year = DATEPART(YEAR,@InParamDate) AND DD.FullDate IS NOT NULL

--  20190524 ArtExtIn.Value_Department as 'Avdeling',
--  ArtExtIn.ArticleId = article.ArticleId

--  20190617 stk pant
--  CASE
--  WHEN article.UnitOfMeasureId = 'L'          THEN sales.WeighedUnitOfMeasureAmount * article.UnitOfMeasurementAmount
--  WHEN article.ArticleTypeId IN (130,133)     THEN (  SELECT  COUNT(FRRSAR.RowIdx)  FROM BI_Mart.RBIM.Fact_ReceiptRowSalesAndReturn AS FRRSAR
--                                                      WHERE  FRRSAR.ArticleIdx = sales.ArticleIdx AND FRRSAR.StoreIdx = sales.StoreIdx AND FRRSAR.ReceiptDateIdx = sales.ReceiptDateIdx)
--  ELSE sales.WeighedUnitOfMeasureAmount
--  END AS Antall_Alternativ_new,

--  20190617 pant leverandør
--  ISNULL(NULLIF(supp.SupplierId,-1),ds.SupplierId) as 'Leverandør_NEW',
--  LEFT JOIN BI_Mart.RBIM.Cov_SupplierArticle AS CSA ON CSA.ArticleIdx = sales.ArticleIdx
--  LEFT JOIN BI_Mart.RBIM.Dim_Supplier AS DS ON DS.SupplierIdx = CSA.SupplierIdx

--  20200131 Endring : DECLARE @SelectionDate DATETIME = @InParamDate --Changed cause of wrong weekno when job is runed in other day manualy AM 20200131
--  20200203 Endring : SET DATEFIRST 1 -- Sets First day of week to Monday 20200129
--  20200205 Endring : LEFT JOIN BI_Mart.RBIM.Cov_SupplierArticle AS CSA ON CSA.ArticleIdx = sales.ArticleIdx AND CSA.SupplierIdx = supp.SupplierIdx 
--  20200206 Endring : and CSA.IsPrimarySupplier=1
  
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
    --@DateFrom AS DATETIME,
    --@DateTo AS DATETIME
)
AS
BEGIN
  
      
  
    DECLARE @true AS INT = 1
    DECLARE @false AS INT = 0
    --SELECT @IsDebugOn AS 'sales_debug'
  
	SET DATEFIRST 1 -- Sets First day of week to Monday 20200129
  
    /* DEBUG SECTION START*/
    /*
    SET @IsDebugOn = 1
    SET @InParamReportTypeId = 1                           
    SET @InParamChainCodeId = 1                           
    SET @InParamDate = CAST('2016-12-27' AS date)--Dec 27 2016 10:39PM         
    SET @InParamGln = 7080001056063               
    SET @EnvironmentId = 1                           
    SET @LogonInfo = ' -U RSAdmin -P xxxxxxxxxxxxxxxxxxxxxxxxx '        
    SET @Server = '172.25.43.60'                
    SET @FolderRootPart = 'd:\genusftp\CAPS\'           
    SET @IsDebugOn = 1                           
    SET @LevChainGroupNo = 1213                        
    SET @SubPath = 'Omsetning\MENY\'
    */
    /* DEBUG SECTION START*/
      
  
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
      
    --DECLARE @SelectionDate DATETIME = @InParamDate
    --DECLARE @SelectionDate DATE = GETDATE()-1 -- Går dagen pga nattlig jobb
	DECLARE @SelectionDate DATETIME = @InParamDate --Changed cause of wrong weekno when job is runed in other day manualy AM 20200131


    SELECT '@SelectionDate : ' + CAST(@SelectionDate AS VARCHAR(20))
  
    --Day er først for test, usikker på om de vil ha samme filnavn for hele uken.
    --SET @fileName =
    --  'OMS' +
    --  RIGHT('0' + CAST(DATEPART(year,@SelectionDate) AS VARCHAR),2) +
    --  RIGHT('0' + CAST(DATEPART(MONTH,@SelectionDate) AS VARCHAR),2) +
    --  RIGHT('0' + CAST(DATEPART(WEEK,@SelectionDate) AS VARCHAR),2) +
    --  RIGHT('0' + CAST(DATEPART(DAY,@SelectionDate) AS VARCHAR),2) +
    --  '_'+
    --  @InParamGln + '.csv'
    DECLARE @ProfilHus VARCHAR(10)
  
    SELECT @ProfilHus = DS.Lev2RegionGroupName FROM  BI_Mart.RBIM.Dim_Store AS DS WHERE DS.GlobalLocationNo=@InParamGln AND DS.IsCurrentStore=1
  
    SET @fileName =
        'OMS_' + @ProfilHus +'_'+
        --RIGHT('0' + CAST(DATEPART(year,GETDATE()) AS VARCHAR),4) +
        --RIGHT('0' + CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR),2) +
        ----RIGHT('0' + CAST(DATEPART(WEEK,GETDATE()) AS VARCHAR),2) +
        --RIGHT('0' + CAST(DATEPART(DAY,GETDATE()) AS VARCHAR),2) +
        --'_'+
        RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)+
        RIGHT('0' + CAST(DATEPART(iso_WEEK,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)+
        '_'+
        @InParamGln + '.csv'
  
          
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
    WHERE tdate.WeekNumberOfYear = DATEPART(WEEK,@InParamDate) AND tdate.Year = DATEPART(YEAR,@InParamDate) AND tdate.FullDate IS NOT NULL
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
                Dato = dbo.GetGenusVaresalgDatoValue(tdate.fulldate),
                AID_Kode = CASE
                        WHEN LEN(CAST(ISNULL(gtin.Gtin,0) AS VARCHAR)) > 6 THEN 'E'
                        WHEN LEN(CAST(ISNULL(gtin.Gtin,0) AS VARCHAR)) <= 6 THEN 'P'
                        ELSE ''
                    END ,
                gtin.Gtin as 'Nummer',
                sales.SalesRevenueInclVat AS 'Netto_omsetning',
                    Kostpris = case
                        when sales.PosNetPurchasePrice> 0
                        then sales.PosNetPurchasePrice
                        else sales.PurchasePrice
                    end,
                --Antall_Alternativ =  CASE
                --      WHEN article.UnitOfMeasureId = 'L'
                --      THEN sales.WeighedUnitOfMeasureAmount * article.UnitOfMeasurementAmount
                --      ELSE sales.WeighedUnitOfMeasureAmount
                --  END ,
                CASE
                    WHEN article.UnitOfMeasureId = 'L'          THEN sales.WeighedUnitOfMeasureAmount * article.UnitOfMeasurementAmount
                    WHEN article.ArticleTypeId IN (130,133)     THEN (  SELECT  COUNT(FRRSAR.RowIdx)  FROM BI_Mart.RBIM.Fact_ReceiptRowSalesAndReturn AS FRRSAR
                                                                        WHERE  FRRSAR.ArticleIdx = sales.ArticleIdx AND FRRSAR.StoreIdx = sales.StoreIdx AND FRRSAR.ReceiptDateIdx = sales.ReceiptDateIdx)
                ELSE sales.WeighedUnitOfMeasureAmount
                END AS Antall_Alternativ,
                /*sales.NumberOfCustomersPerSelectedArticle as 'Kunder',*/
                Kunder = case
                        when price.PriceTypeNo = @ArticleBundlePriceType then 0
                        else sales.NumberOfCustomersPerSelectedArticle
                    end,
                sales.SalesRevenueVat as 'Mva',
                sales.TotalGrossProfit as 'Rabatt',
                --supp.SupplierName as 'Leverandør',
                --supp.SupplierId as 'Leverandør',
                ISNULL(NULLIF(supp.SupplierId,-1),ds.SupplierId) as 'Leverandør',
                'N/A' as 'Grossist',
                article.Lev5ArticleHierarchyId as 'Varegruppe',
                ArtExtIn.Value_Department as 'Avdeling',
                --article.Lev2ArticleHierarchyId  as 'Avdeling',
                article.ArticleName as 'Vartek',
                sales.ReceiptDateIdx,
                sales.ArticleIdx,
                article.ArticleNo,
                sales.StoreIdx,
                --store.StoreNo,
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
                --LEFT JOIN BI_Mart.RBIM.Cov_SupplierArticle AS CSA ON CSA.ArticleIdx = sales.ArticleIdx  
				LEFT JOIN BI_Mart.RBIM.Cov_SupplierArticle AS CSA ON CSA.ArticleIdx = sales.ArticleIdx AND CSA.SupplierIdx = supp.SupplierIdx and CSA.IsPrimarySupplier=1
                LEFT JOIN BI_Mart.RBIM.Dim_Supplier AS DS ON DS.SupplierIdx = CSA.SupplierIdx
            WHERE
                tdate.WeekNumberOfYear = DATEPART(WEEK,@InParamDate) AND tdate.Year = DATEPART(YEAR,@InParamDate) AND tdate.FullDate IS NOT NULL
                AND sales.SalesPrice=sales.SalesAmount -- dvs normalpris
                AND store.GlobalLocationNo = @InParamGln
                and sales.ArticleIdx > 0
                and sales.PriceTypeIdx <> 19 -- ikke ta med overføring mellom butikk
        )
        , Tilbudslinjer as
        (
            SELECT
                'OVUT-RAW' as 'Rapport_Kode',
                store.GlobalLocationNo as 'Filial',
                Dato = dbo.GetGenusVaresalgDatoValue(tdate.fulldate),
                AID_Kode = CASE
                        WHEN LEN(CAST(ISNULL(gtin.Gtin,0) AS VARCHAR)) > 6 THEN 'E'
                        WHEN LEN(CAST(ISNULL(gtin.Gtin,0) AS VARCHAR)) <= 6 THEN 'P'
                        ELSE ''
                    END ,
                gtin.Gtin as 'Nummer',
                sales.SalesRevenueInclVat AS 'Netto_omsetning',
                Kostpris = case
                    when sales.PosNetPurchasePrice> 0
                    then sales.PosNetPurchasePrice
                    else sales.PurchasePrice
                end,
                --Antall_Alternativ =  CASE
                --      WHEN article.UnitOfMeasureId = 'L'
                --      THEN sales.WeighedUnitOfMeasureAmount * article.UnitOfMeasurementAmount
                --      ELSE sales.WeighedUnitOfMeasureAmount
                --  END ,
                CASE
                    WHEN article.UnitOfMeasureId = 'L'          THEN sales.WeighedUnitOfMeasureAmount * article.UnitOfMeasurementAmount
                    WHEN article.ArticleTypeId IN (130,133)     THEN (  SELECT  COUNT(FRRSAR.RowIdx)  FROM BI_Mart.RBIM.Fact_ReceiptRowSalesAndReturn AS FRRSAR
                                                                        WHERE  FRRSAR.ArticleIdx = sales.ArticleIdx AND FRRSAR.StoreIdx = sales.StoreIdx AND FRRSAR.ReceiptDateIdx = sales.ReceiptDateIdx)
                ELSE sales.WeighedUnitOfMeasureAmount
                END AS Antall_Alternativ,
                /*sales.NumberOfCustomersPerSelectedArticle as 'Kunder',*/
                Kunder = case
                        when price.PriceTypeNo = @ArticleBundlePriceType then 0
                        else sales.NumberOfCustomersPerSelectedArticle
                    end,
                sales.SalesRevenueVat as 'Mva',
                sales.TotalGrossProfit as 'Rabatt',
                --supp.SupplierName as 'Leverandør',
                --supp.SupplierId as 'Leverandør',
                ISNULL(NULLIF(supp.SupplierId,-1),ds.SupplierId) as 'Leverandør',
                'N/A' as 'Grossist',
                article.Lev5ArticleHierarchyId as 'Varegruppe',
                ArtExtIn.Value_Department as 'Avdeling',
                --article.Lev2ArticleHierarchyId  as 'Avdeling',
                article.ArticleName as 'Vartek',
                sales.ReceiptDateIdx,
                sales.ArticleIdx,
                article.ArticleNo,
                sales.StoreIdx,
                store.StoreId,
                --store.StoreNo,
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
                --LEFT JOIN BI_Mart.RBIM.Cov_SupplierArticle AS CSA ON CSA.ArticleIdx = sales.ArticleIdx
				LEFT JOIN BI_Mart.RBIM.Cov_SupplierArticle AS CSA ON CSA.ArticleIdx = sales.ArticleIdx AND CSA.SupplierIdx = supp.SupplierIdx and CSA.IsPrimarySupplier=1
                LEFT JOIN BI_Mart.RBIM.Dim_Supplier AS DS ON DS.SupplierIdx = CSA.SupplierIdx
            WHERE
                tdate.WeekNumberOfYear = DATEPART(WEEK,@InParamDate) AND tdate.Year = DATEPART(YEAR,@InParamDate) AND tdate.FullDate IS NOT NULL
                AND sales.SalesPrice<>sales.SalesAmount -- dvs tilbudspris
                --and (campaign.CampaignArticlePriceReductionIdx <> -1 or campaign.CampaignDiscountCombinationIdx <> -1)
                AND store.GlobalLocationNo = @InParamGln
                and sales.PriceTypeIdx <> 19 -- ikke ta med overføring mellom butikk
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
            --StoreNo,
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
            --StoreNo,
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
                sum(Kunder) as 'Kunder' ,
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
        /* DEBUGGING */
        /*
        --Alle salg
        SELECT
                sales.*
            FROM
                BI_Mart.RBIM.Agg_SalesAndReturnPerDay sales
                INNER JOIN BI_Mart.RBIM.Dim_Date tdate ON sales.ReceiptDateIdx = tdate.DateIdx
                INNER JOIN BI_Mart.rbim.Dim_Article article ON sales.ArticleIdx = article.ArticleIdx
                INNER JOIN BI_Mart.RBIM.Dim_Store store ON sales.StoreIdx = store.StoreIdx
                INNER JOIN BI_Mart.RBIM.Dim_Gtin gtin ON sales.GtinIdx = gtin.GtinIdx
                left join BI_Mart.RBIM.Out_ArticleExtraInfo ArtExtIn on ArtExtIn.ArticleExtraInfoIdx = article.ArticleIdx
            WHERE
                CAST(DATEADD(DAY , 7-DATEPART(WEEKDAY,tdate.FullDate),tdate.FullDate) AS DATE) = CAST(@SelectionDate AS DATE)
                and article.ArticleName like '%lettmelk%'
        --Tilbudslinjer
        select campaign.* from BI_Mart.RBIM.Agg_CampaignSalesPerHour campaign
        INNER JOIN BI_Mart.RBIM.Dim_Date cdate ON campaign.ReceiptDateIdx = cdate.DateIdx
        INNER JOIN BI_Mart.rbim.Dim_Article article ON campaign.ArticleIdx = article.ArticleIdx
        WHERE CAST(DATEADD(DAY , 7-DATEPART(WEEKDAY,cdate.FullDate),cdate.FullDate) AS DATE) = CAST(@SelectionDate AS DATE)                   
        and article.ArticleName like '%lettmelk%'
        */
END
  
  
  
  
  
  
  
  
  

GO

