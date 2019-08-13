USE [BI_Mart]
GO

if (object_id('dbo.usp_CBI_ds1752_OperationReport_ExceptionHandling') is not null)
	drop procedure dbo.usp_CBI_ds1752_OperationReport_ExceptionHandling
go

set ansi_nulls on
go

set quoted_identifier on
go


create procedure dbo.usp_CBI_ds1752_OperationReport_ExceptionHandling
	(
	@PeriodType					char(1)
	,@DateFrom					datetime
	,@DateTo					datetime
	,@YearToDate				integer
	,@RelativePeriodType		char(5)
	,@RelativePeriodStart		integer 
	,@RelativePeriodDuration	integer
	,@StoreOrGroupNo			varchar(max)
	)
as
begin
	;with Stores as
		(
		select
			distinct ds.*
		from
			RBIM.Dim_Store ds
		left join ( select ParameterValue from dbo.ufn_RBI_SplittParameterString(@StoreOrGroupNo,',''')) n  on n.ParameterValue in (
								ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
								ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
								ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
								ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
								ds.StoreId) 
		where
				n.ParameterValue is not null
			and ds.IsCurrentStore=1		--to ensure we only get historical changes for the same store (defined by same GLN and same ORG number)
		) 
	,SelectedSales as
		(
		SELECT        
			 sub.CashierId								'CashierId'
			,sub.CasierName								'CasierName'
			,sum(SalesAmount)							'SalesAmount'
			,sum(ReturnAmount)							'ReturnAmount'
			,sum(NumberOfSelectedCorrections)			'NumberOfSelectedCorrections'
			,sum(SelectedCorrectionsAmount)				'SelectedCorrectionsAmount'
			,sum(NumberOfLastCorrections)				'NumberOfLastCorrections'
			,sum(LastCorrectionsAmount)					'LastCorrectionsAmount'
			,sum(NumberOfReceiptsParked)				'NumberOfReceiptsParked'
			,sum(NumberOfReceiptsCanceled)				'NumberOfReceiptsCanceled'
			,sum(CanceledReceiptsAmount)				'CanceledReceiptsAmount'
			,sum(NumberOfReceiptsCorrected)				'NumberOfReceiptsCorrected'
			,sum(NumberOfAgeControl)					'NumberOfAgeControl'
		FROM    
			(
			SELECT     
				su.UserNameID AS CashierId, 
				su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName, 
				SUM(f.SalesAmountExclVat+f.ReturnAmountExclVat) AS SalesAmount,
				SUM(f.ReturnAmountExclVat)*-1 AS ReturnAmount,
				0	AS NumberOfSelectedCorrections, 
				0	AS SelectedCorrectionsAmount, 
				0	AS NumberOfLastCorrections, 
				0	AS LastCorrectionsAmount, 
				0	AS NumberOfReceiptsParked, 
				0	AS NumberOfReceiptsCanceled, 
				0	AS CanceledReceiptsAmount,
				0	AS NumberOfReceiptsCorrected, 
				0	AS NumberOfAgeControl
			FROM
				RBIM.Agg_SalesAndReturnPerDay AS f 
			INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx 
			inner join Stores ds on ds.StoreIdx = f.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
			INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.SystemUserIdx
			WHERE 
				(
					@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo
				OR	@PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
				OR	@PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR	@PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR	@PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR	@PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR	@PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				) 
			GROUP BY
				su.UserNameID
				,su.FirstName
				,su.LastName
			UNION ALL
			SELECT     
				su.UserNameID AS CashierId, 
				su.FirstName + ' ' + ISNULL(su.LastName, '') AS CasierName, 
				0 AS SalesAmount,
				0 AS ReturnAmount,
				SUM(f.NumberOfSelectedCorrections) AS NumberOfSelectedCorrections, 
				SUM(f.SelectedCorrectionsAmount) AS SelectedCorrectionsAmount, 
				SUM(f.NumberOfLastCorrections)   AS NumberOfLastCorrections, 
				SUM(f.LastCorrectionsAmount) AS LastCorrectionsAmount, 
				SUM(f.NumberOfReceiptsParked) AS NumberOfReceiptsParked, 
				SUM(f.NumberOfReceiptsCanceled) AS NumberOfReceiptsCanceled, 
				SUM(CanceledReceiptsAmount) AS CanceledReceiptsAmount, --Missing?
				SUM(f.NumberOfReceiptsCorrected) AS NumberOfReceiptsCorrected, 
				SUM(f.TotalNumberOfAgeControlsApproved + f.TotalNumberOfAgeControlsNotApproved) AS NumberOfAgeControl
			FROM
				RBIM.Agg_CashierSalesAndReturnPerHour AS f 
			INNER JOIN RBIM.Dim_Date AS dd ON dd.DateIdx = f.ReceiptDateIdx 
			inner join Stores ds on ds.StoreIdx = f.StoreIdx		-- VD-1327  (Extend with StoreOrGroupNo)
			INNER JOIN RBIM.Dim_User AS su ON su.UserIdx = f.CashierUserIdx
			WHERE 
				(
					@PeriodType = 'D' AND dd.FullDate BETWEEN @DateFrom AND @DateTo
				OR	@PeriodType = 'Y' AND dd.RelativeYTD = @YearToDate
				OR	@PeriodType = 'R' AND @RelativePeriodType = 'D' AND dd.RelativeDay BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR	@PeriodType = 'R' AND @RelativePeriodType = 'W' AND dd.RelativeWeek BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR	@PeriodType = 'R' AND @RelativePeriodType = 'M' AND dd.RelativeMonth BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR	@PeriodType = 'R' AND @RelativePeriodType = 'Q' AND dd.RelativeQuarter BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				OR	@PeriodType = 'R' AND @RelativePeriodType = 'Y' AND dd.RelativeYear BETWEEN @RelativePeriodStart AND @RelativePeriodStart + @RelativePeriodDuration - 1
				) 
			GROUP BY
				su.UserNameID
				,su.FirstName
				,su.LastName
			) AS sub
		group by
			 sub.CashierId
			,sub.CasierName
		)

	select * from SelectedSales
end

go


