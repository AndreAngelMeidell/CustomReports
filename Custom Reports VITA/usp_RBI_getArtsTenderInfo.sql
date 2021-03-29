USE [BI_Stage]
GO

/****** Object:  StoredProcedure [dbo].[usp_RBI_getArtsTenderInfo]    Script Date: 24.02.2021 11:51:20 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE [dbo].[usp_RBI_getArtsTenderInfo] (@p1 bigint,@p2 bigint)
AS
BEGIN

  SET NOCOUNT ON;

  DECLARE @StartRowIdx bigint = @p1;
  DECLARE @StopRowIdx bigint = @p2;

 SELECT  
 ------------------------------
 ---- BASE OF RECEIPT
 ------------------------------
         H.sArtsXmlReceiptHeadIdx,
         H.sArtsXmlReceiptHeadIdx + R.RowNumber AS ReceiptTenderIdx,
         H.EndDateTime AS ReceiptDateTime,
         CAST(CONVERT(varchar, H.EndDateTime, 112) AS int) AS ReceiptDateIdx,
         CAST(H.EndDateTime AS date) AS ReceiptDate,
         CAST(CAST(H.EndDateTime AS time(1)) AS varchar(5)) AS ReceiptTime,
         H.UnitId AS StoreId,
         H.WorkstationId AS CashRegisterNo,
         CASE
			 WHEN TRIM(H.AssociateId) = 'apiRS.WebClient.Api' THEN 'System'
			 ELSE ISNULL(NULLIF(TRIM(H.AssociateId),''),'N/A') END AS UserName,
         H.SequenceNumber AS ReceiptId,
         CASE
           WHEN H.TrainingModeFlag = 1 THEN 3
           WHEN H.TransactionStatus = 'Canceled' THEN 2
           WHEN H.TransactionStatus IN ('Suspended','InProcess') THEN 4
           ELSE 1
         END AS ReceiptStatusId,
         CASE WHEN R.ForeignCurrencyCode IS NOT NULL THEN CAST(R.ForeignCurrencyCode AS char(3)) ELSE CAST(H.CurrencyCode AS char(3)) END AS CurrencyCode,
         ISNULL(H.CustomerId, '-1') AS CustomerId,
         R.LineType AS Name,
         -1 AS InternalNodeNumber,
         CASE WHEN H.TransactionStatus = 'PostVoided' THEN (CASE
            WHEN R.LineType IN ('Tender','TenderChange') THEN 
               CASE 
                    WHEN (R.LineType = 'TenderChange' AND TenderType IN ('Cash','CashHandlingSystem')) OR TenderType IN ('StoreAccountOut','TypiskNorskReturn') THEN ABS(ISNULL(Amount,0))*-1
                    WHEN (R.LineType = 'Tender' AND TenderType = 'CashHandlingSystem') OR TenderType = 'StoreAccount' THEN ABS(ISNULL(Amount,0))
                    WHEN TenderTypeCode = 'Refund' THEN ISNULL(Amount,0)*-1                    
                    ELSE ISNULL(Amount,0)
                END
            WHEN R.LineType IN ('PaidOut','PaidIn') THEN     ISNULL(Amount,0)     
           ELSE 0
         END)*-1 ELSE
         (CASE
            WHEN R.LineType IN ('Tender','TenderChange') THEN 
               CASE 
                    WHEN (R.LineType = 'TenderChange' AND TenderType IN ('Cash','CashHandlingSystem')) OR TenderType IN ('StoreAccountOut','TypiskNorskReturn') THEN ABS(ISNULL(Amount,0))*-1
                    WHEN (R.LineType = 'Tender' AND TenderType = 'CashHandlingSystem') OR TenderType = 'StoreAccount' THEN ABS(ISNULL(Amount,0))
                    WHEN TenderTypeCode = 'Refund' THEN ISNULL(Amount,0)*-1                    
                    ELSE ISNULL(Amount,0)
                END
            WHEN R.LineType IN ('PaidOut','PaidIn') THEN     ISNULL(Amount,0)     
           ELSE 0
         END) END AS Amount,
         ISNULL(R.ForeignCurrencyExchangeRate,1) AS ExchangeRateToLocalCurrency,
         CASE WHEN H.TransactionStatus = 'PostVoided' THEN (CASE
            WHEN R.LineType IN ('Tender','TenderChange') THEN 
               CASE 
                    WHEN (R.LineType = 'TenderChange' AND TenderType IN ('Cash','CashHandlingSystem')) OR TenderType IN ('StoreAccountOut','TypiskNorskReturn') THEN ABS(ISNULL(R.ForeignCurrencyOriginalFaceAmount,0))*-1
                    WHEN (R.LineType = 'Tender' AND TenderType = 'CashHandlingSystem') OR TenderType = 'StoreAccount' THEN ABS(ISNULL(R.ForeignCurrencyOriginalFaceAmount,0))
                    WHEN TenderTypeCode = 'Refund' THEN ISNULL(R.ForeignCurrencyOriginalFaceAmount,0)*-1                    
                    ELSE ISNULL(R.ForeignCurrencyOriginalFaceAmount,0)
                END
            WHEN R.LineType IN ('PaidOut','PaidIn') THEN     ISNULL(R.ForeignCurrencyOriginalFaceAmount,0)     
           ELSE 0
         END)*-1 ELSE (CASE
            WHEN R.LineType IN ('Tender','TenderChange') THEN 
               CASE 
                    WHEN (R.LineType = 'TenderChange' AND TenderType IN ('Cash','CashHandlingSystem')) OR TenderType IN ('StoreAccountOut','TypiskNorskReturn') THEN ABS(ISNULL(R.ForeignCurrencyOriginalFaceAmount,0))*-1
                    WHEN (R.LineType = 'Tender' AND TenderType = 'CashHandlingSystem') OR TenderType = 'StoreAccount' THEN ABS(ISNULL(R.ForeignCurrencyOriginalFaceAmount,0))
                    WHEN TenderTypeCode = 'Refund' THEN ISNULL(R.ForeignCurrencyOriginalFaceAmount,0)*-1                    
                    ELSE ISNULL(R.ForeignCurrencyOriginalFaceAmount,0)
                END
            WHEN R.LineType IN ('PaidOut','PaidIn') THEN     ISNULL(R.ForeignCurrencyOriginalFaceAmount,0)     
           ELSE 0
         END) END AS CurrencyAmount,
         1 AS Unit,       
         CASE WHEN H.TransactionStatus = 'PostVoided' THEN ISNULL(CashBack,0)*-1 ELSE ISNULL(CashBack,0) END AS Amount2,         
         CASE WHEN H.TransactionStatus = 'PostVoided' THEN ISNULL(CashFee,0)*-1 ELSE ISNULL(CashFee,0) END AS CashFee,
         CASE WHEN H.TransactionStatus = 'PostVoided' THEN ISNULL(Surcharge,0)*-1 ELSE ISNULL(Surcharge,0) END AS Surcharge,
         CAST(ISNULL(SurchargeName,'') AS VARCHAR(50)) AS SurchargeName,
         TenderType,
         ISNULL(IssuerIdentificationNumber,'-1') AS SubTenderId,
------------------------------------------------------
--- TENDER ID
------------------------------------------------------
         CAST(CASE
		 ------------------ THIS IS 17.2 POS CUSTOM AND STANDARD TENDERS
           WHEN R.InternalTenderId IS NOT NULL 
				THEN R.InternalTenderId
         ----------------  THIS IS < 17.2 POS STANDARD TENDERS
		   WHEN R.LineType IN ('Tender','TenderChange','PaidIn','PaidOut') AND TenderType = 'CASH' AND R.ForeignCurrencyExchangeRate IS NULL 
				THEN '1' --Payment in local currency 
           WHEN R.LineType IN ('Tender','TenderChange','PaidIn','PaidOut') AND TenderType = 'CASH' AND ISNULL(H.CurrencyCode,'N/A') != ISNULL(R.ForeignCurrencyCode,'N/A')
				THEN '8' --Payment in foreign currency 
           WHEN R.TenderType = 'HouseAccount' 
				THEN '4'
           WHEN R.TenderType = 'CreditDebit' AND HostAuthorized = 0 
				THEN '5'
           WHEN R.TenderType = 'CreditDebit' AND AutorizationMethod = 'Automatically' 
				THEN '3'
           WHEN R.TenderType = 'CreditDebit' AND AutorizationMethod = 'Manually' 
				THEN '14'
           WHEN R.TenderType = 'CustomerAccount' 
				THEN '6'
           WHEN R.TenderType = 'Coupon' 
				THEN '23'
           WHEN R.TenderType = 'Mobile' 
				THEN '22'
           WHEN R.TenderType = 'GiftCard' 
				THEN '2'
           WHEN REPLACE(R.TenderType, 'VRExt:', '') = 'CashHandlingSystem' 
				THEN '9'
           WHEN R.TenderType = 'StoreAccount' 
				THEN '10'
           WHEN R.TenderType = 'StoreAccountOut' 
				THEN '11'
           WHEN R.TenderType = 'Loyalty' 
				THEN '12'
           WHEN R.TenderType = 'BasketLotteryPrize' 
				THEN '15'
           WHEN R.TenderType = 'Ikano' 
				THEN '16'
           WHEN R.TenderType = 'Retain24In' 
				THEN '17'
		   WHEN R.TenderType = 'Retain24Out' 
				THEN '18'
           WHEN R.TenderType = 'Voucher' 
				THEN '19'
           WHEN R.TenderType = 'OnlinePayment' 
				THEN '24'
           WHEN R.TenderType = 'TypiskNorskDiscount' 
				THEN '20'
           WHEN R.TenderType = 'TypiskNorskReturn' 
				THEN '21'
           WHEN R.TenderType = 'RecyclingLotteryPrize' 
				THEN '25'
           WHEN R.TenderType = 'PurchaseOrder' 
				THEN '26'
		   WHEN R.TenderType = 'AccountsReceivable' 
				THEN '33'
		   WHEN R.TenderType = 'AccountsPayable' 
				THEN '34'
           ----------------  THIS IS < 17.2 POS CUSTOM TENDERS
		   --Custom
		   WHEN r.TenderType = 'trollweb_vipps' THEN '327' --New 20200526
		   WHEN r.TenderType = 'trollwebvipps'	THEN '327' --New cause of wrong tag from Magento 20190110 Andre
		   WHEN r.TenderType = 'KCO3'			THEN '328' --20201110 New webshop Andre
		   WHEN r.TenderType = 'VIPPS'			THEN '327' --20201110 New webshop Andre

           WHEN TT.TenderId IS NOT NULL  
				THEN TT.TenderId	
		   ------ UNKNOWN
		   ELSE -4 END AS VARCHAR(50)) AS TenderId,
-----------------------------------------------------------
-- TRANSACTION TYPE
-----------------------------------------------------------
           CASE
		    ------------------ THIS IS 17.2 POS CUSTOM TENDERS
           WHEN R.InternalTenderId IS NOT NULL AND R.InternalTenderId >= 100 THEN TTT.[TransactionTypeId]
		    ------------------ THIS IS 17.2 POS STANDARD TENDERS
		   WHEN R.LineType = 'Tender' AND TenderType = 'Cash' 
				THEN 20101
		   WHEN R.LineType = 'Tender' AND TenderType = 'CashHandlingSystem' 
				THEN 20102
		   WHEN R.LineType = 'TenderChange' AND TenderType = 'Cash' 
				THEN 21301
		   WHEN R.LineType = 'TenderChange' AND TenderType = 'CashHandlingSystem' 
				THEN 21302
		   WHEN R.TenderType = 'CustomerAccount' 
				THEN 20202
		   WHEN R.TenderType IN ('Check','Loyalty') 
				THEN 20501
		   WHEN R.TenderType = 'Ikano' 
				THEN 20206
		   WHEN R.TenderType = 'CreditDebit' AND HostAuthorized = 0 
				THEN 20301 
		   WHEN R.TenderType = 'CreditDebit' AND AutorizationMethod = 'Automatically' 
				THEN 20303
		   WHEN R.TenderType = 'CreditDebit' AND AutorizationMethod = 'Manually' 
				THEN 20302
		   WHEN R.TenderType IN ('GiftCard','Retain24In') 
				THEN 20702
           WHEN R.TenderType = 'StoreAccountOut' 
				THEN 20704		   
           WHEN R.TenderType = 'StoreAccount' 
				THEN 20705		
           WHEN R.TenderType = 'HouseAccount' 
				THEN 20201                      
		   WHEN R.TenderType = 'Coupon' 
				THEN 21102
		   WHEN R.TenderType = 'Mobile' 
				THEN 20401
		   WHEN R.TenderType = 'OnlinePayment' 
				THEN 21201
		   WHEN R.TenderType = 'Voucher' 
				THEN 20709
           WHEN R.TenderType IN ('TypiskNorskDiscount','TypiskNorskReturn') 
				THEN 20710
           WHEN R.TenderType = 'RecyclingLotteryPrize' 
				THEN 20906	
           WHEN R.LineType = 'PaidIn' 
				THEN 20104 
           WHEN R.LineType = 'PaidOut' 
				THEN 21304 
           WHEN R.TenderType = 'PurchaseOrder' 
				THEN 40303 
           WHEN R.TenderType = 'RXBagPayment' 
				THEN 20805 	
						
		   --Custom for Store 4001
		   WHEN r.TenderType = 'trollweb_vipps'		THEN 21201
		   WHEN r.TenderType = 'trollwebvipps'		THEN 21201
		   WHEN r.TenderType = 'kco_checkout'		THEN 21201 
		   WHEN r.TenderType = 'klarna_kco'			THEN 21201	--20200508 Dag Erik new Type
		   WHEN r.TenderType = 'paypal_standard'	THEN 21201  
		   WHEN r.TenderType = 'KCO3'				THEN 21201  --20201110 New webshop Andre
		   WHEN r.TenderType = 'VIPPS'				THEN 21201  --20201110 New webshop Andre 		

		   ------ UNKNOWN
           ELSE -3 END AS TransTypeIdx,
-----------------------------------------------------------
-- TRANSACTION TYPE ID (seems outdated)
-----------------------------------------------------------
		   CASE 
		   WHEN R.LineType = 'PaidIn' THEN 113 
           WHEN R.LineType = 'PaidOut' THEN 114 
           ELSE 12 END AS sTransactionTypeId
-----------------------------------------------------------
  FROM [RBIS].[tmpArtsXmlReceiptHead] H WITH(NOLOCK)
  INNER JOIN [RBIS].[tmpArtsXmlReceiptRow] R WITH(NOLOCK)
    ON R.sArtsXmlReceiptHeadIdx = H.sArtsXmlReceiptHeadIdx
------ TENDERID MAPPING - ONLY CUSTOM TENDERS - < 17.2
  LEFT OUTER JOIN BI_Mart.RBIM.Dim_Tender TT WITH(NOLOCK) 
    ON TT.TenderName = R.TenderType AND TT.TenderId >= 100 
------ TRANSACTION MAPPING - ONLY CUSTOM TENDERS 
  LEFT OUTER JOIN [BI_Stage].[RBIS].[Lcp_TenderTransactionType] AS TTT WITH(NOLOCK) 
    ON CASE	
			WHEN R.InternalTenderId IS NULL 
				THEN R.TenderType 
				ELSE R.InternalTenderId END = 
		CASE 
			WHEN R.InternalTenderId IS NULL 
				THEN TTT.TenderName
				ELSE TTT.TenderId END
		AND R.LineType = TTT.LineType AND TTT.TenderId >= 100
----------------------------------
  WHERE  H.RowIdx BETWEEN @StartRowIdx AND @StopRowIdx AND RIGHT(H.sartsxmlreceiptheadidx,4) NOT IN (0100,5000)
END


GO

