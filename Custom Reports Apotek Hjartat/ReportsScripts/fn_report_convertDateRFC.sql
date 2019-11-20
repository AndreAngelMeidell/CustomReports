USE [VBDCM]

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES r WHERE r.ROUTINE_NAME = 'fn_report_convertDateRFC')
DROP FUNCTION [fn_report_convertDateRFC]
GO

CREATE FUNCTION [dbo].[fn_report_convertDateRFC](@formatDate  VARCHAR(30))
RETURNS  VARCHAR(12)
BEGIN

/*
declare @formatDate as varchar(30)
set @formatDate = 'Fri Apr 20 08:05:25 UTC 2018'
--*/

	IF ((SELECT CHARINDEX ( 'EEST' , @formatDate ))> 0 OR (SELECT CHARINDEX ( 'UTC' , @formatDate ))> 0)
	  SET @formatDate = (SELECT SUBSTRING(@formatDate, LEN(@formatDate)-3,4)  + months.month + SUBSTRING(@formatDate,9, 2)
						FROM (
							SELECT '01' AS month, N'Jan' monthName 
							UNION ALL
							SELECT '02', N'Feb' 
							UNION ALL
							SELECT '03', N'Mar' 
							UNION ALL
							SELECT '04', N'Apr'
							UNION ALL
							SELECT '05', N'May' 
							UNION ALL
							SELECT '06', N'Jun' 
							UNION ALL
							SELECT'07', N'Jul' 
							UNION ALL
							SELECT '08', N'Aug'
							UNION ALL
							SELECT '09', N'Sep' 
							UNION ALL
							SELECT '10', N'Oct' 
							UNION ALL
							SELECT '11', N'Nov' 
							UNION ALL
							SELECT '12', N'Dec'
						) months
						WHERE months.monthName = (SELECT SUBSTRING(@formatDate, 5,3)))
	--	20180401
	
	--	31-03-2012
	if ((SELECT SUBSTRING(@formatDate,3,1))= '-')
	  SET @formatDate = (SUBSTRING(@formatDate,7,4) + SUBSTRING(@formatDate,4,2)+LEFT(@formatDate,2))
	--	20120331

	--	31.03.2012
	IF ((SELECT SUBSTRING(@formatDate,3,1))= '.')
	  SET @formatDate = (SUBSTRING(@formatDate,7,4) + SUBSTRING(@formatDate,4,2)+left(@formatDate,2))
	-- 20120331

	--	2015-05-31
	IF ((SELECT SUBSTRING(@formatDate,5,1))= '-')
	  SET @formatDate = (left(@formatDate,4) + SUBSTRING(@formatDate,6,2)+SUBSTRING(@formatDate,9,2))

	--	12/31/2014
	IF ((SELECT SUBSTRING(@formatDate,3,1))= '/')
	  SET @formatDate = (SUBSTRING(@formatDate,7,4) + LEFT(@formatDate,2) + SUBSTRING(@formatDate,4,2))  
	--	20141231
	

	--	12\31\2014
	IF ((SELECT SUBSTRING(@formatDate,3,1))= '\')
	  SET @formatDate = (SUBSTRING(@formatDate,7,4) + LEFT(@formatDate,2) + SUBSTRING(@formatDate,4,2))  
	--	20141231


	--	8/3/2019
	IF ( ((SELECT SUBSTRING(@formatDate,2,1))= '/')  AND ((SELECT substring(@formatDate,4,1))= '/') )
	  SET @formatDate = (substring(@formatDate,5,4) + '0' + LEFT(@formatDate,1) + '0' + SUBSTRING(@formatDate,3,1))  
	--	20141231


	--	8/3/2019
	IF ( ((SELECT SUBSTRING(@formatDate,2,1))= '/'))
	  SET @formatDate = (SUBSTRING(@formatDate,6,4) + '0' + LEFT(@formatDate,1) + SUBSTRING(@formatDate,3,2)) 


	RETURN @formatDate
END



GO

