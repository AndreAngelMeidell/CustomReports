USE VBDCM
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id=OBJECT_ID(N'dbo.usp_CBI_ds1380InventoryCorrections_report') AND type in (N'P', N'PC'))
	DROP PROCEDURE dbo.usp_CBI_ds1380InventoryCorrections_report
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



create procedure dbo.usp_CBI_ds1380InventoryCorrections_report
(
	@AdjustmentTransactionCounterList	varchar(max)
)
as
begin
	set nocount on

	declare @start	int
			,@end	int
	
	create table #tmpTransCntNOs
	(
		TransCntNO	varchar(max)
	)
	
	select @start = 1, @end = charindex(',',@AdjustmentTransactionCounterList) 
    while @start < len(@AdjustmentTransactionCounterList) + 1
	begin 
        if @end = 0  
            set @end = len(@AdjustmentTransactionCounterList) + 1
     
        insert into #tmpTransCntNOs (TransCntNO)  
        values(substring(@AdjustmentTransactionCounterList, @start, @end - @start)) 
        set @start = @end + 1 
        set @end = charindex(',', @AdjustmentTransactionCounterList, @start)
      
    end 
	
	select
		sa.AdjustmentDate
		,a.ArticleID
		,a.ArticleReceiptText
		,sa.AdjustmentQty
		,sa.NetPrice
		,sat.StockAdjName
		,usr.UserID
	from
		StockAdjustments sa with (nolock)
	inner join AllArticles a with (nolock) on a.ArticleNo=sa.ArticleNo
	left outer join StockAdjustmentTypes sat with (nolock) on sat.StockAdjType=sa.StockAdjType
	left outer join vwsys_VBDUsers usr with (nolock) on usr.UserNo=sa.UserNo
	inner join (select TransCntNO from #tmpTransCntNOs) n on n.TransCntNO=sa.TransactionCounter

	drop table #tmpTransCntNOs
end


GO


