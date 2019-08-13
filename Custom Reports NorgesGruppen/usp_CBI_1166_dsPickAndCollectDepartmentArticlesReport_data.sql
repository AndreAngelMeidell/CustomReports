USE PickAndCollectDB
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_CBI_1166_dsPickAndCollectDepartmentArticlesReport_data]') AND type in (N'P', N'PC'))
DROP PROCEDURE dbo.usp_CBI_1166_dsPickAndCollectDepartmentArticlesReport_data
GO

set ansi_nulls on
go

set quoted_identifier on
go

create procedure dbo.usp_CBI_1166_dsPickAndCollectDepartmentArticlesReport_data(
	@StoreId	int
	,@DateFrom	date
	,@DateTo	date
)
as
begin
	select  
		dco.StoreName
		,dcole.[Value]											'Department'
		,dcol.ArticleID
		,dcol.ArticleStorageType
		,dcol.ArticleUnit
		,(dcol.ArticleName + ' ' + isnull(dcol.ArticleInfo,''))	'ArticleName'
		,dcol.ArticleEan
		,dcol.PlanogramGroupName
		,cast(dco.CollectStartTime as date)						'PickUpDate'
		,sum(dcol.OrderedQty)									'OrderedQty'
	from
		DeliveryCustomerOrders dco
	inner join dbo.DeliveryCustomerOrderLines dcol on dcol.CustomerOrderNo=dco.CustomerOrderNo
	left outer join dbo.DeliveryCustomerOrderExtraInfos dcole on dcole.CustomerOrderNo=dco.CustomerOrderNo and dcole.CustomerOrderLineNo=dcol.CustomerOrderLineNo and dcole.[Key]='ARTICLE_DEPARTMENT_NAME'
	inner join dbo.CustomerOrderLineStates col on col.CustomerOrderLineStatus=dcol.CustomerOrderLineStatus
	where 
			dco.StoreNo = @StoreId
		and dco.OrderStatus in (10, 20)			-- include only the relevant orders (10=Created, 20=Open)
		and (cast(dco.CollectStartTime as date) between @DateFrom and @DateTo)
		and dcol.CustomerOrderLineStatus = 10	-- only articles that have not been picked (10=Created)
		and dcol.SubstitutionForEan is null		-- only the article to be delivered and not the eventual substitutions
	group by
		cast(dco.CollectStartTime as date)
		,dco.StoreName
		,dcole.[Value]
		,dcol.ArticleID
		,dcol.ArticleStorageType
		,dcol.ArticleUnit
		,dcol.ArticleName
		,dcol.ArticleInfo
		,dcol.ArticleEan
		,dcol.PlanogramGroupName
	order by
		cast(dco.CollectStartTime as date)
		,dco.StoreName
		,dcole.[Value]
		,dcol.ArticleStorageType
		,dcol.ArticleName

end
