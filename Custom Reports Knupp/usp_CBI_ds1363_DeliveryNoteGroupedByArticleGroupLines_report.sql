USE VBDCM
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.usp_CBI_ds1363_DeliveryNoteGroupedByArticleGroupLines_report') AND type in (N'P', N'PC'))
	DROP PROCEDURE dbo.usp_CBI_ds1363_DeliveryNoteGroupedByArticleGroupLines_report
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.usp_CBI_ds1363_DeliveryNoteGroupedByArticleGroupLines_report
	(
	@DeliveryNoteNo VARCHAR(MAX)
	,@ExternalDeliveryNoteID VARCHAR(MAX)
	,@SortColumn VARCHAR(50)
	,@SortOrder VARCHAR(50)
	)
AS
BEGIN
IF @ExternalDeliveryNoteID IS NULL OR @ExternalDeliveryNoteID = ''
	BEGIN
		SELECT * FROM (
			SELECT
				1 AS DeliveryMode,
				a.ArticleID,
				a.PrimaryEAN EANNo,
				dl.SupplierArticleID,
				a.ArticleName,
				dl.DeliveryLineStatus,
				States.DeliveryLineStatusName StatusName,
				ddl.ActualDeliveryDate,
				(SELECT MAX(rl.CompletedReceivalDate) FROM ReceivedLines AS rl WHERE  rl.DeliveryNoteNo = dl.DeliveryNoteNo AND rl.DeliveryLineNo = dl.DeliveryLineNo AND rl.ReceivedLineStatus < 99) AS CompletedReceivalDate,
				dl.FpakInDpak,
				ISNULL(dl.InitialOrderedQtyUpdated, dl.InitialOrderedQty) OrderedQty,
				ISNULL(ddl.DeliveredQty, NULL) AS DeliveredQty,
				ISNULL((SELECT SUM(rl.ReceivedQty) FROM ReceivedLines AS rl WHERE rl.DeliveryNoteNo = dl.DeliveryNoteNo AND rl.DeliveryLineNo = dl.DeliveryLineNo AND rl.ReceivedLineStatus < 99), 0) AS ReceivedQty,
				ISNULL((SELECT SUM(rla.AdjustmentQty) FROM ReceivedLines AS rl INNER JOIN ReceivedLineAdjustments AS rla ON (rla.DeliveryNoteNo = rl.DeliveryNoteNo AND rla.ReceivedLineNo = rl.ReceivedLineNo) WHERE rl.DeliveryNoteNo = dl.DeliveryNoteNo AND rl.DeliveryLineNo = dl.DeliveryLineNo AND rl.ReceivedLineStatus < 99), 0) AS AdjustedQty,
				ISNULL(ddl.NetPriceStoreCurrency, dl.NetPrice) NetPrice,
				ISNULL(dl.TransportationCost,0) TransportationCost,
				ISNULL(dl.CustomsCost,0) CustomsCost
			FROM DeliveryLines dl
			INNER JOIN DeliveryLineStates AS States ON (dl.DeliveryLineStatus = States.DeliveryLineStatus)
			INNER JOIN Articles AS a ON (a.ArticleNo = dl.ArticleNo)
			LEFT JOIN (SELECT DeliveryNoteNo, DeliveryLineNo, SUM(DeliveredQty) AS DeliveredQty, MAX(ActualDeliveryDate) AS ActualDeliveryDate, MAX(NetPriceStoreCurrency) AS NetPriceStoreCurrency
					   FROM DeliveredLines WHERE DeliveredLineStatus >= 20 AND DeliveredLineStatus < 99 GROUP BY DeliveryNoteNo, DeliveryLineNo) ddl ON ddl.DeliveryNoteNo = dl.DeliveryNoteNo AND ddl.DeliveryLineNo = dl.DeliveryLineNo
			WHERE 
				  dl.DeliveryNoteNo IN (SELECT state_split FROM splitStringToTable(@DeliveryNoteNo, ','))
		) deliveryLines
		ORDER BY
			CASE WHEN @SortColumn = 'articleName' AND @SortOrder = 'ASC' THEN ArticleName END,
			CASE WHEN @SortColumn = 'supplierArticleId' AND @SortOrder = 'ASC' THEN SupplierArticleID END,
			CASE WHEN @SortColumn = 'ean' AND @SortOrder = 'ASC' THEN EANNo END,
			CASE WHEN @SortColumn = 'netPrice' AND @SortOrder = 'ASC' THEN NetPrice END,
			CASE WHEN @SortColumn = 'initialOrderedQty' AND @SortOrder = 'ASC' THEN OrderedQty END,
			CASE WHEN @SortColumn = 'expectedDeliveredQty' AND @SortOrder = 'ASC' THEN DeliveredQty END,
			CASE WHEN @SortColumn = 'quantity' AND @SortOrder = 'ASC' THEN ReceivedQty END,
			CASE WHEN @SortColumn = 'transportationCost' AND @SortOrder = 'ASC' THEN TransportationCost END,
			CASE WHEN @SortColumn = 'customsCost' AND @SortOrder = 'ASC' THEN CustomsCost END,
			CASE WHEN @SortColumn = 'totalAmount' AND @SortOrder = 'ASC' THEN NetPrice * ReceivedQty END,
			CASE WHEN @SortColumn = 'deliveryLineStatus' AND @SortOrder = 'ASC' THEN DeliveryLineStatus END,
			
			CASE WHEN @SortColumn = 'articleName' AND @SortOrder = 'DESC' THEN ArticleName END DESC,
			CASE WHEN @SortColumn = 'supplierArticleId' AND @SortOrder = 'DESC' THEN SupplierArticleID END DESC,
			CASE WHEN @SortColumn = 'ean' AND @SortOrder = 'DESC' THEN EANNo END DESC,
			CASE WHEN @SortColumn = 'netPrice' AND @SortOrder = 'DESC' THEN NetPrice END DESC,
			CASE WHEN @SortColumn = 'initialOrderedQty' AND @SortOrder = 'DESC' THEN OrderedQty END DESC,
			CASE WHEN @SortColumn = 'expectedDeliveredQty' AND @SortOrder = 'DESC' THEN DeliveredQty END DESC,
			CASE WHEN @SortColumn = 'quantity' AND @SortOrder = 'DESC' THEN ReceivedQty END DESC,
			CASE WHEN @SortColumn = 'transportationCost' AND @SortOrder = 'DESC' THEN TransportationCost END DESC,
			CASE WHEN @SortColumn = 'customsCost' AND @SortOrder = 'DESC' THEN CustomsCost END DESC,
			CASE WHEN @SortColumn = 'totalAmount' AND @SortOrder = 'DESC' THEN NetPrice * ReceivedQty END DESC,
			CASE WHEN @SortColumn = 'deliveryLineStatus' AND @SortOrder = 'DESC' THEN DeliveryLineStatus END DESC
	END

	ELSE IF @ExternalDeliveryNoteID IS NOT NULL 
	BEGIN
		SELECT * FROM (
			SELECT
				2 AS DeliveryMode, 
				MAX(a.ArticleID) ArticleID,
				MAX(a.PrimaryEAN) EANNo,
				MAX(dl.SupplierArticleID) SupplierArticleID,
				MAX(a.ArticleName) ArticleName,
				MAX(ddLines.DeliveredLineStatus) DeliveredLineStatus,
				MAX(states.DeliveredLineStatusName) StatusName,
				MAX(ddLines.ActualDeliveryDate) AS ActualDeliveryDate,
				(SELECT MAX(rl.CompletedReceivalDate) 
						FROM ReceivedLines AS rl 
						WHERE  rl.DeliveredLineNo = ddLines.DeliveredLineNo
						AND rl.DeliveryNoteNo = ddLines.DeliveryNoteNo 
						AND rl.ReceivedLineStatus < 99) 
						AS CompletedReceivalDate,
				MAX(dl.FpakInDpak) FpakInDpak,
				SUM(ISNULL(dl.InitialOrderedQtyUpdated,dl.InitialOrderedQty)) OrderedQty,	
				ISNULL(SUM(ddLines.DeliveredQty),0) AS DeliveredQty,
				ISNULL((SELECT SUM(rl.ReceivedQty) 
						FROM ReceivedLines AS rl 
						WHERE rl.DeliveredLineNo = ddLines.DeliveredLineNo 
						AND rl.DeliveryNoteNo = ddLines.DeliveryNoteNo 
						AND rl.ReceivedLineStatus < 99), 0) 
						AS ReceivedQty,
				ISNULL((SELECT SUM(rla.AdjustmentQty) 
						FROM ReceivedLines AS rl 
						INNER JOIN ReceivedLineAdjustments AS rla ON (rla.ReceivedLineNo = rl.ReceivedLineNo AND rla.DeliveryNoteNo = rl.DeliveryNoteNo) 
						WHERE rl.DeliveredLineNo = ddLines.DeliveredLineNo
						AND rl.DeliveryNoteNo = ddLines.DeliveryNoteNo 
						AND rl.ReceivedLineStatus < 99), 0) 
						AS AdjustedQty,
				MAX(ISNULL(ddLines.NetPriceStoreCurrency, dl.NetPrice)) NetPrice,
				SUM(dl.TransportationCost) AS TransportationCost,
				SUM(dl.CustomsCost) AS CustomsCost
			FROM DeliveredLines ddLines
			INNER JOIN dbo.DeliveryLines dl ON (ddLines.DeliveryNoteNo = dl.DeliveryNoteNo AND ddLines.DeliveryLineNo = dl.DeliveryLineNo)
			INNER JOIN Articles AS a ON (a.ArticleNo = dl.ArticleNo)
			INNER JOIN DeliveredLineStates AS States ON (ddLines.DeliveredLineStatus = States.DeliveredLineStatus)
			WHERE ddLines.ExternalDeliveryNoteID in (SELECT state_split FROM splitStringToTable(@ExternalDeliveryNoteID, ','))
				AND ddLines.DeliveredLineStatus < 99
			GROUP BY ddLines.ExternalDeliveryNoteID,  ddLines.DeliveredLineNo, ddLines.DeliveryNoteNo
		) deliveryLines
		ORDER BY
			CASE WHEN @SortColumn = 'articleName' AND @SortOrder = 'ASC' THEN ArticleName END,
			CASE WHEN @SortColumn = 'supplierArticleId' AND @SortOrder = 'ASC' THEN SupplierArticleID END,
			CASE WHEN @SortColumn = 'ean' AND @SortOrder = 'ASC' THEN EANNo END,
			CASE WHEN @SortColumn = 'netPrice' AND @SortOrder = 'ASC' THEN NetPrice END,
			CASE WHEN @SortColumn = 'initialOrderedQty' AND @SortOrder = 'ASC' THEN OrderedQty END,
			CASE WHEN @SortColumn = 'expectedDeliveredQty' AND @SortOrder = 'ASC' THEN DeliveredQty END,
			CASE WHEN @SortColumn = 'quantity' AND @SortOrder = 'ASC' THEN ReceivedQty END,
			CASE WHEN @SortColumn = 'transportationCost' AND @SortOrder = 'ASC' THEN TransportationCost END,
			CASE WHEN @SortColumn = 'customsCost' AND @SortOrder = 'ASC' THEN CustomsCost END,
			CASE WHEN @SortColumn = 'totalAmount' AND @SortOrder = 'ASC' THEN NetPrice * ReceivedQty END,
			CASE WHEN @SortColumn = 'deliveryLineStatus' AND @SortOrder = 'ASC' THEN DeliveredLineStatus END,
			
			CASE WHEN @SortColumn = 'articleName' AND @SortOrder = 'DESC' THEN ArticleName END DESC,
			CASE WHEN @SortColumn = 'supplierArticleId' AND @SortOrder = 'DESC' THEN SupplierArticleID END DESC,
			CASE WHEN @SortColumn = 'ean' AND @SortOrder = 'DESC' THEN EANNo END DESC,
			CASE WHEN @SortColumn = 'netPrice' AND @SortOrder = 'DESC' THEN NetPrice END DESC,
			CASE WHEN @SortColumn = 'initialOrderedQty' AND @SortOrder = 'DESC' THEN OrderedQty END DESC,
			CASE WHEN @SortColumn = 'expectedDeliveredQty' AND @SortOrder = 'DESC' THEN DeliveredQty END DESC,
			CASE WHEN @SortColumn = 'quantity' AND @SortOrder = 'DESC' THEN ReceivedQty END DESC,
			CASE WHEN @SortColumn = 'transportationCost' AND @SortOrder = 'DESC' THEN TransportationCost END DESC,
			CASE WHEN @SortColumn = 'customsCost' AND @SortOrder = 'DESC' THEN CustomsCost END DESC,
			CASE WHEN @SortColumn = 'totalAmount' AND @SortOrder = 'DESC' THEN NetPrice * ReceivedQty END DESC,
			CASE WHEN @SortColumn = 'deliveryLineStatus' AND @SortOrder = 'DESC' THEN DeliveredLineStatus END DESC
	END
END


GO


