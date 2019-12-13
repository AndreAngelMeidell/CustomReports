USE [VBDCM]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_SelectedStoreGroupInfo]    Script Date: 8/6/2019 12:46:51 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


/**
** Created: 2019-08-05
** Author:	Lennart Pukitis
** Description: To be used when Input Controle StoreGroup is used
** Output: Returns customer choosen store or stores in a formatted way
** Option: If desired more return values can be added. That should not effect reports allready using this SP
**/

DROP PROCEDURE IF EXISTS [dbo].[usp_CBI_SelectedStoreGroupInfo];
GO

CREATE Procedure [dbo].[usp_CBI_SelectedStoreGroupInfo]
	(														 
		@StoreGroupNos As varchar(8000) = ''
	)

AS
BEGIN 

	DECLARE @InputStoreNames VARCHAR(2000)

	SELECT @InputStoreNames = COALESCE(@InputStoreNames + ', ', '') + s.StoreID + ' ' + s.StoreName 
	FROM dbo.ufn_CBI_getStoreNoForStoreGroups (@StoreGroupNos) ufn
	join Stores s ON ufn.StoreNo = s.StoreNo

	SELECT @InputStoreNames AS InputStoreNames

END
GO


