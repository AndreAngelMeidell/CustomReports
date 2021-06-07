--Genus OMS test filnavn og dato i fil 

USE BI_Mart

SET DATEFIRST 1
--DECLARE @InParamReportDate AS DATE = '2020-12-27' --OMS_kjede_2020122752_
--DECLARE @InParamReportDate AS DATE = '2020-12-28' --OMS_kjede_2020123152_
--DECLARE @InParamReportDate AS DATE = '2020-12-29' --OMS_kjede_2020123152_
--DECLARE @InParamReportDate AS DATE = '2020-12-30' --OMS_kjede_2020123152_
--DECLARE @InParamReportDate AS DATE = '2020-12-31' --OMS_kjede_2020123152_
--DECLARE @InParamReportDate AS date = '2021-01-01' --OMS_kjede_202101031_
--DECLARE @InParamReportDate AS date = '2021-01-02' --OMS_kjede_202101031_
DECLARE @InParamReportDate AS DATE = '2021-01-03' --OMS_kjede_202101031_
--DECLARE @InParamReportDate AS date = '2021-01-04' --OMS_kjede_2021011001_
--DECLARE @InParamReportDate AS date = '2021-01-10' --OMS_kjede_2021011001_


--DECLARE @InParamReportDate AS date = '2020-06-07'
--DECLARE @InParamReportDate AS date = '2021-06-07'
PRINT DATEPART(iso_week,@InParamReportDate)
PRINT DATEPART(week,@InParamReportDate)
PRINT DATEPART(YEAR,@InParamReportDate)
--gir uke 6, men vi er i uke 5

DECLARE @fileName VARCHAR(1000)
DECLARE @SelectionDate DATETIME = @InParamReportDate

DECLARE @DateLine VARCHAR(10)

IF (DATEPART(iso_WEEK,@SelectionDate) = 53 AND DATEPART(WEEK,@SelectionDate) = 53)
	BEGIN
	SET @fileName =
        'OMS_kjede_'+
        RIGHT('0' + CAST(DATEPART(YEAR,@SelectionDate) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,@SelectionDate) AS VARCHAR),2) +
        '31'+
		'52'+
        '_.csv_1'
		PRINT @fileName

		SET @DateLine = 
		RIGHT('0' + CAST(DATEPART(YEAR,@SelectionDate) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,@SelectionDate) AS VARCHAR),2) +
        '31'+
		'52'
		PRINT @DateLine
	END



IF (DATEPART(iso_WEEK,@SelectionDate) = 53 AND DATEPART(WEEK,@SelectionDate) = 1)
	BEGIN
	SET @fileName =
        'OMS_kjede_'+
        RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
		'1'+
        '_.csv_2'
		PRINT @fileName

		SET @DateLine = 
		RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
		'1'
		PRINT @DateLine
	END
    
IF DATEPART(iso_WEEK,@SelectionDate) <> 53 
	BEGIN	
	SET @fileName =
        'OMS_kjede_'+
        RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)+
        RIGHT('0' + CAST(DATEPART(iso_WEEK,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)+
        '_.csv_3'
		PRINT @fileName

		SET @DateLine = 
		RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)+
        RIGHT('0' + CAST(DATEPART(iso_WEEK,DATEADD(DAY , 7-DATEPART(WEEKDAY,@SelectionDate),@SelectionDate)) AS VARCHAR),2)
		PRINT @DateLine
	END
    
    





SELECT DISTINCT tdate.WeekNumberOfYear, tdate.Year,sales.ReceiptDateIdx,@DateLine AS Dato, @fileName AS Filnavn FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay sales
INNER JOIN BI_Mart.RBIM.Dim_Date tdate ON sales.ReceiptDateIdx = tdate.DateIdx
INNER JOIN BI_Mart.RBIM.Dim_Store store ON sales.StoreIdx = store.StoreIdx
WHERE 
tdate.WeekNumberOfYear = DATEPART(iso_WEEK,@InParamReportDate) AND tdate.Year = DATEPART(YEAR,@InParamReportDate) 

--Får ikke endret func. så lage et parameter for denne Dato = dbo.GetGenusVaresalgDatoValue(tdate.fulldate)
--Med 3 if'er som tidligere hvor den siste kan hente den orginale, eller kutte ut func. helt?


-- T tilbud eller N Normal

--13351 tilbud og 43443 tot
SELECT DISTINCT dpt.PriceTypeName, dpt.PriceTypeIdx,sales.PriceTypeIdx,SUM(sales.QuantityOfArticlesSold),SUM(sales.QuantityOfArticlesInReturn), SUM(sales.SalesRevenueInclVat)
FROM BI_Mart.RBIM.Agg_SalesAndReturnPerDay sales 
LEFT JOIN BI_Mart.RBIM.Dim_PriceType AS dpt ON dpt.PriceTypeIdx = sales.PriceTypeIdx
WHERE  1=1
--AND sales.SalesPrice<>sales.SalesAmount
--AND sales.ReceiptDateIdx>20210101
GROUP BY dpt.PriceTypeName, dpt.PriceTypeIdx,sales.PriceTypeIdx
ORDER BY 1


--SELECT * FROM  BI_Mart.RBIM.Dim_PriceType AS dpt


--PriceTypeName	PriceTypeIdx	(No column name)
--Ingen rabatt	14	67103217.29820
--Kampanjerabatt	18	219611.54000
--Mixmatch	24	3476312.00690
--N/A	-1	0.00000
--Nedprising	19	711253.73630
--Winsuper-kampanje	25	11815663.51230