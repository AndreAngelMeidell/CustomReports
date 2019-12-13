go
use [VBDCM]
go

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1199_ds_Monitoring')
drop procedure usp_CBI_1199_ds_Monitoring
GO


CREATE Procedure [dbo].usp_CBI_1199_ds_Monitoring
as
Begin

	--Rapport nr 1199
	set nocount on;

	DECLARE @sql As nvarchar(max)
	DECLARE @supplierOriola	AS VARCHAR(50)		   = (SELECT SupplierNo FROM SupplierOrgs WITH (NOLOCK) WHERE SupplierID = 100860)
	DECLARE @supplierTamro AS VARCHAR(50)		   = (SELECT SupplierNo FROM SupplierOrgs WITH (NOLOCK) WHERE SupplierID = 101032)
	DECLARE @supplierApotekLogistik AS VARCHAR(50) = (SELECT SupplierNo FROM SupplierOrgs WITH (NOLOCK) WHERE SupplierID = 106628)
 
	SET @sql =  '
	SELECT 
		s.storeno as Butiksnr, 
		s.storename as Butiksnamn,
		ISNULL(CONVERT( DATETIME, (select top 1 ordereffectuateddate from purchaseorders po WITH (NOLOCK) where s.storeno = po.storeno and po.supplierNo= '+ @supplierOriola + ' order by ordereffectuateddate desc), 120), '''') as Senaste_Oriola_Order,
		ISNULL(CONVERT( DATETIME, (select top 1 ordereffectuateddate from purchaseorders po WITH (NOLOCK)where s.storeno = po.storeno and po.supplierNo= ' + @supplierTamro + ' order by ordereffectuateddate desc), 120), '''') as Senaste_Tamro_Order,
		ISNULL(CONVERT( DATETIME, (select top 1 ordereffectuateddate from purchaseorders po WITH (NOLOCK)where s.storeno = po.storeno and po.supplierNo=' + @supplierApotekLogistik + ' order by ordereffectuateddate desc), 120), '''') as Senaste_ApoPharm_Order,
		--(select top 1 Recordcreated from CustomerOrders cust WITH (NOLOCK)where s.storeno = cust.storeno order by Recordcreated desc) as Senaste_kundorder,
		ISNULL(CONVERT( DATETIME, (select top 1 Recordcreated from ConfirmedOrderLines Col  WITH (NOLOCK)where s.storeno = col.storeno and Col.ConfirmedOrderLineStatus=10 order by Recordcreated desc), 120), '''') as Senaste_Orderbekräftelse
		--(select top 1 AdjustmentDate from StockAdjustments sa where s.storeno = sa.storeno and sa.stockadjtype=1 and sa.DataSourceNo=10 order by AdjustmentDate desc) as Senaste_Rxkvitto
		--(select top 1 AdjustmentDate from StockAdjustments sa where s.storeno = sa.storeno and sa.stockadjtype=1 and sa.DataSourceNo=20 order by AdjustmentDate desc) as Senaste_Kassakvitto
	FROM  Stores s
	WHERE  s.StoreTypeNo=7 and s.StoreStatus=1 '


	SET @sql = @sql + ' GROUP BY s.storeno,s.storename' 
   
	--set @sql = @sql + ' ORDER BY s.storeno asc'                
	--print(@sql)
	exec sp_executesql @sql

end

/*
exec usp_CBI_1199_ds_Monitoring
*/





