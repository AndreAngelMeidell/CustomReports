USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_AntallRetur]    Script Date: 03.09.2019 10:49:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[usp_CBI_AntallRetur]
AS
BEGIN

--TRN Sikkerhet rapport 2 av 3 -AntallRetur

SET NOCOUNT ON;

	DECLARE @tableHTML  NVARCHAR(MAX) 
	DECLARE @Recipients varchar(1000)
	set @Recipients='trn.sikkerhet@dutyfree.no' -- 'trn.sikkerhet@dutyfree.no' --


	SET @tableHTML =
		N'<H3>Bonger som har hatt Returnerte varer i går</H3>' +
		N'<table border="1">' +
		N'<tr>'+
		N'<th>ButikkNr</th>' +
		N'<th>Dato</th>' +
		N'<th>Tid</th>' +
		N'<th>KasseNr</th>' +
		N'<th>Bongnr</th>' +
		N'<th>Kasserernr</th>' +
		N'<th>AntallVarer</th>' +
		N'<th>BeløpRetur</th>' +
		--N'<th></th>' +
		--N'<th></th>' +
		N'</tr>' +
		
		cast (
			(select  
				td = ds.StoreId,						'',--Butikknr
				td = DD.FullDate,						'',--Dato
				td = dt.TimeDescription,				'',--Time
				td = ACSARPR.CashRegisterNo,			'',--KasseNr 
				td = ACSARPR.ReceiptId,					'',--Bongnr
				td = DSU.UserName,						'',--Kasserer
				td = ACSARPR.NumberOfScannableArticles, '',--Antall Return old:ACSARPR.NumberOfReceiptsWithRetur
				td = CAST(ACSARPR.ReturnAmount AS DECIMAL(18,2)) ,		''--Beløp Return
				FROM  RBIM.Agg_CashierSalesAndReturnPerReceipt AS ACSARPR (NOLOCK)
				JOIN RBIM.Dim_Store AS DS (NOLOCK) ON DS.StoreIdx = ACSARPR.StoreIdx
				JOIN RBIM.Dim_Date AS DD (NOLOCK) ON ACSARPR.ReceiptDateIdx=dd.DateIdx
				JOIN RBIM.Dim_Time AS DT (NOLOCK) ON ACSARPR.ReceiptTimeIdx=dt.TimeIdx
				JOIN RBIM.Dim_SystemUser AS DSU (NOLOCK) ON dsu.SystemUserIdx=ACSARPR.CashierUserIdx
				where 1=1
				AND (
				ACSARPR.NumberOfReceiptsWithReturn <> 0 OR ACSARPR.ReturnAmount <>0
				)
				and CAST((DD.FullDate) as date) = CAST((current_timestamp)-1 as date)
				--order by ds.StoreId, DD.FullDate,dt.TimeDescription, ACSARPR.CashRegisterNo, DSU.UserName, ACSARPR.NumberOfReceiptsWithReturn desc ønsker :order by eanlocationno, posno, CashierNO 
				ORDER BY ds.StoreId, ACSARPR.CashRegisterNo, DSU.UserName
				FOR XML PATH('tr'), TYPE 
			) as nvarchar(MAX) ) + 
			N'</table>'	+
			N'<p>Dette er en automatisk generert rapport</p>' +
			N'<p>Extenda Retail AS</p>' +
			N'<p><em>2019</em></p>'

	--SELECT @tableHTML

		if @tableHTML is null 
		print 0
		
		--select top 1 * from dbo.[TRANSACTION] with(NOLOCK)
		
		--set @tableHTML = '<H3>Ingen korrsiste bonger siste døgn</H3><table border="1"><tr><th>- Ingen korrsiste bonger siste døgn -</th></tr></table>'
		
		else

		EXEC msdb.dbo.sp_send_dbmail 
		@recipients=@Recipients,
		@blind_copy_recipients='henning.lensberg@extendaretail.com',
		@from_address='noreply@extendaRetail.com',
		@profile_name = 'ER',
		@subject = 'Returnerte Bonger TRN siste døgn',
		@importance = 'Normal',
		@body = @tableHTML,
		@reply_to ='noreply@extendaretail.com',
		@body_format='HTML';


END

GO

