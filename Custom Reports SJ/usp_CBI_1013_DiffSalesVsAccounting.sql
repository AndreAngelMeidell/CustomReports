USE [BI_Stage]
GO

IF OBJECT_ID('usp_CBI_1013_DiffSalesVsAccounting') IS NOT NULL DROP PROCEDURE [dbo].[usp_CBI_1013_DiffSalesVsAccounting] 
GO

CREATE PROCEDURE [dbo].[usp_CBI_1013_DiffSalesVsAccounting]
@DiffCounted int = 0
,@DiffAmountSEK int = 0
,@DiffAmountNOK int = 0
,@DiffAmountDKK int = 0
,@DiffAmountEUR int = 0
,@DiffAmountCHF int = 0
,@DiffAmountGBP int = 0
,@DiffAmountUSD int = 0
,@FromDate datetime = '' 
,@ToDate datetime= ''
,@User nvarchar(max) = 'All'


AS

SET NOCOUNT ON;

-- =============================================
-- Author:		Rikard Johansson
-- Description: 
--				All data comes from DA-application. The report shows all rows per user that has a difference between Sales and reported in DA. 
--				The report user can set the "allowed difference" per transactiontype himself\herself.
-- Note:		Sp dependent on the following function: dbo.FnSplit()
-- Note:		Testfall i DA-tabeller finns i följande AccountingID:s 1092,1090,1089,1088,1087,1086,1085,1084,1083,1082
-- Note:		Dataset is created for each transactiontype below
--									 TransType 10 + Valuta=SEK
--									 TransType 71 + Valuta=NOK
--									 TransType 71 + Valuta=DKK
--									 TransType 71 + Valuta EUR
--  								 TransType 71 + Valuta CHF
--									 TransType 3 = Coupon
--									 TransType 312 = Kort signaturslip		
--									 TransType 12 = Is not included in the report since users cannot register on this TransType.									 			
-- Change date: 										
-- Create date: 2016-02-08
-- To Run:		usp_CBI_Rep13_DiffSalesVsAccounting 
-- =============================================
 

	--Declaration of different transaction types
	DECLARE @TransType_Sek int = 10; --SEK amount
	DECLARE @TransType_Curr int = 71; --Other currency amount, not SEK
	DECLARE @TransType_Coupon int = 3; --Coupons quantity
	DECLARE @TransType_SignSlips int = 312; --Kort signaturslip quantity
	DECLARE @TransType_Refund int = 310; --Refund signaturslip quantity

	CREATE Table #DiffTempTable
		(DiffCounted int,
		 DiffAmountSEK int,
		 DiffAmountNOK int,
		 DiffAmountDKK int,
		 DiffAmountEUR int,
		 DiffAmountCHF int,
		 DiffAmountGBP int,
		 DiffAmountUSD int)
	 
	INSERT INTO #DiffTempTable (DiffCounted, DiffAmountSEK, DiffAmountNOK, DiffAmountDKK, DiffAmountEUR, DiffAmountCHF, DiffAmountGBP, DiffAmountUSD)
	SELECT @DiffCounted, @DiffAmountSEK, @DiffAmountNOK, @DiffAmountDKK, @DiffAmountEUR, @DiffAmountCHF, @DiffAmountGBP, @DiffAmountUSD;


	WITH getTransactionType AS (
		SELECT Reported.AccountingID
				,Reported.Currency
				,DAHead.CreationDateTime
				,DAHead.CashierID
				,Reported.TransactionTypeId
				,Reported.TransactionTypeName
				,CASE
					WHEN Reported.TransactionTypeId=@TransType_Sek AND Reported.Currency = 'SEK' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountSEK THEN ISNULL(POS.Amount,0)
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'NOK' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountNOK THEN ISNULL(POS.Amount,0)
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'DKK' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountDKK THEN ISNULL(POS.Amount,0)
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'EUR' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountEUR THEN ISNULL(POS.Amount,0) 
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'CHF' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountCHF THEN ISNULL(POS.Amount,0)
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'GBP' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountGBP THEN ISNULL(POS.Amount,0)
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'USD' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountUSD THEN ISNULL(POS.Amount,0)
					WHEN Reported.TransactionTypeId=@TransType_Coupon AND ABS(ISNULL(POS.Counted,0)-ISNULL(Reported.Counted,0)) > tmp.DiffCounted THEN ISNULL(POS.Counted,0)
					WHEN Reported.TransactionTypeId=@TransType_SignSlips AND ABS(ISNULL(POS.Counted,0)-ISNULL(Reported.Counted,0)) > tmp.DiffCounted THEN ISNULL(POS.Counted,0)
					WHEN Reported.TransactionTypeId=@TransType_Refund AND ABS(ISNULL(POS.Counted,0)-ISNULL(Reported.Counted,0)) > tmp.DiffCounted THEN ISNULL(POS.Counted,0)
				END AS 'POS'
				,CASE
					WHEN Reported.TransactionTypeId=@TransType_Sek AND Reported.Currency = 'SEK' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountSEK THEN Reported.Amount
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'NOK' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountNOK THEN Reported.Amount
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'DKK' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountDKK THEN Reported.Amount
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'EUR' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountEUR THEN Reported.Amount 
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'CHF' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountCHF THEN Reported.Amount
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'GBP' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountGBP THEN Reported.Amount 
					WHEN Reported.TransactionTypeId=@TransType_Curr AND Reported.Currency = 'USD' AND ABS(ISNULL(POS.Amount,0)-ISNULL(Reported.Amount,0)) > tmp.DiffAmountUSD THEN Reported.Amount
					WHEN Reported.TransactionTypeId=@TransType_Coupon AND ABS(ISNULL(POS.Counted,0)-ISNULL(Reported.Counted,0)) > tmp.DiffCounted THEN Reported.Counted
					WHEN Reported.TransactionTypeId=@TransType_SignSlips AND ABS(ISNULL(POS.Counted,0)-ISNULL(Reported.Counted,0)) > tmp.DiffCounted THEN Reported.Counted
					WHEN Reported.TransactionTypeId=@TransType_Refund AND ABS(ISNULL(POS.Counted,0)-ISNULL(Reported.Counted,0)) > tmp.DiffCounted THEN Reported.Counted
				END AS 'Reported'	
	--select *
		FROM CBIS.DA_ReportedCounting Reported
			LEFT JOIN CBIS.DA_PosReportedPayments POS 
				ON Reported.AccountingId = POS.AccountingId
				AND Reported.Currency = POS.Currency
				AND Reported.TransactionTypeId = POS.TransactionTypeId
			LEFT JOIN CBIS.DA_AccountingHead DAHead
				ON Reported.AccountingId = DAHead.AccountingId
			LEFT JOIN #DiffTempTable tmp
				ON 1=1
		WHERE Reported.Status_short = 0 -- 0=Submited, 1=Approved
			AND DAHead.DiffWasSeen = 'YES'
			)


	SELECT x.AccountingID
		,x.TransactionTypeId
		,x.TransactionTypeName
		,x.Currency
		,x.CashierId
		,CONCAT(Users.FirstName, ' ',Users.LastName ) CashierName
		,x.CreationDateTime
		,SUM(x.POS) AS 'POS'
		,SUM(x.Reported) AS 'Reported'
		,ISNULL(SUM(x.Reported-x.POS),0) AS 'Diff'
	FROM getTransactionType x
	LEFT JOIN RBIS.sUsersXML_RS Users 
		ON x.CashierId = Users.UserName 
	WHERE Users.IsCurrent = 1 
		AND x.CreationDateTime >= @FromDate AND  x.CreationDateTime <= CAST(CONVERT(VARCHAR(10), @ToDate, 120) + ' 23:59:59' AS DATETIME)
		AND x.CashierId IN (SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString](@User,',')) 
		AND (x.POS is NOT NULL AND x.Reported is NOT NULL)
	GROUP BY x.AccountingID
		,x.TransactionTypeId
		,x.TransactionTypeName
		,x.Currency
		,x.CashierId
		,Users.FirstName
		,Users.LastName
		,x.CreationDateTime
	ORDER BY x.CashierId
		,x.TransactionTypeId
		,x.Currency



GO


