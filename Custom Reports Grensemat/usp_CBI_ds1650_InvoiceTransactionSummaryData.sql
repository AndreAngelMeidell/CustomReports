
-- 1 [usp_CBI_ds1650_InvoiceTransactionSummaryData]
-- CBI proc with payment for Invoice Transaction Summary (Table in first page)
IF OBJECT_ID('usp_CBI_ds1650_InvoiceTransactionSummaryData') IS NOT NULL DROP PROCEDURE [dbo].[usp_CBI_ds1650_InvoiceTransactionSummaryData]
GO

CREATE PROCEDURE [dbo].[usp_CBI_ds1650_InvoiceTransactionSummaryData](@InvoiceId BIGINT, @StoreGroupId NVARCHAR(50))
AS
/*
------------------------------------------------------------------------------------------------------------------------------
-- /*Added payment part to standard proc */
------------------------------------------------------------------------------------------------------------------------------

declare @InvoiceId BIGINT = 6	
		, @StoreGroupId NVARCHAR(50) =  1004
--*/
	SELECT * FROM (
		SELECT CONVERT(DATE,r.ReceiptDate) AS ReceiptDate, r.ReceiptId, ISNULL(r.TotalAmount,0) + ISNULL(r.DiscountAmount, 0) AS GrossAmount,
		ISNULL(r.DiscountAmount,0) AS DiscountAmount, r.TotalAmount - r.VatAmount AS TotalAmountExcVat, r.VatAmount, r.TotalAmount, 1 AS RowType
		FROM invoices i
		INNER JOIN dbo.InvoiceReceipts ir ON ir.InvoiceNo = i.InvoiceNo
		INNER JOIN dbo.Receipts r ON r.ReceiptNo = ir.ReceiptNo
		WHERE i.InvoiceId = @InvoiceId AND i.StoreGroupId = @StoreGroupId
		UNION 
		SELECT NULL, NULL, InvoiceCost,0.00, InvoiceCost - dbo.vrfn_GetTaxAmount(InvoiceCost, InvoiceCostVATPercent) AS TotalAmountExcVat,
		dbo.vrfn_GetTaxAmount(InvoiceCost, InvoiceCostVATPercent) AS VatAmount, InvoiceCost, 2 AS RowType
		FROM invoices 
		WHERE invoiceid = @InvoiceId AND StoreGroupId = @StoreGroupId
		AND InvoiceTypeNo <> 1 --Invoice cost not on interest invoice
		AND InvoiceCost > 0
		UNION
		SELECT NULL, NULL, ir.ReminderFee,0.00,ir.ReminderFee,0.00, ir.ReminderFee, 3 AS RowType
		FROM dbo.InvoiceReminders ir 
		INNER JOIN dbo.Invoices i ON i.InvoiceNo = ir.InvoiceNo
		WHERE i.InvoiceId =  @InvoiceId AND i.StoreGroupId = @StoreGroupId
		AND ir.ReminderFee > 0
		UNION /*Added payment part to standard proc */
		SELECT CONVERT(DATE, p.PaymentDate) AS PaymentDate, NULL AS ReceiptId, 0 AS GrossAmount, 0 AS DiscountAmount, 0 TotalAmountExcVat, 0 AS VatAmount, -p.Amount AS PayAmount, 3 AS RowType
		FROM dbo.Payments p
		INNER JOIN dbo.Invoices i ON i.InvoiceNo = p.InvoiceNo
		WHERE i.InvoiceId =  @InvoiceId AND i.StoreGroupId = @StoreGroupId
	) r
	ORDER BY (CASE WHEN r.ReceiptDate IS NULL THEN 1 ELSE 0 END), r.ReceiptDate, (CASE WHEN r.ReceiptId IS NULL THEN 1 ELSE 0 END)
GO

