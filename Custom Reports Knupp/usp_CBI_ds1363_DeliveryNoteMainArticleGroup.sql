USE VBDCM
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.usp_CBI_ds1363_DeliveryNoteMainArticleGroup') AND type in (N'P', N'PC'))
	DROP PROCEDURE dbo.usp_CBI_ds1363_DeliveryNoteMainArticleGroup
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE dbo.usp_CBI_ds1363_DeliveryNoteMainArticleGroup
	(
	@DeliveryNoteNo VARCHAR(MAX)
	,@ExternalDeliveryNoteID VARCHAR(MAX)
	,@SortOrder VARCHAR(50)
	)
AS
BEGIN
IF @ExternalDeliveryNoteID IS NULL OR @ExternalDeliveryNoteID = ''
	BEGIN
		SELECT
			1								'DeliveryMode'
			,ArticleHierNo
			,inMainArticleGroup				'MainArticleGroup'
			,SUM(inOrderedQty)				'OrderedQty'
			-- ikke behov for det under her hvis ikke eksterne pakkseddler
			--,SUM(inDeliveredQty)			'DeliveredQty'
			,SUM(inReceivedQty)				'ReceivedQty'
			,SUM(inAdjustedQty)				'AdjustedQty'
			,SUM(inReceivedQty*inNetPrice)	'NetPrice'
			,SUM(inTransportationCost)		'TransportationCost'
			,SUM(inCustomsCost)				'CustomsCost'
		FROM
			(
			SELECT
				ah.ArticleHierNo
				,CONCAT(CAST(ah.ArticleHierNo AS VARCHAR(20)),' ',ah.ArticleHierName)	'inMainArticleGroup'
				,ISNULL(dl.InitialOrderedQtyUpdated, dl.InitialOrderedQty)				'inOrderedQty'
				-- ikke behov for det under her hvis ikke eksterne pakkseddler
				--,ISNULL(ddl.DeliveredQty, NULL)											'inDeliveredQty'
				,ISNULL((SELECT SUM(rl.ReceivedQty) FROM ReceivedLines AS rl WHERE rl.DeliveryNoteNo = dl.DeliveryNoteNo AND rl.DeliveryLineNo = dl.DeliveryLineNo AND rl.ReceivedLineStatus < 99), 0)	'inReceivedQty'
				,ISNULL((SELECT SUM(rla.AdjustmentQty) FROM ReceivedLines AS rl INNER JOIN ReceivedLineAdjustments AS rla ON (rla.DeliveryNoteNo = rl.DeliveryNoteNo AND rla.ReceivedLineNo = rl.ReceivedLineNo) WHERE rl.DeliveryNoteNo = dl.DeliveryNoteNo AND rl.DeliveryLineNo = dl.DeliveryLineNo AND rl.ReceivedLineStatus < 99), 0)	'inAdjustedQty'
				,dl.NetPrice															'inNetPrice'
				-- ikke behov for det under her hvis ikke eksterne pakkseddler
				--,ISNULL(ddl.NetPriceStoreCurrency, dl.NetPrice)							'inNetPrice'
				,ISNULL(dl.TransportationCost,0)										'inTransportationCost'
				,ISNULL(dl.CustomsCost,0)												'inCustomsCost'
			FROM
				DeliveryLines dl
			INNER JOIN DeliveryLineStates AS States ON (dl.DeliveryLineStatus = States.DeliveryLineStatus)
			INNER JOIN Articles AS a ON (a.ArticleNo = dl.ArticleNo)
			INNER JOIN ArticleHierarchys ah ON ah.ArticleHierNo=a.ArticleHierNo
			-- ikke behov for det under her hvis ikke eksterne pakkseddler
			--LEFT JOIN (SELECT DeliveryNoteNo, DeliveryLineNo, SUM(DeliveredQty) AS DeliveredQty, MAX(ActualDeliveryDate) AS ActualDeliveryDate, MAX(NetPriceStoreCurrency) AS NetPriceStoreCurrency
			--		   FROM DeliveredLines WHERE DeliveredLineStatus >= 20 AND DeliveredLineStatus < 99 GROUP BY DeliveryNoteNo, DeliveryLineNo) ddl ON ddl.DeliveryNoteNo = dl.DeliveryNoteNo AND ddl.DeliveryLineNo = dl.DeliveryLineNo
			WHERE 
				  dl.DeliveryNoteNo IN (SELECT state_split FROM splitStringToTable(@DeliveryNoteNo, ','))
			) deliveryLines
		GROUP BY
			ArticleHierNo
			,inMainArticleGroup
		ORDER BY
			CASE WHEN @SortOrder = 'ASC' THEN ArticleHierNo END,
			CASE WHEN @SortOrder = 'DESC' THEN ArticleHierNo END DESC
	END

	-- ######################  Top be implemented  @ExternalDeliveryNoteID IS NOT NULL  ##########
	-- ELSE IF @ExternalDeliveryNoteID IS NOT NULL 
	-- BEGIN
		-- SELECT * FROM (
			-- SELECT
				-- 2 AS DeliveryMode, 
				-- CONCAT(ah.ArticleHierNo,' ',ah.ArticleHierName)		'MainArticleGroup',
				-- MAX(a.ArticleID) ArticleID,
				-- MAX(a.PrimaryEAN) EANNo,
				-- MAX(dl.SupplierArticleID) SupplierArticleID,
				-- MAX(a.ArticleName) ArticleName,
				-- MAX(ddLines.DeliveredLineStatus) DeliveredLineStatus,
				-- MAX(states.DeliveredLineStatusName) StatusName,
				-- MAX(ddLines.ActualDeliveryDate) AS ActualDeliveryDate,
				-- (SELECT MAX(rl.CompletedReceivalDate) 
						-- FROM ReceivedLines AS rl 
						-- WHERE  rl.DeliveredLineNo = ddLines.DeliveredLineNo
						-- AND rl.DeliveryNoteNo = ddLines.DeliveryNoteNo 
						-- AND rl.ReceivedLineStatus < 99) 
						-- AS CompletedReceivalDate,
				-- MAX(dl.FpakInDpak) FpakInDpak,
				-- SUM(ISNULL(dl.InitialOrderedQtyUpdated,dl.InitialOrderedQty)) OrderedQty,	
				-- ISNULL(SUM(ddLines.DeliveredQty),0) AS DeliveredQty,
				-- ISNULL((SELECT SUM(rl.ReceivedQty) 
						-- FROM ReceivedLines AS rl 
						-- WHERE rl.DeliveredLineNo = ddLines.DeliveredLineNo 
						-- AND rl.DeliveryNoteNo = ddLines.DeliveryNoteNo 
						-- AND rl.ReceivedLineStatus < 99), 0) 
						-- AS ReceivedQty,
				-- ISNULL((SELECT SUM(rla.AdjustmentQty) 
						-- FROM ReceivedLines AS rl 
						-- INNER JOIN ReceivedLineAdjustments AS rla ON (rla.ReceivedLineNo = rl.ReceivedLineNo AND rla.DeliveryNoteNo = rl.DeliveryNoteNo) 
						-- WHERE rl.DeliveredLineNo = ddLines.DeliveredLineNo
						-- AND rl.DeliveryNoteNo = ddLines.DeliveryNoteNo 
						-- AND rl.ReceivedLineStatus < 99), 0) 
						-- AS AdjustedQty,
				-- MAX(ISNULL(ddLines.NetPriceStoreCurrency, dl.NetPrice)) NetPrice,
				-- SUM(dl.TransportationCost) AS TransportationCost,
				-- SUM(dl.CustomsCost) AS CustomsCost
			-- FROM DeliveredLines ddLines
			-- INNER JOIN dbo.DeliveryLines dl ON (ddLines.DeliveryNoteNo = dl.DeliveryNoteNo AND ddLines.DeliveryLineNo = dl.DeliveryLineNo)
			-- INNER JOIN Articles AS a ON (a.ArticleNo = dl.ArticleNo)
			-- LEFT OUTER JOIN ArticleHierarchys ah ON ah.ArticleHierNo=a.ArticleHierNo
			-- INNER JOIN DeliveredLineStates AS States ON (ddLines.DeliveredLineStatus = States.DeliveredLineStatus)
			-- WHERE ddLines.ExternalDeliveryNoteID in (SELECT state_split FROM splitStringToTable(@ExternalDeliveryNoteID, ','))
				-- AND ddLines.DeliveredLineStatus < 99
			-- GROUP BY CONCAT(ah.ArticleHierNo,' ',ah.ArticleHierName), ddLines.ExternalDeliveryNoteID,  ddLines.DeliveredLineNo, ddLines.DeliveryNoteNo
		-- ) deliveryLines
		-- ORDER BY
			-- CASE WHEN @SortOrder = 'ASC' THEN MainArticleGroup END,
			-- CASE WHEN @SortOrder = 'DESC' THEN MainArticleGroup END DESC
	-- END
END


GO


