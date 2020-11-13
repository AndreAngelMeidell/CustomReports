USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_PayPointSalesExport_SendMail]    Script Date: 13.11.2020 08:40:47 ******/
DROP PROCEDURE [dbo].[usp_CBI_PayPointSalesExport_SendMail]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_PayPointSalesExport_SendMail]    Script Date: 13.11.2020 08:40:47 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_PayPointSalesExport_SendMail]

AS  
BEGIN

--By Andre Angel Meidell 20191126
--This has to be on, its on for Retail Ops

--EXEC sp_configure 'show advanced options', 1
--RECONFIGURE
--EXEC sp_configure 'xp_cmdshell', 1
--RECONFIGURE


DECLARE @Sqlstr AS VARCHAR(4000)
DECLARE @CmdStr AS VARCHAR(4000)
DECLARE @File AS VARCHAR(4000)
DECLARE @Date AS VARCHAR(20)

SET @Date = (SELECT dd.DateIdx FROM RBIM.Dim_Date AS dd WHERE dd.RelativeDay=0)
SET @File = 'C:\Visma Retail\Data\PayPoint\PayPoint_'+@Date+'.csv'

SET NOCOUNT ON


--Using this mailbox: mercury.afblakemore.com
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'AFB',
    @recipients = 'Jonesj@afblakemore.co.uk',
    @body = 'PayPoint transactions report on CSV from Production',
    @subject = 'PayPoint from Production 10 days' ,
	@copy_recipients = 'andre.meidell@extendaretail.com' ,
	@file_attachments= @File;


END



GO

