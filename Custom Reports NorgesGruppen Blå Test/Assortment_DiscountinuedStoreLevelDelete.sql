USE [msdb]
GO

/****** Object:  Job [Assortment_DiscountinuedStoreLevelDelete]    Script Date: 14.04.2021 11:02:53 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 14.04.2021 11:02:53 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Assortment_DiscountinuedStoreLevelDelete', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This job finds all assortments on store level that has been modified since last job run that is discontinued AND has an active assortment on StoreGroup level, and sets them to status deleted.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [DoTheJob]    Script Date: 14.04.2021 11:02:53 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DoTheJob', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'SET QUOTED_IDENTIFIER ON

DECLARE @job_id binary(16)
DECLARE @lastJobRun DATETIME
SELECT @job_id = job_id FROM msdb.dbo.sysjobs WHERE (name = N''Assortment_DiscountinuedStoreLevelDelete'')

SET @lastJobRun = (
SELECT TOP 1 CONVERT(DATETIME, RTRIM(run_date))
    + ((run_time / 10000 * 3600) 
    + ((run_time % 10000) / 100 * 60) 
    + (run_time % 10000) % 100) / (86399.9964) AS run_datetime
FROM
    msdb..sysjobhistory sjh
WHERE
    sjh.step_id = 0 
    AND sjh.run_status = 1 
    AND sjh.job_id = @job_id
ORDER BY
    run_datetime DESC)

SET @lastJobRun = ISNULL(@lastJobRun, ''1900-01-01 01:01:01.000'')

CREATE TABLE #StoreAssortmentProfiles (
		AssortmentProfileNo INT NOT NULL,
		ParentAssortmentProfileNo INT NOT NULL
		);
CREATE TABLE #DiscontinuedArticles (
		AssortmentProfileArticleNo INT NOT NULL,
		AssortmentProfileNo INT NOT NULL,
		ParentAssortmentProfileNo INT NOT NULL,
		ArticleNo INT NOT NULL
		);
CREATE TABLE #DiscontinuedArticlesWithActiveStoreGroup1 (
		AssortmentProfileArticleNo INT NOT NULL,
		AssortmentProfileNo INT NOT NULL,
		ParentAssortmentProfileNo INT NOT NULL,
		ArticleNo INT NOT NULL
		);
		
INSERT INTO #StoreAssortmentProfiles (AssortmentProfileNo, ParentAssortmentProfileNo)
SELECT AssortmentProfileNo, ParentAssortmentProfileNo FROM dbo.AssortmentProfiles WHERE AssortmentProfileDescription = ''StoreGroupLink''

INSERT INTO #DiscontinuedArticles ( AssortmentProfileArticleNo, AssortmentProfileNo, ParentAssortmentProfileNo, ArticleNo )
SELECT apa.AssortmentProfileArticleNo, apa.AssortmentProfileNo, sap.ParentAssortmentProfileNo, apa.ArticleNo FROM dbo.AssortmentProfileArticles apa
INNER JOIN #StoreAssortmentProfiles sap ON sap.AssortmentProfileNo = apa.AssortmentProfileNo
WHERE apa.AssortmentProfileArticleStatusNo = 8 AND apa.ModifiedDate > @lastJobRun 

INSERT INTO #DiscontinuedArticlesWithActiveStoreGroup1 ( AssortmentProfileArticleNo, AssortmentProfileNo, ParentAssortmentProfileNo, ArticleNo )
SELECT da.AssortmentProfileArticleNo, da.AssortmentProfileNo, da.ParentAssortmentProfileNo, da.ArticleNo FROM dbo.AssortmentProfileArticles apa
INNER JOIN #DiscontinuedArticles da ON da.ArticleNo = apa.ArticleNo
WHERE apa.AssortmentProfileNo = da.ParentAssortmentProfileNo AND apa.AssortmentProfileArticleStatusNo = 1 AND apa.IsMandatory = 1

UPDATE dbo.AssortmentProfileArticles
SET AssortmentProfileArticleStatusNo = 9, ModifiedDate = GETDATE(), ModifiedByUserId = ''SQLAgent: Assortment_DiscountinuedStoreLevelDelete''
FROM dbo.AssortmentProfileArticles apa
INNER JOIN #DiscontinuedArticlesWithActiveStoreGroup1 da ON da.AssortmentProfileArticleNo = apa.AssortmentProfileArticleNo

DROP TABLE #StoreAssortmentProfiles
DROP TABLE #DiscontinuedArticles
DROP TABLE #DiscontinuedArticlesWithActiveStoreGroup1', 
		@database_name=N'RSItemESDb', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'EveryNight_AssortmentUpdate', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20200717, 
		@active_end_date=99991231, 
		@active_start_time=21000, 
		@active_end_time=235959, 
		@schedule_uid=N'216a14cc-344e-4781-9796-7f8022806d51'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

