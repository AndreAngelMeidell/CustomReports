USE [msdb]
GO

/****** Object:  Job [CBI_GenusReportWastageAndReturn_MENY_MND]    Script Date: 24.11.2020 17:41:32 ******/
EXEC msdb.dbo.sp_delete_job @job_id=N'cc7188cb-b156-46af-b327-4d4e381ce7db', @delete_unused_schedule=1
GO

/****** Object:  Job [CBI_GenusReportWastageAndReturn_MENY_MND]    Script Date: 24.11.2020 17:41:32 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 24.11.2020 17:41:33 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'CBI_GenusReportWastageAndReturn_MENY_MND', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'RSAdmin', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Month - executes the Sp only the 7'th]    Script Date: 24.11.2020 17:41:33 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Month - executes the Sp only the 7''th', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'--Week report
USE VRNOMisc
GO
SET ROWCOUNT 0
SET NOCOUNT ON

DECLARE @ReportTypeId AS INT = dbo.GetReportTypeWasteReturn()
DECLARE @ChainCodeId AS INT = dbo.GetChainCodeIdMeny()
DECLARE @DateParam AS DATE
DECLARE @FirstDayInPeriod as DATE
DECLARE @LastDayInPeriod as DATE

print ''Date for this report: ToDay, first, last''

SET @DateParam = GETDATE()
print @DateParam

SET @FirstDayInPeriod = (SELECT MIN(FullDate) FROM  BI_Mart.RBIM.Dim_Date WHERE RelativeMonth=-1)
PRINT @FirstDayInPeriod

SET @LastDayInPeriod = (SELECT max(FullDate) FROM  BI_Mart.RBIM.Dim_Date WHERE RelativeMonth=-1)
PRINT @LastDayInPeriod

EXEC usp_CBI_GenusReportsMain
        @ReportTypeId,
        @ChainCodeId,
        @DateParam,
        @FirstDayInPeriod,
        @LastDayInPeriod
', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Monthly - executes the SP only on the 7''th', 
		@enabled=1, 
		@freq_type=16, 
		@freq_interval=7, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20170103, 
		@active_end_date=99991231, 
		@active_start_time=23002, 
		@active_end_time=235959, 
		@schedule_uid=N'521d0d8c-06c2-443a-83ed-6e88d2d64d76'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

