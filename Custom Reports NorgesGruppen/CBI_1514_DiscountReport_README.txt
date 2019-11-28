CBI_1514_DiscountReport_report er en rapport basert på RBI_0063_ArticleAnalyse

Prosedyrer som må installeres:
*usp_CBI_1514_Discount_Main.sql
*usp_CBI_1514_Discount_ArticleHierarchyName.sql
*usp_CBI_1514_Discount_Detail.sql

Logg inn på Jasper på web finn lokasjon hvor du vil ha rapporten, høyre klikk, add resourse og Jasper report:
Følg navnstandard CBI for konsulent rapporter og begynne på 1000

CBI: 1514 i Descripions for å kunne synkes med RS

Locate the JRXML File, Upload a local file
CBI_1514_DiscountReport.jrxml filen finner du lokalt

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
* /public/RBI_Resources/Input_Controls/inp_RsStoreId_hidden
* /public/RBI_Resources/Input_Controls/inp_DateRangeBegin
* /public/RBI_Resources/Input_Controls/inp_DateRangeEnd
* /public/RBI_Resources/Input_Controls/inp_ArticleSelection
* /public/RBI_Resources/Input_Controls/inp_RsUserLanguageCode_hidden
* /public/RBI_Resources/Input_Controls/inp_UseShortLabelText
* /public/RBI_Resources/Input_Controls/inp_Supplier

Submit





