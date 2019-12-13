if exists(select * from sysobjects WHERE name = N'usp_CBI_1006_ds_PharmacyDifferencialReportReceivingGoods'  AND xtype = 'P' )
drop procedure usp_CBI_1006_ds_PharmacyDifferencialReportReceivingGoods
GO

create procedure [dbo].[usp_CBI_1006_ds_PharmacyDifferencialReportReceivingGoods] (
	 @parDeliveryCompany AS VARCHAR(30) = '',
	 @parStockAdjReasonNo AS VARCHAR(2000) = '',
	 @parDatumFrom AS VARCHAR(30) = '',
	 @parDatumto AS VARCHAR(30) = '',
	 @parDeliveryNoteNo AS VARCHAR(2000) = '',
	 @parExternalDeliveryNoteId_hidden AS VARCHAR(2000) = '',
	 @ParStoreNo AS VARCHAR(8000) = ''
)
as
	SET DATEFORMAT DMY
	DECLARE @sql As nvarchar(max) = ''
	DECLARE @ParamDefinition nvarchar(max)


	set @ParamDefinition = N'@parDeliveryCompany nvarchar(30), @parStockAdjReasonNo nvarchar(2000), @parDatumFrom nvarchar(30), @parDatumto nvarchar(30), 
							 @parDeliveryNoteNo nvarchar(50), @parExternalDeliveryNoteId_hidden NVARCHAR(MAX), @ParStoreNo nvarchar(30)'


	set @sql = @sql + '
	set @parDatumFrom = CONVERT(date, @parDatumFrom ,120)
	set @parDatumto = CONVERT(date, @parDatumto ,120)
	'


		
	if len(isnull(@parStockAdjReasonNo,'')) > 0 
		set @sql = @sql + ';with StockAdjReasonNoTblFltr as (
							select distinct  cast(ParameterValue as smallint) as StockAdjReasonNo
							from [dbo].[ufn_RBI_SplittParameterString](@parStockAdjReasonNo,'','')
						  )
						  '

	set @sql = @sql + '
	select 
		D.StoreNo AS ButiksNr,
		MAX(S.Storename) AS ButiksNamn,
		MAX(D.SupplierNo) AS LevNr,
		MAX(SO.SupplierName) As LevNamn,
		DL.OrderNo as OrderNr,
		CONVERT(VARCHAR, MAX (ISNULL(D.RecordCreated,'''')), 23)  as OrderDatum,
		DL.OrderLineNo As OrderRad, 
		MAX(A.ArticleName) as Benamning,
		MAX(DL.SupplierArticleID) As BestNr,
		MAX(ISNULL(DL.InitialOrderedQty,0)) as BestalltAntal,
		MAX(ISNULL(DL.FpakInDpak,0)) As Fpack,
		MAX(ISNULL(DL.NetPrice,0)) As InkopsPris,
		MAX(ISNULL(RL.ReceivedQty,0)) as SenastMottaget,
		SUM(ISNULL(RL.ReceivedQty,0)) as TotaltMottaget,
		CONVERT(VARCHAR, MAX(ISNULL(RL.CompletedReceivalDate,'''') ), 23) as MottagetDatum,
		MAX(ISNULL(RL.ReceivedLineNo,0)) as MottagetRadnr,
		--MAX(DL.DeliveryLinestatus),
		MAX(DLS.DeliveryLinestatusName) as RadStatus,
		SUM(ISNULL(RLA.AdjustmentQty,0)) As KorrigeratAntal,
		MAX(ISNULL(RLA.StockAdjReasonNo,'''')) As KorrigeringsOrsak, 
		MAX(ISNULL(sarc.StockAdjReasonName,'''')) As KorrigeringsNamn, 
		CONVERT(VARCHAR, MAX(ISNULL(RLA.RecordCreated,'''')), 23) as KorrigeratDatum,
		MAX(d.DeliveryNoteNo) As PacksedelsNr,
		MAX(ISNULL(D.DeliveryNoteText,'''')) As PacksedelsText,
		MAX(D.DeliveryStatus) As PacksedelsStatus,
		MAX(DL.DeliveryNoteNo)as IntPackNo,
		MAX(DL.DeliveryLineNo) as MaxDeliveryLineNo,
		MAX(ISNULL(del.ExternalDeliveryNoteId,'''')) as ExternPacksedel
	FROM DeliveryLines DL with (nolock)
	left join ReceivedLines as RL with (nolock) on dl.DeliveryLineNo=RL.DeliveryLineNo
	left join ReceivedLineAdjustments as RLA with (nolock) on RL.ReceivedLineNo=RLA.ReceivedLineNo
	'
	if len(isnull(@parStockAdjReasonNo,'')) > 0 
		set @sql = @sql + 'inner join StockAdjReasonNoTblFltr stockAdjFltr on RLA.StockAdjReasonNo = stockAdjFltr.StockAdjReasonNo 
		'

	set @sql = @sql +	'left join Deliveries as D with (nolock) on DL.DeliveryNoteNo=D.DeliveryNoteNo 
	left join DeliveryLineStates as DLS with (nolock) on DL.DeliveryLinestatus=DLS.DeliveryLinestatus
	left join DeliveredLines as del with (nolock) on DL.DeliveryLineNo=del.DeliveryLineNo
	left join Stores as S with (nolock) on D.Storeno=S.storeNo
	left join SupplierOrgs As SO with (nolock) on D.SupplierNo=SO.SupplierNo
	left join StockAdjustmentReasonCodes as sarc with (nolock) on RLA.StockAdjReasonNo=sarc.StockAdjReasonNo
	left join Articles A with (nolock) on DL.Articleno=A.Articleno 
	WHERE
	DL.deliverylinestatus = 80 and ISNULL(RLA.AdjustmentQty,0) <> 0 and D.DeliveryTypeNo = 10 
	'

	if len(@ParStoreNo) > 0 
		set @sql = @sql + ' AND D.StoreNo in (@ParStoreNo)'


	IF LEN(@parExternalDeliveryNoteId_hidden) > 0 			 
		SET @sql = @sql + ' AND del.ExternalDeliveryNoteId =  @parExternalDeliveryNoteId_hidden '
	ELSE IF LEN(@parDeliveryNoteNo) > 0 
		SET @sql = @sql + ' AND DL.DeliveryNoteNo IN (SELECT value
													  FROM STRING_SPLIT(@parDeliveryNoteNo,'',''))
													  '
	ELSE IF LEN(@parDatumFrom) > ''
		SET @sql = @sql + '  AND CONVERT(CHAR(10),RLA.RecordCreated,120) BETWEEN  
						 CONVERT(CHAR(10), @parDatumFrom, 120)
						 AND CONVERT(CHAR(10), @parDatumTo, 120) 
						 '

	if len(@parDeliveryCompany) > 0
		set @sql = @sql + '  and D.SupplierNo = @parDeliveryCompany '



	set @sql = @sql + ' 
		group by D.StoreNo,D.SupplierNo,DL.OrderNo,DL.OrderLineNo,DL.ArticleNo
		--,RLA.RecordCreated (borttagen legat efter supplierno)

		order by D.Storeno,D.SupplierNo,DL.Orderno,DL.OrderLineNo 
		 '
	
	--print(@sql)
	exec sp_executesql @sql,
					   @ParamDefinition, 
					   @parDeliveryCompany = @parDeliveryCompany,
					   @parStockAdjReasonNo = @parStockAdjReasonNo,
					   @parDatumFrom = @parDatumFrom,
					   @parDatumto = @parDatumto,
					   @parDeliveryNoteNo = @parDeliveryNoteNo,
					   @ParStoreNo = @ParStoreNo,
					   @parExternalDeliveryNoteId_hidden = @parExternalDeliveryNoteId_hidden


GO


/*

exec usp_CBI_1006_ds_PharmacyDifferencialReportReceivingGoods 
	 @ParStoreNo = '3000', 
	 @parDeliveryCompany  = '',
	 @parStockAdjReasonNo = '',
	 @parDatumFrom ='2015-01-01',
	 @parDatumTo ='2019-10-10',
	 @parDeliveryNoteNo = '',
	 @parExternalDeliveryNoteId_hidden = 'EE02677'


*/

