CBI_1514_DiscountReport_report er en rapport basert p� RBI_0063_ArticleAnalyse

Prosedyrer som m� installeres:
*usp_CBI_1514_Discount_Main.sql
*usp_CBI_1514_Discount_ArticleHierarchyName.sql
*usp_CBI_1514_Discount_Detail.sql

Logg inn p� Jasper p� web finn lokasjon hvor du vil ha rapporten, h�yre klikk, add resourse og Jasper report:
F�lg navnstandard CBI for konsulent rapporter og begynne p� 1000

CBI: 1514 i Descripions for � kunne synkes med RS

Locate the JRXML File, Upload a local file
CBI_1514_DiscountReport.jrxml filen finner du lokalt

Sbmit og Edit p� nytt

Linking mot dataset:
* dataSource: /public/RBI_Resources/Data_Sources/RBIMart


Linking av rapporten mot resources:
* /public/RBI_Resources/Translations/RetailSuiteDWH_nb_NO.properties	Name: RetailSuiteDWH_nb_NO.properties	Next
* /public/RBI_Resources/Translations/RetailSuiteDWH_en_US.properties	Name: RetailSuiteDWH_en_US.properties	Next
* /public/RBI_Resources/Translations/RetailSuiteDWH.properties		Name: RetailSuiteDWH.properties		Next

Velg "In page"

Submit, Edit p� nytt

Add input controls, og dette blir rekkef�lgen av parametere i rapporten 

Linking av rapporten mot input controls og datasource:
* /public/RBI_Resources/Input_Controls/inp_RsStoreId_hidden
* /public/RBI_Resources/Input_Controls/inp_DateRangeBegin
* /public/RBI_Resources/Input_Controls/inp_DateRangeEnd
* /public/RBI_Resources/Input_Controls/inp_ArticleSelection
* /public/RBI_Resources/Input_Controls/inp_RsUserLanguageCode_hidden
* /public/RBI_Resources/Input_Controls/inp_UseShortLabelText
* /public/RBI_Resources/Input_Controls/inp_Supplier

Submit





