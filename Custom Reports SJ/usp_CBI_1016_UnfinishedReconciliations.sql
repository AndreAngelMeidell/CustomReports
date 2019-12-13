USE [BI_Stage]
GO


IF OBJECT_ID('usp_CBI_1016_UnfinishedReconciliations') IS NOT NULL DROP PROCEDURE [dbo].[usp_CBI_1016_UnfinishedReconciliations]
GO


CREATE PROCEDURE [dbo].[usp_CBI_1016_UnfinishedReconciliations]
 @NoOfDays int = 0
AS

SET NOCOUNT ON;

-- =============================================
-- Author:		Rikard Johansson
-- Change date: 2016-02-10 Changed logic to show Cashiers that "has never" reported in DA are shown with "NoReportedDateFoundInDA"
-- Change date: 2016-01-25 Changed to sp instead of sql code in rdl-file.
--						   Changed to get data from TrainStagingDb instead of BI_Stage	
--						   Added filter on latestSalesDate <= (Getdate()-@NoOfDays)			
							
-- Create date: 2015-11-11
-- Description:	sp to get data to report "Rep16_UnfinishedReconciliations".
-- Note: This procedure gets data from 2 differnt data sources, BI_Stage (Primary) and TrainStagingDb. This is hardcoded below!
-- To Run:		usp_CBI_Rep16_UnfinishedReconciliations @NoOfDays=2
-- =============================================

--The data from TrainStagingDb will be deleted after xx-months?
WITH maxSalesDate AS (
	SELECT TillID,
		max(ReceiptDateTime) as 'latestSalesDate'
	FROM TrainStagingDb.dbo.Transactions
	group by TillID

	)

, maxReportedDate AS (
	SELECT CashierId,
		MAX(CreationDateTime) AS 'latestReportedDate'
	FROM CBIS.DA_AccountingHead
	GROUP BY CashierId
	)

SELECT *
FROM (
	SELECT s.TillID as CashierId
		,CONCAT(U.FirstName, ' ',U.LastName ) CashierName
		,CONVERT (varchar(50),S.latestSalesDate,112) AS 'latestSalesDate'
		,CASE WHEN R.latestReportedDate IS NULL THEN '' ELSE CONVERT(varchar(50),R.latestReportedDate,112) END AS 'latestReportedDate'
		,CASE WHEN R.latestReportedDate IS NULL THEN '' ELSE CONVERT(varchar(50),DateDiff(dd,R.latestReportedDate,S.latestSalesDate),121) END AS 'DateDiff'
	FROM maxSalesDate S
		LEFT JOIN maxReportedDate R ON S.TillID = R.CashierId
		LEFT JOIN RBIS.sUsersXML_RS U ON S.TillID = U.UserName
	WHERE U.isCurrent = 1
	 AND (DateDiff(dd,R.latestReportedDate,S.latestSalesDate)) >= @NoOfDays OR (DateDiff(dd,R.latestReportedDate,S.latestSalesDate) IS NULL)
	GROUP BY s.TillID
		,U.FirstName
		,U.LastName

		,S.latestSalesDate
		,R.latestReportedDate
		) x
WHERE x.latestSalesDate <= DateAdd(dd,-@NoOfDays,GetDate())
ORDER BY 
	CASE WHEN x.latestReportedDate ='' THEN -1 ELSE DateDiff(dd,x.latestReportedDate,x.latestSalesDate) END desc,
	x.CashierId,
	x.latestSalesDate desc
	


GO


