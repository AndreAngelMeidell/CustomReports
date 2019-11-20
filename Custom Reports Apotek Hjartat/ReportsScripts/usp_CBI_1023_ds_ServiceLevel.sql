go
use [VBDCM]
go

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'usp_CBI_1023_ds_ServiceLevel')
drop procedure usp_CBI_1023_ds_ServiceLevel
go

CREATE Procedure [dbo].usp_CBI_1023_ds_ServiceLevel
														(
															 @parStoreNo As varchar(8000)=''
															,@parDateFrom As varchar(50) = '1900-01-01'
															,@parDateTo As varchar(50) = '2040-01-01'
														)
AS
BEGIN 
--Rapport nr 1023
	SET NOCOUNT ON;

	DECLARE @sql As nvarchar(max) = ''


	set @sql = @sql + '

					SELECT 
							sum(recept) as antalrecept,
							Sum(kundorder) as antalkundorder,
							((cast(sum(recept)as decimal(10,2))/
							(cast(sum(kundorder)as decimal(10,2)) + cast(sum(recept)as decimal(10,2))))*100) as Servicegra
					From 
					(
						Select
							case stad.StockAdjType when 1 then 1 else 0 End as Recept,
							case stad.StockAdjType when 1 then 0 else 1 End as Kundorder
						From Stores Stor WITH (NOLOCK)
						join stockadjustments stad WITH (NOLOCK) on (stor.storeno = stad.storeno) 
						join  allarticles alar WITH (NOLOCK) on (stad.articleno = alar.articleno)
						WHERE  (stad.stockadjtype in (1) 
								and stad.storeno = @parStoreNo 
								and alar.ArticleHierNameTop like (''%RX'') 
								and stad.adjustmentqty < 0
								and CONVERT(date,stad.adjustmentdate,120) 
									between  
											CONVERT(date, @parDateFrom ,120)
										and CONVERT(date, @parDateTo ,120))
						UNION ALL
						(
							Select	case colpo.CustomerOrderNo when '''' then 0 else 1 End as Kundorder,
									case colpo.CustomerOrderNo when '''' then 0 else 1 End as Recept
							From Stores Stor WITH (NOLOCK)
							join CustomerOrderLinePurchaseOrders colpo WITH (NOLOCK) on (stor.storeno = colpo.storeno) 
							WHERE  (
									colpo.storeno = @parStoreNo 
									and CONVERT(date,colpo.RecordCreated,120) 
									between 
											CONVERT(date,@parDateFrom,120)
										and CONVERT(date,@parDateTo,120)
									)	
						)
					) as temp'
         

	--print (@sql)

	exec sp_executesql @sql,
					   N'@parStoreNo nvarchar(max), @parDateFrom nvarchar(50), @parDateTo nvarchar(50)',
					   @parStoreNo = @parStoreNo,
					   @parDateFrom = @parDateFrom,
					   @parDateTo = @parDateTo

end








/*


exec [dbo].usp_CBI_1023_ds_ServiceLevel	    @parStoreNo ='3010'
											, @parDateFrom = '1900-01-01'
											, @parDateTo = '2040-01-01'



*/	
