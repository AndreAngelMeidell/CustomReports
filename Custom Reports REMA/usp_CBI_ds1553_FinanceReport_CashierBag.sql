USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1553_FinanceReport_CashierBag]    Script Date: 07.02.2020 10:40:30 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   Procedure [dbo].[usp_CBI_ds1553_FinanceReport_CashierBag]
(
 @StoreId varchar(100),
 @PeriodType as char(1), 
 @DateFrom as datetime,
 @DateTo as datetime,
 @YearToDate as integer, 
 @RelativePeriodType as char(5),
 @RelativePeriodStart as integer, 
 @RelativePeriodDuration as integer
)
as 
begin
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


IF (@DateFrom IS NULL)
BEGIN
	SELECT TOP(0) 1 -- {RS-34990} initial load report improvement
END
ELSE BEGIN

DECLARE @IncludeInReportsCurrentStoreOnly INT = (
SELECT TOP(1) ValueInt FROM [BI_Kernel].[dbo].[RSParameters] 
WHERE ParameterName = 'IncludeInReportsCurrentStoreOnly'
);
SET @IncludeInReportsCurrentStoreOnly = ISNULL(@IncludeInReportsCurrentStoreOnly, 1); --{RS-36137}
		
	-- to have resulting dataset consistent with others procedures of Finance report
    -- we filter reconciliations like do there, and then use linked countings for reporting
	/*select distinct
		   cc.ZNR, 
		   du.[LoginName] as CashierLogin, 
		   (du.[FirstName] + du.[LastName]) as CashierName,
		   cc.BagId			
	FROM [RBIM].[Fact_ReconciliationSystemTotalPerTender] (nolock) fc  
	     inner join [RBIM].[Fact_ReconciliationCountingPerTender] (nolock) cc on fc.StoreIdx=cc.StoreIdx and fc.TotalTypeIdx=cc.TotalTypeIdx and fc.ZNR=cc.ZNR
		 inner join [RBIM].[Dim_User] (nolock) du on cc.CountedByUserIdx=du.UserIdx
		 inner join [RBIM].[Dim_Store] (nolock) ds on fc.StoreIdx = ds.StoreIdx
		 inner join [RBIM].[Dim_TotalType] (nolock) dt on fc.TotaltypeIdx=dt.TotalTypeIdx
		 inner join [RBIM].[Dim_Date] (nolock) dd on fc.ReconciliationDateIdx=dd.DateIdx
	where dt.TotalTypeId = 2  /* dt.TotalTypeName='Operator totals' */
		  and ((@StoreId=ds.StoreId or @StoreId is null))
		  and ((@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
        		or (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1))
          and ds.isCurrentStore = 1 
	order by cc.ZNR
	*/

;WITH 
 ---------------------------------------------------------------------------------------------------------------------------------
 ListOfSystemReconciliations AS (
 SELECT fc.ZNR,ds.StoreId,/*fc.StoreIdx,*/fc.TotalTypeIdx,ReconciliationDateIdx 
 FROM RBIM.Fact_ReconciliationSystemTotalPerTender (nolock) fc
	INNER JOIN [RBIM].[Dim_Store] (nolock) ds on fc.StoreIdx = ds.StoreIdx
	INNER JOIN [RBIM].[Dim_TotalType] (nolock) dt on fc.TotaltypeIdx=dt.TotalTypeIdx
	INNER JOIN [RBIM].[Dim_Date] (nolock) dd on fc.ReconciliationDateIdx=dd.DateIdx
 WHERE ((@StoreId=ds.StoreId or @StoreId is null))
       AND ((@PeriodType='D' and dd.FullDate between @DateFrom and @DateTo)
        	OR (@PeriodType='R' and @RelativePeriodType = 'D' and dd.RelativeDay between @RelativePeriodStart and @RelativePeriodStart+@RelativePeriodDuration-1))
       AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
	  AND dt.TotalTypeId = 2   /*Operator*/
 GROUP BY fc.ZNR,ds.StoreId,/*fc.StoreIdx,*/fc.TotalTypeIdx,fc.ReconciliationDateIdx
),
---------------------------------------------------------------------------------------------------------------------------------
ListOfReconciliationsLastCountings AS (
 SELECT  fc.ZNR,ds.StoreId/*,fc.StoreIdx*/,fc.TotalTypeIdx,MAX(CountNo) LastCountNo 
 FROM RBIM.Fact_ReconciliationCountingPerTender (nolock) fc
	 INNER JOIN [RBIM].[Dim_Store] (nolock) ds ON fc.StoreIdx = ds.StoreIdx
	 INNER JOIN [RBIM].[Dim_TotalType] (nolock) dt ON fc.TotaltypeIdx=dt.TotalTypeIdx
	 INNER JOIN ListOfSystemReconciliations sr ON  fc.ZNR=sr.ZNR and ds.StoreId=sr.StoreId and fc.TotalTypeIdx = sr.TotalTypeIdx
 WHERE ((@StoreId=ds.StoreId or @StoreId is null))
		  AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
		 AND dt.TotalTypeId = 2  /*Operator*/
 GROUP BY fc.ZNR,ds.StoreId,/*fc.StoreIdx,*/fc.TotalTypeIdx
)

-- Result Set --------------------------------------------------------------------------------------------------------------------
 SELECT rct.ZNR, 
        du.[LoginName] as CashierLogin, 
	    du.[FirstName] + du.[LastName] as CashierName,
	    rct.BagId	
 FROM RBIM.Fact_ReconciliationCountingPerTender rct
     INNER JOIN ListOfReconciliationsLastCountings rc ON rct.CountNo=rc.LastCountNo
	 INNER JOIN [RBIM].[Dim_User] (nolock) du on rct.CountedByUserIdx=du.UserIdx
 GROUP BY  rct.ZNR, du.[LoginName],du.[FirstName],du.[LastName], rct.BagId	
 ORDER BY rct.ZNR asc
 ---------------------------------------------------------------------------------------------------------------------------------

END
End



GO

