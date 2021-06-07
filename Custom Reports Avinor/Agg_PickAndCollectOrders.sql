USE [BI_Mart]
GO

/****** Object:  Table [CBIM].[Agg_PickAndCollectOrders]    Script Date: 15.08.2019 11:47:09 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [CBIM].[Agg_PickAndCollectOrders](
	[OrderID] [varchar](50) NOT NULL,
	[StoreId] [int] NULL,
	[CollectStartTime] [datetime] NOT NULL,
	[CollectEndTime] [datetime] NOT NULL,
	[ActualAmount] [smallmoney] NULL,
	[OrderStatus] [smallint] NOT NULL,
	[FlightNumber] [varchar](50) NOT NULL,
	[FlightDirection] [varchar](50) NOT NULL,
	[PaymentSuccessTimeStamp] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[OrderID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

