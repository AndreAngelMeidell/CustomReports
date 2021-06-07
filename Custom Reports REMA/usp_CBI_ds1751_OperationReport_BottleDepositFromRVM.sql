USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_ds1751_OperationReport_BottleDepositFromRVM]    Script Date: 07.02.2020 10:43:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


CREATE   PROCEDURE [dbo].[usp_CBI_ds1751_OperationReport_BottleDepositFromRVM]
( --@PeriodType as char(1), 
  @DateFrom as datetime,
  @DateTo as datetime,
  --@YearToDate as integer, 
  --@RelativePeriodType as char(5),
  --@RelativePeriodStart as integer, 
  --@RelativePeriodDuration as integer ,
  @StoreId varchar(100))  -- changed to varchar(100)
AS

BEGIN
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;


--20191219 Endridret til Agg_ReceiptTenderDaily

IF (@DateFrom IS NULL) --{RS-34990}
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

 
SET @DayFromIdx = cast(convert(char(8), @DateFrom, 112) as integer)
SET @DayToIdx = cast(convert(char(8), @DateTo, 112) as integer)
--{RS-34601}


--Start Create temp Fact_RvmReceipt

		IF object_id('tempdb..#FRT') IS NOT NULL DROP TABLE #FRT
		Select top 1 [RvmReceiptIdx],[StoreIdx],[DateIdx],[TimeIdx],[TransTypeIdx],[CashierUserIdx],[CashRegisterIdx],[TotalAmount],[OfflineTotalAmount],[GroupId],[Amount],[Quantity],[CountOfDuplicates],[SourceIdx],[EtlLoadedDate],[EtlChangedDate] into #FRT from BI_Mart.rbim.Fact_RvmReceipt
		truncate TABLE #FRT

		Declare @MultipleStoreIdx INT
		Declare @StoreIdx INT
		Set @MultipleStoreIdx = (select Count(Distinct StoreIdx) from BI_Mart.RBIM.Fact_RvmReceipt where DateIdx BETWEEN @DayFromIdx and @DayToIdx)

--Temp [Fact_ReceiptTender]
		If (@MultipleStoreIdx) = 9595959 --Deactivated
			BEGIN
			
				set @StoreIdx = (select Distinct StoreIdx from BI_Mart.RBIM.Agg_ReceiptTenderDaily where ReceiptDateIdx BETWEEN @DayFromIdx and @DayToIdx)
				Insert into #FRT ([RvmReceiptIdx],[StoreIdx],[DateIdx],[TimeIdx],[TransTypeIdx],[CashierUserIdx],[CashRegisterIdx],[TotalAmount],[OfflineTotalAmount],[GroupId],[Amount],[Quantity],[CountOfDuplicates],[SourceIdx],[EtlLoadedDate],[EtlChangedDate])
				Select
					[RvmReceiptIdx],[StoreIdx],[DateIdx],[TimeIdx],[TransTypeIdx],[CashierUserIdx],[CashRegisterIdx],[TotalAmount],[OfflineTotalAmount],[GroupId],[Amount],[Quantity],[CountOfDuplicates],[SourceIdx],[EtlLoadedDate],[EtlChangedDate]
				FROM
					BI_Mart.rbim.Fact_RvmReceipt
				where
					DateIdx BETWEEN @DayFromIdx and @DayToIdx
					and StoreIdx = @StoreIdx
			END

		ELSE
			BEGIN
				Insert into #FRT ([RvmReceiptIdx],[StoreIdx],[DateIdx],[TimeIdx],[TransTypeIdx],[CashierUserIdx],[CashRegisterIdx],[TotalAmount],[OfflineTotalAmount],[GroupId],[Amount],[Quantity],[CountOfDuplicates],[SourceIdx],[EtlLoadedDate],[EtlChangedDate])
				Select
					FRT.[RvmReceiptIdx],FRT.[StoreIdx],FRT.[DateIdx],FRT.[TimeIdx],FRT.[TransTypeIdx],FRT.[CashierUserIdx],FRT.[CashRegisterIdx],FRT.[TotalAmount],FRT.[OfflineTotalAmount],FRT.[GroupId],FRT.[Amount],FRT.[Quantity],FRT.[CountOfDuplicates],FRT.[SourceIdx],FRT.[EtlLoadedDate],FRT.[EtlChangedDate]
				FROM
					BI_Mart.rbim.Fact_RvmReceipt FRT
						inner JOIN
					BI_Mart.RBIM.Dim_Store DS on frt.StoreIdx = ds.StoreIdx
				where
					DateIdx BETWEEN @DayFromIdx and @DayToIdx
					and DS.StoreId = @StoreId
			END

		
		--END Creat temp Fact_RvmReceipt




SELECT  
 SUM(DepositReturnAmountUsedForLottery) AS DepositReturnAmountUsedForLottery,
 SUM(GainsLess1000)  AS GainsLess1000,
 SUM(GainsAbove1000)  AS GainsAbove1000,
 SUM(UnclaimedGainsLess90days) AS UnclaimedGainsLess90days,
 SUM(UnclaimedGainsAbove90days)  AS UnclaimedGainsAbove90days
FROM (
----------------------------------------------------------------------------------------------------------------
	SELECT
		CASE WHEN tt.TransTypeId = 90306 THEN r.TotalAmount ELSE 0 END AS DepositReturnAmountUsedForLottery,
		CASE WHEN tt.TransTypeId = 90305 THEN (CASE WHEN   r.TotalAmount <  1000  THEN  r.TotalAmount ELSE 0 END) ELSE 0 END AS GainsLess1000,
		CASE WHEN tt.TransTypeId = 90305 THEN (CASE WHEN   r.TotalAmount >= 1000  THEN  r.TotalAmount ELSE 0 END) ELSE 0 END AS GainsAbove1000,
		0 AS UnclaimedGainsLess90days,
		0 AS UnclaimedGainsAbove90days
	FROM #FRT r
	-- JOIN rbim.Dim_Date dd on dd.DateIdx = r.DateIdx -- removed dim_date join {RS-34601}
	JOIN rbim.Dim_Store ds on ds.storeidx = r.Storeidx and ds.StoreId = @StoreId /*and ds.IsCurrentStore = 1-- Mandatory*/
	left JOIN [RBIM].Dim_TransType tt on tt.TransTypeIdx = r.TransTypeIdx

	Where  r.DateIdx >= @DayFromIdx AND r.DateIdx <= @DayToIdx  ---improvement
	and r.TotalAmount > 0
	AND (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137}
	---------------------------------------------------------------------------------------
	UNION ALL

	SELECT  
		0 AS DepositReturnAmountUsedForLottery,
		0 AS GainsLess1000,
		0 AS GainsAbove1000,
		CASE WHEN DATEDIFF(DD,A.FullDate,@DateFrom)<90 THEN A.TotalAmount ELSE 0 END  AS UnclaimedGainsLess90days,
		CASE WHEN DATEDIFF(DD,A.FullDate,@DateFrom)>=90 THEN A.TotalAmount ELSE 0 END  AS UnclaimedGainsAbove90days
	FROM(
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
			SELECT sub.ReceiptHead,																							-- Removed ufn_RBI_IsRedeemed function from where clause for
			MAX(sub.FullDate) AS FullDate,																					-- performance improvement. These new sub-selects get all  
			MAX(sub.TotalAmount) AS TotalAmount																				-- required based on previous function logic and with some
			FROM (																											-- optimizations to query.
					SELECT																																																										
						RvmReceiptIdx,																						
						FLOOR(RvmReceiptIdx/1000000000000000000) AS ReceiptHead,											
						dd.FullDate as FullDate,
						TimeIdx, 
						CASE WHEN tt.TransTypeId = '90307' THEN TotalAmount ELSE 0 END AS TotalAmount,	
						CASE WHEN tt.TransTypeId = '90307' THEN CAST(r.DateIdx AS VARCHAR(8))+CAST(FLOOR(RvmReceiptIdx/10000000)%1000000 AS VARCHAR(9)) ELSE '0' END AS RedeemedDateTime,
						CASE WHEN tt.TransTypeId = '90308'THEN CAST(r.DateIdx AS VARCHAR(8))+CAST(FLOOR(RvmReceiptIdx/10000000)%1000000 AS VARCHAR(9)) ELSE '0' END AS UnredeemedDateTime								
					FROM #FRT r (NOLOCK)
					JOIN rbim.Dim_Date dd on dd.DateIdx = r.DateIdx -- Mandatory
					JOIN rbim.Dim_Store ds on ds.storeidx = r.Storeidx and ds.StoreId = @StoreId and (@IncludeInReportsCurrentStoreOnly = 0 or ds.IsCurrentStore = 1) --{RS-36137} -- Mandatory -- make sure you only get the 'current store' -- (will include all historical rows with the same PublicOrgNo and GlobalLocationNo as the current)
					LEFT JOIN [RBIM].Dim_TransType tt on tt.TransTypeIdx = r.TransTypeIdx			
					WHERE tt.TransTypeId in ('90307','90308')
					AND r.DateIdx <= @DayToIdx					 
				) AS Sub			
			GROUP BY ReceiptHead						
			HAVING MAX(sub.RedeemedDateTime) < MAX(sub.UnredeemedDateTime) OR MAX(sub.RedeemedDateTime) IS NULL
	-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		) AS A 									 
) sub
END

END




GO

