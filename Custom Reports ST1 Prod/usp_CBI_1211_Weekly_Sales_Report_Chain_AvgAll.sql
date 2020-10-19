USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1211_Weekly_Sales_Report_Chain_AvgAll]    Script Date: 06.10.2020 07:50:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_CBI_1211_Weekly_Sales_Report_Chain_AvgAll]
(
	---------------------------------------------
--	@Week as int,
	@District as int
/*	@DateFrom AS DATETIME ,
	@StoreId	AS VARCHAR(100),
	@DateTo AS DATETIME
*/
)
AS  
BEGIN 
DECLARE @Week			INT	= DatePart(year, GetDate())*100+DatePart(week, GetDate()) - 1
--DECLARE @Week			INT	= 202019
--DECLARE @Week			INT  = DatePart(week, GetDate()) - 1
--DECLARE @LastWeek		INT  = @Week - 1
DECLARE @LastWeek		INT	=	(DatePart(year, GetDate())-1)*100+DatePart(week, GetDate()) - 1
--DECLARE @LastWeek		INT	=	201919
DECLARE @NoOfStores		INT = (Select count(distinct StoreId) from RBIM.Dim_Store)
;WITH 
ValidArticles AS
(SELECT ArticleIdx FROM  RBIM.Dim_Article AS DA (NOLOCK) 
where Lev2ArticleHierarchyId not in (937, 995, 981, 985, 982, 965, 990, 999, -98, -99)), -- Exclude Fuel, vouchers, deopsits etc.
CurrentWeek AS
(SELECT 'RIKET' AS 'Grupp', SUM(ASARPW.SALESREVENUE) AS 'OMSÄTTNING', SUM(ASARPW.GrossProfit) AS 'MARGINAL', SUM(ASARPW.NumberOfCustomers) AS 'ANTAL KUNDER', (SUM(ASARPW.SALESREVENUE)/SUM(ASARPW.NumberOfCustomers)) AS 'SNITTKÖP', SUM(ASARPW.QuantityOfArticlesSold) AS 'ANTAL ARTIKLAR'
  FROM [BI_Mart].[RBIM].[Agg_SalesAndReturnPerWeek] as ASARPW
JOIN RBIM.Dim_Date AS DD ON ASARPW.ReceiptDateIdx = DD.DateIdx
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = ASARPW.StoreIdx
JOIN ValidArticles as VA ON ASARPW.ArticleIdx = VA.ArticleIdx
WHERE DD.YearWeekNumber = @Week
--and DS.Lev3DistrictGroupNo = @District -- 1025, 1026, 1027, 1028, 1029
--GROUP BY DS.Lev3DistrictGroupNo)
),
PreviousWeek AS
(SELECT 'RIKET' AS 'Grupp', SUM(ASARPW.SALESREVENUE) AS 'OMSÄTTNING', SUM(ASARPW.GrossProfit) AS 'MARGINAL', SUM(ASARPW.NumberOfCustomers) AS 'ANTAL KUNDER', (SUM(ASARPW.SALESREVENUE)/SUM(ASARPW.NumberOfCustomers)) AS 'SNITTKÖP', SUM(ASARPW.QuantityOfArticlesSold) AS 'ANTAL ARTIKLAR'
  FROM [BI_Mart].[RBIM].[Agg_SalesAndReturnPerWeek] as ASARPW
JOIN RBIM.Dim_Date AS DD ON ASARPW.ReceiptDateIdx = DD.DateIdx
JOIN RBIM.Dim_Store AS DS ON DS.StoreIdx = ASARPW.StoreIdx
JOIN ValidArticles as VA ON ASARPW.ArticleIdx = VA.ArticleIdx
WHERE DD.YearWeekNumber = @LastWeek 
--and DS.Lev3DistrictGroupNo = @District -- 1025, 1026, 1027, 1028, 1029
--GROUP BY DS.Lev3DistrictGroupNo)
) 
Select 'RIKET' AS 'Grupp',
		(CurrentWeek.OMSÄTTNING/PWeek.OMSÄTTNING -1)*1 AS 'OMSÄTTNING VS FG VECKA', 
		CurrentWeek.Marginal/CurrentWeek.Omsättning AS 'Marginal %',
		(CurrentWeek.MARGINAL/PWeek.MARGINAL -1)*1 AS 'MARGINAL VS FG VECKA', 
		CurrentWeek.[ANTAL KUNDER]/@NoOfStores AS 'ANTAL KUNDER', 
		(cast (CurrentWeek.[ANTAL KUNDER] as decimal)/cast (PWeek.[ANTAL KUNDER] as decimal) -1)*1 AS 'ANTAL KUNDER VS FG VECKA', 
		CurrentWeek.SNITTKÖP, 
		(CurrentWeek.[SNITTKÖP]/PWeek.SNITTKÖP -1)*1 AS 'SNITTKÖP VS FG VECKA', 
		(cast (CurrentWeek.[ANTAL ARTIKLAR] as decimal)/cast (CurrentWeek.[ANTAL KUNDER] as decimal)) AS 'ANTAL POSTER PER KUND'
		from CurrentWeek
JOIN PreviousWeek AS PWeek ON CurrentWeek.Grupp = PWeek.Grupp
--ORDER BY CurrentWeek.Lev3DistrictGroupNo

END 
GO
