-- 4. [usp_CBI_ds1650_InvoiceTransactionSummaryDataTotal]
-- Table for first tables total calculations
IF OBJECT_ID('usp_CBI_ds1650_InvoiceTransactionSummaryDataTotal') IS NOT NULL DROP PROCEDURE [dbo].[usp_CBI_ds1650_InvoiceTransactionSummaryDataTotal]
GO

CREATE PROCEDURE [dbo].[usp_CBI_ds1650_InvoiceTransactionSummaryDataTotal](@InvoiceId BIGINT, @StoreGroupId NVARCHAR(50))
AS
/*

declare @InvoiceId BIGINT = 16	
		, @StoreGroupId NVARCHAR(50) =  1004
--*/

	SELECT SUM(DiscountAmount) AS SumDiscountAmount, SUM(TotalAmountExcVat) AS SumTotalAmountExcVat, SUM(VatAmount) AS SumVatAmount, SUM(TotalAmount) AS SumTotalAmount
	FROM (
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
	) r
	GROUP BY RowType

GO


