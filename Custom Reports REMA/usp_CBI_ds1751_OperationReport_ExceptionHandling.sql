USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1751_OperationReport_ExceptionHandling]    Script Date: 03.03.2020 12:24:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   PROCEDURE [dbo].[usp_CBI_ds1751_OperationReport_ExceptionHandling]
( @DateFrom as datetime,
  @DateTo as datetime,
  @StoreId varchar(100))
AS

BEGIN
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


IF (@DateFrom IS NULL) --RS-34990
BEGIN
	SELECT TOP(0) 1
END
ELSE BEGIN

DECLARE @IncludeInReportsCurrentStoreOnly INT = (
SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
);
SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		
--{RS-34601}
DECLARE @DayFromIdx integer
DECLARE @DayToIdx integer

SET @DayFromIdx = CAST(CONVERT(char(8), @dateFrom, 112) as integer)
SET @DayToIdx = CAST(CONVERT(char(8), @dateTo, 112) as integer)

--{RS-34601}
SELECT        
	 CashierId
	,CasierName
	,SalesAmount
	,ReturnAmount
	,NumberOfSelectedCorrections    /*NumberOfPreviousCorrections   old name*/
	,SelectedCorrectionsAmount      /*PreviousCorrectionsAmoun      old name*/
	,NumberOfLastCorrections
	,LastCorrectionsAmount
	,NumberOfReceiptsParked
	,NumberOfReceiptsCanceled
	,CanceledReceiptsAmount
	,NumberOfReceiptsCorrected
	,NumberOfAgeControl
	,ISNULL(NumberOfReceiptsDeleted,0) AS NumberOfReceiptsDeleted
FROM    
 (SELECT     
    su.UserNameID AS CashierId, 
    su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName,  --  <--spelling mistake CashierName
    --SUM(f.SalesAmount) AS SalesAmount, --{RS-27230} 
	SUM(f.SalesAmount+f.ReturnAmount) AS SalesAmount, --{RS-27230} all returns and all sales, 3.rd sales included.
    SUM(f.ReturnAmount)*-1 AS ReturnAmount, --{RS-27230} positive
    SUM(f.NumberOfSelectedCorrections) AS NumberOfSelectedCorrections, 
    SUM(f.SelectedCorrectionsAmount) AS SelectedCorrectionsAmount, 
    SUM(f.NumberOfLastCorrections)   AS NumberOfLastCorrections, 
    SUM(f.LastCorrectionsAmount) AS LastCorrectionsAmount, 
    SUM(f.NumberOfReceiptsParked) AS NumberOfReceiptsParked, 
    SUM(f.NumberOfReceiptsCanceled) AS NumberOfReceiptsCanceled, 
    SUM(CanceledReceiptsAmount) AS CanceledReceiptsAmount, --Missing?
    SUM(f.NumberOfReceiptsCorrected) AS NumberOfReceiptsCorrected, 
    SUM(f.TotalNumberOfAgeControlsApproved + f.TotalNumberOfAgeControlsNotApproved) AS NumberOfAgeControl,
	SUM(f.NumberOfReceiptsDeleted) AS NumberOfReceiptsDeleted
   FROM RBIM.Agg_CashierSalesAndReturnPerHour AS f 
    -- INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx 
     INNER JOIN RBIM.Dim_Store AS ds ON ds.StoreIdx = f.StoreIdx
     INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.CashierUserIdx
      WHERE (ds.StoreId = @StoreId AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1)) --{RS-36137}
             AND f.ReceiptDateIdx >= @DayFromIdx AND f.ReceiptDateIdx <= @DayToIdx --- improvement {RS-34601}
    GROUP BY su.UserNameID, su.FirstName, su.LastName) AS sub
END
END



GO

