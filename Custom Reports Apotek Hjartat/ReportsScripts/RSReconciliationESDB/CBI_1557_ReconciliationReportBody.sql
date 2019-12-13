USE [RSReconciliationESDB]
GO

/****** Object:  StoredProcedure [Reconciliation].[CBI_1557_ReconciliationReportBody]    Script Date: 10/3/2019 10:44:17 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [Reconciliation].[CBI_1557_ReconciliationReportBody]
@ReconciliationNo int

AS
BEGIN

	DECLARE @CurrentCountNo bigint

	SELECT @CurrentCountNo = MAX(c.CountNo)
	FROM Reconciliation.Reconciliations AS r
		INNER JOIN Reconciliation.Counts AS c ON c.ReconciliationNo = r.ReconciliationNo
	WHERE r.ReconciliationNo = @ReconciliationNo


	SELECT
		tmp.SourceTypeId, 
		tmp.DisplayName,
		tmp.TenderId,
		(CASE WHEN (cric.IsAlwaysPositive = 1) THEN (tmp.SystemAmount * -1) ELSE tmp.SystemAmount END) AS SystemAmount,
		tmp.SystemCount,
		(CASE WHEN (cric.IsAlwaysPositive = 1) THEN (tmp.UserAmount * -1) ELSE tmp.UserAmount END) AS UserAmount,
		(CASE WHEN cric.ReconcileAmount = 0 THEN 0 ELSE (tmp.UserAmount - (CASE WHEN (tmp.SystemAmount is null) THEN 0 ELSE tmp.SystemAmount END)) END) AS AmountDifference
	FROM Reconciliation.Counts AS c
		INNER JOIN Reconciliation.ReconciliationConfigs AS crc ON crc.ReconciliationConfigNo = c.ReconciliationConfigNo
		INNER JOIN Reconciliation.ReconciliationItemOrderConfigs AS crioc ON crioc.ReconciliationConfigNo = crc.ReconciliationConfigNo
		INNER JOIN Reconciliation.ReconciliationItemConfigs AS cric ON cric.ReconciliationConfigNo = crc.ReconciliationConfigNo AND cric.ReconciliationItemNo = crioc.ReconciliationItemNo
		INNER JOIN  (
			SELECT ri.ReconciliationItemNo,
				1 AS SourceTypeId,
				ri.DisplayName,
				ri.TenderId,
				ISNULL(stct.Amount, 0) AS SystemAmount,
				ISNULL(stct.[Count], 0) AS SystemCount,
				ISNULL(rtc.Amount, 0) AS UserAmount
			FROM Reconciliation.ReconciliationItems AS ri
				LEFT OUTER JOIN Reconciliation.SystemTenderTotals AS stt ON stt.TenderId = ri.TenderId AND stt.ReconciliationNo = @ReconciliationNo
				LEFT OUTER JOIN Reconciliation.SystemTenderCurrencyTotals AS stct ON stct.SystemTenderTotalNo = stt.SystemTenderTotalNo AND stct.CurrencyCode = ri.TenderCurrency
				LEFT OUTER JOIN Reconciliation.ReconciliationTenderCounts AS rtc ON rtc.TenderId = ri.TenderId AND rtc.TenderCurrency = ri.TenderCurrency AND rtc.CountNo = @CurrentCountNo
			WHERE 
				ri.TenderId IS NOT NULL
				AND ri.TenderId NOT IN (23) -- If ever needed, TenderId 23 Should be obtaind from Accumulators as in CBI_1557_ReconciliationReportBodyTable2
				AND ri.Active = 1
		) AS tmp ON tmp.ReconciliationItemNo = cric.ReconciliationItemNo
		WHERE c.CountNo = @CurrentCountNo
			AND crioc.Display = 1
			AND crioc.[Print] = 1
		ORDER BY
			crioc.PrintOrder, tmp.DisplayName
END;
GO


