
# Getting the data from Ikea database -------------------------------------

con <- DBI::dbConnect(odbc::odbc(),
                      Driver = "Teradata",
                      DBCName = "10.182.0.4",
                      UID    = rstudioapi::askForPassword("Database user"),
                      PWD    = rstudioapi::askForPassword("Database password"))

#dbListTables(con)

kitchen <- dbReadTable(con, "CustomerCommunication")
send_info <- dbReadTable(con, "SendQueue")
com_status <- dbReadTable(con, "CommunicationStatus")
com_type <- dbReadTable(con, "CommunicationType")
openers_clickers_any <- dbGetQuery(con, "select distinct cc.*,
                                   a.*
                                     from NYP.dbo.CustomerCommunication cc
                                   left join NYP.dbo.SendQueue sq on cc.Id_CustomerCommunication = sq.Id_CustomerCommunication
                                   left join DWH.dbo.VF_ApsisAll a ON cc.Id_Customer = a.Id_Customer
                                   where cc.StartDate >= '2017-12-01'
                                   and (sq.Id_CommunicationType in (3,5) and sq.Id_CommunicationStatus = 3)
                                   and a.DateAndTime >= sq.SendDate
                                   and a.NewsletterID in (4058375, 4812672, 4978041, 4978044, 4066991, 3982640)")

openers_clickers <- openers_clickers_any %>%
  filter(Id_Newsletter %in% c(4978041,4066991,3982640,4812672,4978044,4058375))

#budget takea a really long time, maybe better to upload several vcsv files split by months
budget <- dbGetQuery(con, "SELECT 
                     CAST(ti.[TransactionTime] AS date) as BusinessDay,
                     currency.CurrencyCode,
                     ti.Id_Customer,
                     t.Id_LoyaltyCard,
                     t.Id_BusinessKind,
                     SUM(ti.NetAmount) AS Net_Amount,
                     SUM(CASE WHEN hfb.HFB = 7 AND ti.NetAmount >= 0 THEN ti.NetAmount ELSE 0 END) as HFB_7,
                     SUM(CASE WHEN hfb.HFB = 8 AND ti.NetAmount >= 0 THEN ti.NetAmount ELSE 0 END) as HFB_8,
                     SUM(CASE WHEN hfb.HFB = 14 AND ti.NetAmount >= 0 THEN ti.NetAmount ELSE 0 END) as HFB_14,
                     SUM(CASE WHEN hfb.HFB = 15 AND ti.NetAmount >= 0 THEN ti.NetAmount ELSE 0 END) as HFB_15  
                     FROM DWH.[dbo].[V_TF_TransactionItem_Final] AS ti
                     JOIN DWH.dbo.V_TF_Transaction_Final AS t ON ti.[Id_Transaction] = t.[Id_Transaction]
                     LEFT JOIN DWH.[dbo].[VD_Product] AS p ON p.[Id_Product] = ti.Id_Product
                     LEFT JOIN DWH.[dbo].[VD_ProductArea] AS pa ON p.Id_ProductArea = pa.Id_ProductArea
                     LEFT JOIN DWH.dbo.VD_Currency AS currency ON currency.Id_Currency = t.Id_Currency
                     LEFT JOIN DWH.Trn.VF_Transaction td ON t.Id_Transaction = td.Id_Transaction
                     LEFT JOIN DWH.dbo.VD_HFB hfb ON pa.Id_HFB = hfb.Id_HFB
                     LEFT JOIN DWH.dbo.VD_Customer AS c ON c.Id_Customer = ti.Id_Customer
                     WHERE 
                     ti.[TransactionTime] >= '2017-12-20'
                     AND ti.[TransactionTime] < '2018-08-23'
                     AND t.Id_SourceSystem = 3
                     AND t.Id_TransactionStatus = 1
                     AND td.IsCancelled = 0
                     AND td.IsFinalTransaction = 1
                     AND t.NetAmount > 0
                     AND c.Id_Country in (119, 264, 162)
                     GROUP BY 
                     CAST(ti.[TransactionTime] AS date),
                     currency.CurrencyCode,
                     ti.Id_Customer,
                     ti.Id_Customer,
                     t.Id_LoyaltyCard,
                     t.Id_BusinessKind")

for_time <- dbGetQuery(con, "SELECT 
    CAST(ti.[TransactionTime] AS date) as BusinessDay,
	currency.CurrencyCode,
	ti.Id_Customer,
    DATEPART(HOUR,ti.[TransactionTime]) as hour,
	c.Id_Country,
    SUM(ti.NetAmount) AS Net_Amount
  FROM DWH.[dbo].[V_TF_TransactionItem_Final] AS ti
  JOIN DWH.dbo.V_TF_Transaction_Final AS t ON ti.[Id_Transaction] = t.[Id_Transaction]
  LEFT JOIN DWH.[dbo].[VD_Product] AS p ON p.[Id_Product] = ti.Id_Product
  LEFT JOIN DWH.[dbo].[VD_ProductArea] AS pa ON p.Id_ProductArea = pa.Id_ProductArea
  LEFT JOIN DWH.dbo.VD_Currency AS currency ON currency.Id_Currency = t.Id_Currency
  LEFT JOIN DWH.Trn.VF_Transaction td ON t.Id_Transaction = td.Id_Transaction
  LEFT JOIN DWH.dbo.VD_HFB hfb ON pa.Id_HFB = hfb.Id_HFB
  LEFT JOIN DWH.dbo.VD_Customer AS c ON c.Id_Customer = ti.Id_Customer
 WHERE 
	ti.[TransactionTime] >= '2018-07-01'
	AND ti.[TransactionTime] < '2018-08-01'
	AND t.Id_SourceSystem = 3
	AND t.Id_TransactionStatus = 1
    AND td.IsCancelled = 0
    AND td.IsFinalTransaction = 1
    AND t.NetAmount > 0
	AND c.Id_Country in (119, 264, 162)
	AND hfb.HFB in (7,8,14,15)
GROUP BY 
	CAST(ti.[TransactionTime] AS date),
	currency.CurrencyCode,
	ti.Id_Customer,
    DATEPART(HOUR,ti.[TransactionTime]),
	c.Id_Country")

dbDisconnect(con)


# Cleaning the data and changing structure --------------------------------

#adding names to send_info

send_info_names <- send_info %>%
  left_join(com_status, by = "Id_CommunicationStatus") %>%
  left_join(com_type, by = "Id_CommunicationType")

str(send_info_names)

send_info_names %>%
  group_by(Id_CommunicationType, CommunicationType) %>%
  summarize(n = n())

#change the structure of sendqueue table to have all relevant dates

sendqueue <- send_info_names %>%
  filter(SendDate >= ymd('2017-12-01') &
           Id_CommunicationStatus %in% c(3, 5))

#check if only distinct communication flows left

sendqueue %>%
  summarize(all = n(),
            customercommunication = n_distinct(Id_CustomerCommunication))

check <- sendqueue %>%
  group_by(Id_CustomerCommunication) %>%
  summarize(n = n_distinct(Id_CommunicationStatus)) %>%
  filter(n > 1)

#remove customers which are moving from one Control Group to Sent

remove <- sendqueue %>%
  group_by(Id_CustomerCommunication) %>%
  summarize(n = n_distinct(Id_CommunicationStatus)) %>%
  filter(n > 1)

sendqueue_filtered <- sendqueue %>%
  filter(!(Id_CustomerCommunication %in% remove$Id_CustomerCommunication))

sendqueue_spread <- sendqueue_filtered %>%
  select(Id_CustomerCommunication, CommunicationType, CommunicationStatus, SendDate) %>%
  unique() %>%
  group_by(Id_CustomerCommunication, CommunicationType, CommunicationStatus) %>%
  summarize(SendDate = max(SendDate)) %>%
  spread(CommunicationType, SendDate) %>%
  select(Id_CustomerCommunication, CommunicationStatus, Feedback, CrossSell, CaringFirst, CrossSell2, CaringSecond) %>%
  unique() %>%
  group_by(Id_CustomerCommunication, CommunicationStatus) %>%
  summarize(Feedback = max(Feedback, na.rm = TRUE),
            CrossSell = max(CrossSell, na.rm = TRUE),
            CaringFirst = max(CaringFirst, na.rm = TRUE),
            CrossSell2 = max(CrossSell2, na.rm = TRUE),
            CaringSecond = max(CaringSecond, na.rm = TRUE)) %>%
  ungroup() %>%
  unique()

str(sendqueue_spread)

str(sendqueue)
summary(sendqueue)

sendqueue_spread %>%
  summarize(all = n(),
            customercommunication = n_distinct(Id_CustomerCommunication))

# adding values of when the kitchen was bought and net revenue

main <- sendqueue_spread %>%
  left_join(kitchen, by = "Id_CustomerCommunication") %>%
  left_join(budget, by = "Id_Customer")

str(main)

# adjusting start date to have an actual one
unique(main$CurrencyCode)

check <- main %>%
  filter(is.na(main$CurrencyCode))

main <- main %>%
  mutate(start_adj = StartDate + 8)
