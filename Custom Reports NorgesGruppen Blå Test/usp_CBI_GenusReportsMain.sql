USE [VRNOMisc]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GenusReportsMain]    Script Date: 17.11.2020 20:46:41 ******/
DROP PROCEDURE [dbo].[usp_CBI_GenusReportsMain]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GenusReportsMain]    Script Date: 17.11.2020 20:46:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

  
  
  
  
  
  
  
CREATE PROCEDURE [dbo].[usp_CBI_GenusReportsMain]
(
    @InParamReportTypeId AS INT,
    @InParamChainCodeId AS INT,
    @InParamReportDate AS DATETIME,
    @InParamReportFromDate AS DATETIME = null,
    @InParamReportToDate AS DATETIME = null
)
AS
BEGIN
      
    --Modified: AAM 20190423 change Lev2ChainGroupNo to Lev1ChainGroupExternalId 3 lines, and change the GetChainGropuNoMeny func. til ID
    --Modified: AAM 20190506 Change WHERE @InParamReportDate = tdate.FullDate   to   WHERE  tdate.FullDate >=@InParamReportDate
	--Modified: AAM 20201109 Chenging control from sales to stockadjustents
      
    --VARIABLER
    print 'd-@InParamReportFromDate : ' + cast(@InParamReportFromDate as varchar)
    DECLARE @LevChainGroupNo INT, @StoreGln VARCHAR(256), @ChainCodeName VARCHAR(50)
    DECLARE @IsDebugOn AS int, @IsPerChainStoreBased AS BIT, @True AS int = 1, @False AS int = 0, @EnvironmentId INT
    DECLARE @EmptyNumber INT = 0, @Statement AS NVARCHAR(500), @DateParam AS datetime = GETDATE()
    DECLARE @FolderRootPart VARCHAR(100), @LogonInfo VARCHAR(100), @Server VARCHAR(100), @SubPath VARCHAR(100)
      
    --Input values
    PRINT 'Input values'
    SELECT @InParamReportTypeId AS '@InParamReportTypeId '
    SELECT @InParamChainCodeId AS '@InParamChainCodeId '
    SELECT @InParamReportDate AS '@InParamReportDate '
  
    SELECT @ChainCodeName = ChainCodeName FROM dbo.ChainCodes WHERE ChainCodeId = @InParamChainCodeId
    --SELECT ChainCodeName FROM dbo.ChainCodes WHERE ChainCodeId = @InParamChainCodeId
    SELECT @ChainCodeName AS '@ChainCodeName '
  
    SELECT @IsDebugOn = IsDebugOn, @EnvironmentId = EnvironmentId, @LogonInfo = '-U ' + UserId + ' -P ' + WordPass, @Server = ServerIp, @FolderRootPart = RootPath
  
    FROM VRNOMisc.dbo.ServerConfig WHERE Environment LIKE @@servername
  
    SELECT @SubPath = Value
    FROM dbo.ChainConfig
    WHERE
        ChainCodeId = @InParamChainCodeId
        AND ReportTypeId = @InParamReportTypeId
        AND EnvironmentId = @EnvironmentId
        AND ValueId = 'SubPath'
    SELECT @SubPath AS '@SubPath'
    --Skal underliggende prosedyre kjøres for hver enkelt butikk i kjeden
      
    SELECT @IsPerChainStoreBased = IsPerChainStoreBased FROM dbo.ReportTypes WHERE ReportTypeId = @InParamReportTypeId
    SELECT @IsPerChainStoreBased AS '@IsPerChainStoreBased'
  
    --SELECT @InParamChainCodeId AS '@InParamChainCodeId '
    --SELECT @ChainCodeName AS '@ChainCodeName '
      
      
    /*SELECT DISTINCT @LevChainGroupNo =
        CASE
            WHEN NumOfChainLevels = 1 THEN Lev1ChainGroupNo
            WHEN NumOfChainLevels = 2 THEN Lev2ChainGroupNo
            WHEN NumOfChainLevels = 3 THEN Lev3ChainGroupNo
        END FROM
        BI_Mart.RBIM.Dim_Store WHERE CASE
            WHEN NumOfChainLevels = 1 THEN Lev1ChainGroupName
            WHEN NumOfChainLevels = 2 THEN Lev2ChainGroupName
            WHEN NumOfChainLevels = 3 THEN Lev3ChainGroupName
        END = @ChainCodeName
        */
  
  
        if @InParamChainCodeId = dbo.GetChainCodeIdJoker()
        begin
            select @LevChainGroupNo = dbo.GetChainGroupNoJoker()
        end
        else if @InParamChainCodeId = dbo.GetChainCodeIdKiwi()
        begin
            select @LevChainGroupNo = dbo.GetChainGroupNoKiwi()
        end
        else if @InParamChainCodeId = dbo.GetChainCodeIdMeny()
        begin
            select @LevChainGroupNo = dbo.GetChainGroupNoMeny()
        end
        else if @InParamChainCodeId = dbo.GetChainCodeIdSpar()
        begin
            select @LevChainGroupNo = dbo.GetChainGroupNoSpar()
        end
    SELECT @LevChainGroupNo AS '@LevChainGroupNo'
  
    IF(@IsPerChainStoreBased = @True)
    BEGIN
        --Contract check
        --SELECT @IsDebugOn
  
        DECLARE @a AS INT = NULL, @b AS INT =1, @nullers AS VARCHAR(100) =''
        IF(ISNULL(@ChainCodeName,'')='') BEGIN select @nullers = @nullers + '@ChainCodeName,' END
          
        IF(ISNULL(@IsDebugOn,'')='') BEGIN select @nullers = @nullers + '@IsDebugOn,' END
        IF(ISNULL(@EnvironmentId,'')='') BEGIN select @nullers = @nullers + '@EnvironmentId,' END
        IF(ISNULL(@LogonInfo,'')='') BEGIN select @nullers = @nullers + '@LogonInfo,' END
        IF(ISNULL(@Server,'')='') BEGIN select @nullers = @nullers + '@Server,' END
        IF(ISNULL(@FolderRootPart,'')='') BEGIN select @nullers = @nullers + '@FolderRootPart,' END
          
        IF(len(@nullers)>0)
        BEGIN
            DECLARE @StringVariable NVARCHAR(500);
            SET @StringVariable = N'ERROR in usp_CBI_GenusReportsMain(): Following variables is NULL : ' + @nullers;
            RAISERROR (@StringVariable, 12, -1, N'abcde');
        END
        SELECT @LevChainGroupNo AS 'main_levchaingroupno'
        DECLARE @DoExportSalesDataForThisGlnThisWeek AS INTEGER
        DECLARE Butikk_Cursor CURSOR FOR
        --DEBUG/TODO : slette top 2
        --SELECT TOP 2 GlobalLocationNo FROM BI_Mart.RBIM.Dim_Store WHERE Lev2ChainGroupNo = @LevChainGroupNo
          
        --SELECT 123456
  
        --SELECT DISTINCT GlobalLocationNo FROM BI_Mart.RBIM.Dim_Store WHERE Lev2ChainGroupNo = @LevChainGroupNo ORDER BY 1 asc
        SELECT DISTINCT GlobalLocationNo FROM BI_Mart.RBIM.Dim_Store WHERE Lev1ChainGroupExternalId = @LevChainGroupNo AND isCurrent = 1
        UNION
        SELECT DISTINCT GlobalLocationNo FROM BI_Mart.RBIM.Dim_Store WHERE Lev2ChainGroupExternalId = @LevChainGroupNo AND isCurrent = 1
        UNION
        SELECT DISTINCT GlobalLocationNo FROM BI_Mart.RBIM.Dim_Store WHERE Lev3ChainGroupExternalId = @LevChainGroupNo AND isCurrent = 1
  
        OPEN Butikk_Cursor
        FETCH NEXT FROM Butikk_Cursor INTO @StoreGln
        WHILE @@FETCH_STATUS = @EmptyNumber
        BEGIN
            --SELECT '@StoreGln : ' + CAST(@StoreGln AS VARCHAR)
  
  
            --SELECT @count =COUNT(*)  FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay sales
            --  INNER JOIN BI_Mart.RBIM.Dim_Date tdate ON sales.ReceiptDateIdx = tdate.DateIdx
            --  INNER JOIN BI_Mart.RBIM.Dim_Store store ON sales.StoreIdx = store.StoreIdx
            --WHERE CAST(DATEADD(DAY , 7-DATEPART(WEEKDAY,tdate.FullDate),tdate.FullDate) AS DATE) = CAST(@InParamReportDate AS DATE)
            --  AND store.GlobalLocationNo = @StoreGln
            --PRINT '@count: ' + CAST(@count AS VARCHAR(10)) + '(' + CAST(@StoreGln AS VARCHAR(10)) + ')' + '(' + CAST(@InParamReportDate AS VARCHAR(10)) + ')'
              
  
            -- PRINT @StoreGln
            --PRINT @InParamReportDate
              
              
            --SET DATEFIRST 1
            --SET @DoExportSalesDataForThisGlnThisWeek = dbo.DoExportSalesDataForThisGlnThisWeek(@StoreGln,@InParamReportDate)
            --DECLARE @SelectionDate DATETIME = DATEADD(DAY , 7-DATEPART(WEEKDAY,@InParamReportDate),@InParamReportDate);   --OMS{DDMM}{0-9}.{Butikknr}   eks: OMS01109.024
  
  
  
            DECLARE @count AS INT
            --DECLARE @ExsportDataForThisStoreThisDate AS INT
            --DECLARE @true AS INT = 1
            --DECLARE @false AS INT = 0
      
            SELECT @count = COUNT(*)  FROM BI_Mart.RBIM.Fact_StockAdjustment sales
                INNER JOIN BI_Mart.RBIM.Dim_Date tdate ON sales.AdjustmentDateIdx = tdate.DateIdx
                INNER JOIN BI_Mart.RBIM.Dim_Store store ON sales.StoreIdx = store.StoreIdx
            WHERE  tdate.FullDate >=@InParamReportDate
            AND store.GlobalLocationNo = @StoreGln
              
            IF @count>0
            BEGIN
                --SET @ExsportDataForThisStoreThisDate = @true
                PRINT 'Data for this period, do export'
  
                --PRINT 'Containdata : ' + CAST(@DoExportSalesDataForThisGlnThisWeek AS VARCHAR)
                --PRINT 'Pre execute proc 0'
                --PRINT 'Pre execute proc 1'
                SELECT @statement = RepTyp.ReportStoredProcedure + ' @ReportTypeId, @ChainCodeId , @Date, @GLN, @EnvironmentId, @LogonInfo, @Server, @FolderRootPart, @IsDebugOn, @LevChainGroupNo, @SubPath, @InParamFromDate, @InParamToDate' FROM VRNOMisc.dbo.ReportTypes RepTyp WHERE RepTyp.ReportTypeId =  @InParamReportTypeId
                --print @statement
                --PRINT 'Pre execute proc 2'
                --PRINT 'd-Pre execute proc 2' + cast(@InParamReportFromDate as char)
                EXEC sp_executesql
                    @statement
                    ,N'@ReportTypeId INT, @ChainCodeId INT,@Date DATETIME, @gln VARCHAR(256), @EnvironmentId INT, @LogonInfo VARCHAR(100), @Server VARCHAR(100), @FolderRootPart VARCHAR(100), @IsDebugOn int, @LevChainGroupNo int,@SubPath VARCHAR(100), @InParamFromDate datetime, @InParamToDate datetime'
                    ,@ReportTypeId = @InParamReportTypeId
                    ,@ChainCodeId = @InParamChainCodeId
                    ,@Date = @InParamReportDate
                    ,@gln = @StoreGln
                    ,@EnvironmentId = @EnvironmentId
                    ,@LogonInfo = @LogonInfo
                    ,@Server = @Server
                    ,@FolderRootPart = @FolderRootPart
                    ,@IsDebugOn = @IsDebugOn
                    ,@LevChainGroupNo = @LevChainGroupNo
                    ,@SubPath = @SubPath
                    ,@InParamFromDate = @InParamReportFromDate
                    ,@InParamToDate = @InParamReportToDate
  
            END
  
            --ELSE
            --BEGIN
            --  --SET @ExsportDataForThisStoreThisDate = @false
            --  --SELECT 1+1
            --  PRINT 'No Data for this period, do not export'
            --END
              
        
            FETCH NEXT FROM Butikk_Cursor INTO @StoreGln
        END
        CLOSE Butikk_Cursor
        DEALLOCATE Butikk_Cursor
    END
  
    IF(@InParamReportTypeId = dbo.GetReportTypeDownPricing())
    BEGIN
  
        DECLARE @Today AS DATETIME = GETDATE()
  
  
        DECLARE @TodayMinusSeven AS DATETIME = GETDATE()-7
  
        EXEC usp_CBI_GenusReportDownPricingDiscount
            @InParamReportTypeId
            ,@InParamChainCodeId
            ,@InParamReportDate
            ,@EnvironmentId
            ,@LogonInfo
            ,@Server
            ,@FolderRootPart
            ,@IsDebugOn
            ,@LevChainGroupNo
            ,@SubPath
            ,@Today
            ,@TodayMinusSeven
  
    END
      
END
  
  
  
  
  
  

GO

