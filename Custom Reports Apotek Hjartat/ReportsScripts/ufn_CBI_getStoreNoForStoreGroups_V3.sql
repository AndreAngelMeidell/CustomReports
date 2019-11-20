go
use [VBDCM]
go

go
if exists(select * from sysobjects where name = N'ufn_CBI_getStoreNoForStoreGroups' and xtype in ('IF', 'TF'))
drop function ufn_CBI_getStoreNoForStoreGroups
go


CREATE FUNCTION [dbo].[ufn_CBI_getStoreNoForStoreGroups]
(
    @StoreGroupNos nvarchar(max)
)
RETURNS TABLE
AS
			RETURN
			(
		WITH Dim_Store as (
						select  stor.StoreID, stor.StoreNo, 
								strGr5.StoreGroupNo as StoreGroupNoLvl1, 
								strGr5.StoreGroupLinkNo as StoreGroupNoLvl2 , 
								strGrlvl4.StoreGroupLinkNo as StoreGroupNoLvl3,
								strGrlvl3.StoreGroupLinkNo as StoreGroupNoLvl4,
								strGrlvl5.StoreGroupLinkNo as StoreGroupNoLvl5
								--,strGrType.*
						from Stores stor with (nolock)
						left join [dbo].[StoreGroupLinks] strGrLink with (nolock) on stor.StoreNo = strGrLink.StoreNo
						left join [dbo].[StoreGroups] strGr5 with (nolock) on strGrLink.StoreGroupNo = strGr5.StoreGroupNo
						left join [dbo].[StoreGroups] strGrlvl4 with (nolock) on strGrlvl4.StoreGroupNo = strGr5.StoreGroupLinkNo
						left join [dbo].[StoreGroups] strGrlvl3 with (nolock) on strGrlvl4.StoreGroupLinkNo = strGrlvl3.StoreGroupNo
						left join [dbo].[StoreGroups] strGrlvl5 with (nolock) on strGrlvl3.StoreGroupLinkNo = strGrlvl5.StoreGroupNo
						left join [dbo].[StoreGroupTypes] strGrType with (nolock) on  strGrType.StoreGroupTypeNo = strGr5.StoreGroupTypeNo
						where strGr5.StoreGroupTypeNo in (2,3,11,12)
					   )
			SELECT distinct StoreNo
			-- * 
			FROM Dim_Store ds
			LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString]( @StoreGroupNos , ',')) n  ON n.ParameterValue IN (
			ds.StoreNo, ds.StoreGroupNoLvl1, ds.StoreGroupNoLvl2, ds.StoreGroupNoLvl3, ds.StoreGroupNoLvl4,	ds.StoreGroupNoLvl5
			)
			WHERE n.ParameterValue IS NOT NULL
			)

GO






/*

select *
from [dbo].[ufn_CBI_getStoreNoForStoreGroups1] ('3000,30001,3010')




	select *
	from Stores with (nolock)




	select  stor.StoreID, stor.StoreNo, 
			strGr5.StoreGroupNo as StoreGroupNoLvl1, 
			strGr5.StoreGroupLinkNo as StoreGroupNoLvl2 , 
			strGrlvl4.StoreGroupLinkNo as StoreGroupNoLvl3,
			strGrlvl3.StoreGroupLinkNo as StoreGroupNoLvl4,
			strGrlvl5.StoreGroupLinkNo as StoreGroupNoLvl5
			--,strGrType.*
	from Stores stor with (nolock)
	left join [dbo].[StoreGroupLinks] strGrLink with (nolock) on stor.StoreNo = strGrLink.StoreNo
	left join [dbo].[StoreGroups] strGr5 on strGrLink.StoreGroupNo = strGr5.StoreGroupNo
	left join [dbo].[StoreGroups] strGrlvl4 on strGrlvl4.StoreGroupNo = strGr5.StoreGroupLinkNo
	left join [dbo].[StoreGroups] strGrlvl3 on strGrlvl4.StoreGroupLinkNo = strGrlvl3.StoreGroupNo
	left join [dbo].[StoreGroups] strGrlvl5 on strGrlvl3.StoreGroupLinkNo = strGrlvl5.StoreGroupNo
	left join [dbo].[StoreGroupTypes] strGrType with (nolock) on  strGrType.StoreGroupTypeNo = strGr5.StoreGroupTypeNo
	where strGr5.StoreGroupTypeNo in (2,3,11,12)
	and StoreID = 3000




	--select *
	--from [dbo].[StoreGroupTypes] with (nolock)



	select ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo, StoreNo, StoreId
	from BI_Mart.RBIM.Dim_Store ds
	where StoreId = 3000
	union all

	select ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo, StoreNo, StoreId
	from BI_Mart.RBIM.Dim_Store ds
	where StoreId = 3000

	union all

	select ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo, StoreNo, StoreId
	from BI_Mart.RBIM.Dim_Store ds
	where StoreId = 3000




			insert into @resultTable
			SELECT DISTINCT StoreId, StoreExternalId
			from CBIM.Dim_Store ds with (nolock) --on sto.StoreId = ds.StoreID  and sto.ExternalStoreId = ds.StoreExternalId and ds.IsCurrent = 1
			LEFT JOIN ( SELECT ParameterValue FROM [dbo].[ufn_RBI_SplittParameterString]( @StoreGroupNos , ',')) n  ON n.ParameterValue IN (
									ds.Lev1RegionGroupNo ,ds.Lev2RegionGroupNo,ds.Lev3RegionGroupNo,ds.Lev4RegionGroupNo,ds.Lev5RegionGroupNo,				--Region
									ds.Lev1LegalGroupNo,ds.Lev2LegalGroupNo,ds.Lev3LegalGroupNo,ds.Lev4LegalGroupNo,ds.Lev5LegalGroupNo,					--Legal
									ds.Lev1ChainGroupNo,ds.Lev2ChainGroupNo,ds.Lev3ChainGroupNo,ds.Lev4ChainGroupNo,ds.Lev5ChainGroupNo,					--Chain
									ds.Lev1DistrictGroupNo,ds.Lev2DistrictGroupNo,ds.Lev3DistrictGroupNo,ds.Lev4DistrictGroupNo,ds.Lev5DistrictGroupNo,		--District
									ds.StoreId) 
			WHERE n.ParameterValue IS NOT NULL and ds.IsCurrentStore = 1 --to ensure we only get historical changes for the same store (defined by same GLN and same ORG number) 







*/

