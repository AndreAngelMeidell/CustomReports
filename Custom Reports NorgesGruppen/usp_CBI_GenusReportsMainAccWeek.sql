USE [VRNOMisc]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GenusReportsMainAccWeek]    Script Date: 07.02.2020 13:06:12 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

  
  
  
  
  
  
  
CREATE PROCEDURE [dbo].[usp_CBI_GenusReportsMainAccWeek]
(
    @InParamReportTypeId AS INT,
    @InParamChainCodeId AS INT,
    @InParamReportDate AS DATETIME,
    @InParamReportFromDate AS DATETIME = null,
    @InParamReportToDate AS DATETIME = null
)
AS
BEGIN
      
    -- 20190527 Opprettet av Andre Meidell
    -- Pga NG ønsker acc ukes fil, baset på pros med samme navn for dag.
  
	SET DATEFIRST 1 -- Sets First day of week to Monday 20200129
  
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
              
            --Sjekke om det er noe salg for uken for aktuell butikk
  
            DECLARE @count AS INT
              
            SELECT @count = COUNT(*)  FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay sales
                INNER JOIN BI_Mart.RBIM.Dim_Date tdate ON sales.ReceiptDateIdx = tdate.DateIdx
                INNER JOIN BI_Mart.RBIM.Dim_Store store ON sales.StoreIdx = store.StoreIdx
                WHERE tdate.WeekNumberOfYear = DATEPART(WEEK,@InParamReportDate) AND tdate.Year = DATEPART(YEAR,@InParamReportDate) AND tdate.FullDate IS NOT NULL
                --WHERE  tdate.FullDate >=@InParamReportDate
                AND store.GlobalLocationNo = @StoreGln
              
            IF @count>0
            BEGIN
  
                -- Week file
                --EXECUTE dbo.usp_CBI_GenusReportsSalesAccWeek
                --  @ReportTypeId = @InParamReportTypeId
                --  ,@ChainCodeId = @InParamChainCodeId
                --  ,@Date = @InParamReportDate
                --  ,@gln = @StoreGln
                --  ,@EnvironmentId = @EnvironmentId
                --  ,@LogonInfo = @LogonInfo
                --  ,@Server = @Server
                --  ,@FolderRootPart = @FolderRootPart
                --  ,@IsDebugOn = @IsDebugOn
                --  ,@LevChainGroupNo = @LevChainGroupNo
                --  ,@SubPath = @SubPath
                --  ,@InParamFromDate = @InParamReportFromDate
                --  ,@InParamToDate = @InParamReportToDate
  
                    EXECUTE dbo.usp_CBI_GenusReportsSalesAccWeek
                        @InParamReportTypeId = @InParamReportTypeId , -- int
                        @InParamChainCodeId = @InParamChainCodeId , -- int
                        @InParamDate = @InParamReportDate, -- datetime
                        @InParamGln = @StoreGln, -- varchar(256)
                        @EnvironmentId = @EnvironmentId, -- int
                        @LogonInfo = @LogonInfo, -- varchar(100)
                        @Server = @Server,
                        @FolderRootPart = @FolderRootPart,
                        @IsDebugOn = @IsDebugOn ,
                        @LevChainGroupNo = @LevChainGroupNo,
                        @SubPath = @SubPath ,
                        @InParamFromDate = @InParamReportFromDate,
                        @InParamToDate = @InParamReportToDate
                      
            END
        
            FETCH NEXT FROM Butikk_Cursor INTO @StoreGln
        END
        CLOSE Butikk_Cursor
        DEALLOCATE Butikk_Cursor
    END
  
      
      
END
  
  
  
  
  
  

GO

