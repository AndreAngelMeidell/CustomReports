USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[AFB_f_001_EndOfDayStock]    Script Date: 13.11.2020 08:44:36 ******/
DROP PROCEDURE [dbo].[AFB_f_001_EndOfDayStock]
GO

/****** Object:  StoredProcedure [dbo].[AFB_f_001_EndOfDayStock]    Script Date: 13.11.2020 08:44:36 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Gavin Pearce
-- Create date: 20/09/2020
-- Description:	Export the end of day stock
-- =============================================
CREATE PROCEDURE [dbo].[AFB_f_001_EndOfDayStock] 
-- Add the parameters for the stored procedure here
(@DateFrom AS datetime, 
 @DateTo AS   datetime
)
AS
    BEGIN
        -- SET NOCOUNT ON added to prevent extra result sets from
        -- interfering with SELECT statements.
        SET NOCOUNT ON;

        -- Insert statements for procedure here
        SELECT ds.StoreId 'CustomerCode', 
               ds.CurrentStoreName 'CustomerName', 
               da.[ArticleId] 'ArticleID', 
               dg.[Gtin], 
               [StockQuantity] 'Qty', 
               dst.StockTypeDescription, 
               --       dst.StockTypeName,
               ssed.StatusDate 'CreateDate'
        FROM [BI_Mart].[RBIM].[Per_StockStatusAtEndOfDay] (nolock) AS ssed
             JOIN RBIM.Dim_Article (nolock) AS DA ON DA.ArticleIdx = ssed.ArticleIdx
             JOIN RBIM.Dim_Store (nolock) AS DS ON DS.StoreIdx = ssed.StoreIdx
             JOIN [BI_Mart].[RBIM].[Dim_StockType] (nolock) dst ON dst.StockTypeIdx = ssed.StockTypeIdx -- 1 = Stock that can be sold
             JOIN RBIM.Dim_Gtin (nolock) AS Dg ON dg.gtinidx = ssed.gtinidx
        WHERE CAST(statusdate AS DATE) >= CAST(@DateFrom AS DATE)
              AND CAST(statusdate AS DATE) <= CAST(@DateTo AS DATE)
			  and ds.StoreId in ('11809','10222');
    END;

GO

