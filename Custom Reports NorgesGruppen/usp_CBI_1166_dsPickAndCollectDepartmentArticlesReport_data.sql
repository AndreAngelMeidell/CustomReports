USE [PickAndCollectDB]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1166_dsPickAndCollectDepartmentArticlesReport_data]    Script Date: 04.06.2020 13:51:41 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE procedure [dbo].[usp_CBI_1166_dsPickAndCollectDepartmentArticlesReport_data](
@StoreId	int
,@DateFrom	date
,@DateTo	date
)
as
begin
select  
dco.OrderID
,dco.StoreName
,dcole.[Value]	'Department'
,CAST(dcol.ArticleID AS BIGINT) AS ArticleID 
,dcol.ArticleStorageType
,dcol.ArticleUnit
,(dcol.ArticleName + ' ' + isnull(dcol.ArticleInfo,''))	'ArticleName'
,dcol.ArticleEan
,CAST(CAST(dco.CollectStartTime as TIME) AS VARCHAR(5))+'-'+CAST(CAST(dco.CollectEndTime as TIME) AS VARCHAR(5))  AS 'PicUpTime'
,dcol.OrderedQty	'OrderedQty'
,dco.CustomerOrderCustomerText	'CustomerText'
from
DeliveryCustomerOrders dco
inner join dbo.DeliveryCustomerOrderLines dcol on dcol.CustomerOrderNo=dco.CustomerOrderNo
left outer join dbo.DeliveryCustomerOrderExtraInfos dcole on dcole.CustomerOrderNo=dco.CustomerOrderNo and dcole.CustomerOrderLineNo=dcol.CustomerOrderLineNo and dcole.[Key]='ARTICLE_DEPARTMENT_NAME'
inner join dbo.CustomerOrderLineStates col on col.CustomerOrderLineStatus=dcol.CustomerOrderLineStatus
where 
dco.StoreNo = @StoreId
and dco.OrderStatus in (10, 20)	-- include only the relevant orders (10=Created, 20=Open)
and (cast(dco.CollectStartTime as date) between @DateFrom and @DateTo)
and dcol.CustomerOrderLineStatus = 10	-- only articles that have not been picked (10=Created)
and dcol.SubstitutionForEan is null	-- only the article to be delivered and not the eventual substitutions
group BY
dco.OrderID
,dco.StoreName
,dcole.[Value]
,CAST(dco.CollectStartTime as TIME)
,cast(dco.CollectEndTime as TIME)
,dcol.ArticleID
,dcol.ArticleStorageType
,dcol.ArticleUnit
,dcol.ArticleName
,dcol.ArticleInfo
,dcol.ArticleEan
,dcol.OrderedQty
,dco.CustomerOrderCustomerText
order by
dco.StoreName
,dcole.[Value]
,CAST(dco.CollectStartTime as TIME)
,dcol.ArticleStorageType
,dcol.ArticleName

end  
GO

