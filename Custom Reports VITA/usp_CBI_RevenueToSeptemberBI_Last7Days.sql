use [bi_mart]
go

set ansi_nulls on
go

set quoted_identifier on
go

--drop procedure dbo.usp_CBI_RevenueToSeptemberBI_Last7Days
--go

-- =============================================
-- Author:		<Terje Golden Sæther - Visma Retail AS>
-- CreatedDate: 26.06.2017
-- Last ModifiedDate: 26.06.2017
-- This Stored Procedure is a modified version of the usp_CBI_RevenueToSeptemberBI
-- It in sted of gettng data from the previous day it retreives data from 22.05.2017
-- How to use:  
--		Contains following local parameters which must be set:
--		@FromDate 			= Start date of period
--		@ToDate 			= End date of period
--		@FullExportPath 	= Path to where thje exported file is to be placed
--		@DatabaseBCPCommand	= Database server holding the BI_Mart database
--		@UserBCPCommand 	= The SQL user with permissions to run the stored procedure
--		@PasswordBCPCommand	= SQL user's Password 
--		Output:
--		A semicolon separated file name similar to <TheRunDate-VITA_KontrolltallSeptemberBI_Period.csv>
--		A semicolon separated file name similar to <26.06.2017-VITA_KontrolltallSeptemberBI_Fom19.06.2017Tom25.06.2017.csv>
--
-- =============================================

create procedure dbo.usp_CBI_RevenueToSeptemberBI_Last7Days
as
begin
	declare @ExportFileName		varchar(1000)
	declare @FullExportPath		varchar(1000)
	declare @DatabaseBCPCommand varchar(1000)
	declare @UserBCPCommand		varchar(1000)
	declare @PasswordBCPCommand varchar(1000)
	declare @BCPCommands		varchar(1000)
	declare @CMD				varchar(8000)
	declare @CMD2				varchar(8000)
	declare @FromDate			date
	declare @ToDate				date

	-- config start	
	set @FromDate 			= dateadd(day,-7,getdate())
	set @ToDate 			= dateadd(day,-1,getdate())
	set @ExportFileName		= convert(varchar(10),getdate(),104) + '-'+'VITA_KontrolltallSeptemberBI_Fom' + convert(varchar(10),@FromDate,104) + 'Tom' + convert(varchar(10),@ToDate,104) + '.csv'
	set @FullExportPath 	= '\\n13os2sut351\104610Data$\SeptemberBI\Sale.csvReport\' + @ExportFileName
	set @DatabaseBCPCommand	= 'N13OS2SSQ127\A104610'
	set @UserBCPCommand 	= 'rbssql'
	set @PasswordBCPCommand	= 'ett2tre'
	set @BCPCommands 		= '-c -CACP -t";" -S'


	select
		*
	into ##testExport
	from
		(
			(
			select
				1 as id
				,'ButikkID'				as 'ButikkID'
				,'Butikknavn'			as 'Butikknavn'
				,'Dato'					as 'Dato'
				,'Omsetning_ink_MVA'	as 'Omsetning_ink_MVA'
				,'Omsetning_ex_MVA'		as 'Omsetning_ex_MVA'
				,'Antall_Kunder'		as 'Antall_Kunder'
				,'Antall_varer'			as 'Antall_varer'
			)
		union 
			(
			select
				2 as id
				,s.StoreExternalId																				'ButikkID'
				,s.StoreName																					'Butikknavn'
				,cast(convert(varchar(10),d.FullDate,104) as varchar(100))										'Dato'
				,cast(convert(decimal(19,2),sum(sr.SalesAmount+sr.ReturnAmount)) as varchar(100))				'Omsetning_ink_MVA'
				,cast(convert(decimal(19,2),sum(sr.SalesAmountExclVat+sr.ReturnAmountExclVat)) as varchar(100))	'Omsetning_ex_MVA'
				,cast(sum(sr.NumberOfCustomers) as varchar(100))												'Antall_Kunder'
				,cast(sum(sr.QuantityOfArticlesSold - sr.QuantityOfArticlesInReturn) as varchar(100))			'Antall_varer'
			from
				BI_Mart.RBIM.Agg_SalesAndReturnPerDay sr 
			inner join BI_Mart.RBIM.Dim_Store s on s.StoreIdx=sr.StoreIdx and s.IsCurrentStore=1 --and s.isCurrent=1
			inner join BI_Mart.RBIM.Dim_Date d on d.DateIdx=sr.ReceiptDateIdx
			where
				d.FullDate between @FromDate and @ToDate
			group by
				s.StoreExternalId
				,s.StoreName
				,d.FullDate
			)
			union
			(
			select
				3 as id
				,'SumAlleButikker'																					'ButikkID'
				,' '																								'Butikknavn'
				,cast(convert(varchar(10),d.FullDate,104) as varchar(100))											'Dato'
				,cast(convert(decimal(19,2),sum(sr.SalesAmount+ sr.returnAmount)) as varchar(100))					'Omsetning_ink_MVA'
				,cast(convert(decimal(19,2),sum(sr.SalesAmountExclVat+ sr.ReturnAmountExclVat)) as varchar(100))	'Omsetning_ex_MVA'
				,cast(sum(sr.NumberOfCustomers) as varchar(100))													'Antall_Kunder'
				,cast(sum(sr.QuantityOfArticlesSold - sr.QuantityOfArticlesInReturn) as varchar(100))				'Antall_varer'
			from
				BI_Mart.RBIM.Agg_SalesAndReturnPerDay sr 
			inner join BI_Mart.RBIM.Dim_Date d on d.DateIdx=sr.ReceiptDateIdx
			where
				d.FullDate between @FromDate and @ToDate
			group by
				d.FullDate
			)
		) test 
			--	select * from ##testExport

			--select ButikkID, Butikknavn, Dato, Omsetning_ink_MVA, Omsetning_ex_MVA, Antall_Kunder, Antall_varer from ##testExport order by id, ButikkID desc

		set @CMD = 'BCP "select ButikkID, Butikknavn, Dato, Omsetning_ink_MVA, Omsetning_ex_MVA, Antall_Kunder, Antall_varer from ##testExport order by id, ButikkID desc" queryout "'+@FullExportPath+'" '+@BCPCommands +' '+ @DatabaseBCPCommand+' -U '+@UserBCPCommand+' -P '+@PasswordBCPCommand+''
	
		exec master..xp_cmdshell @CMD

		drop table ##testExport
end
