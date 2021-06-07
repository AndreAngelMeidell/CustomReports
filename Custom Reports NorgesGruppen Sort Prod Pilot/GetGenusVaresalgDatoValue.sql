USE [VRNOMisc]
GO

/****** Object:  UserDefinedFunction [dbo].[GetGenusVaresalgDatoValue]    Script Date: 05.02.2021 13:23:28 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

 
 
 
 
CREATE FUNCTION [dbo].[GetGenusVaresalgDatoValue]
(
    @date DATE
)  
RETURNS VARCHAR(1000) AS
 
BEGIN    
    --SET DATEFIRST 1
 
    RETURN
        --RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@date),@date)) AS VARCHAR),4)  +
        --RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@date),@date)) AS VARCHAR),2) +
        --RIGHT('0' + CAST(DATEPART(DAY,@date) AS VARCHAR),2)+
        --RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@date),@date)) AS VARCHAR),2)+
        --RIGHT('0' + CAST(DATEPART(iso_WEEK,DATEADD(DAY , 7-DATEPART(WEEKDAY,@date),@date)) AS VARCHAR),2)
 
        --AAM 20190423 endret fra RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@date),@date)) AS VARCHAR),2)+
        --Må Endret tilbake for å få siste dag i uken til denne over, og skrive om dato for å lage akkumulert
        --Endrer pga feil mnd i den over, denne gir søndag i uken det gjelder
        RIGHT('0' + CAST(DATEPART(YEAR,DATEADD(DAY , 7-DATEPART(WEEKDAY,@date),@date)) AS VARCHAR),4)  +
        RIGHT('0' + CAST(DATEPART(MONTH,DATEADD(DAY , 7-DATEPART(WEEKDAY,@date),@date)) AS VARCHAR),2) +
        RIGHT('0' + CAST(DATEPART(DAY,DATEADD(DAY , 7-DATEPART(WEEKDAY,@date),@date)) AS VARCHAR),2)+
        RIGHT('0' + CAST(DATEPART(iso_WEEK,DATEADD(DAY , 7-DATEPART(WEEKDAY,@date),@date)) AS VARCHAR),2)
/*
 
    RETURN
    '<Mappingrapport>
    <Dato>'+ cast(cast(getdate() as date) as varchar) + '</Dato>
    <Server>'+ @@SERVERNAME + '</Server>
    <Database>' + @db +'</Database>
    <Tabell>' + @table + '</Tabell>
    <Bruksområde>' + @bruksområde + '</Bruksområde>
    <RaderIUtvalg>' + cast(@RaderIUtvalg as varchar) + '</RaderIUtvalg>
    <DagerIUtvalg>' + cast(@DagerIUtvalg as varchar) + '</DagerIUtvalg>
    <Målepunkter>'
    */ 
     END
 
 
 
 

GO

