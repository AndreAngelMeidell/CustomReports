1358_StockCountNotCounted.jrxml is a new report for TRN

Procedure to be installed on VBDCM  (Copy text from file to an Query and Execute)
*usp_CBI_ds1358StockCountArticlesNotCounted_report.sql

Use Jasper Web to install:
In JasperServerPro - View from TopMenu, And "Repository"

Clik on: Public\CBI Content\Reports\
Right-click on \Reports\ Select Add Recource and Jasper Report.

Click "Browse" in Upload a Local file, find the file local.

Set infomation:
Name: "1358 StockCountNotCounted
Resource ID (required): standard
Description: "CBI: 1358" in Descripions to sync with RS!

"Submit" 
and right Click on the report, "Edit"

Resource:
-Add resource, select an resouce and browse
* /public/RBI_Resources/Translations/RetailSuiteDWH_nb_NO.properties	Name: RetailSuiteDWH_nb_NO.properties	Next

-Add resource, select an resouce and browse
* /public/RBI_Resources/Translations/RetailSuiteDWH_en_US.properties	Name: RetailSuiteDWH_en_US.properties	Next

-Add resource, select an resouce and browse
* /public/RBI_Resources/Translations/RetailSuiteDWH.properties		Name: RetailSuiteDWH.properties		Next

Choose: Display mode to: "In page"

"Submit" 
and right Click on the report, "Edit"

Add Input Control…, and This is the order of inputs: + "NEXT":

/public/RBI_Resources/Input_Controls/inp_DateRangeBegin 
/public/RBI_Resources/Input_Controls/inp_DateRangeEnd 
/public/RBI_Resources/Input_Controls/inp_RsStoreId_hidden 
/public/RBI_Resources/Input_Controls/inp_UseShortLabelText 
/public/RBI_Resources/Input_Controls/inp_RsUserLanguageCode_hidden 



"Submit" 
and right Click on the report, "Edit"


Link a Data Source to the Report, Select data source from repository:
/public/RBI_Resources/Data_Sources/VBDCM

"Submit"


Then you can synck the report to RS within RS Client.
























CBI_xxxx_RevenueFigures_report er en rapport basert på RBI_xxxx_RevenueFigures_report

Prosedyrer som må installeres:

Logg inn på Jasper på web finn lokasjon hvor du vil ha rapporten, høyre klikk, add resourse og Jasper report:
Følg navnstandard CBI for konsulent rapporter og begynne på 1000

CBI: xxxx i Descripions for å kunne synkes med RS


Locate the JRXML File, Upload a local file
CBI_xxxx.jrxml filen finner du lokalt

Sbmit og Edit på nytt

Linking mot dataset:
* dataSource: /public/RBI_Resources/Data_Sources/RBIMart



Linking av rapporten mot resources:
* /public/RBI_Resources/Translations/RetailSuiteDWH_nb_NO.properties	Name: RetailSuiteDWH_nb_NO.properties	Next
* /public/RBI_Resources/Translations/RetailSuiteDWH_en_US.properties	Name: RetailSuiteDWH_en_US.properties	Next
* /public/RBI_Resources/Translations/RetailSuiteDWH.properties		Name: RetailSuiteDWH.properties		Next

Velg "In page"

Submit, Edit på nytt

Add input controls, og dette blir rekkefølgen av parametere i rapporten 



Linking av rapporten mot input controls og datasource:
* /public/RBI_Resources/Input_Controls/inp_StoreGroupCategory
* /public/RBI_Resources/Input_Controls/inp_StoreGroup
* /public/RBI_Resources/Input_Controls/inp_DateRangeBegin
* /public/RBI_Resources/Input_Controls/inp_DateRangeEnd
* /public/RBI_Resources/Input_Controls/inp_0155_GroupBy
* /public/RBI_Resources/Input_Controls/inp_Exclude3rdPartyArticles
* /public/RBI_Resources/Input_Controls/inp_ExcludeBottleDeposit
* /CBI_Resources/Input_Controls/inp_1155_IncludeSellers
* /public/RBI_Resources/Input_Controls/inp_BrandIdFrom
* /public/RBI_Resources/Input_Controls/inp_BrandIdTo
* /public/RBI_Resources/Input_Controls/inp_ArticleIdFrom
* /public/RBI_Resources/Input_Controls/inp_ArticleIdTo
* /public/RBI_Resources/Input_Controls/inp_ArticleHierarchyIdFrom
* /public/RBI_Resources/Input_Controls/inp_ArticleHierarchyIdTo
* /public/RBI_Resources/Input_Controls/inp_RsStoreId_hidden
* /public/RBI_Resources/Input_Controls/inp_RsUserLanguageCode_hidden
* /public/RBI_Resources/Input_Controls/inp_UseShortLabelText

* /public/RBI_Resources/Input_Controls/inp_RsStoreId_hidden
* /public/RBI_Resources/Input_Controls/inp_DateRangeBegin
* /public/RBI_Resources/Input_Controls/inp_DateRangeEnd
* /public/RBI_Resources/Input_Controls/inp_ArticleSelection
* /public/RBI_Resources/Input_Controls/inp_RsUserLanguageCode_hidden
* /public/RBI_Resources/Input_Controls/inp_UseShortLabelText
* /public/RBI_Resources/Input_Controls/inp_Supplier

Linking mot dataset:
* dataSource: /public/RBI_Resources/Data_Sources/RBIMart
*

Prosedyrer som må installeres:
*
*
