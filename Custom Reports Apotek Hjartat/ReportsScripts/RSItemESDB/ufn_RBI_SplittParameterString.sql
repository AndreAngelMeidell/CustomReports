USE RSItemESDb
GO

If exists (select * from INFORMATION_SCHEMA.ROUTINES r where r.ROUTINE_NAME = 'ufn_RBI_SplittParameterString')
drop function [ufn_RBI_SplittParameterString]
GO


CREATE FUNCTION [dbo].[ufn_RBI_SplittParameterString]
(
   @ParametersList      VARCHAR(Max),
   @Delimiter           VARCHAR(1)
)
RETURNS @output TABLE (ParameterValue VARCHAR(Max))
BEGIN 
    DECLARE @start INT, @end INT 
    SELECT @start = 1, @end = CHARINDEX(@delimiter,@ParametersList) 
    WHILE @start < LEN(@ParametersList) + 1 BEGIN 
        IF @end = 0  
            SET @end = LEN(@ParametersList) + 1
       
        INSERT INTO @output (ParameterValue)  
        VALUES(SUBSTRING(@ParametersList, @start, @end - @start)) 
        SET @start = @end + 1 
        SET @end = CHARINDEX(@delimiter, @ParametersList, @start)
        
    END 
    RETURN 
END


GO

