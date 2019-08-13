USE [RSReportingESDb]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_InitCBIContentChannelsAndCategories]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_InitCBIContentChannelsAndCategories]
GO

USE [RSReportingESDb]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Description: Insert/Update CBI reports with default connection settings
-- Run procedure after sync of jasper reports is done
-- =============================================
CREATE procedure [dbo].[usp_InitCBIContentChannelsAndCategories] 
	AS
BEGIN 


declare @RoleStoreAndStoreGroupAdmin varchar(50) = '1'
declare @RoleUserPermissionAdmin varchar(50) = '2'
declare @RoleAdministrator varchar(50) = '3'
declare @RoleStockManager varchar(50) = '7'
declare @RoleStockUser varchar(50) = '8'
declare @RoleStoreManager varchar(50) = '9'

--ChannelNo = dbo.ContentChannels.ContentChannelNo
declare @ChannelRetailSuiteAdmin varchar(50) = '10'
declare @ChannelRetailSuitePos varchar(50) = '20'
declare @ChannelVismaReportingWeb varchar(50) = '30'
declare @ChannelVismaReportingMobile varchar(50) = '40'
declare @ChannelSmartStorePdf varchar(50) = '50'

--CategoryName = dbo.ContentCategories.ContentCategoryName
declare @CategoryOrderDialog varchar(50) = 'Order Dialog'
declare @CategoryStockCountDialog varchar(50) = 'Stock Count Dialog'
declare @CategoryHomeDialog varchar(50) = 'Home Dialog'
declare @CategoryArticlesDialog varchar(50) = 'Articles Dialog'
declare @CategoryArticleDetailsDialog varchar(50) = 'Article Details Dialog'

--Contentname = dbo.Contents.ContentName \ Jasper report ID
--Connect reports below:

--1559_ReconciliationSummary
exec usp_CreateContentRoleLink		@ContentDisplayId = '1559',		@RoleId = @RoleAdministrator
exec usp_CreateContentChannelLink	@ContentDisplayId = '1559',		@ContentChannelNo = @ChannelRetailSuiteAdmin
exec usp_CreateContentChannelLink	@ContentDisplayId = '1559',		@ContentChannelNo = @ChannelSmartStorePdf
exec usp_SetContentDescription		@ContentDisplayId = '1559',		@Description = 'Custom Reconciliation Summary Report', @DisplayName = 'Reconciliation Summary Report for store'

--1160_FlightRevenue
exec usp_CreateContentRoleLink		@ContentDisplayId = '1160',		@RoleId = @RoleAdministrator
exec usp_CreateContentChannelLink	@ContentDisplayId = '1160',		@ContentChannelNo = @ChannelRetailSuiteAdmin
exec usp_CreateContentChannelLink	@ContentDisplayId = '1160',		@ContentChannelNo = @ChannelSmartStorePdf
exec usp_SetContentDescription		@ContentDisplayId = '1160',		@Description = 'Custom Flight Report', @DisplayName = 'Flight Report for store'


--1135_ArticleSalesAndRevenueSG
exec usp_CreateContentRoleLink		@ContentDisplayId = '1135',		@RoleId = @RoleAdministrator
exec usp_CreateContentChannelLink	@ContentDisplayId = '1135',		@ContentChannelNo = @ChannelRetailSuiteAdmin
exec usp_CreateContentChannelLink	@ContentDisplayId = '1135',		@ContentChannelNo = @ChannelSmartStorePdf
exec usp_SetContentDescription		@ContentDisplayId = '1135',		@Description = 'Custom revenue report SG', @DisplayName = 'Revenue Report for HQ'

--1155_RevenueFigures
exec usp_CreateContentRoleLink		@ContentDisplayId = '1155',		@RoleId = @RoleAdministrator
exec usp_CreateContentChannelLink	@ContentDisplayId = '1155',		@ContentChannelNo = @ChannelRetailSuiteAdmin
exec usp_CreateContentChannelLink	@ContentDisplayId = '1155',		@ContentChannelNo = @ChannelSmartStorePdf
exec usp_SetContentDescription		@ContentDisplayId = '1155',		@Description = 'Custom revenue figures report', @DisplayName = 'Revenue Report for store'



END