USE [VRNOMisc]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GenusReportsWastageAndReturn]    Script Date: 12.11.2020 13:46:11 ******/
DROP PROCEDURE [dbo].[usp_CBI_GenusReportsWastageAndReturn]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_GenusReportsWastageAndReturn]    Script Date: 12.11.2020 13:46:11 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

  
  
CREATE PROCEDURE [dbo].[usp_CBI_GenusReportsWastageAndReturn]
(
    --@ReportTypeName AS VARCHAR(20),
    --@ChainCodeName AS VARCHAR(20),
    --@Date AS DATETIME,
    --@gln VARCHAR(256)
    --@DateFrom AS DATETIME,
    --@DateTo AS DATETIME
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
  
  
-- Endringer : Andre 20190506 --for ekstra test filer og dropper sub i denne
-- Denne økes til 5 : DECLARE @StoreId AS VARCHAR(4)
-- endres @StoreId = RIGHT('0' + CAST(StoreId AS VARCHAR),4)     til @StoreId =  StoreId --RIGHT('0' + CAST(StoreId AS VARCHAR),4)
-- Andre 20190510 VD-2171 Reason code 19 - store transfer, should not be part of wastage.  AND rc.ReasonCodeIdx<>36
-- Andre 20190524           CAST(COALESCE(REPLACE(CAST(CAST(r.AdjustmentNetSalesAmountExclVat AS DECIMAL(18,2)) AS VARCHAR(20)), ''.'', '',''),''0,00'') AS VARCHAR(22)),
-- Andre 20190524           CAST(COALESCE(REPLACE(CAST(CAST(r.AdjustmentVatAmount AS DECIMAL(18,2)) AS VARCHAR(20)), ''.'', '',''),''0,00'') AS VARCHAR(22)),
  
-- Andre 20200330 Bytter cast(REPLACE(CAST(CAST(r.AdjustmentNetCostAmount AS DECIMAL(18,2)) AS VARCHAR(20)), ''.'', '','') as varchar(22)),
-- med: cast(REPLACE(CAST(CAST(r.AdjustmentNetPurchasePrice*r.AdjustmentQuantity AS DECIMAL(18,2)) AS VARCHAR(20)), ''.'', '','') as varchar(22)),
-- Endringer 20200603 Endrer format i utleggsfil fra to spacer til tab: fra: '" -c -CACP -t" " ' til:'" -c -CACP -T '

-- Andre 20201109 Endring THEN '''' else '''' END + REPLACE(CAST(CAST(r.AdjustmentQuantity AS DECIMAL(18,2)) AS VARCHAR(20)), ''.'', '','') as varchar(22)),
-- til: THEN ''-'' else '''' END + REPLACE(CAST(CAST(r.AdjustmentQuantity AS DECIMAL(18,2)) AS VARCHAR(20)), ''.'', '','') as varchar(22)),
-- minus manger i spørringen

--Andre 20201109 endrer NGVRSDBCIMST01P til NGVRSDBTEST01U
  
    SET DATEFIRST 1
    DECLARE @sql AS VARCHAR(4000)
    DECLARE @sqlStr VARCHAR(4000)
    DECLARE @cmdStr VARCHAR(4000)
    DECLARE @fileName VARCHAR(1000)
    DECLARE @DateFromIdx INT
    DECLARE @DateToIdx INT
    --DECLARE @StoreNo AS VARCHAR(4)
    DECLARE @StoreId AS VARCHAR(5)
    DECLARE @StoreIdSearch AS VARCHAR(6)
    DECLARE @true AS INT = 1
    DECLARE @false AS INT = 0
    DECLARE @groupName VARCHAR(50)
    --DECLARE @DateFrom AS VARCHAR(10) = CONVERT(VARCHAR,DATEADD(DAY , 1-DATEPART(WEEKDAY,@InParamDate),@InParamDate),112);
    --DECLARE @DateTo AS VARCHAR(10) = CONVERT(VARCHAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@InParamDate),@InParamDate),112);
    DECLARE @DateFrom AS VARCHAR(10) = CONVERT(VARCHAR,DATEADD(DAY , 1-DATEPART(WEEKDAY,@InParamFromDate),@InParamFromDate),112);
    DECLARE @DateTo AS VARCHAR(10) = CONVERT(VARCHAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@InParamToDate),@InParamToDate),112);
  
  
    print '@InParamFromDate : '+cast(@InParamFromDate as varchar)
  
    print '@@InParamToDate : '+cast(@InParamToDate as varchar)
    print '@DateTo : '+@DateTo
    print 'd-@DateFrom : ' +cast(@DateFrom as varchar)
    if  not isnull(@InParamFromDate,'')=''
    begin
        set @DateFrom = convert(varchar,@InParamFromDate,112)
        select @DateFrom as '@DateFrom'
        print '@InParamFromDate != null'
          
    end
    else
    begin
        --select 'null' as '@DateFrom'
        print 'NOT @InParamFromDate != null'
    end
  
  
    print 'd-@DateFrom : ' +cast(@DateFrom as varchar)
  
    if not isnull(@InParamToDate ,'')=''
    begin
        --set @DateTo = convert(varchar,@InParamToDate,112)
        --set @DateTo = @InParamToDate
        select @DateTo as '@DateTo'
    end
  
  
    DECLARE @SubpathBase AS VARCHAR(20) = 'Nedprisning\'
    --DECLARE @SubPath  AS VARCHAR(40)
    --SELECT @groupName = StoreGroupName FROM BI_Mart.RSCC.StoreGroups WHERE StoreGroupTypeName = 'region' AND StoreGroupNo = @StoreAuthIdOrStoreGroupNo
      
    --IF(@IsDebugOn=@true)
    --BEGIN
    --  SELECT '@groupName(raw) :' + CAST(@groupName AS CHAR)
    --END
  
      
      
    --IF @groupName ='Kjøpmannshuset Norge AS'
    --BEGIN
    --  SET  @groupName ='KMH'
          
    --END
    --ELSE IF @groupName = 'MENY'
    --BEGIN
    --  SET @groupName = 'MENY'
    --END
    --ELSE IF @groupName = 'KIWI'
    --BEGIN
    --  SET @groupName = 'KIWI'
    --END
    --ELSE
    --BEGIN
    --  SET @groupName = 'UNKNOWN'
    --END
    --SET @SubPath = @SubpathBase + @groupName + '\'
  
  
  
    SELECT DISTINCT TOP 1
    --@StoreNo = RIGHT('0' + CAST(StoreNo AS VARCHAR),4)    ,
    @StoreId =  StoreId --RIGHT('0' + CAST(StoreId AS VARCHAR),4) 
    ,@StoreIdSearch = CAST(StoreId AS VARCHAR)
    FROM BI_Mart.RBIM.Dim_Store WHERE   GlobalLocationNo = @InParamGln AND isCurrent=1
      
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT '[usp_CBI_GenusReportsWastageAndReturn]DebugInfo:Start'
        SELECT '@InParamReportTypeId :' + CAST(ISNULL(@InParamReportTypeId,'') AS CHAR)
        SELECT '@InParamChainCodeId :' + CAST(ISNULL(@InParamChainCodeId,'') AS CHAR)
        SELECT '@InParamDate :' + CAST(ISNULL(@InParamDate,'') AS CHAR)
        SELECT '@InParamGln :' + CAST(ISNULL(@InParamGln,'') AS CHAR)
        SELECT '@EnvironmentId :' + CAST(ISNULL(@EnvironmentId,'') AS CHAR)
        SELECT '@LogonInfo :' + CAST(ISNULL(@LogonInfo,'') AS CHAR)
        SELECT '@Server :' + CAST(ISNULL(@Server,'') AS CHAR)
        SELECT '@FolderRootPart :' + CAST(ISNULL(@FolderRootPart,'') AS CHAR)
        SELECT '@IsDebugOn :' + CAST(ISNULL(@IsDebugOn,'') AS CHAR)
        SELECT '@LevChainGroupNo :' + CAST(ISNULL(@LevChainGroupNo,'') AS CHAR)
        SELECT '@SubPath :' + CAST(ISNULL(@SubPath,'') AS CHAR)
        SELECT '@StoreIdSearch :' + CAST(ISNULL(@StoreIdSearch,'') AS CHAR)
        --SELECT '@StoreNo :' + CAST(ISNULL(@StoreNo,'') AS CHAR)     
  
        SELECT '[usp_CBI_GenusReportsWastageAndReturn]DebugInfo:End'
    END
      
    /*Svinn_{Butikknr}_{eanlok}_{ DDMMYYhhmmss }.txt     */
    SET @fileName =
            'Svinn_' +
            --RIGHT('0' + CAST(DATEPART(DAY,GETDATE()) AS VARCHAR),2) +
            --RIGHT('0' + CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR),2) +
            --TODO: disse skal bytte plass
            --RIGHT('0' + CAST(DATEPART(MONTH,@SelectionDate) AS VARCHAR),2) +
            --RIGHT('0' + CAST(DATEPART(DAY,@SelectionDate) AS VARCHAR),2) +
            --@storeno,1) +
            --@StoreNo+
            @StoreId+
            '_'+
            @InParamGln+
            '_' +
            --RIGHT(@StoreNo,3)
            --@Filepart +
            --'_' +
            --@butikkGLN +
            --'_' +
            RIGHT('0' + CAST(DATEPART(DAY,GETDATE()) AS VARCHAR),2) +
            RIGHT('0' + CAST(DATEPART(MONTH,GETDATE()) AS VARCHAR),2) +
            RIGHT('0' + CAST(DATEPART(YEAR,GETDATE()) AS VARCHAR),2) +
            RIGHT('0' + CAST(DATEPART(HOUR,GETDATE()) AS VARCHAR),2) +
            RIGHT('0' + CAST(DATEPART(MINUTE,GETDATE()) AS VARCHAR),2) +
            RIGHT('0' + CAST(DATEPART(SECOND,GETDATE()) AS VARCHAR),2) +
            '.txt'
      
  
  
  
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT '@fileName :' + CAST(ISNULL(@fileName,'') AS CHAR)
    END
  
    SELECT @sqlStr = '
SET NOCOUNT ON;
SELECT
gtin.Gtin,
CONVERT(VARCHAR(20), d.FullDate, 104) + '' '' + t.Hour + '':'' + t.Minute + '':'' + ''00'',
cast(REPLACE(CAST(CAST(r.AdjustmentNetPurchasePrice*r.AdjustmentQuantity AS DECIMAL(18,2)) AS VARCHAR(20)), ''.'', '','') as varchar(22)),
cast(CASE WHEN (r.AdjustmentSign = -1) 
				THEN ''-'' else '''' END + REPLACE(CAST(CAST(r.AdjustmentQuantity AS DECIMAL(18,2)) AS VARCHAR(20)), ''.'', '','') as varchar(22)),
COALESCE( CAST(wat.reasonCodeNo AS VARCHAR(20)),  
CASE WHEN st2.GlobalLocationNo  IS NOT NULL
THEN
(case when
st.lev1legalgroupno = st2.Lev1LegalGroupNo and
st.lev2legalgroupno = st2.Lev2LegalGroupNo and
st.lev3legalgroupno = st2.Lev3LegalGroupNo and
st.lev4legalgroupno = st2.Lev4LegalGroupNo and
st.lev5legalgroupno = st2.Lev5LegalGroupNo
then 23 else 19 end)
ELSE (CASE rc.ReasonNo WHEN -4 THEN '''' ELSE CAST(rc.ReasonNo AS VARCHAR(20)) END) END),
CAST(nullif(CAST(wat.ToDepartment AS varchar(20)),'''') AS VARCHAR(22)),
CAST(nullif(case when not isnull(st3.GlobalLocationNo,'''')=''''  then st3.GlobalLocationNo  else st2.GlobalLocationNo end,'''') AS VARCHAR(22)),
CAST(COALESCE(REPLACE(CAST(CAST(r.StockSalesPriceExclVat  * r.AdjustmentQuantity AS DECIMAL(18,2)) AS VARCHAR(20)), ''.'', '',''),''0,00'') AS VARCHAR(22)),
CAST(COALESCE(REPLACE(CAST(CAST((r.StockSalesPrice -r.StockSalesPriceExclVat) * r.AdjustmentQuantity AS DECIMAL(18,2)) AS VARCHAR(20)), ''.'', '',''),''0,00'') AS VARCHAR(22)),
CAST(st.GlobalLocationNo AS VARCHAR(22))
FROM [BI_Mart].RBIM.Fact_StockAdjustment r (NOLOCK)
INNER JOIN [BI_Mart].RBIM.Dim_Gtin gtin (NOLOCK) ON gtin.GtinIdx=r.GtinIdx AND gtin.isCurrent=1
INNER JOIN [BI_Mart].RBIM.Dim_Time t (NOLOCK) ON t.TimeIdx=r.AdjustmentTimeIdx
INNER JOIN [BI_Mart].RBIM.Dim_Date d (NOLOCK) ON d.DateIdx=r.AdjustmentDateIdx
INNER JOIN [BI_Mart].RBIM.Dim_ReasonCode rc (NOLOCK) ON rc.ReasonCodeIdx=r.ReasonCodeIdx
INNER JOIN [BI_Mart].RBIM.Dim_Store st (NOLOCK) ON st.StoreIdx=r.StoreIdx
INNER JOIN  [BI_Mart].RBIM.Dim_StockCount sc (NOLOCK) ON sc.StockCountIdx=r.StockcountIdx
INNER JOIN[BI_Mart].RBIM.Dim_StockAdjustmentType sat (NOLOCK) ON sat.StockAdjustmentTypeIdx=r.StockAdjustmentTypeIdx
LEFT JOIN [NGVRSDBTEST01U].VBDCM.dbo.WorkAreaTransfers wat (NOLOCK)  ON wat.WorkAreaTransferNo=sc.StockCountNo AND sat.StockAdjustmentTypeNo IN (79)
LEFT JOIN [BI_Mart].RBIM.Dim_ReasonCode rc2 (NOLOCK) ON rc2.ReasonNo=wat.ReasonCodeNo
LEFT JOIN [NGVRSDBTEST01U].VBDCM.dbo.Deliveries del (NOLOCK) ON del.DeliveryNoteNo=sc.StockCountNo AND sat.StockAdjustmentTypeNo IN (3)
LEFT JOIN [BI_Mart].RBIM.Dim_Store st2 (NOLOCK) ON st2.StoreId=del.StoreNo AND st2.isCurrent = 1
LEFT JOIN [BI_Mart].RBIM.Dim_Store st3 (NOLOCK) ON st3.StoreId=wat.Storeno AND st3.isCurrent = 1
WHERE d.FullDate BETWEEN cast(''' + @DateFrom + ''' as datetime) AND cast(''' + @DateTo + ''' AS datetime)' +
' AND (rc.ReasonNo > 0 OR wat.WorkAreaTransferNo IS NOT NULL OR del.DeliveryNoteNo IS NOT NULL)
AND rc.ReasonCodeIdx<>36
AND st.Storeid = ' + @StoreIdSearch
  
  
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT '@sqlStr :' + CAST(@sqlStr AS VARCHAR(4000))
    END
    print @sqlStr
    SET @sqlStr = REPLACE(@sqlStr,CHAR(10),' ')
    SET @sqlStr = REPLACE(@sqlStr,CHAR(13),' ')
  
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT '@sqlStr :' + CAST(@sqlStr AS VARCHAR(4000))
    END
      
  
  
						--OLD SET @cmdStr = 'bcp "' + @sqlStr + '" queryout "' + @FolderRootPart + @SubPath + @fileName + '" -c -CACP -t" " ' + @LogonInfo + ' -S ' + @Server + ' -d VRNOMisc'
	SET @cmdStr = 'bcp "' + @sqlStr + '" queryout "' + @FolderRootPart + @SubPath + @fileName + '" -c -CACP -T ' + @LogonInfo + ' -S ' + @Server + ' -d VRNOMisc'
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT '@cmdStr :' + CAST(ISNULL(@cmdStr,'') AS VARCHAR(4000))
    END
    print @cmdStr
    EXEC xp_cmdshell @cmdStr
  
  
    --for ekstra test filer dropper sub
    SET @FolderRootPart='D:\genusFTP\backup\Waste\'
    SET @cmdStr = 'bcp "' + @sqlStr + '" queryout "' + @FolderRootPart  + @fileName + '" -c -CACP -T '  + @LogonInfo + ' -S ' + @Server + ' -d VRNOMisc'
    IF(@IsDebugOn=@true)
    BEGIN
        SELECT '@cmdStr :' + CAST(ISNULL(@cmdStr,'') AS VARCHAR(4000))
    END
    print @cmdStr
    EXEC xp_cmdshell @cmdStr
  
  
    --slutt
  
END
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  

GO

