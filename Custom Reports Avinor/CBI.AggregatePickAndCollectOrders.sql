USE [msdb]
GO

/****** Object:  Job [CBI.AggregatePickAndCollectOrders]    Script Date: 15.08.2019 11:47:44 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 15.08.2019 11:47:44 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'CBI.AggregatePickAndCollectOrders', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'Copies recent records from DeliveryCustomerOrders table in PickAndCollectDb to CBIM.Agg_PickAndCollectOrders', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Aggregate Pick&CollectOrder with OrderLines]    Script Date: 15.08.2019 11:47:44 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Aggregate Pick&CollectOrder with OrderLines', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'USE [BI_mart]

/* Create temp orderID table with diff between DeliveryCustomerOrders and Agg_PickAndCollectOrders */
IF OBJECT_ID(''tempdb.dbo.#diff'', ''U'') IS NOT NULL
DROP TABLE #diff; 
SELECT origin.[OrderID], origin.[StoreNo]
INTO #diff
FROM [PickAndCollectDB].[dbo].[DeliveryCustomerOrders] AS origin
LEFT JOIN [BI_Mart].[CBIM].[Agg_PickAndCollectOrders] AS destination
ON origin.OrderID = destination.OrderID
WHERE destination.OrderID IS NULL

/* Insert into aggregation order table the orders present in #diff */
INSERT INTO [CBIM].[Agg_PickAndCollectOrders]
	SELECT  dco.OrderID, dco.StoreNo AS StoreId, dco.CollectStartTime, dco.CollectEndTime, dco.ActualAmount, dco.OrderStatus, 
            ei1.[Value] AS FlightNumber, ei2.[Value] AS FlightDirection, 
            ct.RecordCreated AS PaymentSuccessTimeStamp 
	FROM [PickAndCollectDB].[dbo].DeliveryCustomerOrders dco
	
	INNER JOIN [PickAndCollectDB].[dbo].DeliveryCustomerOrderExtraInfos ei1	
	ON dco.CustomerOrderNo = ei1.CustomerOrderNo  INNER JOIN [PickAndCollectDB].[dbo].[DeliveryCustomerOrderExtraInfos] ei2
	ON ei1.CustomerOrderNo = ei2.CustomerOrderNo AND ei2.[Key] = ''FlightDirection'' AND ei2.CustomerOrderLineNo IS NULL
	INNER JOIN #diff ON #diff.OrderID = dco.OrderID
	INNER JOIN [PickAndCollectDB].[dbo].DeliveryCustomerOrderChangeTracking ct
    ON dco.CustomerOrderNo = ct.CustomerOrderNo AND ct.OrderStatus = 60
	WHERE ei1.[Key] = ''FlightNumber'' AND ei1.CustomerOrderLineNo IS NULL AND dco.OrderStatus >= 55 AND dco.OrderStatus != 58	

/* Insert into aggregation order line table the orders present in #diff */    	
INSERT INTO [CBIM].[Agg_PickAndCollectOrderLines]
	SELECT dcol.CustomerOrderLineNo, dco.OrderID, dcol.ArticleEan, dcol.ReceivedQty, dcol.ArticleDeliveredPrice
	FROM [PickAndCollectDB].[dbo].DeliveryCustomerOrderLines dcol
	
	INNER JOIN [CBIM].[Agg_PickAndCollectOrders] dco ON dco.OrderID = dcol.CustomerOrderNo
	INNER JOIN #diff ON #diff.OrderID = dcol.CustomerOrderNo', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'AggregatePickAndCollectOrdersSchedule', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=20, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20170106, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'b03c08da-694d-4ea6-b192-ec0d7fa90080'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO

