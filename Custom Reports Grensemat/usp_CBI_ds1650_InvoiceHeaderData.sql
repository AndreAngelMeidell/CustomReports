
-- 3. [usp_CBI_ds1650_InvoiceHeaderData]
IF OBJECT_ID('usp_CBI_ds1650_InvoiceHeaderData') IS NOT NULL DROP PROCEDURE [dbo].[usp_CBI_ds1650_InvoiceHeaderData]
GO
CREATE PROCEDURE [dbo].[usp_CBI_ds1650_InvoiceHeaderData](@InvoiceId BIGINT, @StoreGroupId NVARCHAR(50))
AS

/*
------------------------------------------------------------------------------------------------------------------------------
-- /*Added payment part to standard proc */
------------------------------------------------------------------------------------------------------------------------------

	declare @InvoiceId BIGINT = 6	
			, @StoreGroupId NVARCHAR(50) =  1004
--*/
	;WITH invoiceValueTotals AS(
		SELECT InvoiceId, SUM(GrossAmount) AS SumGrossAmount, 	SUM(DiscountAmount) AS SumDiscountAmount, 
		SUM(TotalAmountExcVat) AS SumTotalAmountExcVat,	SUM(VatAmount) AS SumVatAmount, SUM(TotalAmount) SumTotalAmount
		FROM (
			SELECT invoiceid,  ISNULL(r.TotalAmount,0) + ISNULL(r.DiscountAmount, 0) AS GrossAmount,
			ISNULL(r.DiscountAmount,0) AS DiscountAmount, r.TotalAmount - r.VatAmount AS TotalAmountExcVat, r.VatAmount, r.TotalAmount
			FROM invoices i
			INNER JOIN dbo.InvoiceReceipts ir ON ir.InvoiceNo = i.InvoiceNo
			INNER JOIN dbo.Receipts r ON r.ReceiptNo = ir.ReceiptNo
			WHERE i.InvoiceId = @InvoiceId AND i.StoreGroupId = @StoreGroupId
			UNION 
			SELECT invoiceid, InvoiceCost,0.00, InvoiceCost - dbo.vrfn_GetTaxAmount(InvoiceCost, InvoiceCostVATPercent) AS TotalAmountExcVat,
			dbo.vrfn_GetTaxAmount(InvoiceCost, InvoiceCostVATPercent) AS VatAmount, InvoiceCost
			FROM invoices 
			WHERE invoiceid = @InvoiceId AND StoreGroupId = @StoreGroupId
			AND InvoiceTypeNo <> 1 --Invoice cost not on interest invoice
			AND InvoiceCost > 0
			UNION
			SELECT i.InvoiceId, ir.ReminderFee,0.00,ir.ReminderFee,0.00, ir.ReminderFee
			FROM dbo.InvoiceReminders ir 
			INNER JOIN dbo.Invoices i ON i.InvoiceNo = ir.InvoiceNo
			WHERE i.InvoiceId =  @InvoiceId AND i.StoreGroupId = @StoreGroupId
			AND ir.ReminderFee > 0
		) r
		GROUP BY InvoiceId
	)
	SELECT i.InvoiceId, InvoiceTypeNo, ISNULL(ReminderDate,InvoiceDate) InvoiceDate, ISNULL(ReminderDueDate,ExpireDate) ExpireDate, i.CustomerId, CustomerName,CustomerAddressLine1,
	 NULLIF(CustomerAddressLine2, '') AS CustomerAddressLine2, NULLIF(CustomerAddressLine3, '') AS CustomerAddressLine3, CustomerAddressZipCode, CustomerAddressZipName,
	PostAddressLine, PostAddressZipCode, PostAddressZipName, InvoiceReminderText, Iban, Swift, Email,ChildCustomerName, ParentCustomerId, CustomerAlias,
	TotalAmount, TotalVatAmount,  Rounding, OcrNumber, OrganizationNo, BankAccount, PhoneNumber, NULLIF(CustomerPhoneNumber, '') AS CustomerPhoneNumber, OriginalInvoiceId, StoreName, StoreGroupName
	,i.VatNo ,ISNULL(Payments,0) Payments, ISNULL(ir.ReminderNo, 0) ReminderNo, InvoiceCopyCount,
	ISNULL(InvoiceLogoUrl, (SELECT ValueStr FROM dbo.RsParameters WHERE ParameterName = 'LogoUrl')) AS InvoiceLogoUrl,
	SumGrossAmount, SumDiscountAmount, SumTotalAmountExcVat,SumVatAmount, SumTotalAmount
	,ISNULL(cusInvInf.PaymentTermsInDays, 0) AS PaymentTermsInDays
	FROM dbo.Invoices i
	LEFT JOIN (SELECT Invoiceno, SUM(Amount) Payments FROM dbo.Payments GROUP BY InvoiceNo) p ON p.InvoiceNo = i.InvoiceNo 
	LEFT JOIN (SELECT InvoiceNo, MAX(ReminderNo) ReminderNo, MAX(ReminderDate) ReminderDate, MAX(DueDate) ReminderDueDate FROM dbo.InvoiceReminders GROUP BY InvoiceNo) ir ON ir.InvoiceNo = i.InvoiceNo
	LEFT JOIN invoiceValueTotals invT ON invT.InvoiceId = i.InvoiceId
	LEFT JOIN (
				SELECT cus.CustomerID, cii.StoreGroupNo, cii.PaymentTermsInDays AS PaymentTermsInDays
				FROM VBDCM.dbo.CustomerInvoiceInformations cii with (nolock)
				LEFT JOIN VBDCM.[dbo].[Customers] cus with (nolock) on cii.CustomerNo = cus.CustomerNo
	) cusInvInf ON cusInvInf.CustomerID = i.CustomerId AND cusInvInf.StoreGroupNo = i.StoreGroupId
	WHERE i.invoiceid = @InvoiceId AND i.StoreGroupId = @StoreGroupId


GO
