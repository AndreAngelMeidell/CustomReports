USE [PickAndCollectDB]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1165_dsPickAndCollectDiffReport_data]    Script Date: 25.09.2020 12:13:50 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[usp_CBI_1165_dsPickAndCollectDiffReport_data](
	@StoreId	int 
	,@DateFrom	date
	,@DateTo	date
)
as
begin
	select * from
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
		inner join dbo.CustomerOrderLineStates col on col.CustomerOrderLineStatus = dcol.CustomerOrderLineStatus
		--inner join dbo.Customers c on c.CustomerNo = dco.CustomerNo --changed in blue
		inner join dbo.vCustomers AS c ON c.CustomerID = dco.CustomerID
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
			,0																						'QuantityDiffers'
			,(dcol2.ArticleOriginalPrice - dcol.ArticleOriginalPrice)								'DifferPrice'
			,isnull(dcol.ReceivedQty,0) * (dcol2.ArticleOriginalPrice - dcol.ArticleOriginalPrice)	'DifferResult'
		from
			DeliveryCustomerOrders dco
		inner join dbo.DeliveryCustomerOrderLines dcol on dcol.CustomerOrderNo = dco.CustomerOrderNo
		inner join dbo.DeliveryCustomerOrderLines dcol2 on dcol2.CustomerOrderNo=dco.CustomerOrderNo and dcol2.LineNumber=dcol.LineNumber and dcol2.ArticleDeliveredUnit is not null
		inner join dbo.CustomerOrderLineStates col on col.CustomerOrderLineStatus = dcol.CustomerOrderLineStatus
		--inner join dbo.Customers c on c.CustomerNo = dco.CustomerNo --changed in blue
		inner join dbo.vCustomers AS c ON c.CustomerID = dco.CustomerID
		where 
				dco.StoreNo = @StoreId
			and (cast(dco.OrderPickedDate as date) between @DateFrom and @DateTo)
			and dcol.CustomerOrderLineStatus  in (60,70,80)		-- 60-Ready for delivery,70-Picked,80-Delivered
			and	(dcol2.ArticleOriginalPrice - dcol.ArticleOriginalPrice) > 0
		)s
	order by
		PickedByEmployee
		,OrderPickedDate
end


GO

