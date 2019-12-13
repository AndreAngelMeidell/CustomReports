GO
use [VBDCM]
GO

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1001_ds_Pharmacy_RemainingNotes')
drop procedure [usp_CBI_1001_ds_Pharmacy_RemainingNotes]
GO


Create Procedure [dbo].[usp_CBI_1001_ds_Pharmacy_RemainingNotes]
														(
															@ParStoreNo As varchar(30)='' 
															,@parOrderDatumFrom As varchar(30)=''
															,@parOrderDatumto As varchar(30)  =''
															,@parDeliveryCompany As varchar(4000)=''
														)
AS
BEGIN 

	---------------------------------------------------------------
	--SET DATEFORMAT DMY;
	SET NOCOUNT ON;

	DECLARE @sql as nvarchar(max) = ''
	DECLARE @ParamDefinition as nvarchar(max)

	set @ParamDefinition = N'@ParStoreNo nvarchar(30), @parOrderDatumFrom nvarchar(300), @parOrderDatumto nvarchar(30), @parDeliveryCompany nvarchar(4000)'


	set @sql = @sql + ' 
				set @parOrderDatumFrom = convert(datetime, @parOrderDatumFrom  + '' 00:00:00'', 121)
				set @parOrderDatumto = convert(datetime, @parOrderDatumto + '' 23:59:59'', 121)
				'
	
	if len(isnull(@parDeliveryCompany, '') ) > 0 
	set @sql = @sql + '	;WITH DeliveryCompanyFltrTbl AS (
						select distinct  cast(ParameterValue as int) as SupplierNo 
						from [dbo].[ufn_RBI_SplittParameterString](@parDeliveryCompany,'','')
						) 
						'
	set @sql = @sql  + '
				select distinct PO.OrderNo, 
								 PO.StoreNo, 
								 DL.DeliverynoteNo, 
								 DL.DeliveryLineNo, 
								 AA.ArticleID as ArtID, 
								 AA.SupplierArticleID as Varunr, 
								 AA.ArticleName, 
								 AA.SupplierName, 
								 CONVERT(varchar, PO.OrderEffectuatedDate, 23) as OrderEffectuatedDate,
								 DL.InitialOrderedQty, 
								 ISNULL((SELECT SUM(delivered.DeliveredQty)  
										 FROM DeliveredLines AS delivered  
										 WHERE delivered.DeliveryNoteNo = dl.DeliveryNoteNo  
										 AND delivered.DeliveryLineNo = dl.DeliveryLineNo  
										 AND delivered.DeliveredLineStatus = 80 ),0) AS toBeDeliveredQty, 
								 SARC.StockAdjReasonName, 
								 DL.DeliveryLineText, 
								 PO.POText as OrderKommentar  
				from confirmedorderlines COL with (nolock)
				join purchaseorders PO with (nolock) on PO.storeno = COL.storeno and PO.orderno = COL.orderno 
				join deliveries D with (nolock) on D.storeno = COL.storeno 
				join deliverylines DL with (nolock) on DL.orderno = COL.orderno and DL.articleno = COL.articleno and DL.deliverynoteno = D.deliverynoteno and DL.deliverylinestatus not in (70,80,99) 
				join allarticles AA with (nolock) on AA.articleno = COL.articleno 
				join stockadjustmentreasoncodes SARC on SARC.stockadjreasonno = COL.stockadjreasonno
				'

	if len(@parDeliveryCompany) > 0
		set @sql = @sql  +	'join DeliveryCompanyFltrTbl delComFltr on AA.SupplierNo = delComFltr.SupplierNo
		'
	
	set @sql = @sql  + 'where COL.stockadjreasonno in (9910,9911,9912, 9920, 9921, 9922,9930,9931,9932,9995,9996,9997) ' -- VPT-1878 added 9920, 9921, 9922,9930,9931,9932


	if len(@ParStoreNo) > 0
		set @sql = @sql + ' and COL.StoreNo =  @ParStoreNo '

	set @sql = @sql + ' and PO.OrderEffectuatedDate between  @parOrderDatumFrom and @parOrderDatumto'

	set @sql = @sql + ' order by AA.ArticleName asc'


	--print (@sql)
	execute sp_executesql @sql,
						  @ParamDefinition,
						  @ParStoreNo = @ParStoreNo ,
						  @parDeliveryCompany = @parDeliveryCompany,
						  @parOrderDatumFrom = @parOrderDatumFrom,
						  @parOrderDatumto = @parOrderDatumto

END

GO








/*

exec [dbo].[usp_CBI_1001_ds_Pharmacy_RemainingNotes] 		@ParStoreNo = N'3000'
															,@parOrderDatumFrom = '2018-01-01'
															,@parOrderDatumto = '2018-05-01'
															,@parDeliveryCompany = N'20,23,11,59,5,60,12,37,17,67,15,65,14,62,54,64,57'--,61,55,32,45,6,34,3,66,52,27,1,19,63,46,47,28,13,7,2,9,10,41'


*/

