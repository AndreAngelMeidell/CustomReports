USE BI_Mart
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.usp_CBI_Omnivex_data') AND type in (N'P', N'PC'))
	DROP PROCEDURE dbo.usp_CBI_Omnivex_data
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



create procedure dbo.usp_CBI_Omnivex_data
as
begin
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	set nocount on;

	declare @NoOfDaysBack	int
	set @NoOfDaysBack = 364  --## Endret til 364 dager etter ønske fra PlayIpp (Johnny) 15.03.2016 Henning
	declare @LastYearDateIdx	int			= cast(convert(char(8),(current_timestamp)-@NoOfDaysBack, 112) as int)
			,@CurrentTimeIdx	int			= cast(concat(cast(datepart(hh,current_timestamp) as varchar),right('00'+datename(mi, current_timestamp),2)) as int)

	if object_id('ExportTableOmnivex') is not null
	begin 
		drop table ExportTableOmnivex
	end

	create table BI_Mart..ExportTableOmnivex (	Data		int
												,IsTotal	int
												,Store		bigint
												,date		date
												,Hour		int
												,Amount		money
												,Target		money
												,StoreName	varchar(256)
											);
												
	create table #Store (	StoreId bigint
							,StoreName varchar(256)
						);
	insert into #Store values(7102,N'OSL DFD E');	--øst
	insert into #Store values(7103,N'OSL DFA');
	insert into #Store values(7105,N'OSL TVS');
	insert into #Store values(7107,N'OSL TVF E');	--øst
	insert into #Store values(7108,N'OSL DFD N');
	insert into #Store values(7109,N'OSL TVF N');	--avgang nord
	insert into #Store values(7110,N'OSL NON-Schengen');
	insert into #Store values(7201,N'KRS DF');
	insert into #Store values(7301,N'SVG DF');
	insert into #Store values(7303,N'SVG DFA');		--ankomst
	insert into #Store values(7307,N'SVG TVF');
	insert into #Store values(7401,N'BGO DF');
	insert into #Store values(7403,N'BGO DFA');		--ankomst
	insert into #Store values(7405,N'BGO TVS');
	insert into #Store values(7501,N'TRD DF');
	insert into #Store values(7505,N'TRD TVS');
 
	-- select *  from #Store
	-- drop table #Store

	-- Fetch last years data to own temporary table inorder to find target
	 select 
		dd.FullDate																				as 'Date' 
		,asrd.StoreIdx																			as 'StoreIdx'
		,sum(asrd.NumberOfCustomers)															as 'CustomersLY'
		,cast(avg(asrd.SalesAmount+asrd.ReceiptRounding+asrd.ReturnAmount) as decimal(10,2))	as 'AvgBuyLY'
		,cast((cast((cast((sum(asrd.NumberOfArticlesSold-asrd.NumberOfArticlesInReturn)) as float) / nullif(cast((sum(asrd.NumberOfCustomers)) as float),0)) as float)) as decimal(10,2))			as 'AvgItemsLY'
		,cast(((cast((cast((sum(asrd.NumberOfArticlesSold-asrd.NumberOfArticlesInReturn)) as float) / nullif(cast(sum(asrd.NumberOfCustomers) as float),0)) as float)) + 0.05 ) as decimal(10,2))	as 'TargetItems' --NY LINJE 23/08-12
		,cast(sum(asrd.NumberOfArticlesSold-asrd.NumberOfArticlesInReturn) as decimal(10,2))	as 'ItemssoldLY'
		,cast(sum(asrd.SalesAmountExclVat+asrd.ReturnAmountExclVat) as decimal(10,2))			as 'TurnoverexVATLY'
		--,st.StoreName
	into
		#OMS_lyOmnivex
	from 
		RBIM.Agg_SalesAndReturnPerDay asrd with (nolock)
	left outer join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=asrd.ReceiptDateIdx
	where 
		dd.FullDate = cast((current_timestamp)-@NoOfDaysBack as date) 
	group by
		dd.FullDate
		,asrd.StoreIdx

		
	--Omsetning total hittil i dag per butikk
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		1						as 'Data'
		,1						as 'IsTotal'
		,st.StoreId				as 'Store' 
		,dd.FullDate			as 'Date'
		,'-1'					as 'Hour'	-- -1 =Hele dagen
		,cast(isnull(sum(asrh.SalesAmountExclVat+asrh.ReturnAmountExclVat),0) as decimal(10,2))	as 'Amount'  
		,0						as 'Target' 
		,st.StoreName			as 'StoreName'
	from
		RBIM.Agg_SalesAndReturnPerHour asrh with (nolock)
	inner join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=asrh.ReceiptDateIdx
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=asrh.StoreIdx --and s.IsCurrent=1
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
			dd.FullDate = cast(current_timestamp as date) 
	group by
		st.StoreId
		,dd.FullDate
		,st.StoreName


	--Omsetning per time hittil i dag per butikk
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		2						as 'Data'
		,0						as 'IsTotal'
		,st.StoreId				as 'Store' 
		,dd.FullDate			as 'Date'
		,dt.HourNumber			as 'Hour'	-- -1 =Hele dagen
		,cast(isnull(sum(asrh.SalesAmountExclVat+asrh.ReturnAmountExclVat),0) as decimal(10,2))	as 'Amount'  
		,0						as 'Target' 
		,st.StoreName			as 'StoreName'
	from
		RBIM.Agg_SalesAndReturnPerHour asrh with (nolock)
	inner join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=asrh.ReceiptDateIdx
	inner join RBIM.Dim_Time dt with (nolock) on dt.TimeIdx=asrh.ReceiptTimeIdx
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=asrh.StoreIdx --and s.IsCurrent=1
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
		dd.FullDate = cast(current_timestamp as date) 
	group by
		st.StoreId
		,dd.FullDate
		,dt.HourNumber
		,st.StoreName


	--kunder total hittil i dag per butikk
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		3										as 'Data'
		,1										as 'IsTotal'
		,st.StoreId								as 'Store' 
		,dd.FullDate							as 'Date'
		,'-1'									as 'Hour'	-- -1 =Hele dagen
		,isnull(sum(asrd.NumberOfCustomers),0)	as 'Amount'  
		,0										as 'Target' 
		,st.StoreName							as 'StoreName'
	from
		RBIM.Agg_SalesAndReturnPerDay asrd with (nolock)
	left outer join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=asrd.ReceiptDateIdx
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=asrd.StoreIdx --and s.IsCurrent=1
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
		dd.FullDate = cast(current_timestamp as date) 
	group by
		st.StoreId
		,dd.FullDate
		,st.StoreName


	--kunder per time hittil i dag per butikk
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		4										as 'Data'
		,0										as 'IsTotal'
		,st.StoreId								as 'Store' 
		,dd.FullDate							as 'Date'
		,dt.HourNumber							as 'Hour'	-- -1 =Hele dagen
		,isnull(sum(asrh.NumberOfCustomers),0)	as 'Amount'  
		,0										as 'Target' 
		,st.StoreName							as 'StoreName'
	from
		RBIM.Agg_SalesAndReturnPerHour asrh with (nolock)
	inner join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=asrh.ReceiptDateIdx
	inner join RBIM.Dim_Time dt with (nolock) on dt.TimeIdx=asrh.ReceiptTimeIdx
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=asrh.StoreIdx --and s.IsCurrent=1
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
		dd.FullDate = cast(current_timestamp as date) 
	group by
		st.StoreId
		,dd.FullDate
		,dt.HourNumber
		,st.StoreName


	--Avg items per bong per dag
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		5										as 'Data'
		,1										as 'IsTotal'
		,st.StoreId								as 'Store' 
		,dd.FullDate							as 'Date'
		,'-1'									as 'Hour'	-- -1 =Hele dagen
		,cast(isnull(cast(sum(asrd.NumberOfArticlesSold) as float) / nullif(sum(asrd.NumberOfReceipts),0),0) as decimal(10,2))	as 'Amount'  
		,isnull(ly.TargetItems,0)				as 'Target' 
		,st.StoreName							as 'StoreName'
	from
		RBIM.Agg_SalesAndReturnPerDay asrd with (nolock)
	left outer join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=asrd.ReceiptDateIdx
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=asrd.StoreIdx --and s.IsCurrent=1
	left outer join #OMS_lyOmnivex ly on ly.StoreIdx=asrd.StoreIdx
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
		dd.FullDate = cast(current_timestamp as date) 
	group by
		st.StoreId
		,dd.FullDate
		,ly.TargetItems
		,st.StoreName

		
	--OMsetning pr kunde pr time
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		6										as 'Data'
		,1										as 'IsTotal'
		,st.StoreId								as 'Store' 
		,dd.FullDate							as 'Date'
		,dt.HourNumber							as 'Hour'	-- -1 =Hele dagen
		,isnull((sum(asrh.SalesAmountExclVat+asrh.ReturnAmountExclVat) / nullif(sum(asrh.NumberOfCustomers),0)),0)	as 'Amount'  
		,0										as 'Target' 
		,st.StoreName							as 'StoreName'
	from
		RBIM.Agg_SalesAndReturnPerHour asrh with (nolock)
	inner join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=asrh.ReceiptDateIdx
	inner join RBIM.Dim_Time dt with (nolock) on dt.TimeIdx=asrh.ReceiptTimeIdx
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=asrh.StoreIdx --and s.IsCurrent=1
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
		dd.FullDate = cast(current_timestamp as date) 
	group by
		st.StoreId
		,dd.FullDate
		,dt.HourNumber
		,st.StoreName
		
--########### Start Forrige År #################

	--Omsetning total hittil i dag per butikk  Last Year
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		11					as 'Data'
		,1					as 'IsTotal'
		,st.StoreId			as 'Store' 
		,dd.FullDate		as 'Date'
		,'-1'				as 'Hour'	-- -1 =Hele dagen
		,cast(isnull(sum(rsr.SalesAmountExclVat+rsr.ReturnAmountExclVat),0) as decimal(10,2))	as 'Amount'  
		,0					as 'Target' 
		,st.StoreName		as 'StoreName'
	from
		RBIM.Fact_ReceiptRowSalesAndReturn rsr with (nolock)
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=rsr.StoreIdx
	inner join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=rsr.ReceiptDateIdx
																						  
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
			rsr.ReceiptDateIdx=@LastYearDateIdx
		and rsr.ReceiptTimeIdx<=@CurrentTimeIdx
		and rsr.ReceiptStatusIdx=1		-- ReceiptStatusIdx=1 => Dim_ReceiptStatus.Dim_ReceiptStatus=1, Normal
 	group by
		st.StoreId
		,dd.FullDate
		,st.StoreName


	--Omsetning per time hittil i dag per butikk, Last Year
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		12					as 'Data'
		,0					as 'IsTotal'
		,st.StoreId			as 'Store' 
		,dd.FullDate		as 'Date'
		,dt.HourNumber		as 'Hour'	-- -1 =Hele dagen
		,cast(isnull(sum(rsr.SalesAmountExclVat+rsr.ReturnAmountExclVat),0) as decimal(10,2))	as 'Amount'  
		,0					as 'Target' 
		,st.StoreName		as 'StoreName'
	from
		RBIM.Fact_ReceiptRowSalesAndReturn rsr with (nolock)
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=rsr.StoreIdx
	inner join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=rsr.ReceiptDateIdx
	inner join RBIM.Dim_Time dt with (nolock) on dt.TimeIdx=rsr.ReceiptTimeIdx
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
			rsr.ReceiptDateIdx=@LastYearDateIdx
		and rsr.ReceiptTimeIdx <= @CurrentTimeIdx
		and rsr.ReceiptStatusIdx=1		-- ReceiptStatusIdx=1 => Dim_ReceiptStatus.Dim_ReceiptStatus=1, Normal
 	group by
		st.StoreId
		,dd.FullDate
		,dt.HourNumber
		,st.StoreName


	--kunder total hittil i dag per butikk, Last Year
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		13										as 'Data'
		,1										as 'IsTotal'
		,st.StoreId								as 'Store' 
		,dd.FullDate							as 'Date'
		,'-1'									as 'Hour'	-- -1 =Hele dagen
		,isnull(sum(rsr.NumberOfCustomers),0)	as 'Amount'  
		,0										as 'Target' 
		,st.StoreName							as 'StoreName'
	from
		RBIM.Fact_ReceiptRowSalesAndReturn rsr with (nolock)
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=rsr.StoreIdx
	inner join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=rsr.ReceiptDateIdx
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
			rsr.ReceiptDateIdx=@LastYearDateIdx
		and rsr.ReceiptTimeIdx<=@CurrentTimeIdx
		and rsr.ReceiptStatusIdx=1		-- ReceiptStatusIdx=1 => Dim_ReceiptStatus.Dim_ReceiptStatus=1, Normal
 	group by
		st.StoreId
		,dd.FullDate
		,st.StoreName


	--kunder per time hittil i dag per butikk, Last Year
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		14										as 'Data'
		,0										as 'IsTotal'
		,st.StoreId								as 'Store' 
		,dd.FullDate							as 'Date'
		,dt.HourNumber							as 'Hour'	-- -1 =Hele dagen
		,isnull(sum(rsr.NumberOfCustomers),0)	as 'Amount'  
		,0										as 'Target' 
		,st.StoreName							as 'StoreName'
	from
		RBIM.Fact_ReceiptRowSalesAndReturn rsr with (nolock)
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=rsr.StoreIdx
	inner join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=rsr.ReceiptDateIdx
	inner join RBIM.Dim_Time dt with (nolock) on dt.TimeIdx=rsr.ReceiptTimeIdx
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
			rsr.ReceiptDateIdx=@LastYearDateIdx
		and rsr.ReceiptTimeIdx<=@CurrentTimeIdx
		and rsr.ReceiptStatusIdx=1		-- ReceiptStatusIdx=1 => Dim_ReceiptStatus.Dim_ReceiptStatus=1, Normal
 	group by
		st.StoreId
		,dd.FullDate
		,dt.HourNumber
		,st.StoreName


	--Avg items per bong per dag, Last Year
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		15										as 'Data'
		,1										as 'IsTotal'
		,st.StoreId								as 'Store' 
		,dd.FullDate							as 'Date'
		,'-1'									as 'Hour'	-- -1 =Hele dagen
		,cast(isnull(cast(sum(rsr.QuantityOfArticlesSold) as float) / nullif(sum(rsr.NumberOfReceiptsWithSale),0),0) as decimal(10,2))	as 'Amount'  
		,isnull(ly.TargetItems,0)				as 'Target' 
		,st.StoreName							as 'StoreName'
	from
		RBIM.Fact_ReceiptRowSalesAndReturn rsr with (nolock)
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=rsr.StoreIdx
	inner join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=rsr.ReceiptDateIdx
	left outer join #OMS_lyOmnivex ly on ly.StoreIdx=rsr.StoreIdx
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
			rsr.ReceiptDateIdx=@LastYearDateIdx
		and rsr.ReceiptTimeIdx<=@CurrentTimeIdx
		and rsr.ReceiptStatusIdx=1		-- ReceiptStatusIdx=1 => Dim_ReceiptStatus.Dim_ReceiptStatus=1, Normal
	group by
		st.StoreId
		,dd.FullDate
		,ly.TargetItems
		,st.StoreName


	--OMsetning pr kunde pr time, Last Year
	insert BI_Mart..ExportTableOmnivex (Data, IsTotal, Store, Date, Hour, Amount, Target, StoreName)
	select
		16										as 'Data'
		,1										as 'IsTotal'
		,st.StoreId								as 'Store' 
		,dd.FullDate							as 'Date'
		,dt.HourNumber							as 'Hour'	-- -1 =Hele dagen
		,isnull((sum(rsr.SalesAmountExclVat+rsr.ReturnAmountExclVat) / nullif(sum(rsr.NumberOfCustomers),0)),0)	as 'Amount'  
		,0										as 'Target' 
		,st.StoreName							as 'StoreName'
	from
		RBIM.Fact_ReceiptRowSalesAndReturn rsr with (nolock)
	inner join RBIM.Dim_Store s with (nolock) on s.StoreIdx=rsr.StoreIdx
	inner join RBIM.Dim_Date dd with (nolock) on dd.DateIdx=rsr.ReceiptDateIdx
	inner join RBIM.Dim_Time dt with (nolock) on dt.TimeIdx=rsr.ReceiptTimeIdx
	left outer join #Store st with (nolock) on st.StoreId=cast(s.StoreId as bigint)
	where 
			rsr.ReceiptDateIdx=@LastYearDateIdx
		and rsr.ReceiptTimeIdx<=@CurrentTimeIdx
		and rsr.ReceiptStatusIdx=1		-- ReceiptStatusIdx=1 => Dim_ReceiptStatus.Dim_ReceiptStatus=1, Normal
 	group by
		st.StoreId
		,dd.FullDate
		,dt.HourNumber
		,st.StoreName


	drop table #OMS_lyOmnivex
	drop table #Store
end


go

