USE [VRNOMisc]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GenusReportDownPricingDiscountKiwi]    Script Date: 04.06.2020 13:34:23 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


  
  
--
--  Name:           usp_CBI_ExportDownPricingDiscountToGENUS
--
--  Description:    Export Downpricingdiscounts to Genus DWH
--    
--                  Bakgrunn:     
--                      "Det er snakk om en SuperStat-rapport som skrives til fil.
--                      Jobben kjøres en gang pr uke, av KMH og Meny. Utvalget som brukes er alle butikker og rabattype 3629 (Nedprisingrabatt).
--                      Filen er en txt-fil (se vedlagt). Det er viktig at filnavnet på filen får formatet som eksempelet vedlagt.
--                      Datostempelet på filnavnet = created date.
--                      Feltene i filen er henholdsvis dato, GTIN, varetekst, innverdi, antall, rabattbeløp, utverdi, mva, GLN.)"
--                
--  Requirements:   xp_cmdshell must be enabled
--                  EXEC sp_configure 'show advanced options', 1
--                  RECONFIGURE
--                  EXEC sp_configure 'xp_cmdshell', 1
--                  RECONFIGURE
--
--  Uses:         
--
--  ToDo:           Hardcoded path, server address and userinfo must be changed according to production settings
--
--  Date:           2015-10-13
--
--  By:             D. Molde, Visma Retail
--
--  Modifications:  20190311 Andre Meidell AND (f.WeighedSalesAmount)<>0
--                
--                
--
CREATE PROCEDURE [dbo].[usp_CBI_GenusReportDownPricingDiscountKiwi]
(
    --@InParamReportTypeId AS INT
    --,@InParamChainCodeId AS INT
    --@InParamDate AS DATETIME
    --,@InParamGln VARCHAR(256)
    --,@EnvironmentId INT
    --,@LogonInfo VARCHAR(100)
    --,@Server VARCHAR(100)
    --,@FolderRootPart VARCHAR(100)
    --,@IsDebugOn BIT
    --,@LevChainGroupNo INT
    --,@SubPath VARCHAR(100)
    --@StoreAuthIdOrStoreGroupNo AS VARCHAR(100),
    @DateTo AS DATETIME = NULL
    ,@DateFrom AS DATETIME = NULL
)
AS
BEGIN
  
    DECLARE @sqlStr VARCHAR(4000)
    DECLARE @cmdStr VARCHAR(4000)
    DECLARE @filePathName VARCHAR(1000)
    DECLARE @fileName VARCHAR(1000)
    DECLARE @groupName VARCHAR(50) = 'Kiwi'
    DECLARE @Folder VARCHAR(100)
    DECLARE @DateFromIdx INT
    DECLARE @DateToIdx INT
    declare @DebugMode INT
      
    DECLARE @ServerIp VARCHAR(100)
    DECLARE @LogonInfo VARCHAR(100)
  
    SELECT top 1 @LogonInfo = '-U ' + UserId + ' -P ' + WordPass, @ServerIp = ServerIp from ServerConfig where Environment = @@SERVERNAME
    SELECT @DebugMode = DebugMode, @Folder = folder from ReportDownPricingConfig where EnvironmentId = @@SERVERNAME and GroupName = @groupName
    if NOT SUBSTRING(rtrim(@Folder),DATALENGTH( rtrim(@Folder)),1) ='\'
    BEGIN
        SELECT @Folder = @Folder + '\'
    END
  
    SET @filePathName = @Folder +
        'Nedprising' +
        upper(@groupName) +
        '_' +
        RIGHT('0' + CAST(DATEPART(DAY,GETDATE()) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(SECOND,GETDATE()) AS VARCHAR),2) +
        '.txt'
    IF(@DebugMode=1)
    BEGIN
        SELECT '@DebugMode: ' + cast(@DebugMode as varchar)
        SELECT '@filePathName: ' + @filePathName
        SELECT '@LogonInfo: ' + @LogonInfo
    END
      
    SELECT 3
    SELECT @DateFromIdx = MIN(DateIdx), @DateToIdx = MAX(DateIdx) FROM BI_Mart.RBIM.Dim_Date WHERE FullDate BETWEEN @DateFrom AND @DateTo
    SELECT @DateFromIdx
    SET @sqlStr = '
        SELECT
            CONVERT(VARCHAR(10),dd.FullDate,104),
            gt.Gtin,
            da.ArticleName,
            REPLACE(CAST(CAST(SUM(f.NetPurchasePrice/f.WeighedSalesAmount) AS DECIMAL(20,2)) * f.WeighedSalesAmount AS VARCHAR),''.'','',''),
            /*REPLACE(CAST(CAST(SUM(f.NumberOfArticlesSold) AS DECIMAL(20,2)) AS VARCHAR),''.'','',''),*/
            REPLACE(CAST(CAST(SUM(f.WeighedSalesAmount) AS DECIMAL(20,2)) AS VARCHAR),''.'','',''),
            CASE WHEN E.PriceTypeNo = 5 AND E.IsArtsPriceType = 1  THEN REPLACE(CAST(CAST(SUM(f.discountamount) AS DECIMAL(20,2)) AS VARCHAR),''.'','','')
            ELSE
            REPLACE(CAST(CAST(0 AS DECIMAL(20,2)) AS VARCHAR),''.'','','')
            END,
            /*REPLACE(CAST(CAST(SUM(f.SalesAmount) AS DECIMAL(20,2)) AS VARCHAR),''.'','',''),*/
            REPLACE(CAST(CAST(SUM(f.SalesAmountExclVat) AS DECIMAL(20,2)) AS VARCHAR),''.'','',''),
              
            /*REPLACE(CAST(CAST(SUM((f.SalesAmount/100) *(f.SalesVatAmount/f.SalesAmountExclVat*100)) AS DECIMAL(20,2)) AS VARCHAR),''.'','',''),*/
            REPLACE(CAST(CAST(SUM(f.SalesVatAmount) AS DECIMAL(20,2)) AS VARCHAR),''.'','',''),
            ds.GlobalLocationNo
        from
            BI_Mart.RBIM.Agg_SalesAndReturnPerDay f with (nolock)
            JOIN BI_Mart.rbim.Dim_Date dd with (nolock) on dd.DateIdx = f.ReceiptDateIdx
            join BI_Mart.RBIM.Dim_Article da with (nolock) on da.ArticleIdx = f.ArticleIdx
            join BI_Mart.RBIM.Dim_Store ds with (nolock) on ds.storeidx = f.storeidx
            join BI_Mart.RBIM.Dim_PriceType AS E with (nolock) ON f.PriceTypeIdx = E.PriceTypeIdx
            JOIN BI_Mart.RBIM.Dim_Customer c with (nolock) on c.customeridx = f.customeridx
            JOIN BI_Mart.RBIM.Dim_Gtin gt with (nolock) ON f.GtinIdx = gt.GtinIdx
        Where
            (
                ' + CAST(dbo.GetChainGroupNokiwi() AS varchar) + ' in (
                Lev2RegionGroupExternalId,ds.Lev1chainGroupNo,ds.Lev2chainGroupNo,ds.Lev3chainGroupNo,ds.Lev4chainGroupNo,
                ds.Lev1RegionGroupNo,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,
                ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,
                ds.AuthorizationRegionGroupId,ds.AuthorizationLegalGroupId)
                OR
                ds.StoreIdx < 0
            )
            and dd.dateidx between ' + CAST(ISNULL(@DateFromIdx,'') AS varchar) + ' and ' + CAST(@DateToIdx AS varchar) + '
            and da.ArticleIdx > -1         
            and ds.isCurrentStore = 1 
            and E.PriceTypeNo = 5 
            AND (f.WeighedSalesAmount)<>0
        group by
            da.ArticleName, E.PriceTypeNo, E.IsArtsPriceType, gt.gtin, ds.GlobalLocationNo, dd.FullDate, f.WeighedSalesAmount
    '
  
    PRINT @sqlStr
    SELECT @sqlStr
    SET @sqlStr = REPLACE(@sqlStr,CHAR(10),' ')
    SET @sqlStr = REPLACE(@sqlStr,CHAR(13),' ')
  
    --  Export
      
    SET @cmdStr = 'bcp "' + @sqlStr + '" queryout "' + @filePathName + '" -c -CACP -T ' + @LogonInfo + ' -S ' + @ServerIp + ' -d VRNOMisc'
    EXEC xp_cmdshell @cmdStr
    SELECT @filePathName
    SELECT @sqlStr
    PRINT @cmdStr
  
END           
  
  
  
  
  
  
  
  
  
  
  
  
  
  

GO

