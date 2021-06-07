USE [BI_Mart]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1723_Wastage_csv]    Script Date: 13.11.2020 08:41:13 ******/
DROP PROCEDURE [dbo].[usp_CBI_1723_Wastage_csv]
GO

/****** Object:  StoredProcedure [dbo].[usp_CBI_1723_Wastage_csv]    Script Date: 13.11.2020 08:41:13 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






CREATE PROCEDURE [dbo].[usp_CBI_1723_Wastage_csv] 
(
@DateFrom AS DATE ,
@DateTo AS DATE 
)
AS
BEGIN
SET NOCOUNT ON


DECLARE @UseDerivedShrinkNetCostSQL NVARCHAR(500) = ',CASE WHEN (StockAdjustmentTypeNo = 2 OR StockAdjustmentTypeNo = 52) AND drc.IsIncludedInLossCalculation = 1 THEN fc.InAdjustmentNetCostAmount-fc.OutAdjustmentNetCostAmount ELSE 0 END AS ShrinkNetCostAmount'
	DECLARE @UseDerivedShrinkNetCost  AS TINYINT
	IF @UseDerivedShrinkNetCost = 1
	BEGIN
		SET @UseDerivedShrinkNetCostSQL = '
		,CASE WHEN (StockAdjustmentTypeNo = 2 OR StockAdjustmentTypeNo = 52) AND drc.IsIncludedInLossCalculation = 1 
		THEN CASE WHEN (fc.InAdjustmentNetCostAmount-fc.OutAdjustmentNetCostAmount) = 0 
				  THEN fc.InAdjustmentNetCostAmountDerived-fc.OutAdjustmentNetCostAmountDerived 
				  ELSE fc.InAdjustmentNetCostAmount-fc.OutAdjustmentNetCostAmount END
		ELSE 0 END AS ShrinkNetCostAmount'
	END
	
	;WITH SelectedAdjustments_exp AS (
SELECT
 dd.FullDate, DS.StoreName, DS.StoreId
,DA.ArticleId, DA.ArticleName, DG.Gtin, DA.Lev2ArticleHierarchyId, DA.Lev2ArticleHierarchyName,DA.Lev3ArticleHierarchyId, DA.Lev3ArticleHierarchyName, dsat.StockAdjustmentTypeNo
				,CASE WHEN da.DefaultManufacturerId IS NULL OR da.DefaultManufacturerName IS NULL OR da.DefaultManufacturerId = '' OR da.DefaultManufacturerId='-1' OR da.DefaultManufacturerId IS NULL 
					  THEN '-1 - None'
					  ELSE CAST(da.DefaultManufacturerId as varchar(50)) + ' - ' + da.DefaultManufacturerName END AS DefaultManufacturerName 
				,ISNULL(oae.Value_Department, '')+ ''+ISNULL(oae.Value_DepartmentName, '''') AS Value_Department
				,CASE WHEN (StockAdjustmentTypeNo = 2 OR StockAdjustmentTypeNo = 52) AND drc.IsIncludedInLossCalculation = 1 THEN fc.InAdjustmentQuantity-fc.OutAdjustmentQuantity
				  ELSE 0 END AS ShrinkQuantity
				,(fc.InAdjustmentQuantity-fc.OutAdjustmentQuantity) as AdjustmentQuantity -- {RS-37162}
				,(fc.InAdjustmentNetSalesAmountExclVat-fc.OutAdjustmentNetSalesAmountExclVat) as AdjustmentNetSalesAmountExclVat 
				,(fc.InAdjustmentNetCostAmount-fc.OutAdjustmentNetCostAmount) as AdjustmentNetCostAmount
				,IIF(COALESCE(sht.StockHandlingTypeId, da.StockHandlingTypeId) = 2, 2, 1) AS StockHandling
				,da.LeafArticleHierarchyName as LeafNode
				,fc.EndOfPeriodDateIdx,
				CASE WHEN (StockAdjustmentTypeNo = 2 OR StockAdjustmentTypeNo = 52) AND drc.IsIncludedInLossCalculation = 1 
		THEN CASE WHEN (fc.InAdjustmentNetCostAmount-fc.OutAdjustmentNetCostAmount) = 0 
				  THEN fc.InAdjustmentNetCostAmountDerived-fc.OutAdjustmentNetCostAmountDerived 
				  ELSE fc.InAdjustmentNetCostAmount-fc.OutAdjustmentNetCostAmount END
		ELSE 0 END AS ShrinkNetCostAmount
			from RBIM.Agg_StockAdjustmentPerDay fc
				  inner join RBIM.Dim_Date (nolock) dd on fc.EndOfPeriodDateIdx=dd.DateIdx
				  inner join RBIM.Dim_Store (nolock)  ds on fc.StoreIdx=ds.StoreIdx
				  inner join RBIM.Dim_Article (nolock)  da on fc.ArticleIdx=da.ArticleIdx	  
				  inner join RBIM.Dim_Supplier (nolock)  dsup on fc.SupplierIdx=dsup.SupplierIdx      
				  inner join RBIM.Dim_StockType (nolock)  dst on fc.StockTypeIdx=dst.StockTypeIdx
				  inner join RBIM.Dim_StockAdjustmentType (nolock)  dsat on fc.StockAdjustmentTypeIdx=dsat.StockAdjustmentTypeIdx
				  inner join RBIM.Dim_ReasonCode (nolock)  drc on fc.ReasonCodeIdx=drc.ReasonCodeIdx
				  JOIN RBIM.Dim_Gtin (nolock) dg ON fc.GtinIdx = dg.GtinIdx
				  left join RBIM.Out_ArticleExtraInfo (nolock)  oae on oae.ArticleId = da.ArticleId   -- {RS-37338}
				  left join RBIM.Cov_StoreOverrideArticle (nolock) soa on soa.ArticleIdx = da.ArticleIdx and soa.StoreIdx = ds.StoreIdx and  soa.SupplierIdx = dsup.SupplierIdx and soa.IsCurrentStock = 1
				  left join RBIM.Dim_StockHandlingType (nolock) sht on sht.StockHandlingTypeIdx = soa.StockHandlingTypeIdx
			where  dst.StockTypeNo in (1,2,3,4,5,6) -- Sales stock,B-Stock,On display stock,On loan stock,On Service stock,During transport
				   and ((fc.ReasonCodeIdx in (SELECT ReasonCodeIdx as ReasonCodeIdx FROM RBIM.Dim_ReasonCode WHERE IsIncludedInLossCalculation = 1) ))
				   AND fc.ReasonCodeIdx = '49'
				   AND dd.FullDate BETWEEN @DateFrom AND @DateTo
				   )

				   select  'Wastage' AS Description, sa.FullDate, sa.StoreName, sa.StoreId
,sa.ArticleId, sa.ArticleName, sa.Gtin, sa.Lev2ArticleHierarchyId, sa.Lev2ArticleHierarchyName,sa.Lev3ArticleHierarchyId, sa.Lev3ArticleHierarchyName, 
		sum(case when sa.StockAdjustmentTypeNo=2 then sa.ShrinkNetCostAmount else 0 end) as 'Reg. shrinkage cost'
		,sum(case when sa.StockAdjustmentTypeNo=52 then sa.ShrinkNetCostAmount else 0 end) as 'Unreg. shrinkage cost'
		,sum(sa.ShrinkQuantity) as 'Shrink quantity'
		,sum(sa.ShrinkNetCostAmount) as 'Shrinkage amt.'
		,sum(case when sa.StockAdjustmentTypeNo=1 then sa.AdjustmentQuantity * (-1) else 0 end) as 'Qty. of articles sold'
		,sum(case when sa.StockAdjustmentTypeNo=1 then sa.AdjustmentNetSalesAmountExclVat * (-1) else 0 end) as 'Adj. Net Sales Amt. exVat'
		,sum(case when sa.StockAdjustmentTypeNo=1 then sa.AdjustmentNetCostAmount * (-1) else 0 end) as 'Adj. Net Cost Amt.'
		,sum(isnull(((case when sa.StockAdjustmentTypeNo=1 then sa.AdjustmentNetSalesAmountExclVat * (-1) else 0 end) - case when sa.StockAdjustmentTypeNo=1 then sa.AdjustmentNetCostAmount * (-1) else 0 end),0)) as 'Gross Profit'
		,sum(case when sa.StockAdjustmentTypeNo=1 then sa.AdjustmentNetSalesAmountExclVat *(-1) else 0 end - case when sa.StockAdjustmentTypeNo=1 then sa.AdjustmentNetCostAmount  *(-1) else 0 end + isnull(sa.ShrinkNetCostAmount,0)) as 'Gross realized'
		from  SelectedAdjustments_exp sa
		left join [RBIM].[Fact_TargetPerStoreAndArticle] (nolock)  ft on ft.StoreId=sa.StoreId and ft.ArticleId=sa.ArticleId
		where (sa.ShrinkQuantity <> 0 or sa.AdjustmentQuantity <> 0) 
		and 
		exists (Select 1 from SelectedAdjustments_exp sa2 where sa.ArticleId = sa2.ArticleId and StockAdjustmentTypeNo in (2,52) and ShrinkQuantity != 0) --Mandatory filter
	group by  sa.FullDate, sa.StoreName, sa.StoreId
,sa.ArticleId, sa.ArticleName, sa.Gtin, sa.Lev2ArticleHierarchyId, sa.Lev2ArticleHierarchyName,sa.Lev3ArticleHierarchyId, sa.Lev3ArticleHierarchyName 



END 



GO

