GO
USE [VBDCM]
GO

SET ANSI_WARNINGS ON
SET ANSI_NULLS ON
GO

IF EXISTS(SELECT * FROM sysobjects WHERE name = N'vw_PharmaStoreUsers'  AND xtype = 'V')
drop view vw_PharmaStoreUsers
go

CREATE VIEW [dbo].[vw_PharmaStoreUsers]
AS 
	SELECT  Sp.StoreID
			,St.Name AS Butiksnamn
			,Sp.UserID
			,Us.UserName
			,Us.UserLoginName
			,Sp.RoleID
			,Ro.Name AS Roll
			,Sp.ValidTo
	FROM RS17_1.RSSecurityESDb.dbo.StorePermissions AS Sp
	INNER JOIN RS17_1.RSSecurityESDb.dbo.Stores AS St ON Sp.StoreID = St.StoreID 
	INNER JOIN RS17_1.RSSecurityESDb.dbo.Users AS Us ON Sp.UserID = Us.UserID 
	INNER JOIN RS17_1.RSSecurityESDb.dbo.Roles AS Ro ON Sp.RoleID = Ro.RoleID
	WHERE (Sp.RoleID > 2)and us.active='True'
GO

use [VBDCM]
GO

IF EXISTS(SELECT * FROM sysobjects WHERE name = N'usp_CBI_1095_ds_PharmacyUsers' AND xtype = 'P')
DROP PROCEDURE usp_CBI_1095_ds_PharmacyUsers
GO

CREATE PROCEDURE usp_CBI_1095_ds_PharmacyUsers (@parStoreNo AS VARCHAR(100) = '')
AS

	SET ANSI_WARNINGS ON
	SET ANSI_NULLS ON
	--Rapport nr 1095
	DECLARE @sql AS NVARCHAR(MAX)

	SET @sql = '
	SELECT 
		sto.storeid, 
		sto.StoreName, 
		PSU.UserName as Namn ,
		PSU.Butiksnamn,
		PSU.UserLoginName as Anvandare,
		PSU.UserID,
		PSU.RoleID, 
		PSU.Roll
	FROM Stores sto
	JOIN vw_PharmaStoreUsers as PSU on (PSU.StoreID = sto.StoreID COLLATE DATABASE_DEFAULT )'

	IF LEN(@parStoreNo) > 0
		SET @sql = @sql + N' AND sto.StoreNo = @parStoreNo'

	SET @sql = @sql + ' ORDER BY PSU.UserID desc, PSU.RoleID'

	--EXEC(@sql)

	EXECUTE sp_executesql @sql, N'@parStoreNo NVARCHAR(100)', @parStoreNo = @parStoreNo

go





