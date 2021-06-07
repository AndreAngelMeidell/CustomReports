--Dato for rekjøring Meny og Kiwi

--1. feb
--11. Jan
--4. Jan


--Kiwi

USE VRNOMisc
GO
SET ROWCOUNT 0
SET NOCOUNT on
 
--DECLARE @ChainCodeId AS INT = dbo.GetChainCodeIdMeny()    --1
DECLARE @ChainCodeId AS INT = dbo.GetChainCodeIdKiwi()  --3
--DECLARE @ChainCodeId AS INT = dbo.GetChainCodeIdJoker()   --5
--DECLARE @ChainCodeId AS INT = dbo.GetChainCodeIdSpar()    --6
 
DECLARE @ReportTypeId AS INT =  dbo.GetReportTypeSales()  --1
 
--DECLARE @DateParam AS DATE = '2020-12-27' --OK
--DECLARE @DateParam AS DATE = '2020-12-31' --OK
--DECLARE @DateParam AS DATE = '2021-01-03' --OK
--DECLARE @DateParam AS DATE = '2021-01-10'  --OK

 
EXEC usp_CBI_GenusReportsMainAccWeek
    @ReportTypeId,
    @ChainCodeId,
    @DateParam




--Meny

USE VRNOMisc
GO
SET ROWCOUNT 0
SET NOCOUNT on
 
DECLARE @ChainCodeId AS INT = dbo.GetChainCodeIdMeny()  --1
--DECLARE @ChainCodeId AS INT = dbo.GetChainCodeIdKiwi()    --3
--DECLARE @ChainCodeId AS INT = dbo.GetChainCodeIdJoker()   --5
--DECLARE @ChainCodeId AS INT = dbo.GetChainCodeIdSpar()    --6
 
DECLARE @ReportTypeId AS INT =  dbo.GetReportTypeSales()  --1
 
--DECLARE @DateParam AS DATE = '2020-12-27' --OK
--DECLARE @DateParam AS DATE = '2020-12-31' --OK
--DECLARE @DateParam AS DATE = '2021-01-03' --OK
DECLARE @DateParam AS DATE = '2021-01-10' 


EXEC usp_CBI_GenusReportsMainAccWeek
    @ReportTypeId,
    @ChainCodeId,
    @DateParam

	--CAST(DATEPART(MONTH,@SelectionDate) AS VARCHAR),2)

	SELECT TOP 100 CAST(dd.DateIdx AS VARCHAR(8))+CAST(dd.WeekNumberOfYear AS VARCHAR(2)),* FROM BI_Mart.RBIM.Dim_Date AS dd WHERE dd.DateIdx=20201231

	USE VRNOMisc


	SET DATEFIRST 1
	SELECT TOP 100 
	DATEPART(WEEK,dd.FullDate),
	CAST(dd.DateIdx AS VARCHAR(8))+ CAST(DATEPART(iso_week,dd.FullDate) AS VARCHAR(2)),
	CAST(dd.DateIdx AS VARCHAR(8))+	CAST(dd.WeekNumberOfYear AS VARCHAR(2)),
	CAST(DATEPART(iso_WEEK,DATEADD(DAY , 7-DATEPART(WEEKDAY,dd.FullDate),dd.FullDate)) AS VARCHAR)
	,CAST(DATEPART(WEEK,DATEADD(DAY , 7-DATEPART(WEEKDAY,dd.FullDate),dd.FullDate)) AS VARCHAR)
	 FROM BI_Mart.RBIM.Dim_Date AS dd WHERE dd.DateIdx=20201231

