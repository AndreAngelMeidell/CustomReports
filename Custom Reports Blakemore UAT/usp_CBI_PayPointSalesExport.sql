USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_PayPointSalesExport]    Script Date: 13.11.2020 08:41:01 ******/
DROP PROCEDURE [dbo].[usp_CBI_PayPointSalesExport]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_PayPointSalesExport]    Script Date: 13.11.2020 08:41:01 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_PayPointSalesExport]

AS  
BEGIN

--By Andre Angel Meidell 20191126
--This has to be on, its on for Production

--EXEC sp_configure 'show advanced options', 1
--RECONFIGURE
--EXEC sp_configure 'xp_cmdshell', 1
--RECONFIGURE


DECLARE @Sqlstr AS VARCHAR(4000)
DECLARE @CmdStr AS VARCHAR(4000)
DECLARE @File AS VARCHAR(4000)
DECLARE @Date AS VARCHAR(20)

SET @Date = (SELECT dd.DateIdx FROM RBIM.Dim_Date AS dd WHERE dd.RelativeDay=0)
--SET @File = 'C:\Visma Retail\Data\PayPointTemp\PayPoint_'+@Date+'.csv'

SET NOCOUNT ON

SET @Sqlstr = '
SELECT  
ds.StoreId,fr.ReceiptDateIdx, dt.TimeDescription AS TimeDescription
,RSI.SchemeId,RSI.PayPointTransactionId,RSI.ShortDescription,fr.Amount AS Value
,CASE WHEN fr.Amount<>0  THEN ''Success'' ELSE ''Failure'' END AS Status 
FROM [BI_Stage].[RBIS].[sArtsXmlReceiptSaleitemRow1] RSI 
JOIN BI_Mart.RBIM.Fact_Receipt AS fr ON RSI.sArtsXmlReceiptHeadIdx+RSI.RowNumber=fr.ReceiptIdx 
JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = fr.StoreIdx 
JOIN RBIM.Dim_Date AS dd ON dd.DateIdx=fr.ReceiptDateIdx 
JOIN RBIM.Dim_Time AS dt ON dt.TimeIdx=fr.ReceiptTimeIdx 
JOIN RBIM.Dim_Article AS da ON da.ArticleId = RSI.ArticleId AND da.isCurrent=1 
WHERE (RSI.LineType=''Sale'' OR RSI.LineType=''Return'')
AND da.Lev3ArticleHierarchyDisplayId=30084 
AND RSI.CancelFlag=0 
AND RSI.PayPointTransactionId<>0 
AND dd.FullDate BETWEEN GETDATE()-10 AND GETDATE() 
order BY ds.StoreId,fr.ReceiptDateIdx,dt.TimeDescription,RSI.PayPointTransactionId'

--print @Sqlstr

SET @sqlStr = REPLACE(@sqlStr,CHAR(10),'')
SET @sqlStr = REPLACE(@sqlStr,CHAR(13),'')

SET @cmdStr = 'bcp "' + @sqlStr + '" queryout "C:\Visma Retail\Data\PayPoint\PayPoint_'+@Date+'.csv" -U rbssql -P ett2tre -c -t";"  -S 172.18.44.171 -d BI_Mart'

--print @CmdStr

EXEC xp_cmdshell @cmdStr


END



GO

