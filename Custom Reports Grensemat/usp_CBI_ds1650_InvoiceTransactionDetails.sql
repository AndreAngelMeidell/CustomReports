-- 2. [usp_CBI_ds1650_InvoiceTransactionDetails]
-- Table in second page with detail rows
IF OBJECT_ID('usp_CBI_ds1650_InvoiceTransactionDetails') IS NOT NULL DROP PROCEDURE [dbo].[usp_CBI_ds1650_InvoiceTransactionDetails]
GO

CREATE PROCEDURE [dbo].[usp_CBI_ds1650_InvoiceTransactionDetails](@InvoiceId BIGINT, @StoreGroupId NVARCHAR(50))
AS
/*

------------------------------------------------------------------------------------------------------------------------------
-- /*Added payment part to standard proc */
------------------------------------------------------------------------------------------------------------------------------

	declare @InvoiceId BIGINT = 6	
			, @StoreGroupId NVARCHAR(50) =  1004
--*/

	SELECT CONVERT(DATE,r.ReceiptDate) AS ReceiptDate,r.ReceiptNo, CAST(r.ReceiptId AS VARCHAR(MAX)) AS Description, ISNULL(r.TotalAmount,0) + ISNULL(r.DiscountAmount, 0) AS GrossAmount,
		ISNULL(r.DiscountAmount, 0) AS DiscountAmount, r.TotalAmount - r.VatAmount AS TotalAmountExcVat, r.VatAmount, r.TotalAmount, 0 AS RowType, 0 AS ReceiptRowRefNumber, r.RequisitionNumber, r.CustomerReference
		,CASE WHEN LEN(r.CustomerIdentification) <= 4 THEN NULL
		 ELSE STUFF(r.CustomerIdentification, LEN(r.CustomerIdentification) - 3, 4, REPLICATE('*',4)) END AS CustomerIdentification
		,NULL AS EuSubTaxCode
		INTO #TempTransactionsDetails
		FROM dbo.Receipts r
		INNER JOIN dbo.InvoiceReceipts ir ON r.ReceiptNo = ir.ReceiptNo
		INNER JOIN dbo.Invoices i ON ir.InvoiceNo = i.InvoiceNo
		WHERE i.InvoiceId = @InvoiceId AND i.StoreGroupId = @StoreGroupId
		UNION ALL
		SELECT null, rr.receiptNo,
		rr.ReceiptText, ISNULL(rr.QuantityAmount, rr.TotalPrice),
		CASE WHEN rr.TransactionType = 1 OR rr.TransactionType = 6
			THEN ISNULL((SELECT SUM(TotalPrice) FROM dbo.ReceiptRows WHERE ReceiptNo = rr.ReceiptNo AND ReceiptRowRefNumber = rr.ReceiptRowRefNumber AND TransactionType = 2 GROUP BY ReceiptNo),0)
			ELSE 0 
		END AS DiscountAmount,
		rr.TotalPrice - dbo.vrfn_GetTaxAmount(rr.TotalPrice,rr.VatRate) AS TotalAmountExcVat, dbo.vrfn_GetTaxAmount(rr.TotalPrice,rr.VatRate) AS VatAmount, rr.TotalPrice, rr.TransactionType,rr.ReceiptRowRefNumber, NULL,NULL, NULL,
		rr.EuSubTaxCode AS EuSubTaxCode
	FROM dbo.ReceiptRows rr 
	INNER JOIN dbo.Receipts r ON r.ReceiptNo = rr.ReceiptNo
	INNER JOIN dbo.InvoiceReceipts ir ON r.ReceiptNo = ir.ReceiptNo
	INNER JOIN dbo.Invoices i ON ir.InvoiceNo = i.InvoiceNo
	WHERE i.InvoiceId = @InvoiceId AND i.StoreGroupId = @StoreGroupId
	AND rr.TransactionType IN (1,6,62,64)
	UNION
	SELECT 
		CONVERT(DATE, p.PaymentDate) AS PaymentDate, NULL AS ReceiptNo, CAST('Betalning' AS VARCHAR(MAX)) AS Description, 0 AS GrossAmount, 0 AS DiscountAmount, 
		0 AS TotalAmountExcVat, 0 AS VatAmount, -TotalAmount AS TotalAmount, 0 AS RowType, 0 AS ReceiptRowRefNumber, NULL AS RequisitionNumber , NULL AS CustomerReference, 
		NULL AS CustomerIdentification, NULL AS EuSubTaxCode
	FROM dbo.Payments p
	INNER JOIN dbo.Invoices i ON i.InvoiceNo = p.InvoiceNo
	WHERE i.InvoiceId =  @InvoiceId AND i.StoreGroupId = @StoreGroupId  /*Added payment part to standard proc */

	SELECT * FROM #TempTransactionsDetails
	ORDER BY ISNULL(ReceiptNo, 9223372036854775807), (CASE WHEN ReceiptDate IS NULL THEN 1 ELSE 0 END), ReceiptRowRefNumber, ReceiptDate
GO
