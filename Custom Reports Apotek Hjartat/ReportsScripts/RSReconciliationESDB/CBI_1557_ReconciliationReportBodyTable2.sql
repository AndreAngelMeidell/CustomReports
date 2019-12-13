USE [RSReconciliationESDB]
GO

/****** Object:  StoredProcedure [Reconciliation].[CBI_1557_ReconciliationReportBodyTable2]    Script Date: 10/3/2019 11:03:41 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [Reconciliation].[CBI_1557_ReconciliationReportBodyTable2]
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
		tmp.TypeId,
		(CASE WHEN (cric.IsAlwaysPositive = 1) THEN (tmp.SystemAmount * -1) ELSE tmp.SystemAmount END) AS SystemAmount,
		tmp.SystemCount
	FROM Reconciliation.Counts AS c
		INNER JOIN Reconciliation.ReconciliationConfigs AS crc ON crc.ReconciliationConfigNo = c.ReconciliationConfigNo
		INNER JOIN Reconciliation.ReconciliationItemOrderConfigs AS crioc ON crioc.ReconciliationConfigNo = crc.ReconciliationConfigNo
		INNER JOIN Reconciliation.ReconciliationItemConfigs AS cric ON cric.ReconciliationConfigNo = crc.ReconciliationConfigNo AND cric.ReconciliationItemNo = crioc.ReconciliationItemNo
		INNER JOIN  (
			SELECT 
				ri.ReconciliationItemNo,
				2 AS SourceTypeId,
				ri.DisplayName,
				ri.AccumulationId  AS TypeId,
				ISNULL(sat.Amount, 0) AS SystemAmount,
				sat.[Count] AS SystemCount
			FROM Reconciliation.ReconciliationItems AS ri
				LEFT OUTER JOIN Reconciliation.SystemAccumulationTotals AS sat ON sat.AccumulationId = ri.AccumulationId AND sat.ReconciliationNo = @ReconciliationNo
				LEFT OUTER JOIN Reconciliation.ReconciliationAccumulationCounts AS rac ON rac.AccumulationId = ri.AccumulationId AND rac.CountNo = @CurrentCountNo
			WHERE 
				ri.AccumulationId IS NOT NULL
				AND ri.Active = 1
				AND sat.[Count] > 0
				AND ri.AccumulationId IN (104)

			UNION

			SELECT ri.ReconciliationItemNo,
				1 AS SourceTypeId,
				ri.DisplayName,
				ri.TenderId AS TypeId,
				ISNULL(stct.Amount, 0) AS SystemAmount,
				stct.[Count] AS SystemCount
			FROM Reconciliation.ReconciliationItems AS ri
				LEFT OUTER JOIN Reconciliation.SystemTenderTotals AS stt ON stt.TenderId = ri.TenderId AND stt.ReconciliationNo = @ReconciliationNo
				LEFT OUTER JOIN Reconciliation.SystemTenderCurrencyTotals AS stct ON stct.SystemTenderTotalNo = stt.SystemTenderTotalNo AND stct.CurrencyCode = ri.TenderCurrency
				LEFT OUTER JOIN Reconciliation.ReconciliationTenderCounts AS rtc ON rtc.TenderId = ri.TenderId AND rtc.TenderCurrency = ri.TenderCurrency AND rtc.CountNo = @CurrentCountNo
			WHERE 
				ri.TenderId IS NOT NULL
				AND ri.TenderId NOT IN (23) -- TenderId = 23 redovisas i seleten ovan som accumulatorer
				AND ri.Active = 1
				AND stct.[Count] > 0
		) AS tmp ON tmp.ReconciliationItemNo = cric.ReconciliationItemNo

	WHERE c.CountNo = @CurrentCountNo
		AND crioc.Display = 0
		AND crioc.[Print] = 1
	ORDER BY
		crioc.PrintOrder, tmp.DisplayName
END;
GO


