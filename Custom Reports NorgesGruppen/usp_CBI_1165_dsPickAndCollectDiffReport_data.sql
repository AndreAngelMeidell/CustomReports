USE [PickAndCollectDB]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1165_dsPickAndCollectDiffReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_CBI_1165_dsPickAndCollectDiffReport_data]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create procedure [dbo].[usp_CBI_1165_dsPickAndCollectDiffReport_data](
	@StoreId	int 
	,@DateFrom	date
	,@DateTo	date
)
as
begin
	select
		StoreName
		,PickedByEmployee
		,OrderPickedDate
		,CustomerOrderNo
		,CustomerOrderLineNo
		,CustomerNo
		,Customer
		,DifferQty
		,DifferPrice
		,DifferResult
	from
		(
		-- Find the DeliveryCustomerOrderLines where DeliveredQuantity differs from ordered
		select  
			dco.StoreName																			'StoreName'
			,dco.PickedByEmployee																	'PickedByEmployee'
			,cast(dco.OrderPickedDate as date)														'OrderPickedDate'
			,dcol.CustomerOrderNo																	'CustomerOrderNo'
			,dcol.CustomerOrderLineNo																'CustomerOrderLineNo'
			,c.CustomerNo																			'CustomerNo'
			,(isnull(c.FirstName,'') + ' ' + isnull(c.MiddleName,'') + ' ' + isnull(c.LastName,''))	'Customer'
			,(isnull(dcol.ReceivedQty,0) - isnull(dcol.OrderedQty,0))								'DifferQty'
			,0																						'DifferPrice'
			,((isnull(dcol.ReceivedQty,0) - isnull(dcol.OrderedQty,0)) * dcol.ArticleCurrentPrice)	'DifferResult'
		from
			DeliveryCustomerOrders dco
		inner join dbo.DeliveryCustomerOrderLines dcol on dcol.CustomerOrderNo = dco.CustomerOrderNo
		inner join dbo.Customers c on c.CustomerNo = dco.CustomerNo
		where 
				dco.StoreNo = @StoreId
			and (cast(dco.OrderPickedDate as date) between @DateFrom and @DateTo)
			and dcol.CustomerOrderLineStatus  in (60,70,80)		-- 60-Ready for delivery,70-Picked,80-Delivered
			and isnull(dcol.ReceivedQty,0) <> isnull(dcol.OrderedQty,0)
			and isnull(dcol.ReceivedQty,0) - isnull(dcol.OrderedQty,0) <> 0
		union all
		-- Find the DeliveryCustomerOrderLines where DeliveredPrice differs from ordered
		select  
			dco.StoreName																			'StoreName'
			,dco.PickedByEmployee																	'PickedByEmployee'
			,cast(dco.OrderPickedDate as date)														'OrderPickedDate'
			,dcol.CustomerOrderNo																	'CustomerOrderNo'
			,dcol.CustomerOrderLineNo																'CustomerOrderLineNo'
			,c.CustomerNo																			'CustomerNo'
			,(isnull(c.FirstName,'') + ' ' + isnull(c.MiddleName,'') + ' ' + isnull(c.LastName,''))	'Customer'
			,(isnull(dcol2.ReceivedQty,0) - isnull(dcol.OrderedQty,0))								'DifferQty'
			,(dcol2.ArticleCurrentPrice - dcol.ArticleCurrentPrice)									'DifferPrice'
			,(isnull(dcol2.ReceivedQty,0) * isnull(dcol2.ArticleCurrentPrice,0)) - (isnull(dcol.OrderedQty,0) * isnull(dcol.ArticleCurrentPrice,0))	'DifferResult'
		from
			DeliveryCustomerOrders dco
		inner join dbo.DeliveryCustomerOrderLines dcol on dcol.CustomerOrderNo = dco.CustomerOrderNo
		inner join dbo.DeliveryCustomerOrderLines dcol2 on dcol2.CustomerOrderNo=dco.CustomerOrderNo and dcol2.LineNumber=dcol.LineNumber and dcol2.OrderedQty=dcol2.ReceivedQty
		inner join dbo.Customers c on c.CustomerNo = dco.CustomerNo
		where 
				dco.StoreNo = @StoreId
			and (cast(dco.OrderPickedDate as date) between @DateFrom and @DateTo)
			and dcol.CustomerOrderLineStatus=54		--54-Substituted
			and	(dcol2.ArticleCurrentPrice - dcol.ArticleCurrentPrice) > 0
		)s
	order by
		PickedByEmployee
		,OrderPickedDate
end
