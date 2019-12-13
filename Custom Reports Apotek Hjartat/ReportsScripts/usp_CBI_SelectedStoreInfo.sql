GO
USE [VBDCM]
GO

IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES r WHERE r.ROUTINE_NAME = 'usp_CBI_SelectedStoreInfo')
DROP PROCEDURE usp_CBI_SelectedStoreInfo
GO

CREATE PROCEDURE [dbo].[usp_CBI_SelectedStoreInfo]
(
@StoreId VARCHAR(100)
)
AS 
BEGIN

	SELECT 
		s.PublicOrgNumber,
		sg1.StoreGroupName,
		s.StoreId,
		s.StoreName,
		s.EANLocationNo
	FROM [VBDCM].[dbo].[Stores] s
	INNER JOIN [VBDCM].[dbo].[StoreGroupLinks] sgl on s.StoreNo = sgl.StoreNo
	INNER JOIN [VBDCM].[dbo].[StoreGroups] sg on sgl.StoreGroupNo = sg.StoreGroupNo 
	INNER JOIN [VBDCM].[dbo].[storeGroups] sg1 on sg.StoreGroupLinkNo = sg1.StoreGroupNo 
	WHERE s.storeno = @StoreId 
	AND sg.StoreGroupTypeNo = 3

END;

GO

/*
exec [dbo].[usp_CBI_SelectedStoreInfo] '3000'
*/