USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1560_SupplierInfo]    Script Date: 13.11.2020 08:42:38 ******/
DROP PROCEDURE [dbo].[usp_CBI_1560_SupplierInfo]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1560_SupplierInfo]    Script Date: 13.11.2020 08:42:38 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE  PROCEDURE [dbo].[usp_CBI_1560_SupplierInfo]

AS  
BEGIN
  
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

DECLARE @sql AS VARCHAR(100)

IF OBJECT_ID('tempdb..#Supplier_Flattern') IS NOT NULL
BEGIN 
	SET @Sql = 'drop table #Supplier_Flattern'
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

SELECT DISTINCT  S.SupplierId
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_ACCOUNTMANAGER_CONTACTEMAIL' THEN SI.DynamicFieldValue  END) AS 'AFB_ACCOUNTMANAGER_CONTACTEMAIL' --1
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_ACCOUNTMANAGER_CONTACTNAME' THEN SI.DynamicFieldValue  END) AS 'AFB_ACCOUNTMANAGER_CONTACTNAME'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_ACCOUNTMANAGER_CONTACTTEL' THEN SI.DynamicFieldValue END) AS 'AFB_ACCOUNTMANAGER_CONTACTTEL'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_ATLAS_EXPORT' THEN SI.DynamicFieldValue END) AS 'AFB_delivery_type'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_delivery_type' THEN SI.DynamicFieldValue END) AS 'AFB_c_carrige'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_FINANCEDIRECTOR_CONTACTEMAIL' THEN SI.DynamicFieldValue END) AS 'AFB_FINANCEDIRECTOR_CONTACTEMAIL'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_FINANCEDIRECTOR_CONTACTNAME' THEN SI.DynamicFieldValue END) AS 'AFB_FINANCEDIRECTOR_CONTACTNAME'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_FINANCEDIRECTOR_CONTACTTEL' THEN SI.DynamicFieldValue END) AS 'AFB_FINANCEDIRECTOR_CONTACTTEL'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_IMPORTED_ATLAS' THEN SI.DynamicFieldValue END) AS 'AFB_IMPORTED_ATLAS'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_REMITTANCEEMAIL' THEN SI.DynamicFieldValue END) AS 'AFB_REMITTANCEEMAIL'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_SALESLEDGER_CONTACTEMAIL' THEN SI.DynamicFieldValue END) AS 'AFB_SALESLEDGER_CONTACTEMAIL' --11
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_SALESLEDGER_CONTACTNAME' THEN SI.DynamicFieldValue END) AS 'AFB_SALESLEDGER_CONTACTNAME'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_SALESLEDGER_CONTACTTEL' THEN SI.DynamicFieldValue END) AS 'AFB_SALESLEDGER_CONTACTTEL'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_SETTLEMENT_DISCOUNT' THEN SI.DynamicFieldValue END) AS 'AFB_SETTLEMENT_DISCOUNT'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_SUPP_ANA' THEN SI.DynamicFieldValue END) AS 'AFB_SUPP_ANA'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_SUPP_AWRS_URN' THEN SI.DynamicFieldValue END) AS 'AFB_SUPP_AWRS_URN'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_SUPP_EXPORT_TO_MDS' THEN SI.DynamicFieldValue END) AS 'AFB_SUPP_EXPORT_TO_MDS'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_SWITCHPHONE' THEN SI.DynamicFieldValue END) AS 'AFB_SWITCHPHONE'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_TRADER_EMAIL' THEN SI.DynamicFieldValue END) AS 'AFB_TRADER_EMAIL'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_TRADER_NAME' THEN SI.DynamicFieldValue END) AS 'AFB_TRADER_NAME'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_TRADER_TELNO' THEN SI.DynamicFieldValue END) AS 'AFB_TRADER_TELNO' --21
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'AFB_URL' THEN SI.DynamicFieldValue END) AS 'AFB_URL'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'MI_CONTACT_PERSON' THEN SI.DynamicFieldValue END) AS 'MI_CONTACT_PERSON'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'MI_EMAIL' THEN SI.DynamicFieldValue END) AS 'MI_EMAIL'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'MI_FAX' THEN SI.DynamicFieldValue END) AS 'MI_FAX'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'MI_LEDETID' THEN SI.DynamicFieldValue END) AS 'MI_LEDETID'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'MI_PHONE' THEN SI.DynamicFieldValue END) AS 'MI_PHONE'
,MAX(CASE WHEN SI.DynamicFieldDefinitionId = 'PO_EMAIL' THEN SI.DynamicFieldValue END) AS 'PO_EMAIL'
INTO #Supplier_Flattern
FROM [AFB-VRSSQL-ITEM].RSItemESDb.dbo.SupplierDynamicFields AS SI
LEFT JOIN [AFB-VRSSQL-ITEM].RSItemESDb.dbo.Suppliers AS S ON S.SupplierNo = SI.SupplierNo
GROUP BY S.SupplierId



SELECT S.SupplierId, S.SupplierDisplayId, S.SupplierName, s.LegalName,
s.OrganizationNumber,S.GlobalLocationNumber, S.CostCalculationNo, SS.SupplierStatusName, ST.SupplierTypeName, s.AreStoreGroupConnectionsEnabled
,a.AddressId, A.AddressLine1, A.AddressLine2, a.AddressLine3, a.CountryCode, A.CountyId, A.ZipCode, A.ZipName, a.AddressValidFrom, A.AddressValidTo, AT.AddressTypeName
,sf.*
FROM  [AFB-VRSSQL-ITEM].RSItemESDb.dbo.Suppliers AS S 
JOIN [AFB-VRSSQL-ITEM].RSItemESDb.dbo.SupplierStatuses AS SS ON SS.SupplierStatusNo = S.SupplierStatusNo
LEFT JOIN [AFB-VRSSQL-ITEM].RSItemESDb.dbo.SupplierTypes AS ST ON ST.SupplierTypeNo = S.SupplierTypeNo
LEFT JOIN [AFB-VRSSQL-ITEM].RSItemESDb.dbo.SupplierAddresses AS SA ON SA.SupplierNo = S.SupplierNo
LEFT JOIN [AFB-VRSSQL-ITEM].RSItemESDb.dbo.Addresses AS A ON A.AddressNo = SA.AddressNo
LEFT JOIN [AFB-VRSSQL-ITEM].RSItemESDb.dbo.AddressTypes AS AT ON AT.AddressTypeNo = A.AddressTypeNo
LEFT JOIN #Supplier_Flattern SF ON SF.SupplierId=s.SupplierId
--WHERE S.SupplierId IN (10005,10003)



END







GO

