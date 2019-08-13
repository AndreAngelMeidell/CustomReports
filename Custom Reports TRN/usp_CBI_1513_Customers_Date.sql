USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1513_Customers_Date]    Script Date: 15.01.2019 14:35:39 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






ALTER PROCEDURE [dbo].[usp_CBI_1513_Customers_Date] 
(@DateTo AS DATE)

AS 
BEGIN
SET NOCOUNT ON;

IF (@DateTo IS NULL OR @DateTo = '') 
BEGIN
	SELECT TOP(0) 1 --  {RS-34990}
	SET @DateTo = GETDATE()-1
END

--TRN Customers 7 days 

DECLARE @DateFrom1 DATE = DATEADD(DAY, -1, @DateTo)
DECLARE @DateFrom2 DATE = DATEADD(DAY, -2, @DateTo)
DECLARE @DateFrom3 DATE = DATEADD(DAY, -3, @DateTo)
DECLARE @DateFrom4 DATE = DATEADD(DAY, -4, @DateTo)
DECLARE @DateFrom5 DATE = DATEADD(DAY, -5, @DateTo)
DECLARE @DateFrom6 DATE = DATEADD(DAY, -6, @DateTo)
DECLARE @DateFrom7 DATE = DATEADD(DAY, -7, @DateTo)

DECLARE @sql NVARCHAR(MAX)

SELECT st.StoreId AS 'ShopId'
	,st.StoreName AS 'Shop'
	,SUM(CASE WHEN d.FullDate = @DateFrom7 THEN f.NumberOfCustomers ELSE 0 END) AS Day7
	,SUM(CASE WHEN d.FullDate = @DateFrom6 THEN f.NumberOfCustomers ELSE 0 END) AS Day6
	,SUM(CASE WHEN d.FullDate = @DateFrom5 THEN f.NumberOfCustomers ELSE 0 END) AS Day5
	,SUM(CASE WHEN d.FullDate = @DateFrom4 THEN f.NumberOfCustomers ELSE 0 END) AS Day4
	,SUM(CASE WHEN d.FullDate = @DateFrom3 THEN f.NumberOfCustomers ELSE 0 END) AS Day3
	,SUM(CASE WHEN d.FullDate = @DateFrom2 THEN f.NumberOfCustomers ELSE 0 END) AS Day2
	,SUM(CASE WHEN d.FullDate = @DateFrom1 THEN f.NumberOfCustomers ELSE 0 END) AS Day1
FROM RBIM.Agg_SalesAndReturnPerDay f (NOLOCK)
	INNER JOIN RBIM.Dim_Store st (NOLOCK) ON f.StoreIdx = st.StoreIdx
	INNER JOIN RBIM.Dim_Date d (NOLOCK) ON d.DateIdx = f.ReceiptDateIdx
WHERE d.FullDate BETWEEN @DateFrom7 AND @DateFrom1
GROUP BY st.StoreId, st.StoreName
ORDER BY st.StoreId



END


GO

