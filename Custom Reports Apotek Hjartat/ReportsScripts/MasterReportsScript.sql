-- Master script
-- This script should be run in cmdsql mode
:setvar SQLFile3 "fn_report_convertDateRFC.sql"
:setvar SQLFile333 "usp_CBI_SelectedStoreInfo.sql"
:setvar SQLFile4 "usp_CBI_1095_ds_PharmacyUsers.sql"
:setvar SQLFile5 "usp_CBI_1004_ds_Sustainability_V4.sql"
:setvar SQLFile6 "usp_CBI_1007_ds_PharmacyLoggingNarcotics.sql"
:setvar SQLFile7 "usp_CBI_1001_ds_Pharmacy_RemainingNotes_org.sql"
:setvar SQLFile8 "usp_CBI_1005_ds_DeviationReportMerchandiseReceivencePreliminary.sql"
:setvar SQLFile9 "usp_CBI_1006_ds_PharmacyDifferencialReportReceivingGoods.sql"
:setvar SQLFile10 "ufn_RBI_SplittParameterString.sql"
:setvar SQLFile11 "usp_CBI_1099_Store_Article_MainGroup.sql"
:setvar SQLFile12 "usp_CBI_1043_ds_Stock_AvailableShelves_V2.sql"
:setvar SQLFile13 "usp_CBI_1041_ds_StockMinAndMaxStorage_v3.sql"
:setvar SQLFile14 "usp_CBI_1020_ds_StockCorrectionsPerReasonCode.sql"
:setvar SQLFile15 "usp_CBI_1016_ds_StockBalanceHistoricallyPerStore.sql"
:setvar SQLFile16 "usp_CBI_1013_ds_StockBalancePerItemDetailed.sql"
:setvar SQLFile17 "usp_CBI_1014_ds_OutstandingBalanceOfStocks.sql"
:setvar SQLFile18 "usp_CBI_1012_ds_NegativeStockBalancePerItem.sql"
:setvar SQLFile19 "usp_CBI_1023_ds_ServiceLevel.sql"
:setvar SQLFile20 "usp_CBI_1009_ds_ItemsMissingExpiryDate.sql"
:setvar SQLFile21 "usp_CBI_1033_ds_VaruInventering_Details.sql"
:setvar SQLFile22 "usp_CBI_1032_ds_StockCount_StockCountProposal.sql"
:setvar SQLFile23 "usp_CBI_1031_ds_StockAuction_InventoryList.sql"
:setvar SQLFile24 "usp_CBI_1199_ds_Monitoring.sql"
:setvar SQLFile25 "usp_CBI_1030_ds_StockCount_Differences.sql"
:setvar SQLFile26 "usp_CBI_1024_ds_LoginReport_V2.sql"
:setvar SQLFile27 "usp_CBI_1042_ds_StorageShelf_V2.sql"
:setvar SQLFile28 "usp_CBI_1011_ds_StockValuePerItem.sql"
:setvar SQLFile29 "usp_CBI_1010_ds_StockValuePerItemGroup.sql"
:setvar SQLFile30 "usp_CBI_1025_ds_Stock_Movements_V2.sql"
:setvar SQLFile31 "usp_CBI_1204_ds_Varouvation_Differences_Total.sql"
:setvar SQLFile32 "usp_CBI_1205_ds_VarouvationDifferenceDetail.sql"
:setvar SQLFile33 "ufn_CBI_getDynamicColsStrings.sql"
:setvar SQLFile34 "CBI_vrsp_GetDynamicValues_V3.sql"
:setvar SQLFile35 "ufn_CBI_getStoreNoForStoreGroups_V3.sql"
:setvar SQLFile36 "usp_CBI_1002_ds_SuppliersInformation.sql"
:setvar SQLFile37 "usp_CBI_1021_ds_StockCorrectionsPerReasonCodeDetails.sql"
:setvar SQLFile38 "usp_CBI_1022_ds_StockAdjustmentTransactionDetails.sql"
:setvar SQLFile39 "usp_CBI_SelectedStoreGroupInfo.sql"
:setvar SQLFile40 "usp_CBI_1032_ds_StockCount_StockCountProposal_ReturnInputValues.sql"


:setvar Error "Errors.txt"
:setvar Path "C:\FinalReportsDone\" 
 --specify the path of the error file
 :error $(Path)$(Error)

USE VBDCM -- Set the database name

--fn_report_convertDateRFC.sql
:r $(Path)$(SQLFile3)

--usp_CBI_SelectedStoreInfo.sql
:r $(Path)$(SQLFile333)

--usp_CBI_1095_ds_PharmacyUsers.sql
:r $(Path)$(SQLFile4)

--usp_CBI_1004_ds_Sustainability_V4.sql
:r $(Path)$(SQLFile5)

--usp_CBI_1007_ds_PharmacyLoggingNarcotics.sql
:r $(Path)$(SQLFile6)

--usp_CBI_1001_ds_Pharmacy_RemainingNotes_org.sql
:r $(Path)$(SQLFile7)

-- usp_CBI_1005_ds_DeviationReportMerchandiseReceivencePreliminary.sql
:r $(Path)$(SQLFile8)

-- usp_CBI_1006_ds_PharmacyDifferencialReportReceivingGoods
:r $(Path)$(SQLFile9)

--ufn_RBI_SplittParameterString.sql
:r $(Path)$(SQLFile10)

--usp_CBI_1099_Store_Article_MainGroup.sql
:r $(Path)$(SQLFile11)

--usp_CBI_1043_ds_Stock_AvailableShelves_V2
:r $(Path)$(SQLFile12)

--usp_CBI_1041_ds_StockMinAndMaxStorage_v3.sql
:r $(Path)$(SQLFile13)

--usp_CBI_1020_ds_StockCorrectionsPerReasonCodeV2
:r $(Path)$(SQLFile14)

--usp_CBI_1016_ds_StockBalanceHistoricallyPerStore.sql
:r $(Path)$(SQLFile15)

-- usp_CBI_1013_ds_StockBalancePerItemDetailed.sql
:r $(Path)$(SQLFile16)

-- usp_CBI_1014_ds_OutstandingBalanceOfStocks.sql
:r $(Path)$(SQLFile17)

-- usp_CBI_1012_ds_NegativeStockBalancePerItem.sql
:r $(Path)$(SQLFile18)

-- usp_CBI_1023_ds_ServiceLevel
:r $(Path)$(SQLFile19)

-- usp_CBI_1009_ds_ItemsMissingExpiryDate
:r $(Path)$(SQLFile20)

-- usp_CBI_1033_ds_VaruInventering_Details.sql
:r $(Path)$(SQLFile21)

-- usp_CBI_1032_ds_StockCount_StockCountProposal
:r $(Path)$(SQLFile22)

-- usp_CBI_1031_ds_StockAuction_InventoryList
:r $(Path)$(SQLFile23)

-- usp_CBI_1199_ds_Monitoring.sql
:r $(Path)$(SQLFile24)

-- usp_CBI_1030_ds_StockCount_Differences
:r $(Path)$(SQLFile25)

--usp_CBI_1024_ds_LoginReport_V2.sql
:r $(Path)$(SQLFile26)

-- usp_CBI_1042_ds_StorageShelf_V2.sql
:r $(Path)$(SQLFile27)

-- usp_CBI_1011_ds_StockValuePerItem.sql
:r $(Path)$(SQLFile28)

-- usp_CBI_1010_ds_StockValuePerItemGroup.sql
:r $(Path)$(SQLFile29)


-- usp_CBI_1025_ds_Stock_Movements_V2.sql
:r $(Path)$(SQLFile30)

-- "usp_CBI_1204_ds_Varouvation_Differences_Total.sql"
:r $(Path)$(SQLFile31)


-- usp_CBI_1205_ds_VarouvationDifferenceDetail.sql
:r $(Path)$(SQLFile32)


-- ufn_CBI_getDynamicColsStrings.sql
:r $(Path)$(SQLFile33)


-- CBI_vrsp_GetDynamicValues_V2.sql
:r $(Path)$(SQLFile34)

--ufn_CBI_getStoreNoForStoreGroups_V3.sql
:r $(Path)$(SQLFile35)

--usp_CBI_1002_ds_SuppliersInformation.sql
:r $(Path)$(SQLFile36)


-- usp_CBI_1021_ds_StockCorrectionsPerReasonCodeDetails.sql
:r $(Path)$(SQLFile37)


-- usp_CBI_1022_ds_StockAdjustmentTransactionDetails.sql
:r $(Path)$(SQLFile38)


-- usp_CBI_SelectedStoreGroupInfo
:r $(Path)$(SQLFile39)


-- usp_CBI_1032_ds_StockCount_StockCountProposal_ReturnInputValues
:r $(Path)$(SQLFile40)




/*
exec usp_CBI_1095_ds_PharmacyUsers

exec usp_CBI_1004_ds_Sustainability_Report @parDatumFrom = '2008-01-01',
											 @parDatumTo = '2018-06-01',
											 @ParStoreNo = '3000'



exec usp_CBI_1007_ds_PharmacyLoggingNarcotics @parDatumFrom = '2018-01-01',
												@parDatumTo = '2018-06-01',
												@ParStoreNo = 3000


exec [dbo].[usp_CBI_1001_ds_Pharmacy_RemainingNotes] 	@ParStoreNo = '1725' 
														,@parOrderDatumFrom = '2018-01-01'
														,@parOrderDatumto = '2018-02-01'
														,@parDeliveryCompany = '1025'



exec usp_CBI_1005_ds_DeviationReportMerchandiseReceivencePreliminary 	@ParStoreNo = '3000',
																		@parDeliveryCompany = '', -- SupplierNo
																		@parDatumFrom = '2018-05-01',
																		@parDatumTo = '2018-05-04',
																		@parDeliveryNoteNo = '7398'



exec usp_CBI_1006_ds_PharmacyDifferencialReportReceivingGoods @parDeliveryCompany = '',
																@parStockAdjReasonNo = '',
																@parDatumFrom = '',
																@parDatumto = '',
																@parDeliveryNoteNo = ''




exec usp_CBI_1099_ds_OmlopshastighetHjartatStore	@parFromDate = '2008-01-01',
													@parToDate = '2018-05-23',
													@StoreGroupNos  = '3000,3010', --'0,375,3009,1007,2000,2999,3002,9232,9908,9237,9190,9929,9227,9913,9223,9270,9798,9765,1047,9808,9275,1265,1286,9242,9226,9915,9942,1107,9269,9266,9259,9802,9008,9189,1136,9557,9566,1152,9868,9893,9896,9900,9546,9119,1332,9553,9562,9003,9580,9101,9527,9549,9548,9520,9559,9542,9118,9149,9157,9168,9138,9161,9139,9829,9838,9085,1231,9063,9082,1046,1351,9831,9064,9967,1630,1140,9830,9200,9219,9836,9216,9215,9203,9213,9201,9214,9489,9468,9478,1274,9417,9487,9506,9507,9470,9514,9962,9480,9418,9485,9431,1126,9413,9177,9593,9767,9766,1612,9755,9504,9685,3099,9665,9676,1288,9677,9294,9686,9678,9303,9324,9689,9674,9390,9748,9180,9399,9372,9336,9402,9740,9736,9375,9403,9335,9392,1132,1163,9647,9568,1155,1368,9040,9026,9637,1615,9031,1530,9663,9027,9019,9029,9656,9648,9043,9654,9038,9036,9360,9363,9344,9347,9348,9354,9355,9351,9457,9451,9461,9460,9462,9123,9697,9619,9127,9615,9614,1629,1626,9721,9610,9128,9621,9705,9720,9700,1321,9706,9701,1202,1531,1528,1527,1529,1562,1684,1691,1692,1693,9051,1720,1721,1722,1723,1726,1725,1724,1727,1728,1729,1730,1731,1733,1732,1734,1735,1736,1737,1738,1739,1740,1741,1744,1743,1742,1746,1748,1747,1749,1750,1751,1648,1642,9260,9288,1752,1753,1754,1761,10000,5722,5720,5721,5723,5727,5728,9659,9248,9846,9865,9803,9307,9332,9750,9398,9312,9889,3000,3010,3001,12345,3003,3005,1641,1649,1656,1657,1658,1659,1660,1661,1662,1663,1664,1667,1668,1669,1670,1671,1672,1673,1674,1675,1676,1677,1678,1680,1705,1707,1708,3004,3008',
													@parInclDeleted = 'Y',
													@parInclNewArticles = 'Y',
													@parSupplierArticleID = '',
													@parArticleName = '',
													@parSumAllStores = '',
													@parGroupBy = '1'






exec usp_CBI_1099_ds_OmlopshastighetHjartatArticle	@parFromDate = '2008-01-01',
														@parToDate = '2018-05-23',
														@StoreGroupNos  = '0,375,3009,1007,2000,2999,3002,9232,9908,9237,9190,9929,9227,9913,9223,9270,9798,9765,1047,9808,9275,1265,1286,9242,9226,9915,9942,1107,9269,9266,9259,9802,9008,9189,1136,9557,9566,1152,9868,9893,9896,9900,9546,9119,1332,9553,9562,9003,9580,9101,9527,9549,9548,9520,9559,9542,9118,9149,9157,9168,9138,9161,9139,9829,9838,9085,1231,9063,9082,1046,1351,9831,9064,9967,1630,1140,9830,9200,9219,9836,9216,9215,9203,9213,9201,9214,9489,9468,9478,1274,9417,9487,9506,9507,9470,9514,9962,9480,9418,9485,9431,1126,9413,9177,9593,9767,9766,1612,9755,9504,9685,3099,9665,9676,1288,9677,9294,9686,9678,9303,9324,9689,9674,9390,9748,9180,9399,9372,9336,9402,9740,9736,9375,9403,9335,9392,1132,1163,9647,9568,1155,1368,9040,9026,9637,1615,9031,1530,9663,9027,9019,9029,9656,9648,9043,9654,9038,9036,9360,9363,9344,9347,9348,9354,9355,9351,9457,9451,9461,9460,9462,9123,9697,9619,9127,9615,9614,1629,1626,9721,9610,9128,9621,9705,9720,9700,1321,9706,9701,1202,1531,1528,1527,1529,1562,1684,1691,1692,1693,9051,1720,1721,1722,1723,1726,1725,1724,1727,1728,1729,1730,1731,1733,1732,1734,1735,1736,1737,1738,1739,1740,1741,1744,1743,1742,1746,1748,1747,1749,1750,1751,1648,1642,9260,9288,1752,1753,1754,1761,10000,5722,5720,5721,5723,5727,5728,9659,9248,9846,9865,9803,9307,9332,9750,9398,9312,9889,3000,3010,3001,12345,3003,3005,1641,1649,1656,1657,1658,1659,1660,1661,1662,1663,1664,1667,1668,1669,1670,1671,1672,1673,1674,1675,1676,1677,1678,1680,1705,1707,1708,3004,3008',
														@parInclDeleted = 'Y',
														@parInclNewArticles = 'Y',
														@parSupplierArticleID = '',
														@parArticleName = '',
														@parSumAllStores = '',
														@parGroupBy = '2'



exec usp_CBI_1099_ds_OmlopshastighetHjartatMainGroupNo	@parFromDate = '2018-01-01',
															@parToDate = '2018-07-01',
															@StoreGroupNos  = '0,375,3009,1007,2000,2999,3002,9232,9908,9237,9190,9929,9227,9913,9223,9270,9798,9765,1047,9808,9275,1265,1286,9242,9226,9915,9942,1107,9269,9266,9259,9802,9008,9189,1136,9557,9566,1152,9868,9893,9896,9900,9546,9119,1332,9553,9562,9003,9580,9101,9527,9549,9548,9520,9559,9542,9118,9149,9157,9168,9138,9161,9139,9829,9838,9085,1231,9063,9082,1046,1351,9831,9064,9967,1630,1140,9830,9200,9219,9836,9216,9215,9203,9213,9201,9214,9489,9468,9478,1274,9417,9487,9506,9507,9470,9514,9962,9480,9418,9485,9431,1126,9413,9177,9593,9767,9766,1612,9755,9504,9685,3099,9665,9676,1288,9677,9294,9686,9678,9303,9324,9689,9674,9390,9748,9180,9399,9372,9336,9402,9740,9736,9375,9403,9335,9392,1132,1163,9647,9568,1155,1368,9040,9026,9637,1615,9031,1530,9663,9027,9019,9029,9656,9648,9043,9654,9038,9036,9360,9363,9344,9347,9348,9354,9355,9351,9457,9451,9461,9460,9462,9123,9697,9619,9127,9615,9614,1629,1626,9721,9610,9128,9621,9705,9720,9700,1321,9706,9701,1202,1531,1528,1527,1529,1562,1684,1691,1692,1693,9051,1720,1721,1722,1723,1726,1725,1724,1727,1728,1729,1730,1731,1733,1732,1734,1735,1736,1737,1738,1739,1740,1741,1744,1743,1742,1746,1748,1747,1749,1750,1751,1648,1642,9260,9288,1752,1753,1754,1761,10000,5722,5720,5721,5723,5727,5728,9659,9248,9846,9865,9803,9307,9332,9750,9398,9312,9889,3000,3010,3001,12345,3003,3005,1641,1649,1656,1657,1658,1659,1660,1661,1662,1663,1664,1667,1668,1669,1670,1671,1672,1673,1674,1675,1676,1677,1678,1680,1705,1707,1708,3004,3008',
															@parInclDeleted = 'Y',
															@parInclNewArticles = 'Y',
															@parSupplierArticleID = '',
															@parArticleName = '',
															@parSumAllStores = '',
															@parGroupBy = '4'



exec dbo.usp_CBI_1043_ds_Stock_AvailableShelves '1725'



exec usp_CBI_1041_ds_StockMinAndMaxStorage	@StoreGroupNos = '2018',
												@parInkPrisMin = '',
												@parInkPrisMax = '',
												@parTop1='Y',
												@parTop2='N',
												@parTop3='N',
												@parTop4='N',
												@parTop5='N'



exec usp_CBI_1020_ds_StockCorrectionsPerReasonCode	@parDateFrom  = '19-03-2012',
														@parDateTo = '18-04-2012',
														@StoreGroupNos = '9347,1725',
														@parSupplierArticleID  = '',
														@parStockAdjReasonNo = ''


exec usp_CBI_1016_ds_StockBalanceHistoricallyPerStore @StoreGroupNos = '5122,9227,9403', 
														@parNearestDate= '2018-01-01'



exec usp_CBI_1013_ds_StockBalancePerItemDetailed   @parStoreNo = '1725'
													 ,@parSupplierNo = ''
													 ,@parArticleHierNo = '1,19'
													 ,@parArticleHierNoSubGroups = '' --'1,19'
													 ,@parArticleName = ''
													 ,@parArticleID = ''
													 ,@parEanNo = ''
													 ,@parSupplierArticleID = ''



exec usp_CBI_1014_ds_OutstandingBalanceOfStocks	@StoreGroupNos = '1725,1250',
													@parExpiredateFrom = '2018-01-01', 
													@parExpiredateTo = '2018-01-20'



exec [dbo].[usp_CBI_1012_ds_NegativeStockBalancePerItem]  @StoreGroupNos = '3000,3010', 
															@parSupplierNo = '',
															@parArticleHierNo = '',
															@parArticleHierNoSubGroups = '',
															@parArticleName = '',
															@parArticleID = '',
															@parEanNo = '',
															@parSupplierArticleID = ''



exec [dbo].usp_CBI_1023_ds_ServiceLevel	 @parStoreNo =''
											, @parDateFrom = '1900-01-01'
											, @parDateTo = '2040-01-01'



exec usp_CBI_1009_ds_ItemsMissingExpiryDate  @ParStoreNo = ''		
											  ,@parHuvudGruppNo = '' WITH RECOMPILE; 



exec [dbo].[usp_CBI_1033_ds_VaruInventering_Details]	@parStoreNo = '3000'	--'3000'
														,@parStockCountNo = '1202'	--'807'
														,@parShowNumberInDPacks  = 'Y'



exec [dbo].usp_CBI_1032_ds_StockCount_StockCountProposal									 
															 @StoreGroupNos = '1725,1000'
															, @parArticleHierNo = '1,19'
															, @parArticleHierNoSubGroups = ''--'123,321'
															, @parArticleName = ''
															, @ParHylla1 = ''
															, @ParHylla2 = ''
															, @parNotCountedInXDays = '3'




exec  [dbo].[usp_CBI_1031_ds_StockAuction_InventoryList]	@parStoreNo = '3000'
															,@parStockCountNo  = '935'
															,@parArticleHierNo  = ''
															,@parArticleHierNoSubGroups  = ''
															,@parSupplierNo  = ''
															,@parArticleName  = ''
															,@parOrderBy = ''
															,@parShowNumberInDPacks = 'N'



exec usp_CBI_1199_ds_Monitoring




exec usp_CBI_1030_ds_StockCount_Differences	@parStoreNo = '3000'
												,@parStockCountNo = '934'
												,@parArticleHierNo = ''
												,@parArticleHierNoSubGroups = ''
												,@parSupplierNo = ''
												,@parIncl = ''



exec usp_CBI_1024_ds_LoginReport	@StoreGroupNos = N'1725,5122,2801,9227,9403,9705,1774,9580,5108,2303,1656,9200,1186,9051,9053,1629,9485,9038,1648,1612,9755,1778,9372,9354,9393,1132,9542,9043,9648,9619,9219,9161,9128,9040,9568,1739,5137,9546,1703,9548,9177,5175,5103,9064,9549,9527,9913,9686,1733,1747,9685,5720,5164,1732,9553,9031,9766,9355,9392,9085,5135,9082,2502,4911,9269,5719,9478,1769,5163,9390,9838,1730,9460,9201,9019,9012,1368,5172,5136,1751,1152,5139,5101,1748,1675,1783,1705,9868,9846,5140,1743,5158,9557,9413,9103,9736,9765,9487,1662,1767,5110,5120,9896,5199,9398,5114,9399,1726,5147,9678,5125,9461,9417,5109,2306,5205,5151,9942,9248,1745,5148,1781,9615,9748,5195,5126,5200,9647,5189,5177,9674,5717,9029,9157,1735,5131,9138,9127,1758,5191,2101,4551,9216,5187,9504,2001,5107,1126,1765,5116,16439,9375,2501,1760,9036,9559,9720,1672,9689,5160,5146,9758,9659,2304,5143,9908,5141,9593,5102,1777,9676,5129,1562,1736,9232,9893,9226,5714,5178,2301,9254,9418,9506,5203,1678,9637,9324,9119,2802,1722,9507,1046,1780,5117,9967,1731,5716,2903,2901,1231,9451,5170,2202,9213,9520,9027,9270,1047,1667,5123,9266,1140,5207,9697,5128,9700,9701,1727,1107,9260,1265,2308,9621,1657,9798,1746,1754,1728,1757,1658,9803,1673,9802,1737,2305,9808,1664,5145,1286,5115,9101,5196,5132,9562,5803,5806,5805,5804,5820,5801,5802,9063,1753,5118,9215,5119,2902,9767,1772,1642,5124,1761,9163,9614,1721,9830,1670,1671,9836,5134,5165,5728,1755,5725,2401,1527,9740,9214,5188,2503,1351,9402,5198,9706,9189,5133,1752,1274,5730,1674,1676,9514,5166,4915,4917,4916,1677,1530,5721,9431,5150,1630,9360,5167,5202,9457,9489,5201,9654,9149,1766,9008,5183,9242,9237,5210,1692,5192,2307,1729,9831,1649,9180,1321,5149,1626,5161,9123,9480,1329,1668,1332,5727,9468,1750,9026,5104,5206,9750,2403,1763,9566,9656,9303,5112,1679,1680,9665,5111,5715,1156,9190,9275,1691,1742,2404,1779,5724,1669,1771,1770,9336,1529,1734,5113,9332,1288,9312,1663,2405,1163,9335,2402,5722,5726,9962,1782,5174,1136,1528,1768,1724,1155,1738,5130,1615,5156,9462,9288,1756,9118,9363,9915,9900,5142,5144,2302,5159,1723,1684,1707,9663,5182,5729,5197,1202,9610,9307,1641,2601,9351,5169,1759,1531,9348,9344,5713,1773,5127,9347,1741,9294,9677,1708,5193,5173,5162,5155,9139,1749,5106,1661,1740,5105,1776,2701,9470,4901,5723,1659,9865,2201,1720,9223,16463,5121,1744,1693,4601,1775,5176,9829,9203,9929,5157,9721,9168,1762', 
									@parDateFrom =  N'2018-01-01' ,
									@parDateTo =  N'2019-01-01' ,
									@parInkPrisMin = null,
									@parInkPrisMax = null



exec usp_CBI_1042_ds_StorageShelf	@StoreGroupNos = '1202',
										@parDaysSinceLastSold = '',
										@parInkPrisMin = '',
										@parInkPrisMax = '',
										@parTop1='Y',
										@parTop2='Y',
										@parTop3='N',
										@parTop4='N',
										@parTop5='N'



exec usp_CBI_1011_ds_StockValuePerItem	@StoreGroupNos = '1202,1725,1152,1562',
											@parSupplierNo = '',
											@parSupplierArticleID = '',
											@ParNarcoticsClass ='',
											@parInkPrisMin = '',
											@parInkPrisMax = '',
											@parTop1='Y',
											@parTop2='Y',
											@parTop3='Y',
											@parTop4='Y',
											@parTop5='Y',
											@Urval=''

exec dbo.usp_CBI_1010_ds_StockValuePerItemGroup @StoreGroupNos = '1152,1202,1562,1725'




exec [dbo].[usp_CBI_1025_ds_Stock_Movements]	@parStoreNo ='1725',
												@parDateFrom = '2018-01-01',
												@parDateTo = '2018-06-01',
												@parSupplierNo = '',
												@parSupplierArticleID = '',
												@parArticleNo = '',
												@parArticleID = '',
												@parEANNo = '',
												@parArticleName = '',
												@parArticleHierNo = ''






exec usp_CBI_1204_ds_Varouvation_Differences_Total	@parStoreNo = '1725' ,
														@parDateFrom = '2018-01-01',
														@parDateTo = '2018-06-01'



exec [dbo].[usp_CBI_1205_ds_VarouvationDifferenceDetail] '3000','961'


EXEC dbo.[usp_CBI_1002_ds_SuppliersInformation] @ParStoreNo = '10000'
												,@parDateFrom = '2016-01-01'
												,@parDateTo = '2019-01-01'
												,@parDeliveryCompany = ''
												,@parDeliveryNoteNo	 = ''
		

*/



