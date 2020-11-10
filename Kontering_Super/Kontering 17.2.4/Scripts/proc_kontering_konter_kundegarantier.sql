use Varesalg
go

SET ANSI_NULLS on
GO
SET QUOTED_IDENTIFIER on
GO
-- =============================================
-- Author:		HFH
-- Create date: 	06 2013
-- Version:		17.2.5
-- Description:		Gjenbrukt SQL fra gammel konteringspakke for kundegarantireglene. 
--
--Forklaring til BongvareGenFelt:
--FELTNR:	4000	Kundegaranti beløp			feltdata1:	Garantinr		feltdata2:	Regelnr
--FELTNR:	4001	Kundegaranti antall			feltdata1:	Garantinr		feltdata2:	Regelnr
--FELTNR:	4002	Kundegaranti mvabeløp		feltdata1:	Garantinr		feltdata2:	Regelnr
--FELTNR:	4003	Kundegaranti mengde			feltdata1:	Garantinr		feltdata2:	Regelnr
--FELTNR:	4004	Kundegaranti innpris		feltdata1:	Garantinr		feltdata2:	Regelnr
--FELTNR:	4005	Kundegaranti årsakskode		feltdata1:	Garantinr		feltdata2:	Regelnr
-- =============================================

if exists(select * from   sys.procedures where  name = 'Kontering_kundegarantier') 
	begin 
		drop procedure Kontering_kundegarantier 
	end;
go

create procedure Kontering_kundegarantier (@fradato as datetime, @tildato as datetime)
as
begin
	set nocount on;		
    --declare @fradato as datetime
	--declare @tildato as datetime
	--set @fradato = (select min(OPPGJOERFORDATO) from super..KONTERINGSOPPGJOER where GODKJENT IS NULL AND ZNR IN (select min(znr) from super..KonteringIkkeGodkjent))
	--set @tildato = @fradato + 1

	   declare @dato as date;
       set @dato = (select cast(@fradato as date))
       
       select --§§§§ SQLNR 1144 HG erstatningsvare (under bg.verdi) Debet G2
             b.utsalgsstednr
             , null as avdelingsnr                   
             , 7322 as debetkontonr
             , sum(bvg.verdi1 * bvgm.verdi1) as debetbeloep
             , null as kreditbeloep
             , null as kreditkontonr
             , cast(0 as DECIMAL(15, 3)) as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('39' as VARCHAR(2)) as fritekst3  
       from bong b
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid
             and bvg.feltnr = 4004 --Kundegaranti innpris
             and bvg.feltdata1 = '2'--Garantinr
             and bvg.feltdata2 = '7'--Regelnr 
       inner join bongvaregenfelt bvgm on bvgm.bongid = b.bongid                    
             and bvgm.EAN=bvg.EAN                   
             and bvgm.FELTDATA3 = bvg.FELTDATA3
             and bvgm.feltnr = 4003 --Kundegaranti mengde 
             and bvgm.feltdata1 = '2'--Garantinr
             and bvgm.feltdata2 = '7'--Regelnr 
       inner join eaninfo e on e.eannr = bvg.ean
             and e.eanid = (     select Max(eanid) 
                                        from   eaninfo
                                        where  eannr = bvg.ean)
       where  b.datotid > @fradato
             and b.datotid < @tildato
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning
                                  from   bong b2
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b.bongid
                                        and bvg2.feltnr = 4000 --Kundegaranti beløp
                                        and bvg2.feltdata1 = '2' --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr 
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from  eaninfo e3  
                                                                   where  e3.eannr = bvg2.ean)
                                  where  b2.datotid > @fradato
                                        and b2.datotid < @tildato
                                        and b.bongid = b2.bongid
                                        and bvg.ean = bvg2.ean
                                  group  by 
                                        b2.bongid
                                        ,bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                  having sum(bvg2.verdi1) < 100
                                  )
       group  by 
             b.utsalgsstednr
             , e.underavdelingsnr
       
       select --§§§§ SQLnr 1145 HG erstatningsvare (under bg.verdi) Kredit G2
             b.utsalgsstednr
             , null as avdelingsnr                
             , null as debetkontonr
             , null as debetbeloep
             , 4300 as kreditkontonr
             , sum(bvg.verdi1 * bvgm.verdi1) as kreditbeloep
             , cast(0 as DECIMAL(15, 3)) as mvaprosent                
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('39' as VARCHAR(2))      as fritekst3 
       from   bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4004 --Kundegaranti innpris --Kundegaranti innpris --Kundegaranti innpris
             and bvg.feltdata1 = '2' --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join bongvaregenfelt bvgm on bvgm.bongid = b.bongid 
             and bvgm.EAN=bvg.EAN
             and bvgm.FELTDATA3 = bvg.FELTDATA3                                    
             and bvgm.feltnr = 4003 --Kundegaranti mengde--Kundegaranti mengde
             and bvgm.feltdata1 = '2'--Garantinr
             and bvgm.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                               from   eaninfo 
                                               where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
                    and b.datotid < @tildato 
                    and exists (select 
                                               b2.bongid 
                                               ,bvg2.ean
                                               ,b2.utsalgsstednr
                                               ,e2.underavdelingsnr
                                               ,sum(bvg2.verdi1) as omsetning 
                                        from bong b2 
                                        inner join bongvaregenfelt bvg2 on bvg2.bongid = b.bongid 
                                               and bvg2.feltnr = 4000 --Kundegaranti beløp
                                               and bvg2.feltdata1 = '2' --Garantinr
                                               and bvg2.feltdata2 = '7' --Regelnr
                                        inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                               and e2.eanid = (select Max(e3.eanid) 
                                                                                 from   eaninfo e3 
                                                                                 where  e3.eannr = bvg2.ean) 
                                     where  b2.datotid > @fradato 
                                               and b2.datotid < @tildato 
                                               and b.bongid = b2.bongid 
                                               and bvg.ean = bvg2.ean 
                                     group  by 
                                               b2.bongid 
                                               , bvg2.ean
                                               , b2.utsalgsstednr
                                               ,e2.underavdelingsnr 
                                     having sum(bvg2.verdi1) < 100
                                     ) 
       group  by 
             b.utsalgsstednr
             ,e.underavdelingsnr

       select ---§§§ SQLNR 1146 HG erstatningsvare (over bg.verdi) Debet G2
             b.utsalgsstednr
             , null as avdelingsnr
             , 7322  as debetkontonr
             , sum(bvg.verdi1) as debetbeloep
             ,null as kreditkontonr
             ,null as kreditbeloep
             , cast(0 as DECIMAL(15, 3)) as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             ,null as fritekst2
             , cast('39' as VARCHAR(2)) as fritekst3  
       from bong b
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid
             and bvg.feltnr = 4000 --Kundegaranti beløp
             and bvg.feltdata1 = '2' --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean
             and e.eanid = (select Max(eanid)
                                        from   eaninfo
                                        where  eannr = bvg.ean)  
       where  b.datotid > @fradato 
             and b.datotid < @tildato
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        ,b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning 
                                  from   bong b2
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid
                                        and bvg2.feltnr = 4000 --Kundegaranti beløp
                                        and bvg2.feltdata1 = '2'--Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid)
                                                                   from   eaninfo e3
                                                                   where  e3.eannr = bvg2.ean)
                                  where  b2.datotid > @fradato
                                        and b2.datotid < @tildato
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean
                                  group  by 
                                        b2.bongid
                                        ,bvg2.ean
                                        ,b2.utsalgsstednr
                                        ,e2.underavdelingsnr
                                  having sum(bvg2.verdi1) >= 100
                                  )  
             group  by 
                    b.utsalgsstednr
                    ,e.underavdelingsnr
                    ,e.mvaprosent  
       
       union  
             
             select 
                    b.utsalgsstednr
                    , null as avdelingsnr                                 
                    , 3030 as debetkontonr
                    , sum(bvgu.verdi1 - bvg.VERDI1) as debetbeloep
                    , null as kreditkontonr
                    , null as kreditbeloep
                    , cast(0 as DECIMAL(15, 3)) as mvaprosent
                    , cast('Garanti' as VARCHAR(7)) as fritekst1
                    , null as fritekst2
                    , cast('39' as VARCHAR(2)) as fritekst3  
             from bong b 
             inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
                    and bvg.feltnr = 4002 --Kundegaranti mvabeløp
                    and bvg.feltdata1 = '2'--Garantinr
                    and bvg.feltdata2 = '7' --Regelnr
             inner join bongvaregenfelt bvgu on bvgu.bongid = bvg.bongid
                    and bvgu.EAN=bvg.EAN
                    and bvgu.FELTDATA3 = bvg.FELTDATA3
                    and bvgu.feltnr = 4000 --Kundegaranti beløp
                    and bvgu.feltdata1 = '2' --Garantinr
                    and bvgu.feltdata2 = '7' --Regelnr
             inner join eaninfo e on e.eannr = bvg.ean
                    and e.eanid = (select Max(eanid)
                                               from   eaninfo
                                               where  eannr = bvg.ean)  
                    where  b.datotid > @fradato
                           and b.datotid < @tildato 
                           and exists (select 
                                                      b2.bongid
                                                      , bvg2.ean
                                                      , b2.utsalgsstednr
                                                      , e2.underavdelingsnr
                                                      , sum(bvg2.verdi1) as omsetning
                                               from   bong b2
                                               inner join bongvaregenfelt bvg2   on bvg2.bongid = b2.bongid
                                                      and bvg2.feltnr = 4000 --Kundegaranti beløp
                                                      and bvg2.feltdata1 = '2'--Garantinr
                                                      and bvg2.feltdata2 = '7' --Regelnr
                                               inner join eaninfo e2 on e2.eannr = bvg2.ean
                                                      and e2.eanid = (select Max(e3.eanid)
                                                                                 from   eaninfo e3
                                                                                 where  e3.eannr = bvg2.ean)
                                               where  b2.datotid > @fradato
                                                      and b2.datotid < @tildato
                                                      and b.bongid = b2.bongid
                                                      and bvg.ean = bvg2.ean
                                               group  by 
                                                      b2.bongid
                                                      , bvg2.ean
                                                      , b2.utsalgsstednr
                                                      , e2.underavdelingsnr
                                               having sum(bvg2.verdi1) >= 100
                                               )  
                    group  by 
                           b.utsalgsstednr
                           , e.underavdelingsnr  
             
             union  
                    
                    select 
                           b.utsalgsstednr
                           , null as avdelingsnr                                       
                           , 7322 as debetkontonr
                           , sum(bvg.verdi1 * bvgm.verdi1)  as debetbeloep
                           , null as kreditkontonr
                           , null as kreditbeloep
                           , cast(0 as DECIMAL(15, 3)) as mvaprosent
                           , cast('Garanti' as VARCHAR(7)) as fritekst1
                           , null as fritekst2
                           , cast('39' as VARCHAR(2)) as fritekst3  
                    from bong b 
                    inner join bongvaregenfelt bvg on bvg.bongid = b.bongid
                           and bvg.feltnr = 4004 --Kundegaranti innpris
                           and bvg.feltdata1 = '2'--Garantinr
                           and bvg.feltdata2 = '7' --Regelnr
                    inner join bongvaregenfelt bvgm on bvgm.bongid = b.bongid
                           and bvgm.EAN=bvg.EAN
                           and bvgm.FELTDATA3 = bvg.FELTDATA3
                           and bvgm.feltnr = 4003 --Kundegaranti mengde
                           and bvgm.feltdata1 = '2'--Garantinr
                           and bvgm.feltdata2 = '7' --Regelnr
                    inner join eaninfo e on e.eannr = bvg.ean
                           and e.eanid = (select Max(eanid)
                                                      from   eaninfo
                                                      where  eannr = bvg.ean)  
                    where  b.datotid > @fradato
                           and b.datotid < @tildato
                           and exists (select 
                                                      b2.bongid
                                                      , bvg2.ean
                                                      , b2.utsalgsstednr
                                                      , e2.underavdelingsnr
                                                      , sum(bvg2.verdi1) as omsetning
                                               from   bong b2
                                               inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid
                                                      and bvg2.feltnr = 4000 --Kundegaranti beløp
                                                      and bvg2.feltdata1 = '2'--Garantinr
                                                      and bvg2.feltdata2 = '7' --Regelnr
                                               inner join eaninfo e2 on e2.eannr = bvg2.ean
                                                      and e2.eanid = (select Max(e3.eanid)
                                                                                 from   eaninfo e3
                                                                                 where  e3.eannr = bvg2.ean)
                                                      where  b2.datotid > @fradato
                                                            and b2.datotid < @tildato
                                                            and b.bongid = b2.bongid
                                                            and bvg.ean = bvg2.ean
                                                      group  by 
                                                            b2.bongid
                                                            , bvg2.ean
                                                            , b2.utsalgsstednr
                                                            , e2.underavdelingsnr
                                                      having sum(bvg2.verdi1) >= 100
                                               )  
                    group  by 
                           b.utsalgsstednr
                           ,e.underavdelingsnr
             
       select ---§§§ SQLNR 1147 HG erstatningsvare (over bg.verdi) Kredit G2
             b.utsalgsstednr
             , null as avdelingsnr                      
             , null as debetkontonr
             , null as debetbeloep
             , 3030 as kreditkontonr
             , sum(bvg.verdi1)as kreditbeloep
             , e.mvaprosent as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('39' as VARCHAR(2)) as fritekst3 
       from   bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4000 --Kundegaranti beløp
             and bvg.feltdata1 = '2'--Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean
                                        ) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid, 
                                        bvg2.ean, 
                                        b2.utsalgsstednr, 
                                        e2.underavdelingsnr, 
                                        sum(bvg2.verdi1) as omsetning 
                                  from   bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid 
                                        and bvg2.feltnr = 4000 --Kundegaranti beløp
                                        and bvg2.feltdata1 = '2' --Garantinr
                                        and bvg2.feltdata2 = '7'  --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                        where  b2.datotid > @fradato 
                                               and b2.datotid < @tildato 
                                               and b.bongid = b2.bongid 
                                               and bvg.ean = bvg2.ean 
                                        group  by 
                                               b2.bongid
                                               , bvg2.ean
                                               , b2.utsalgsstednr
                                               , e2.underavdelingsnr 
                                        having sum(bvg2.verdi1) >= 100) 
       group  by 
             b.utsalgsstednr 
             , e.underavdelingsnr
             , e.mvaprosent 
       
       union 
       
       select 
             b.utsalgsstednr
             , null as avdelingsnr                      
             , null as debetkontonr
             , null as debetbeloep
             , 7322 as kreditkontonr
             , sum(bvgu.verdi1 - bvg.verdi1) as kreditbeloep
             , cast(0 as DECIMAL(15, 3)) as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('39' as VARCHAR(2)) as fritekst3 
       from   bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4002 --Kundegaranti mvabeløp
             and bvg.feltdata1 = '2' --Garantinr
             and bvg.feltdata2 = '7'  --Regelnr
       inner join bongvaregenfelt bvgu on bvgu.bongid = bvg.bongid 
             and bvgu.ean = bvg.ean 
             and bvgu.feltdata3 = bvg.feltdata3 
             and bvgu.feltnr = 4000 --Kundegaranti mvabeløp
             and bvgu.feltdata1 = '2' --Garantinr
             and bvgu.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid, 
                                        bvg2.ean, 
                                        b2.utsalgsstednr, 
                                        e2.underavdelingsnr, 
                                        sum(bvg2.verdi1) as omsetning 
                                  from   bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid 
                                        and bvg2.feltnr = 4000 --Kundegaranti mvabeløp
                                        and bvg2.feltdata1 = '2' --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                  where  b2.datotid > @fradato 
                                        and b2.datotid < @tildato 
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean 
                                  group  by 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr 
                                  having sum(bvg2.verdi1) >= 100) 
       group  by 
             b.utsalgsstednr
             , e.underavdelingsnr 

       union 
       
       select 
             b.utsalgsstednr
             , null as avdelingsnr
             , null as debetkontonr
             , null as debetbeloep
             , 4300 as kreditkontonr
             , sum(bvg.verdi1 * bvgm.verdi1)  as kreditbeloep
             , cast(0 as DECIMAL(15, 3)) as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('39' as VARCHAR(2)) as fritekst3 
       from   bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4004 --Kundegaranti innpris 
             and bvg.feltdata1 = '2' --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join bongvaregenfelt bvgm on bvgm.bongid = b.bongid 
             and bvgm.ean = bvg.ean 
             and bvgm.feltdata3 = bvg.feltdata3 
             and bvgm.feltnr = 4003 --Kundegaranti mengde
             and bvgm.feltdata1 = '2'--Garantinr
             and bvgm.feltdata2 = '7'  --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning 
                                  from bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid  
                                        and bvg2.feltnr = 4000 --Kundegaranti mvabeløp
                                        and bvg2.feltdata1 = '2' --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                  where  b2.datotid > @fradato 
                                        and b2.datotid < @tildato 
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean 
                                  group  by 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr 
                                  having sum(bvg2.verdi1) >= 100) 
       group  by 
             b.utsalgsstednr
             ,e.underavdelingsnr 
       
       select ---§§§ SQLNR 1148 HG Penger G3
             k.utsalgsstednr
             ,null as avdelingsnr                    
             , 7322 as debetkontonr
             , sum(k.omsetning) as debetbeloep
             ,null as kreditkontonr
             ,null as kreditbeloep
             , cast(0 as DECIMAL(15, 3)) as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             ,null as fritekst2
             , cast('39' as VARCHAR(2)) as fritekst3 
       from   kundegarantisalgdag k 
       where  dato = @dato                  
             and garantinr = 3 
             and regelnr = 5 
       group  by k.utsalgsstednr 
       
       select ---§§§ SQLNR 1149 FG Debet (under bg.verdi) G21 og 22
             b.utsalgsstednr
             , null as avdelingsnr                                         
             , 7322 as debetkontonr
             , sum(bvg.verdi1 * bvgm.verdi1)  as debetbeloep
             , null as kreditkontonr
             , null as kreditbeloep
             , cast(0 as DECIMAL(15, 3))      as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('38' as VARCHAR(2))      as fritekst3 
       from   bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4004 --Kundegaranti innpris 
             and ((bvg.feltdata1 = '21') 
                    or (bvg.feltdata1 = '22')) --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join bongvaregenfelt bvgm on bvgm.bongid = b.bongid 
             and bvgm.ean = bvg.ean 
             and bvgm.feltdata3 = bvg.feltdata3 
             and bvgm.feltnr = 4003 --Kundegaranti mengde
             and (( bvgm.feltdata1 = '21' ) 
                    or (bvgm.feltdata1 = '22' )) --Garantinr
             and bvgm.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning 
                                  from   bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b.bongid 
                                        and bvg2.feltnr = 4000 --Kundegaranti mvabeløp
                                        and (( bvg2.feltdata1 = '21') 
                                               or (bvg2.feltdata1 = '22' )) --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                  where  b2.datotid > @fradato 
                                        and b2.datotid < @tildato 
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean 
                                  group  by 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr 
                                  having sum(bvg2.verdi1) < 100) 
       group  by 
             b.utsalgsstednr
             , e.underavdelingsnr 
       
       select ---§§§ SQLNR 1150 FG Kredit (under bg.verdi) G21 og 22
             b.utsalgsstednr
             , null as avdelingsnr                      
             , null as debetkontonr
             , null as debetbeloep
             , 4300 as kreditkontonr
             , sum(bvg.verdi1 * bvgm.verdi1)  as kreditbeloep
             , cast(0 as DECIMAL(15, 3))      as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('38' as VARCHAR(2))      as fritekst3 
       from bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4004 --Kundegaranti innpris 
             and (( bvg.feltdata1 = '21' ) 
                    or ( bvg.feltdata1 = '22' )) --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join bongvaregenfelt bvgm on bvgm.bongid = b.bongid 
             and bvgm.ean = bvg.ean
             and bvgm.FELTDATA3 = bvg.FELTDATA3                                    
             and bvgm.feltnr = 4003 --Kundegaranti mengde
             and (( bvgm.feltdata1 = '21' ) 
                    or ( bvgm.feltdata1 = '22' )) --Garantinr
             and bvgm.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning 
                                  from bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid 
                                        and bvg2.feltnr = 4000 --Kundegaranti mvabeløp
                                        and (( bvg2.feltdata1 = '21' ) 
                                               or ( bvg2.feltdata1 = '22' )) --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                  where  b2.datotid > @fradato 
                                        and b2.datotid < @tildato 
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean 
                                  group  by 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr 
                                  having sum(bvg2.verdi1) < 100) 
       group  by 
             b.utsalgsstednr
             , e.underavdelingsnr 

       select ---§§§ SQLNR 1151 FG Debet (over bg.verdi) Debet G21 og 22
             b.utsalgsstednr
             ,null as avdelingsnr                 
             , 7322 as debetkontonr -- Motpos Kredit 3030
             , sum(bvg.verdi1) as debetbeloep -- Varens  salgspris
             , null as kreditkontonr
             , null as kreditbeloep
             , e.MVAPROSENT as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('38' as VARCHAR(2)) as fritekst3 
       from bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4000 --Kundegaranti beløp
             and ((bvg.feltdata1 = '21') 
                    or (bvg.feltdata1 = '22')) --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning 
                                  from   bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid 
                                        and bvg2.feltnr = 4000 --Kundegaranti mvabeløp
                                        and ((bvg2.feltdata1 = '21') 
                                               or (bvg2.feltdata1 = '22')) --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                  where  b2.datotid > @fradato 
                                        and b2.datotid < @tildato 
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean 
                                  group  by 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr 
                                  having sum(bvg2.verdi1) >= 100) 
       group  by 
             b.utsalgsstednr
             , e.underavdelingsnr
             , e.mvaprosent 
       
       union 
       
       select 
             b.utsalgsstednr
             , null as avdelingsnr                      
             , 3030 as debetkontonr -- Motpost Kredit 7320
             , sum(bvgu.verdi1 - bvg.verdi1)  as debetbeloep -- Varens salgspris ex.mva
             ,null as kreditkontonr
             ,null as kredtibeloep
             , cast(0 as DECIMAL(15, 3)) as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             ,null as fritekst2
             , cast('38' as VARCHAR(2)) as fritekst3 
       from bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4002 --Kundegaranti mvabeløp
             and (( bvg.feltdata1 = '21' )
                    or (bvg.feltdata1 = '22' )) --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join bongvaregenfelt bvgu on bvgu.bongid = b.bongid 
             and bvgu.ean = bvg.ean 
             and bvgu.feltdata3 = bvg.feltdata3 
             and bvgu.feltnr = 4000 --Kundegaranti beløp
             and (( bvgu.feltdata1 = '21' ) 
                    or ( bvgu.feltdata1 = '22' )) --Garantinr
             and bvgu.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning 
                                  from bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid 
                                        and bvg2.feltnr = 4000 --Kundegaranti beløp
                                        and (( bvg2.feltdata1 = '21' ) 
                                               or ( bvg2.feltdata1 = '22' )) --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                  where  b2.datotid > @fradato 
                                        and b2.datotid < @tildato 
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean 
                                  group by 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr 
                                  having sum(bvg2.verdi1) >= 100) 
       group by 
             b.utsalgsstednr
             , e.underavdelingsnr 
       
       --union  /* fjernet 10.07.2014 grunnet feil der det gis rabatt verdi som er lik mva prosent som gjør at det bare vise en linje for debet 7322 fordi slagsprisen == netto innpris */
       
       select 
             b.utsalgsstednr
             , null as avdelingsnr                      
             , 7322 as debetkontonr -- Motpost kredit 4300 
             , sum(bvg.verdi1 * bvgm.verdi1)  as debetbeloep -- Varens netto innpris
             ,null as kreditkontonr
             ,null as kreditbeloep
             , cast(0 as DECIMAL(15, 3)) as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             ,null as fritekst2
             , cast('38' as VARCHAR(2)) as fritekst3 
       from bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4004 --Kundegaranti innpris 
             and (( bvg.feltdata1 = '21' ) 
                    or ( bvg.feltdata1 = '22' )) --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join bongvaregenfelt bvgm on bvgm.bongid = b.bongid 
             and bvgm.ean = bvg.ean 
             and bvgm.feltdata3 = bvg.feltdata3 
             and bvgm.feltnr = 4003 --Kundegaranti mengde
             and (( bvgm.feltdata1 = '21' ) 
                    or ( bvgm.feltdata1 = '22' )) --Garantinr
             and bvgm.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning 
                                  from bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid 
                                        and bvg2.feltnr = 4000 --Kundegaranti beløp
                                        and (( bvg2.feltdata1 = '21' ) 
                                               or ( bvg2.feltdata1 = '22' )) --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                  where  b2.datotid > @fradato 
                                        and b2.datotid < @tildato 
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean 
                                  group by 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr 
                                  having sum(bvg2.verdi1) >= 100) 
       group  by 
             b.utsalgsstednr
             , e.underavdelingsnr 

       select ---§§§ SQLNR 1152 FG Kredit (over bg.verdi) G21 og 22
             b.utsalgsstednr
             , null as avdelingsnr                      
             , null as debetkontonr
             , null as debetbeloep
             , 3030 as kreditkontonr -- Motpost Debet 7322
             , sum(bvg.verdi1) as kreditbeloep -- Varens  salgspris
             , e.mvaprosent as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('38' as VARCHAR(2)) as fritekst3 
       from   bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4000 --Kundegaranti beløp
             and (( bvg.feltdata1 = '21' ) 
                    or ( bvg.feltdata1 = '22' )) --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning 
                                  from bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid 
                                        and bvg2.feltnr = 4000 --Kundegaranti beløp
                                        and (( bvg2.feltdata1 = '21' ) 
                                               or ( bvg2.feltdata1 = '22' )) --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                  where  b2.datotid > @fradato 
                                        and b2.datotid < @tildato 
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean 
                                  group  by 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr 
                                  having sum(bvg2.verdi1) >= 100) 
       group  by 
             b.utsalgsstednr
             , e.underavdelingsnr
             , e.mvaprosent 
       
       union 
       
       select 
             b.utsalgsstednr
             , null as avdelingsnr                      
             , null as debetkontonr
             , null as debetbeloep
             , 7320 as kreditkontonr  -- Motpost FG over bagatellverdi Debet 3030     /*Endet 10.07 fra 7322 til 7320 - oppdaget feil i ift spekk*/
             , sum(bvgu.verdi1 - bvg.verdi1) as kreditbeloep -- Varens salgspris ex.mva
             , cast(0 as DECIMAL(15, 3)) as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('38' as VARCHAR(2)) as fritekst3 
       from bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4002 --Kundegaranti mvabeløp
             and (( bvg.feltdata1 = '21' ) 
                    or ( bvg.feltdata1 = '22' )) --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join bongvaregenfelt bvgu on bvgu.bongid = b.bongid 
             and bvgu.ean = bvg.ean 
             and bvgu.feltdata3 = bvg.feltdata3 
             and bvgu.feltnr = 4000 --Kundegaranti mvabeløp
             and (( bvgu.feltdata1 = '21' ) 
                    or ( bvgu.feltdata1 = '22' )) --Garantinr
             and bvgu.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning 
                                  from bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid 
                                        and bvg2.feltnr = 4000 --Kundegaranti mvabeløp
                                        and ( ( bvg2.feltdata1 = '21' ) --Garantinr
                                               or ( bvg2.feltdata1 = '22' ) ) --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                  where  b2.datotid > @fradato 
                                        and b2.datotid < @tildato 
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean 
                                  group by 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr 
                                  having sum(bvg2.verdi1) >= 100) 
       group by 
             b.utsalgsstednr
             , e.underavdelingsnr 
       
       union 
       
       select 
             b.utsalgsstednr
             , null as avdelingsnr                      
             , null as debetkontonr
             , null as debetbeloep
             , 4300 as kreditkontonr -- Motpos Debet 7322 
             , sum(bvg.verdi1 * bvgm.verdi1) as kreditbeloep -- Varens netto innpris
             , cast(0 as DECIMAL(15, 3)) as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst
             , cast('38' as VARCHAR(2)) as fritekst3 
       from   bong b 
       inner join bongvaregenfelt bvg on bvg.bongid = b.bongid 
             and bvg.feltnr = 4004 --Kundegaranti innpris 
             and (( bvg.feltdata1 = '21' ) 
                    or ( bvg.feltdata1 = '22' )) --Garantinr
             and bvg.feltdata2 = '7' --Regelnr
       inner join bongvaregenfelt bvgm on bvgm.bongid = b.bongid 
             and bvgm.ean = bvg.ean 
             and bvgm.feltdata3 = bvg.feltdata3 
             and bvgm.feltnr = 4003 --Kundegaranti mengde
             and (( bvgm.feltdata1 = '21' ) 
                    or ( bvgm.feltdata1 = '22' )) --Garantinr
             and bvgm.feltdata2 = '7' --Regelnr
       inner join eaninfo e on e.eannr = bvg.ean 
             and e.eanid = (select Max(eanid) 
                                        from   eaninfo 
                                        where  eannr = bvg.ean) 
       where  b.datotid > @fradato 
             and b.datotid < @tildato 
             and exists (select 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr
                                        , sum(bvg2.verdi1) as omsetning 
                                  from bong b2 
                                  inner join bongvaregenfelt bvg2 on bvg2.bongid = b2.bongid 
                                        and bvg2.feltnr = 4000 --Kundegaranti mvabeløp
                                        and (( bvg2.feltdata1 = '21' ) 
                                               or ( bvg2.feltdata1 = '22' )) --Garantinr
                                        and bvg2.feltdata2 = '7' --Regelnr
                                  inner join eaninfo e2 on e2.eannr = bvg2.ean 
                                        and e2.eanid = (select Max(e3.eanid) 
                                                                   from   eaninfo e3 
                                                                   where  e3.eannr = bvg2.ean) 
                                  where  b2.datotid > @fradato 
                                        and b2.datotid < @tildato 
                                        and b.bongid = b2.bongid 
                                        and bvg.ean = bvg2.ean 
                                  group by 
                                        b2.bongid
                                        , bvg2.ean
                                        , b2.utsalgsstednr
                                        , e2.underavdelingsnr 
                                  having sum(bvg2.verdi1) >= 100) 
       group by 
             b.utsalgsstednr
             , e.underavdelingsnr 

       select ---§§§ SQLNR 1153 FG Gammel G23
             k.utsalgsstednr
             ,null as avdelingsnr
             , 7322 as debetkontonr
             , sum(k.omsetning) as debetbeloep
             , null as kreditkontonr
             , null as kreditbeloep
             , cast(0 as DECIMAL(15, 3)) as mvaprosent
             , cast('Garanti' as VARCHAR(7)) as fritekst1
             , null as fritekst2
             , cast('38' as VARCHAR(2)) as fritekst3 
       from kundegarantisalgdag K 
       where dato = @dato
             and garantinr IN ( 23, 24 ) 
             and regelnr = 5 
       group  by 
             k.utsalgsstednr 

end
GO
