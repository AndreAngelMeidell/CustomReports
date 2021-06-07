USE [VRNOMisc]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GenusReportsMain]    Script Date: 24.11.2020 17:50:29 ******/
DROP PROCEDURE [dbo].[usp_CBI_GenusReportsMain]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GenusReportsMain]    Script Date: 24.11.2020 17:50:29 ******/
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
    --Modified: AAM 20201017 Date in controll of existing data for export and some cleaning of code
	
	  
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
 
        SELECT DISTINCT GlobalLocationNo FROM BI_Mart.RBIM.Dim_Store WHERE Lev1ChainGroupExternalId = @LevChainGroupNo AND isCurrent = 1
        UNION
        SELECT DISTINCT GlobalLocationNo FROM BI_Mart.RBIM.Dim_Store WHERE Lev2ChainGroupExternalId = @LevChainGroupNo AND isCurrent = 1
        UNION
        SELECT DISTINCT GlobalLocationNo FROM BI_Mart.RBIM.Dim_Store WHERE Lev3ChainGroupExternalId = @LevChainGroupNo AND isCurrent = 1
  
        OPEN Butikk_Cursor
        FETCH NEXT FROM Butikk_Cursor INTO @StoreGln
        WHILE @@FETCH_STATUS = @EmptyNumber
        BEGIN
 
            DECLARE @count AS INT
			
			--New with between control and from stockadjustment not sales 
            SELECT @count = COUNT(*)  FROM BI_Mart.RBIM.Fact_StockAdjustment sales
                INNER JOIN BI_Mart.RBIM.Dim_Date tdate ON sales.AdjustmentDateIdx = tdate.DateIdx
                INNER JOIN BI_Mart.RBIM.Dim_Store store ON sales.StoreIdx = store.StoreIdx
            WHERE  tdate.FullDate BETWEEN @InParamReportFromDate AND @InParamReportToDate
            AND store.GlobalLocationNo = @StoreGln
              
            IF @count>0
            BEGIN
                --SET @ExsportDataForThisStoreThisDate = @true
                PRINT 'Data for this period, do export'
  
                SELECT @statement = RepTyp.ReportStoredProcedure + ' @ReportTypeId, @ChainCodeId , @Date, @GLN, @EnvironmentId, @LogonInfo, @Server, @FolderRootPart, @IsDebugOn, @LevChainGroupNo, @SubPath, @InParamFromDate, @InParamToDate' FROM VRNOMisc.dbo.ReportTypes RepTyp WHERE RepTyp.ReportTypeId =  @InParamReportTypeId

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

