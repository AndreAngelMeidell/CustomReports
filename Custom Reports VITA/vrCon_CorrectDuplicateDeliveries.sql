USE [VBDCM]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

                                 

IF OBJECT_ID('vrCon_CorrectDuplicateDeliveries') IS NOT NULL
	DROP PROCEDURE vrCon_CorrectDuplicateDeliveries
GO

CREATE PROCEDURE [dbo].vrCon_CorrectDuplicateDeliveries
  @StoreNo as VARCHAR(2000),
  @DeliveryNoteNo AS VARCHAR(200),
  @FromDate AS VARCHAR(200),
  @ToDate AS VARCHAR(200),
  @InsertStockAdjustments AS INT,
  @IncludeQtyInDuplicateCheck AS INT,
  @ArticleNo AS VARCHAR(2000),
  @QuantityToAdjust AS VARCHAR(20)
AS

BEGIN	

/*
       Name:				vrCon_CorrectDuplicateDeliveries              

       Description:			Prosedyre for å finne duplikate varemottak som bruker har gjort. Dette kan enten være at LogWeb har hengt og 
							bruker har trykket "Lagre" flere ganger, eller at varemottak er gjort både på WEB og HHT. 
                                  
       Parameters:			@StoreNo: Butikk, en eller flere kommasepareres.
							@DeliveryNoteNo: Pakkseddelnr og AdjustmentRefNo i StockAdjustments
							@FromDate: Fradato, AdjustmentDate, på spørringen
							@ToDate: Tildato, AdjustmentDate, på spørringen
							@InsertStockAdjustments: Hvis denne er satt til 1 så legges det inn transaksjoner for å korrigere i StockAdjustments.
												     Korrigeringer blir lagt inn i vbdtmp..DuplicateDeliveriesCorretions
													 Hvis denne er satt til 0 så returneres resultatet av spørringen. Finnes også i en temporær tabell ##Duplicates
							@IncludeQtyInDuplicateCheck: Hvis denne er satt så er AdjustmentQty med i Group By delen av spørringen, det vil si at antallet 
														 må være likt for at raden skal bli plukket ut. Kun mulig å automatisk korrigere når denne er satt.
							@ArticleNo: Varenummer som brukes i søket
							@QuantityToAdjust: Hvis @IncludeQtyInDuplicateCheck = 0 og @InsertStockAdjustments = 1 så må det angies antallet som skal justeres
											   Dette er kun mulig hvis alle parameterne @StoreNo, @DeliveryNoteNo, @ArticleNo og @QuantityToAdjust er angitt. Kun
											   mulig for en vare av gangen
       Customers:			Vita   

       ToDo:               

       Date:				22.07.2013

       By:					Carsten af Geijerstam, Visma Retail

       Revision:			22.07.2013: Created
       
       Hours to invoice:	 
                                  
*/
 
	DECLARE @iErrorcode as INT,
			@sErrorMessage as varchar(1000),
			@ProcedureName as varchar(100),
			@SQL As varchar(8000)
	set @ProcedureName = 'vrCon_CorrectDuplicateDeliveries'
	
	IF OBJECT_ID('vbdtmp..DuplicateDeliveriesCorretions') IS NULL
	BEGIN
		CREATE TABLE vbdtmp..[DuplicateDeliveriesCorretions](
				[StoreNo] [int] NOT NULL,
				[ArticleNo] [int] NOT NULL,
				[AdjustmentQty] [float] NOT NULL,
				[MaxAdjustmentQty] [float]  NULL,
				[MinAdjustmentQty] [float]  NULL,
				[StockAdjType] [smallint] NOT NULL,
				[AdjustmentRefNo] [varchar](100) NOT NULL,
				[AdjustmentLineNo] [smallint] NULL,
				[antall] [int] NULL,
				[NumberToCorrect] [int] NULL,
				[maxadjustmentdate] [datetime] NULL,
				[netPrice] [float] NULL,
				[SalesPrice] [float] NULL,
				[vatpercentage] [money] NULL,
				[RecordCreated] [DATETIME] NOT NULL 
	) ON [Base]
		CREATE NONCLUSTERED INDEX [IX_StoreNo_ArticleNo] ON vbdtmp..DuplicateDeliveriesCorretions
	(
		[StoreNo] ASC,
		[ArticleNo] ASC
	)

	CREATE UNIQUE NONCLUSTERED INDEX [IX_StoreNo_ArticleNo_AdjustmentRefNo] ON vbdtmp..DuplicateDeliveriesCorretions
	(
		[StoreNo] ASC,
		[ArticleNo] ASC,
		[AdjustmentRefNo] ASC,
		[AdjustmentLineNo] ASC
	)

	END

	IF OBJECT_ID('Tempdb..##Duplicates') IS NOT NULL
	BEGIN 
		set @Sql = 'drop table ##Duplicates'
		exec (@Sql)
	END
	--Hvis ikke antall er med i gruppering, men det skal settes inn korreksjoner, må alle parametere være satt
	IF ((@InsertStockAdjustments = 1 AND @IncludeQtyInDuplicateCheck = 0) AND 
				(LEN(@DeliveryNoteNo) = 0 OR LEN(@ArticleNo) = 0 OR @StoreNo = 0 OR LEN(@QuantityToAdjust) = 0 ))
		BEGIN
			PRINT 'Kan ikke sette inn korrigeringer når IncludeQtyInDuplicateCheck = 0 og alle parameterene DeliveryNoteNo, ArticleNo, QuantityToAdjust og StoreNo ikke er satt'
			RETURN
		END
	--	Hvis ikke antall er med i gruppering, men det skal settes inn korreksjoner. Skal det ikke grupperes, henter ut top 1 i tilfelle det er flere
	IF @InsertStockAdjustments = 1 AND @IncludeQtyInDuplicateCheck = 0
	BEGIN
		SET @SQL = 'SELECT top 1 sa.StoreNo, 
						sa.ArticleNo,'
						+@QuantityToAdjust + ' as AdjustmentQty, 
						NULL as MaxAdjustmentQty,
						NULL as MinAdjustmentQty,
						sa.StockAdjType, 
						sa.AdjustmentRefNo, 
						sa.AdjustmentLineNo, 
						2 AS antall , 
						1 as NumberToCorrect, 
						sa.adjustmentdate as maxadjustmentdate, 
						sa.netPrice as netPrice, 
						sa.SalesPrice as SalesPrice,
						sa.vatpercentage as vatpercentage,
						GETDATE() as RecordCreated '
	END
	ELSE
	BEGIN
		SET @SQL = 'SELECT sa.StoreNo, sa.ArticleNo,'
		IF @IncludeQtyInDuplicateCheck = 1
			SET @SQL = @SQL + '	sa.AdjustmentQty * -1 as AdjustmentQty, '
		ELSE
			SET @SQL = @SQL + '	NULL as AdjustmentQty, '
		SET @SQL = @SQL + '
							MAX(sa.AdjustmentQty) as MaxAdjustmentQty,
							MIN(sa.AdjustmentQty) as MinAdjustmentQty,
							sa.StockAdjType, 
						   sa.AdjustmentRefNo, 
						   sa.AdjustmentLineNo, 
						   COUNT(*) AS antall , 
						   COUNT(*) -1 as NumberToCorrect, 
						   MAX(sa.adjustmentdate) as maxadjustmentdate,
						   MAX(sa.netPrice) as netPrice, 
						   MAX(sa.SalesPrice) as SalesPrice,
						   MAX(sa.vatpercentage) as vatpercentage,
						   GETDATE() as RecordCreated '
	END
	
	SET @SQL = @SQL + '
			into ##Duplicates
			FROM StockAdjustments sa 
			LEFT JOIN vbdtmp..DuplicateDeliveriesCorretions ddc on sa.StoreNo = ddc.StoreNo AND sa.ArticleNo = ddc.ArticleNo AND sa.AdjustmentRefNo = ddc.AdjustmentRefNo
			WHERE sa.StockAdjType = 4
			and ddc.StoreNo IS NULL
			and sa.AdjustmentRefNo is not null
			and sa.AdjustmentLineNo is not null
'
	IF len(@StoreNo) > 0
		SET @SQL = @SQL + '	AND sa.StoreNo IN ('+@StoreNo+')'
	IF len(@DeliveryNoteNo) > 0
		SET @SQL = @SQL + ' AND sa.AdjustmentRefNo = ''' + @DeliveryNoteNo+ ''''
	if len(@FromDate) > 0
		set @sql = @sql + ' and sa.adjustmentdate >= ''' + @FromDate + ' 00:00:00'''
	if len(@ToDate) > 0
		set @sql = @sql + ' and sa.adjustmentdate <= ''' + @ToDate + ' 23:59:59'''
	if LEN (@ArticleNo) > 0
		set @sql = @sql + ' and sa.ArticleNo IN ('+@ArticleNo+')'
		

	IF @IncludeQtyInDuplicateCheck = 1
		SET @SQL = @SQL + '	GROUP BY sa.StoreNo, sa.ArticleNo, sa.AdjustmentQty, sa.StockAdjType, sa.AdjustmentRefNo, sa.AdjustmentLineNo 
			HAVING COUNT ( * ) > 1 
'	ELSE IF @InsertStockAdjustments = 0 AND @IncludeQtyInDuplicateCheck = 0
		SET @SQL = @SQL + '	GROUP BY sa.StoreNo, sa.ArticleNo, sa.StockAdjType, sa.AdjustmentRefNo, sa.AdjustmentLineNo 
			HAVING COUNT ( * ) > 1 
'	ELSE
		SET @SQL = @SQL + ' '
	
	SET @SQL = @SQL + '
	ORDER BY sa.StoreNo, sa.AdjustmentRefNo, RecordCreated desc
	'			
	PRINT @SQL
	exec (@SQL)

	set @iErrorCode = @@ERROR
		IF (@iErrorCode <> 0)
		goto Errorhandler
	
	BEGIN TRANSACTION
		IF @InsertStockAdjustments = 1 
		BEGIN
				insert into StockAdjustments (
							adjustmentqty, 
							adjustmentdate, 
							stockadjtype, 
							StockAdjReasonNo, 
							storeno, 
							articleno, 
							userno, 
							adjustmentrefno, 
							adjustmentnetcostamount, 
							adjustmentsalesamount, 
							adjustmentnetsalesamount,
							AdjustmentLineNo)
				SELECT 
				AdjustmentQty * NumberToCorrect ,		
				maxadjustmentdate,
				4, 
				NULL,
				StoreNo, 
				articleno,
				9999,
				'Retting av doble varemottak', 
				(AdjustmentQty * NumberToCorrect) * netprice,
				(AdjustmentQty * NumberToCorrect)*ISNULL(salesprice,0),
				(AdjustmentQty * NumberToCorrect)*(ISNULL(salesprice,0)/(1+(ISNULL(vatpercentage,0)/100))),
				AdjustmentLineNo
				FROM ##Duplicates
	
			set @iErrorCode = @@ERROR
				IF (@iErrorCode <> 0)
				goto Errorhandler
			
			INSERT INTO vbdtmp..DuplicateDeliveriesCorretions
			SELECT * FROM ##Duplicates
	
			set @iErrorCode = @@ERROR
				IF (@iErrorCode <> 0)	
				goto Errorhandler
				
		END
		ELSE
			SELECT * FROM ##Duplicates	
			
			set @iErrorCode = @@ERROR
				IF (@iErrorCode <> 0)
				goto Errorhandler
			
	END
			
ErrorHandler:

  IF (@iErrorCode = 0)
  BEGIN
        COMMIT
  END
  ELSE
  BEGIN
  
	IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK
				set @sErrorMessage = (select description from master..sysmessages where error = @iErrorCode)
					exec vbdcm.dbo.vbdspSYS_insert_vbderror @iErrorCode, @sErrorMessage, 
					@ProcedureName, 'Stored Procedure', '', ''
		END
				
  END
  