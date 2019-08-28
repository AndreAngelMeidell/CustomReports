USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1555_StoreInfo]    Script Date: 28.08.2019 13:09:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE  PROCEDURE [dbo].[usp_CBI_1555_StoreInfo]

AS  
BEGIN
  
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @sql AS VARCHAR(100)

IF OBJECT_ID('tempdb..#Store_Flattern') is NOT NULL
BEGIN 
	set @Sql = 'drop table #Store_Flattern'
	EXEC (@Sql)
END

--AFB Uttrekk med storeformat fra UAT
--From UAT TEST DWH
--sp_linkedservers
--[AFBS-VRSSQL-ITEM01] needs to be changes du to linkserver name is different this is for UAT
--[AFBS-VRSSQL-R1] for Retail operation
--[AFB-VRSSQL-CORE01] Prod Enviroment for RSCompanyAdminESDb
--[AFB-VRSSQL-ITEM] Prod Enviroment for RSItem



--DROP TABLE #Store_Flattern

SELECT DISTINCT S.StoreNo, S.StoreID,S.EANLocationNo, S.StoreName
,MAX(CASE WHEN SI.InfoID = 'AFB_area_code' THEN SI.InfoValue  END) AS 'AFB_area_code' --1
,MAX(CASE WHEN SI.InfoID = 'AFB_awrs_urn' THEN SI.InfoValue  END) AS 'AFB_awrs_urn'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_alloc' THEN SI.InfoValue END) AS 'AFB_c_alloc'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_carriage' THEN SI.InfoValue END) AS 'AFB_c_carriage'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_carrige' THEN SI.InfoValue END) AS 'AFB_c_carrige'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_damage' THEN SI.InfoValue END) AS 'AFB_c_damage'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_debit' THEN SI.InfoValue END) AS 'AFB_c_debit'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_deltrade' THEN SI.InfoValue END) AS 'AFB_c_deltrade'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_pod' THEN SI.InfoValue END) AS 'AFB_c_pod'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_prop' THEN SI.InfoValue END) AS 'AFB_c_prop'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_ptel' THEN SI.InfoValue END) AS 'AFB_c_ptel' --11
,MAX(CASE WHEN SI.InfoID = 'AFB_c_qty' THEN SI.InfoValue END) AS 'AFB_c_qty'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_retsumm' THEN SI.InfoValue END) AS 'AFB_c_retsumm'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_Scan' THEN SI.InfoValue END) AS 'AFB_c_Scan'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_status' THEN SI.InfoValue END) AS 'AFB_c_status'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_store_type' THEN SI.InfoValue END) AS 'AFB_c_store_type'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_streetno' THEN SI.InfoValue END) AS 'AFB_c_streetno'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_sub' THEN SI.InfoValue END) AS 'AFB_c_sub'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_tel' THEN SI.InfoValue END) AS 'AFB_c_tel'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_type' THEN SI.InfoValue END) AS 'AFB_c_type'
,MAX(CASE WHEN SI.InfoID = 'AFB_c_type_desc' THEN SI.InfoValue END) AS 'AFB_c_type_desc' --21
,MAX(CASE WHEN SI.InfoID = 'AFB_c_vat' THEN SI.InfoValue END) AS 'AFB_c_vat'
,MAX(CASE WHEN SI.InfoID = 'AFB_dbm_code1' THEN SI.InfoValue END) AS 'AFB_dbm_code1'
,MAX(CASE WHEN SI.InfoID = 'AFB_division_code' THEN SI.InfoValue END) AS 'AFB_division_code'
,MAX(CASE WHEN SI.InfoID = 'AFB_e_mail' THEN SI.InfoValue END) AS 'AFB_e_mail'
,MAX(CASE WHEN SI.InfoID = 'AFB_e_mail_per' THEN SI.InfoValue END) AS 'AFB_e_mail_per'
,MAX(CASE WHEN SI.InfoID = 'AFB_export_to_MDS' THEN SI.InfoValue END) AS 'AFB_export_to_MDS'
,MAX(CASE WHEN SI.InfoID = 'AFB_garage_ind' THEN SI.InfoValue END) AS 'AFB_garage_ind'
,MAX(CASE WHEN SI.InfoID = 'AFB_Iniitial_delivery_RDC' THEN SI.InfoValue END) AS 'AFB_Iniitial_delivery_RDC'
,MAX(CASE WHEN SI.InfoID = 'AFB_Initial_delivery_RDC' THEN SI.InfoValue END) AS 'AFB_Initial_delivery_RDC'
,MAX(CASE WHEN SI.InfoID = 'AFB_inv_layout' THEN SI.InfoValue END) AS 'AFB_inv_layout'
,MAX(CASE WHEN SI.InfoID = 'AFB_inv_seq' THEN SI.InfoValue END) AS 'AFB_inv_seq' --31
,MAX(CASE WHEN SI.InfoID = 'AFB_markerting_email' THEN SI.InfoValue END) AS 'AFB_markerting_email'
,MAX(CASE WHEN SI.InfoID = 'AFB_marketing_email' THEN SI.InfoValue END) AS 'AFB_marketing_email'
,MAX(CASE WHEN SI.InfoID = 'AFB_marketing_sms' THEN SI.InfoValue END) AS 'AFB_marketing_sms'
,MAX(CASE WHEN SI.InfoID = 'AFB_marketing_tel' THEN SI.InfoValue END) AS 'AFB_marketing_tel'
,MAX(CASE WHEN SI.InfoID = 'AFB_news' THEN SI.InfoValue END) AS 'AFB_news'
,MAX(CASE WHEN SI.InfoID = 'AFB_offsales_ind' THEN SI.InfoValue END) AS 'AFB_offsales_ind'
,MAX(CASE WHEN SI.InfoID = 'AFB_order_method' THEN SI.InfoValue END) AS 'AFB_order_method'
,MAX(CASE WHEN SI.InfoID = 'AFB_red_sub_info' THEN SI.InfoValue END) AS 'AFB_red_sub_info'
,MAX(CASE WHEN SI.InfoID = 'AFB_roa_code' THEN SI.InfoValue END) AS 'AFB_roa_code'
,MAX(CASE WHEN SI.InfoID = 'AFB_ROANAMES_ROA_CODE' THEN SI.InfoValue END) AS 'AFB_ROANAMES_ROA_CODE' --41
,MAX(CASE WHEN SI.InfoID = 'AFB_ROANAMES_ROA_NAME' THEN SI.InfoValue END) AS 'AFB_ROANAMES_ROA_NAME'
,MAX(CASE WHEN SI.InfoID = 'AFB_single_retail_units' THEN SI.InfoValue END) AS 'AFB_single_retail_units'
,MAX(CASE WHEN SI.InfoID = 'AFB_sl_code' THEN SI.InfoValue END) AS 'AFB_sl_code'
,MAX(CASE WHEN SI.InfoID = 'AFB_sparelo10' THEN SI.InfoValue END) AS 'AFB_sparelo10'
,MAX(CASE WHEN SI.InfoID = 'AFB_sparlo10' THEN SI.InfoValue END) AS 'AFB_sparlo10'
,MAX(CASE WHEN SI.InfoID = 'AFB_sq_feet' THEN SI.InfoValue END) AS 'AFB_sq_feet'
,MAX(CASE WHEN SI.InfoID = 'AFB_store_type_desc' THEN SI.InfoValue END) AS 'AFB_store_type_desc'
,MAX(CASE WHEN SI.InfoID = 'AFB_tates_cust_code' THEN SI.InfoValue END) AS 'AFB_tates_cust_code'
,MAX(CASE WHEN SI.InfoID = 'AFB_vat' THEN SI.InfoValue END) AS 'AFB_vat'
,MAX(CASE WHEN SI.InfoID = 'AFB_xml_format' THEN SI.InfoValue END) AS 'AFB_xml_format' --51
,MAX(CASE WHEN SI.InfoID = 'CA_ACCOUNTING_EXPORT_FILE_FORMAT' THEN SI.InfoValue END) AS 'CA_ACCOUNTING_EXPORT_FILE_FORMAT'
,MAX(CASE WHEN SI.InfoID = 'CA_ACCOUNTING_EXPORT_IS_ENABLED' THEN SI.InfoValue END) AS 'CA_ACCOUNTING_EXPORT_IS_ENABLED'
,MAX(CASE WHEN SI.InfoID = 'CA_ARTICLE_EXPIREDATE_PASSED_REASON_CODE' THEN SI.InfoValue END) AS 'CA_ARTICLE_EXPIREDATE_PASSED_REASON_CODE'
,MAX(CASE WHEN SI.InfoID = 'CA_AUTO_INVOICING_IS_ENABLED' THEN SI.InfoValue END) AS 'CA_AUTO_INVOICING_IS_ENABLED'
,MAX(CASE WHEN SI.InfoID = 'CA_BATCH_AUTO_CLOSE_STOCK_THRESHOLD' THEN SI.InfoValue END) AS 'CA_BATCH_AUTO_CLOSE_STOCK_THRESHOLD'
,MAX(CASE WHEN SI.InfoID = 'CA_CONTACT_NAME' THEN SI.InfoValue END) AS 'CA_CONTACT_NAME'
,MAX(CASE WHEN SI.InfoID = 'CA_COST_CENTER_ID' THEN SI.InfoValue END) AS 'CA_COST_CENTER_ID'
,MAX(CASE WHEN SI.InfoID = 'CA_E_MAIL' THEN SI.InfoValue END) AS 'CA_E_MAIL'
,MAX(CASE WHEN SI.InfoID = 'CA_FAX' THEN SI.InfoValue END) AS 'CA_FAX'
,MAX(CASE WHEN SI.InfoID = 'CA_HAS_ESL' THEN SI.InfoValue END) AS 'CA_HAS_ESL'
,MAX(CASE WHEN SI.InfoID = 'CA_HAS_SALESLOCATION' THEN SI.InfoValue END) AS 'CA_HAS_SALESLOCATION'
,MAX(CASE WHEN SI.InfoID = 'CA_IS_WEBSHOP' THEN SI.InfoValue END) AS 'CA_IS_WEBSHOP'
,MAX(CASE WHEN SI.InfoID = 'CA_PHONE_NUMBER1' THEN SI.InfoValue END) AS 'CA_PHONE_NUMBER1'
,MAX(CASE WHEN SI.InfoID = 'CA_PHONE_NUMBER2' THEN SI.InfoValue END) AS 'CA_PHONE_NUMBER2'
,MAX(CASE WHEN SI.InfoID = 'CA_VAT_ZONE' THEN SI.InfoValue END) AS 'CA_VAT_ZONE'
,MAX(CASE WHEN SI.InfoID = 'EOIC' THEN SI.InfoValue END) AS 'EOIC'
,MAX(CASE WHEN SI.InfoID = 'FIC' THEN SI.InfoValue END) AS 'FIC'
,MAX(CASE WHEN SI.InfoID = 'MobileAccessActive' THEN SI.InfoValue END) AS 'MobileAccessActive'
,MAX(CASE WHEN SI.InfoID = 'Phonenumber1' THEN SI.InfoValue END) AS 'Phonenumber1'
,MAX(CASE WHEN SI.InfoID = 'Phonenumber2' THEN SI.InfoValue END) AS 'Phonenumber2'
,MAX(CASE WHEN SI.InfoID = 'Zipname' THEN SI.InfoValue END) AS 'Zipname' --61
--,MAX(CASE WHEN SI.InfoID = 'xxx' THEN SI.InfoValue END) AS 'xxx' 
--,MAX(CASE WHEN SI.InfoID = 'xxx' THEN SI.InfoValue END) AS 'xxx'
--,MAX(CASE WHEN SI.InfoID = 'xxx' THEN SI.InfoValue END) AS 'xxx'
--,MAX(CASE WHEN SI.InfoID = 'xxx' THEN SI.InfoValue END) AS 'xxx'
--,MAX(CASE WHEN SI.InfoID = 'xxx' THEN SI.InfoValue END) AS 'xxx'
--,MAX(CASE WHEN SI.InfoID = 'xxx' THEN SI.InfoValue END) AS 'xxx'
--,MAX(CASE WHEN SI.InfoID = 'xxx' THEN SI.InfoValue END) AS 'xxx'
--,MAX(CASE WHEN SI.InfoID = 'xxx' THEN SI.InfoValue END) AS 'xxx'
--,MAX(CASE WHEN SI.InfoID = 'xxx' THEN SI.InfoValue END) AS 'xxx'--70
,S.StoreStatus
INTO #Store_Flattern
FROM [AFB-VRSSQL-ITEM].RSItemESDb.dbo.StoreInfos AS SI
LEFT JOIN [AFB-VRSSQL-ITEM].RSItemESDb.dbo.Stores AS S ON S.StoreNo = SI.StoreNo
GROUP BY S.StoreNo, S.StoreID,S.EANLocationNo, S.StoreName,S.StoreStatus


IF OBJECT_ID('tempdb..#StoreFormat') is NOT NULL
BEGIN 
	set @Sql = 'drop table #StoreFormat'
	EXEC (@Sql)
END

SELECT S.StoreID,sg.StoreGroupName
INTO #StoreFormat
FROM [AFB-VRSSQL-CORE01].RSCompanyAdminESDb.dbo.Stores AS S 
JOIN [AFB-VRSSQL-CORE01].RSCompanyAdminESDb.dbo.StoreGroupLinks AS SGL ON SGL.StoreNo = S.StoreNo
JOIN [AFB-VRSSQL-CORE01].RSCompanyAdminESDb.dbo.StoreGroups AS SG ON SG.StoreGroupNo = SGL.StoreGroupNo AND SG.StoreGroupTypeNo = 14
WHERE 1=1
--AND s.StoreID=14777 

IF OBJECT_ID('tempdb..#IsCurrentStore') is NOT NULL
BEGIN 
	set @Sql = 'drop table #IsCurrentStore'
	EXEC (@Sql)
END

SELECT DS.StoreId,MAX(DS.StoreIdx) AS StoreIdx
INTO #IsCurrentStore
FROM  RBIM.Dim_Store AS DS
WHERE DS.IsCurrent=1
--AND DS.StoreId=10138
GROUP BY DS.StoreId


SELECT 
DS.StoreName AS 'Name'
,DS.StoreDisplayId AS 'Display ID'
,DS.StoreId AS 'Store ID'
,DS.StoreExternalId AS 'External ID'
,SF.EANLocationNo AS 'EAN loaction NO'
,DS.StoreDescription AS 'Description'
,SGS.StoreGroupStatusName AS 'Status'
,DS.ValidFromDate AS 'Opening date'
,DS.ValidToDate AS 'Closed date'
,DS.IsWebShop AS 'Web'
,DS.StoreCostCenter AS 'Cost center'
,SF.CA_PHONE_NUMBER1 AS 'Phone number 1'
,SF.CA_PHONE_NUMBER2 AS 'Phone number 2'
,SF.CA_FAX AS 'Fax'
,SF.CA_E_MAIL AS 'E-mail'
,S.StoreAdress AS 'Post-Line 1'
,S.ZipName AS 'Post-Line 2'
,'' AS 'Post-Line 3'
,S.ZipCode AS 'Post-Zip Code'
,'' AS 'Invoice-Line 1'
,'' AS 'Invoice-Line 2'
,'' AS 'Invoice-Line 3'
,'' AS 'Invoice-Zip Code'
,'' AS 'Delivery-Line 1'
,'' AS 'Delivery-Line 2'
,'' AS 'Delivery-Line 3'
,'' AS 'Delivery-Zip Code'
,'Hierarchy associations-Region' = CASE 
									WHEN DS.NumOfRegionLevels=5 THEN ds.Lev5RegionGroupName
									WHEN DS.NumOfRegionLevels=4 THEN ds.Lev4RegionGroupName
									WHEN DS.NumOfRegionLevels=3 THEN ds.Lev3RegionGroupName
									WHEN DS.NumOfRegionLevels=2 THEN ds.Lev2RegionGroupName
									ELSE Lev1RegionGroupName
								   END
,'Hierarchy associations-Legal' = CASE 
									WHEN DS.NumOfLegalLevels=5 THEN ds.Lev5LegalGroupName
									WHEN DS.NumOfLegalLevels=4 THEN ds.Lev4LegalGroupName
									WHEN DS.NumOfLegalLevels=3 THEN ds.Lev3LegalGroupName
									WHEN DS.NumOfLegalLevels=2 THEN ds.Lev2LegalGroupName
									ELSE ds.Lev1LegalGroupName
								   END
,'Hierarchy associations-Item' = CASE 
									WHEN DS.NumOfAssortmentProfileLevels=5 THEN ds.Lev1AssortmentProfileName
									WHEN DS.NumOfAssortmentProfileLevels=4 THEN ds.Lev1AssortmentProfileName
									WHEN DS.NumOfAssortmentProfileLevels=3 THEN ds.Lev1AssortmentProfileName
									WHEN DS.NumOfAssortmentProfileLevels=2 THEN ds.Lev1AssortmentProfileName
									ELSE ds.Lev1AssortmentProfileName
								   END

,'' AS 'Hierarchy associations-Currency' 
,'Hierarchy associations-Price' = CASE 
									WHEN DS.NumOfPriceProfileLevels=5 THEN ds.Lev5PriceProfileName
									WHEN DS.NumOfPriceProfileLevels=4 THEN ds.Lev4PriceProfileName
									WHEN DS.NumOfPriceProfileLevels=3 THEN ds.Lev3PriceProfileName
									WHEN DS.NumOfPriceProfileLevels=2 THEN ds.Lev2PriceProfileName
									ELSE ds.Lev1PriceProfileName
								   END

,'' AS 'Hierarchy associations-CustomerCredit'
,'' AS 'Hierarchy associations-Customer'
,'Hierarchy associations-Chain' = CASE 
									WHEN DS.NumOfChainLevels=5 THEN ds.Lev5ChainGroupName
									WHEN DS.NumOfChainLevels=4 THEN ds.Lev4ChainGroupName
									WHEN DS.NumOfChainLevels=3 THEN ds.Lev3ChainGroupName
									WHEN DS.NumOfChainLevels=2 THEN ds.Lev2ChainGroupName
									ELSE ds.Lev1ChainGroupName
								   END

,'Hierarchy associations-District' = CASE 
									WHEN DS.NumOfDistrictLevels=5 THEN ds.Lev5DistrictGroupName
									WHEN DS.NumOfDistrictLevels=4 THEN ds.Lev4DistrictGroupName
									WHEN DS.NumOfDistrictLevels=3 THEN ds.Lev3DistrictGroupName
									WHEN DS.NumOfDistrictLevels=2 THEN ds.Lev2DistrictGroupName
									ELSE Lev1DistrictGroupName
								   END
,'' AS 'Hierarchy associations-Maintenance'
,ISNULL(SF2.StoreGroupName,'') AS 'Hierarchy associations-Store Format'
,ds.Lev1OperatingRegionGroupName
--,ds.Lev1OperatingRegionGroupName
,EOIC
,FIC
,AFB_Initial_delivery_RDC
,CA_COST_CENTER_ID,CA_VAT_ZONE
,AFB_export_to_MDS
--,AFB_C_NAME
,AFB_c_store_type
,CA_CONTACT_NAME
,AFB_sq_feet
,AFB_garage_ind
,AFB_offsales_ind
,AFB_news
,AFB_c_qty
,AFB_c_VAT
,AFB_c_sub
,AFB_c_alloc
,AFB_c_carriage
,AFB_inv_seq
,AFB_single_retail_units
,AFB_c_pod
,AFB_marketing_sms
,AFB_marketing_email
,AFB_marketing_tel
,AFB_awrs_urn
,AFB_c_debit
,AFB_division_code
,AFB_c_type
,AFB_c_damage
,AFB_c_deltrade
,AFB_inv_layout
,AFB_c_status
,AFB_order_method
,AFB_red_sub_info
,AFB_c_retsumm
,AFB_roa_code
,AFB_c_Scan
,AFB_xml_format
--,DS.NumOfRegionLevels
--,DS.NumOfLegalLevels
--,DS.NumOfAssortmentProfileLevels
--,DS.NumOfPriceProfileLevels
--,DS.NumOfChainLevels
--,DS.NumOfDistrictLevels
--,DS.NumOfOperatingRegionLevels
FROM  RBIM.Dim_Store AS DS
JOIN #IsCurrentStore AS ICS ON ICS.StoreIdx = DS.StoreIdx
JOIN [AFB-VRSSQL-ITEM].RSItemESDb.dbo.Stores AS S ON S.StoreID = DS.StoreId
JOIN #Store_Flattern AS SF ON SF.StoreID = DS.StoreId
JOIN [AFB-VRSSQL-ITEM].RSItemESDb.dbo.StoreGroupStates AS SGS ON SGS.StoreGroupStatus=SF.StoreStatus
LEFT JOIN #StoreFormat AS SF2 ON SF2.StoreId = SF.StoreID 
WHERE DS.IsCurrent=1
--AND DS.StoreId=14777
--AND S.StoreStatus=1



END






GO

