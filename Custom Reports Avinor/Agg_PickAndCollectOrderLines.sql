USE [BI_Mart]
GO

/****** Object:  Table [CBIM].[Agg_PickAndCollectOrderLines]    Script Date: 15.08.2019 11:46:49 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [CBIM].[Agg_PickAndCollectOrderLines](
	[OrderLineID] [int] NOT NULL,
	[OrderID] [varchar](50) NOT NULL,
	[ArticleEan] [varchar](50) NULL,
	[ReceivedQty] [float] NULL,
	[ArticleDeliveredPrice] [smallmoney] NULL,
PRIMARY KEY CLUSTERED 
(
	[OrderLineID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO

ALTER TABLE [CBIM].[Agg_PickAndCollectOrderLines]  WITH CHECK ADD FOREIGN KEY([OrderID])
REFERENCES [CBIM].[Agg_PickAndCollectOrders] ([OrderID])
GO

