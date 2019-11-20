USE [VBDCM]
GO


IF EXISTS ( SELECT * FROM sysobjects WHERE name = N'usp_CBI_1005_ds_DeviationReportMerchandiseReceivencePreliminary'  AND xtype = 'P')
DROP PROCEDURE usp_CBI_1005_ds_DeviationReportMerchandiseReceivencePreliminary
GO

CREATE PROCEDURE [dbo].[usp_CBI_1005_ds_DeviationReportMerchandiseReceivencePreliminary]  (
				 	@ParStoreNo AS VARCHAR(4000),
					@parDeliveryCompany AS VARCHAR(30),
					@parDatumFrom AS VARCHAR(30) = '',
					@parDatumTo AS VARCHAR(30)  = '',
					@parDeliveryNoteNo AS VARCHAR(4000) = '',
					@parExternalDeliveryNoteId_hidden AS VARCHAR(4000) = ''
)
AS
BEGIN

		SET DATEFORMAT DMY

		DECLARE @SQL AS VARCHAR(8000)

		SET @SQL = '
		SELECT 
			D.StoreNo AS ButiksNr,
			MAX(D.SupplierNo) AS LevNr,
			MAX(SO.SupplierName) AS LevNamn,
			DL.OrderNo AS OrderNr,
			DL.OrderLineNo AS OrderRad, 
			DL.ArticleNo AS ArtNo,
			MAX(A.ArticleID) AS ArtId,
			MAX(A.ArticleName) AS Benamning,
			MAX(DL.SupplierArticleID) AS BestNr,
			SUM(ISNULL(DL.InitialOrderedQty,0)) AS BestalltAntal,
			SUM(ISNULL(RL.ReceivedQty,0)) AS SenastMottaget,  -- LPU 20190527 SUM is still not senast(latest), but I have changed the header to Mottaget(Received) so it matches what we send

			case 
				when MAX(ISNULL(RL.ReceivingTypeNo,0))=1 --rla
				then ''Ja''
				else ''Nej''
			end AS Scannad,

			case 
				when MAX(DL.DeliveryLinestatus)>10
				then MAX(CONVERT(varchar, RL.CompletedReceivalDate, 23)) 
			end AS MottagetDatum,
			SUM(ISNULL(RL.ReceivedQty,0)) - SUM(ISNULL(del.deliveredqty,0)) AS Avikelse, -- LPU 20190527 Taken away the old Avvikelse since it missed a lot of deviations
			MAX(a.articlehiernametop) AS Huvudgrupp,
			MAX(d.DeliveryNoteNo) AS PacksedelsNr,
			ISNULL(del.ExternalDeliveryNoteId,'''') AS ExternPacksedel,
			SUM(ISNULL(del.deliveredqty,0)) AS Bekraftat
		FROM Deliveries AS D WITH (NOLOCK)
		INNER JOIN DeliveryLines DL WITH (NOLOCK) on DL.DeliveryNoteNo=D.DeliveryNoteNo 
		--LEFT JOIN ReceivedLines as RL WITH (NOLOCK) on dl.DeliveryLineNo=RL.DeliveryLineNo and RL.ReceivingTypeNo IS NOT NULL	-- /* VPT-1522  to take only received lines*/
		--  left join ReceivedLines as RL WITH (NOLOCK) on dl.DeliveryLineNo=RL.DeliveryLineNo and RL.ReceivingTypeNo IS NOT NULL -- LPU 20190502
		--left join Deliveries as D WITH (NOLOCK) on DL.DeliveryNoteNo=D.DeliveryNoteNo 
		LEFT JOIN DeliveryLineStates as DLS WITH (NOLOCK) on DL.DeliveryLinestatus=DLS.DeliveryLinestatus
		--  left join DeliveredLines as del WITH (NOLOCK) on DL.DeliveryLineNo=del.DeliveryLineNo --and del.deliveredlinetypeno<30
		LEFT JOIN DeliveredLines as del on DL.DeliveryLineNo=del.DeliveryLineNo and del.DeliveryNoteNo = DL.DeliveryNoteNo
		OUTER APPLY ( SELECT DeliveryNoteNo, DeliveredLineNo, MAX(ReceivingTypeNo) AS ReceivingTypeNo, MAX(RL.CompletedReceivalDate) AS CompletedReceivalDate, SUM(ReceivedQty) AS ReceivedQty 
					  FROM ReceivedLines rl WITH (NOLOCK) 
					  WHERE rl.DeliveryNoteNo = del.DeliveryNoteNo AND rl.DeliveredLineNo = del.DeliveredLineNo  
					  GROUP BY DeliveryNoteNo, DeliveredLineNo ) RL
		LEFT JOIN Stores as S WITH (NOLOCK) on D.Storeno=S.storeNo
		LEFT JOIN SupplierOrgs As SO WITH (NOLOCK) on D.SupplierNo=SO.SupplierNo
		LEFT JOIN Allarticles A WITH (NOLOCK) on DL.Articleno=A.Articleno 
		LEFT OUTER JOIN SupplierInfos si WITH (NOLOCK) ON d.SupplierNo=si.SupplierNo AND si.InfoID=''DN_UseExternalDeliveryNoteID''
		WHERE  1=1 
		AND (D.DeliveryStatus <= 79) 
		AND (D.DeliveryStatus >= 60) -- LPU 20190815 VPT-1522 
		AND (si.SupplierNo IS NULL OR si.InfoValue=''0'')

		' 

		IF LEN(@parStoreNo) > 0 
			set @SQL = @SQL + ' AND D.StoreNo in (' + @parStoreNo + ')'

		IF LEN(@parExternalDeliveryNoteId_hidden) > 0 			 
			SET @sql = @sql + ' AND del.ExternalDeliveryNoteId = ''' + @parExternalDeliveryNoteId_hidden + ''''
		ELSE IF LEN(@parDeliveryNoteNo) > 0 
			SET @sql = @sql + ' AND DL.DeliveryNoteNo IN (SELECT value
														  FROM STRING_SPLIT( ''' + @parDeliveryNoteNo + ''','',''))
														  '
		ELSE IF LEN(@parDatumFrom) > ''
			SET @SQL = @SQL + ' AND CONVERT(CHAR(10), RL.RecordCreated, 120) 
				BETWEEN  
						CONVERT(CHAR(10),CONVERT(DateTime,'''+ @parDatumFrom +''',105),120)
					AND CONVERT(CHAR(10),CONVERT(DateTime,'''+ @parDatumTo +''' ,105),120)'
		

		IF LEN(@parDeliveryCompany) > 0
			set @SQL = @SQL + '  AND D.SupplierNo = '  + @parDeliveryCompany 

		SET @SQL = @SQL + '
		GROUP BY del.ExternalDeliveryNoteId, D.StoreNo, D.SupplierNo, DL.OrderNo, DL.OrderLineNo, DL.ArticleNo 
		HAVING (MAX(ISNULL(RL.ReceivingTypeNo,0)) <> 1 AND SUM(ISNULL(RL.ReceivedQty,0)) - SUM(ISNULL(del.deliveredqty,0)) = 0 ) 
				OR (SUM(ISNULL(RL.ReceivedQty,0)) - SUM(ISNULL(del.deliveredqty,0))) <> 0
		 '


		SET @SQL = @SQL + '
		UNION ALL '

		SET @SQL = @SQL + '
				SELECT  ed.StoreNo AS StoreNo, 
				MAX(ed.SupplierNo) AS SupplierNo,
				MAX(so.SupplierName) AS SupplierName,
				dl.OrderNo AS OrderNr,
				dl.OrderLineNo AS OrderRad, 
				dl.ArticleNo AS ArtNo,
				MAX(al.ArticleID) AS ArtId,
				MAX(al.ArticleName) AS Benamning,
				MAX(dl.SupplierArticleID) AS BestNr,
				SUM(ISNULL(dl.InitialOrderedQty,0)) AS BestalltAntal,
				SUM(ISNULL(RL.ReceivedQty,0)) AS SenastMottaget,
				case 
					when MAX(ISNULL(RL.ReceivingTypeNo,0))=1 --rla
					then ''Ja''
					else ''Nej''
				end AS Scannad,
				case 
					when MAX(dl.DeliveryLinestatus)>10
					then MAX(CONVERT(varchar, RL.CompletedReceivalDate, 23)) 
				end AS MottagetDatum,
				SUM(ISNULL(RL.ReceivedQty,0)) - SUM(ISNULL(ddl.deliveredqty,0)) AS Avikelse,
		
				MAX(al.articlehiernametop) AS Huvudgrupp,
				MAX(dl.DeliveryNoteNo) AS PacksedelsNr,
				-- MAX(ISNULL(del.ExternalDeliveryNoteId,'''')) AS ExternPacksedel,
				ISNULL(ed.ExternalDeliveryNoteId,'''') AS ExternPacksedel,
				SUM(ISNULL(ddl.deliveredqty,0)) AS Bekraftat
		FROM ExternalDeliveries ed
		JOIN Stores store WITH (NOLOCK) ON ed.StoreNo = store.StoreNo
		JOIN SupplierOrgs so WITH (NOLOCK) ON (so.SupplierNo = ed.SupplierNo)
		LEFT JOIN DeliveredLines ddl WITH (NOLOCK) ON (ed.ExternalDeliveryNoteID = ddl.ExternalDeliveryNoteID)
		JOIN VBDCM.dbo.deliverylines dl WITH (NOLOCK) ON ddl.deliverynoteno = dl.deliverynoteno and ddl.deliverylineno = dl.deliverylineno
		JOIN VBDCM.dbo.AllArticles al WITH (NOLOCK) ON al.ArticleNo = dl.ArticleNo
		--LEFT JOIN ReceivedLines RL WITH (NOLOCK) on dl.DeliveryLineNo = RL.DeliveryLineNo 
		OUTER APPLY ( SELECT DeliveryNoteNo, DeliveredLineNo, MAX(ReceivingTypeNo) AS ReceivingTypeNo, MAX(RL.CompletedReceivalDate) AS CompletedReceivalDate, SUM(ReceivedQty) AS ReceivedQty 
				FROM ReceivedLines rl WITH (NOLOCK) 
				WHERE rl.DeliveryNoteNo = ddl.DeliveryNoteNo AND rl.DeliveredLineNo = ddl.DeliveredLineNo  
				GROUP BY DeliveryNoteNo, DeliveredLineNo ) RL
		WHERE  1=1 
		AND (ed.DeliveryStatus <= 79) 
		AND (ed.DeliveryStatus >= 60) -- LPU 20190815 VPT-1522
		'

		IF LEN(@parStoreNo) > 0 
			set @SQL = @SQL + ' AND ed.StoreNo in (' + @parStoreNo + ')'

		
		IF LEN(@parExternalDeliveryNoteId_hidden) > 0 			 
			SET @sql = @sql + ' AND ddl.ExternalDeliveryNoteId = ''' + @parExternalDeliveryNoteId_hidden + ''''
		ELSE IF LEN(@parDeliveryNoteNo) > 0 
			SET @sql = @sql + ' AND DL.DeliveryNoteNo IN (SELECT value
														  FROM STRING_SPLIT( ''' + @parDeliveryNoteNo + ''','',''))
														  '
		ELSE IF LEN(@parDatumFrom) > ''
			SET @SQL = @SQL + ' AND CONVERT(CHAR(10), RL.RecordCreated, 120) 
				BETWEEN  
						CONVERT(CHAR(10),CONVERT(DateTime,'''+ @parDatumFrom +''',105),120)
					AND CONVERT(CHAR(10),CONVERT(DateTime,'''+ @parDatumTo +''' ,105),120)'
		

		IF LEN(@parDeliveryCompany) > 0
			set @SQL = @SQL + '  AND so.SupplierNo = '  + @parDeliveryCompany 


		SET @SQL = @SQL + '
		GROUP BY ed.ExternalDeliveryNoteId, ed.StoreNo, ed.SupplierNo, DL.OrderNo, DL.OrderLineNo,DL.ArticleNo 
		HAVING (MAX(ISNULL(RL.ReceivingTypeNo,0)) <> 1 AND  SUM(ISNULL(RL.ReceivedQty,0)) - SUM(ISNULL(ddl.deliveredqty,0)) = 0 ) 
			    OR (SUM(ISNULL(RL.ReceivedQty,0)) - SUM(ISNULL(ddl.deliveredqty,0))) <> 0
		'
		--print(@sql)
		EXEC(@SQL)

END
GO











/*
exec usp_CBI_1005_ds_DeviationReportMerchandiseReceivencePreliminary 	@ParStoreNo = '3000',
																		@parDeliveryCompany = '', -- SupplierNo
																		@parDatumFrom = '',
																		@parDatumto = ''
																		,@parDeliveryNoteNo = '13745'
																		,@parExternalDeliveryNoteId_hidden = 'E801159'

*/




