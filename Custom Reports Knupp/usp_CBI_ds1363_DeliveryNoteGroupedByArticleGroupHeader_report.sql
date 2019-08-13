USE VBDCM
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.usp_CBI_ds1363_DeliveryNoteGroupedByArticleGroupHeader_report') AND type in (N'P', N'PC'))
	DROP PROCEDURE dbo.usp_CBI_ds1363_DeliveryNoteGroupedByArticleGroupHeader_report
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE dbo.usp_CBI_ds1363_DeliveryNoteGroupedByArticleGroupHeader_report
	(
	@DeliveryNoteNo VARCHAR(MAX)
	,@ExternalDeliveryNoteID VARCHAR(MAX)
	)
AS
BEGIN
IF @ExternalDeliveryNoteID IS NULL OR @ExternalDeliveryNoteID = ''
BEGIN
	SELECT
		CONVERT(VARCHAR(MAX),NULL) AS ExternalDeliveryNoteID,
		Del.DeliveryNoteNo DeliveryNoteNo,
		Del.DeliveryNoteText DeliveryNoteText,
		Del.DeliveryTypeNo,
		ISNULL(Del.StartReceivalDate, (SELECT MIN(rl.RecordCreated) FROM ReceivedLines AS rl WHERE  rl.DeliveryNoteNo in (SELECT state_split FROM splitStringToTable(@DeliveryNoteNo, ',')) AND rl.ReceivedLineStatus < 99)) AS StartReceivalDate,
		Del.CompletedReceivalDate CompletedReceivalDate,
		Del.ActiveDate ActiveDate,
		Del.SupplierOrderReferenceID,
		SStore.StoreName SenderName,
		Sup.SupplierName SupplierName,
		RStore.StoreName ReceiverName,
		RStore.PublicOrgNumber ReceiverOrgNo,
		RStore.EANLocationNo ReceiverEANNo,
		RStore.StoreVATNo ReceiverVATNo,
		RStore.Phone ReceiverPhone,
		RStore.StoreAdress ReceiverAddress,
		RStore.ZipCode ReceiverZipCode,
		RStore.ZipName ReceiverCity,
		RStore.ZipCountry ReceiverCountry
	FROM 
		Deliveries Del
		LEFT OUTER JOIN Stores SStore ON (Del.StoreNoSender = SStore.StoreNo)
		LEFT OUTER JOIN SupplierOrgs Sup ON (Del.SupplierNo = Sup.SupplierNo)
		JOIN Stores RStore ON (Del.StoreNo = RStore.StoreNo)
	WHERE 
		del.DeliveryNoteNo in (SELECT state_split FROM splitStringToTable(@DeliveryNoteNo, ','))
END

ELSE IF @ExternalDeliveryNoteID IS NOT NULL 
BEGIN
	SELECT 
		ddLines.ExternalDeliveryNoteID AS ExternalDeliveryNoteID,
		MAX(ddLines.DeliveryNoteNo) AS DeliveryNoteNo,
		MAX(Del.DeliveryNoteText) DeliveryNoteText,
		10 AS DeliveryTypeNo,
		ISNULL(MIN(del.StartReceivalDate), (SELECT MIN(rl.RecordCreated) FROM ReceivedLines AS rl WHERE  rl.DeliveryNoteNo = MAX(ddLines.DeliveryNoteNo) AND rl.ReceivedLineStatus < 99)) AS StartReceivalDate,
		MAX(del.CompletedReceivalDate) AS CompletedReceivalDate,
		NULL AS ActiveDate,
		MAX(ddLines.SupplierOrderReferenceID) AS SupplierOrderReferenceID,
		NULL AS SenderName,
		MAX(Sup.SupplierName) AS SupplierName,
		MAX(RStore.StoreName) AS ReceiverName,
		MAX(RStore.PublicOrgNumber) AS ReceiverOrgNo,
		MAX(RStore.EANLocationNo) AS ReceiverEANNo,
		MAX(RStore.StoreVATNo) AS ReceiverVATNo,
		MAX(RStore.Phone) AS ReceiverPhone,
		MAX(RStore.StoreAdress) AS ReceiverAddress,
		MAX(RStore.ZipCode) AS ReceiverZipCode,
		MAX(RStore.ZipName) ReceiverCity,
		MAX(RStore.ZipCountry) ReceiverCountry
	FROM 
		DeliveredLines ddLines 
		JOIN deliveries del ON ddLines.DeliveryNoteNo = del.DeliveryNoteNo 
		JOIN SupplierOrgs Sup ON (Del.SupplierNo = Sup.SupplierNo)
		JOIN Stores RStore ON (Del.StoreNo = RStore.StoreNo)
	WHERE 
		ddLines.ExternalDeliveryNoteID in (SELECT state_split FROM splitStringToTable(@ExternalDeliveryNoteID, ',') )
		AND ddLines.DeliveredLineStatus < 99
	GROUP BY 
		ddLines.ExternalDeliveryNoteID
	END
END


GO
