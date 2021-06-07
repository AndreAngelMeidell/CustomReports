USE [VRNOMisc]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GensReportsFinancial]    Script Date: 07.02.2020 13:06:50 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

  
  
  
  
CREATE PROCEDURE [dbo].[usp_CBI_GensReportsFinancial]    (@storeId AS VARCHAR(100) = NULL)
AS BEGIN
    DECLARE @sqlStr VARCHAR(MAX)
    DECLARE @cmdStr VARCHAR(MAX)
    DECLARE @filePath VARCHAR(1000)
    DECLARE @fileName VARCHAR(1000)
    DECLARE @Server VARCHAR(100)
    DECLARE @LogonInfo VARCHAR(100)
    DECLARE @IsDebugOn INT
    DECLARE @StoreAuthIdOrStoreGroupNoJoker AS VARCHAR(100)
    DECLARE @StoreAuthIdOrStoreGroupNoSpar AS VARCHAR(100)
  
    SELECT @Server = sc.ServerIp,
        @LogonInfo = '-U ' + sc.UserId + ' -P ' + sc.WordPass,
        @filepath =  sc.RootPath,
        @IsDebugOn = sc.IsDebugOn FROM [ServerConfig] sc WHERE Environment LIKE @@SERVERNAME
      
    DECLARE @true AS INT = 1
    DECLARE @false AS INT = 0
    DECLARE @SubpathBase AS VARCHAR(20) = 'Kassererlogg\'
    DECLARE @SubPath  AS VARCHAR(40)
    SET @SubPath = 'Kassererlogg\KMH\'
    SET @StoreAuthIdOrStoreGroupNoJoker = CAST(dbo.GetStoreGroupRegionJOKER() AS CHAR)
    SET @StoreAuthIdOrStoreGroupNoSpar = CAST(dbo.GetStoreGroupRegionSPAR() AS CHAR)
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT '@Server :' + CAST(@Server AS CHAR)
        SELECT '@LogonInfo :' + CAST(@LogonInfo AS CHAR)
        SELECT '@filepath :' + CAST(@filepath AS CHAR)
        SELECT '@SubPath :' + CAST(@SubPath AS CHAR)
        select '@StoreAuthIdOrStoreGroupNoJoker :' + @StoreAuthIdOrStoreGroupNoJoker
        select '@StoreAuthIdOrStoreGroupNoSpar :' + @StoreAuthIdOrStoreGroupNoSpar
    END
    /*M:\Genus\Kassererlogg\KMH\Finanstall-KMH-uke_{UU}-{DDMMYYYY}.txt*/
    SET @fileName =
        'Finanstall-KMH-uke' +
         +
        '_' +
        RIGHT('0' + CAST(DATEPART(WEEK,GETDATE()) AS VARCHAR),2) +
        '_' +
        RIGHT('0' + CAST(DATEPART(DAY,GETDATE()) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR),4) +
        '.txt'
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT '@fileName :' + CAST(@fileName AS CHAR)
    END
    set @sqlStr  = 'select * from vrnomisc.dbo.usp_CBI_GensReportsFinancial_View'
    --  Export
    SET @cmdStr = 'bcp "' + @sqlStr + '" queryout "' + @filePath + @SubPath + @fileName + '" -c -C ACP ' + @LogonInfo + ' -S ' + @Server + ' -t "," -d BI_Mart'
    --EXEC xp_cmdshell @cmdStr
    DECLARE @nvcmdstr VARCHAR(8000) = CAST(@cmdStr AS VARCHAR(8000))
    --EXEC sp_executesql @nvcmdstr
    EXEC xp_cmdshell @nvcmdstr
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT '@cmdStr :' + CAST(@cmdStr AS VARCHAR(8000))
    END
END

GO

