USE [PickAndCollectDB]
GO

/****** Object:  View [dbo].[vCustomers]    Script Date: 25.09.2020 14:44:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE VIEW [dbo].[vCustomers]
AS 
SELECT 
	Customers.CustomerNo,
	CustomerID,
	DateOfBirth,
	NationalCustNo,
	FirstName,
	MiddleName,
	LastName,
	CustomerAlias,
	Gender,
	MainPhone,
	MainPhonePrefix,
	MobilePhone,
	MobilePhonePrefix,
	Email,
	CustomerStatus,
	Customers.RecordCreated,
	ModifiedBy,
	ModifiedDate,
	DeletedDate,
	OrganizationNumber,
	CustomerExternalId,
	InfoValue AS ExternalIdFromPickAndCollect
	 
FROM [VBDCM].[dbo].[Customers] Customers  WITH (NOLOCK)
LEFT JOIN [VBDCM].[dbo].[CustomerInfos] CustomerInfos  WITH (NOLOCK)
ON Customers.CustomerNo = CustomerInfos.CustomerNo
WHERE CustomerInfos.InfoID = 'ExternalIdFromPickAndCollect' OR CustomerInfos.InfoID IS NULL

GO


