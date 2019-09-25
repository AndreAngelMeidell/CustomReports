USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[vrsp_Avinor_SaleReport]    Script Date: 06.09.2019 13:41:45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[vrsp_Avinor_SaleReport]
	@StoreId AS VARCHAR(100), 
	@DateFrom AS DATE,
	@DateTo AS DATE,
	@ReportType SMALLINT -- 0 all flights, 1 departure, 2 arrival, 3 extra
AS
BEGIN

	SET NOCOUNT ON;
	
    DECLARE @sqlStr VARCHAR(MAX)
	DECLARE @cmdStr VARCHAR(6000)
	DECLARE @login VARCHAR(20)
	DECLARE @pw VARCHAR(20)
	DECLARE @server VARCHAR(100)
	DECLARE @folder VARCHAR(100)
	DECLARE @fileName VARCHAR(1000)
	DECLARE @DateFromStr AS VARCHAR(10) = CONVERT(VARCHAR, @DateFrom)
	DECLARE @DateToStr AS VARCHAR(10) = CONVERT(VARCHAR, @DateTo)
	DECLARE @ReportTypeStr AS VARCHAR(1) = CONVERT(VARCHAR, @ReportType)


	SET @folder = '\\sgm434\AppData2\TRN\'	
	SET @server = 'gm-a01-s0046'
	SET @login = 'AvinorSA'
	SET @pw = '@vinor4055123'


	SET @fileName = 'Avinor_' + @StoreId + '_' + @DateToStr + '.csv'
	
	SET @sqlStr = '
	
	DECLARE @DateF DATE = ''' +  @DateFromStr  + '''
	DECLARE @DateT DATE = ''' +  @DateToStr + '''
	DECLARE @DateFromIdx int = cast(convert(varchar(8),@DateF, 112) as integer)
	DECLARE @DateToIdx int = cast(convert(varchar(8),@DateT, 112) as integer) 

	select 
	case flight.Lev2RegionGroupNo 
		when 1009 then ''ENBO''  
		when 1010 then ''ENEV''  
		when 1011 then ''ENHD'' 
		when 1012 then ''ENKB''  
		when 1013 then ''ENML''  
		when 1014 then ''ENTC''  
		when 1015 then ''ENAL''  
		else ''EN''
	end AS Airport,
	FLIGHT.store as Store,
	FLIGHT.storename as StoreName,
	FLIGHT.fulldate as Date, 
	FLIGHT.FlightNo, 
	FLIGHT.Origin,
	FLIGHT.Destination,
	FLIGHT.FlightType,
	case SALES.ArticleHierarchyId 
		when -4 then 9999
		else SALES.ArticleHierarchyId 
	end AS ArticleHierarchyId,

	case SALES.ArticleHierarchyId 
		when -4 then ''**No of customers**''
		else SALES.ArticleHierarchyName 
	end AS ArticleHierarchyName,

	SUM(NoOfArticlesSold) as NoOfArticlesSold,

	CASE SALES.ArticleHierarchyId
		WHEN -4 THEN sum(sales.cust)
		ELSE CAST((SUM(Revenue)) as MONEY)
	END as Revenue

	,isnull(FLIGHT.flightid,'''')			as FlightID
	,isnull(FLIGHT.Traveltype,'''')			as TravelType
	,isnull(FLIGHT.finalairport,'''')		as FinalAirport
	
	,isnull(flight.FinalAirportName,(select AirportName from [RSFlightESDb].[dbo].[Airports] a where flight.finalairport = a.airportcode )) as FinalAirportName

	,case TravelType
			WHEN ''EXT''	THEN case when isnumeric(PreviousAirport)=1 then '''' Else isnull(PreviousAirport,'''') end
			WHEN ''ARR''	THEN case when isnumeric(PreviousAirport)=1 then '''' Else isnull(PreviousAirport,'''') end
			WHEN ''DEP''	THEN case when isnumeric(PreviousAirport)=1 then '''' Else isnull(PreviousAirport,'''') end
			WHEN ''DD''		THEN case when isnumeric(ConnectedAirport)=1 then '''' Else isnull(ConnectedAirport,'''') end
			WHEN ''ID''		THEN case when isnumeric(ConnectedAirport)=1 then '''' Else isnull(PreviousAirport,'''') end
			WHEN ''II''		THEN case when isnumeric(ConnectedAirport)=1 then '''' Else isnull(ConnectedAirport,'''') end
			WHEN ''DI''		THEN case when isnumeric(PreviousAirport)=1 then '''' Else isnull(PreviousAirport,'''') end
			WHEN ''DD''		THEN case when isnumeric(ConnectedAirport)=1 then '''' Else isnull(ConnectedAirport,'''') end
			else case when isnumeric(ConnectedAirport)=1 then '''' Else isnull(ConnectedAirport,'''') end
	end AS ConnectedAirport
	,isnull(ConnectingFlightNo,'''') as ConnectingFlightNo
	,isnull(ConnectingUniqueID,'''') as ConnectingUniqueID

	from
	(SELECT
		ReceiptHeadIdx,
		ds.storeid as Store,
		ds.StoreName as StoreName,
		ds.Lev2RegionGroupNo, 
		se.localairport as LocalAirport,
		dd.fulldate,
		FlightNo,
			CASE origincode
						WHEN ''D'' THEN se.LocalAirport
						WHEN ''A'' THEN se.connectedairport
						ELSE 	se.LocalAirport 
			END AS Origin,
			CASE origincode
						WHEN ''D'' THEN se.connectedairport
						WHEN ''A'' THEN se.LocalAirport
						ELSE 	se.LocalAirport
			END AS Destination,
			CASE origincode
						WHEN ''D'' THEN ''Departure''
						WHEN ''A'' THEN ''Arrival''
						ELSE ''Extra''
			END  AS FlightType
		, ConnectedAirport
		, PreviousAirport
		,CASE
			WHEN (se.uniqueid <0) THEN null
		    ELSE se.uniqueid
		END as FLightID
		,case 
			when se.traveltype is null then
				case se.origincode
					when ''D'' then ''DEP''
					when ''A'' then ''ARR''
					else ''EXT''
				end 
			else traveltype
		end as TravelType
		,case 
			when se.finalairport is null then
				case se.origincode
					when ''D'' then se.connectedairport
					when ''A'' then se.LocalAirport 
					when '''' then se.LocalAirport
					else se.LocalAirport
				end
			else se.FinalAirport
		end as FinalAirport

		,FinalAirportName	as FinalAirportName
		,InboundFlightNo	as ConnectingFlightNo

		,CASE 
			WHEN (InboundUniqueId <=-1) THEN null
			ELSE InboundUniqueId  
		END as ConnectingUniqueID

	FROM RBIM.Cov_customerflightinfo se (NOLOCK)
		JOIN RBIM.Dim_Date dd (NOLOCK) ON dd.dateidx = se.receiptdateidx
		JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = se.storeidx
		AND se.ReceiptDateIdx between @DateFromIdx AND @DateToIdx	
		AND ( ds.storeid IS NULL OR  ds.storeid = '''' OR ds.StoreId =  ' + @StoreId + ')
		AND ( 
			' +@ReportTypeStr + ' = 0 
			OR (' + @ReportTypeStr + ' = 1 AND se.origincode = ''D'') 	
			OR (' + @ReportTypeStr + ' = 2 AND se.origincode = ''A'') 	
			OR (' + @ReportTypeStr + ' = 3 AND se.origincode is null) 	
			OR (' + @ReportTypeStr + ' = 9 AND isnull(se.origincode,''X'')  not in (''A'',''D''))
			)
	) FLIGHT

	INNER JOIN 
	(SELECT 
		ReceiptHeadIdx, 
		da.Lev1ArticleHierarchyId AS ArticleHierarchyId,
		da.Lev1ArticleHierarchyName AS ArticleHierarchyName,
		SUM(f.QuantityOfArticlesSold-f.QuantityOfArticlesInReturn) AS NoOfArticlesSold,
		cast((SUM(cast((f.SalesAmountExclVat) as money)+(cast((f.ReturnAmountExclVat) as money))))as decimal(18,2) 	) AS Revenue,
		sum(f.numberofcustomers) as Cust
	FROM RBIM.Fact_ReceiptRowSalesAndReturn f (NOLOCK)
		JOIN RBIM.Dim_Article da (NOLOCK) ON da.ArticleIdx = f.ArticleIdx
		JOIN RBIM.Dim_store ds (NOLOCK) ON ds.storeidx = f.storeidx
		WHERE f.ReceiptDateIdx between @DateFromIdx AND @DateToIdx
		and ( ds.storeid IS NULL OR  ds.storeid = '''' OR ds.StoreId =  ' + @StoreId + ')
	GROUP BY f.ReceiptTimeIdx,ReceiptHeadIdx, da.Lev1ArticleHierarchyId, da.Lev1ArticleHierarchyName
	) SALES

	ON FLIGHT.ReceiptHeadIdx = SALES.ReceiptHeadIdx
	where ArticleHierarchyId >0
	or cust >0

	GROUP BY FlightType, FlightNo, storeName, fulldate, ArticleHierarchyId, ArticleHierarchyName,LocalAirport, Destination, Origin, cust, FLightID, TravelType, FinalAirport,
			ConnectedAirport, ConnectingFlightNo, ConnectingUniqueID, PreviousAirport, FinalAirportName, Store, Lev2RegionGroupNo
	ORDER by FLIGHT.Store, date, Flightno,Flightid, FinalAirport, ArticleHierarchyId
	'

	SET @sqlStr = REPLACE(@sqlStr,CHAR(10),' ')
	SET @sqlStr = REPLACE(@sqlStr,CHAR(13),' ')

	SET @cmdStr = 'bcp "' + @sqlStr + '" queryout "' + @folder + @fileName + '" -c -t";" -U' + @login + ' -P' + @pw + ' -S' + @Server + ' -dBI_Mart'
	
	--print @sqlstr	
	--	PRINT @cmdStr
	--select len(@cmdstr)
	EXEC xp_cmdshell @cmdStr
END

GO

