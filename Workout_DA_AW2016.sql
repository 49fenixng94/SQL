-- Please run below three lines to drop temp tables from the record (If you cannot run the below code as a whole!)--
Drop Table ##base
Drop Table ##Sum1_Result
Drop Table ##Sum2_Result

--PART I--

SELECT * 
INTO ##base
FROM
(
	SELECT SOD.SalesOrderID, 

		-- Adjust the Calendar Year & Quarter to the "fiscal year" & "Fiscal Quarter"--
		CASE WHEN YEAR(SOH.OrderDate) = 2012 AND MONTH(SOH.OrderDate) >=1 AND MONTH(SOH.OrderDate) <=6 THEN 2011
		WHEN YEAR(SOH.OrderDate) = 2012 AND MONTH(SOH.OrderDate) >=7 AND MONTH(SOH.OrderDate) <=12 THEN 2012
		WHEN YEAR(SOH.OrderDate) = 2013 AND MONTH(SOH.OrderDate) >=1 AND MONTH(SOH.OrderDate) <=6 THEN 2012
		WHEN YEAR(SOH.OrderDate) = 2013 AND MONTH(SOH.OrderDate) >=7 AND MONTH(SOH.OrderDate) <=12 THEN 2013
		WHEN YEAR(SOH.OrderDate) = 2014 AND MONTH(SOH.OrderDate) >=1 AND MONTH(SOH.OrderDate) <=6 THEN 2013
		WHEN YEAR(SOH.OrderDate) = 2014 AND MONTH(SOH.OrderDate) >=7 AND MONTH(SOH.OrderDate) <=12 THEN 2014
		WHEN YEAR(SOH.OrderDate) = 2015 AND MONTH(SOH.OrderDate) >=1 AND MONTH(SOH.OrderDate) <=6 THEN 2014
		END AS 'FiscalYear',
		MONTH(SOH.OrderDate) AS 'OrderMonth',
		DATEPART(quarter, DATEADD(quarter, 2, SOH.OrderDate)) AS 'FiscalFQ',
		PPCAT.[Name],

		-- Separate out offline orders and online orders into two columns of "Online_Orders" & "Offline_Orders"--
		CASE WHEN SOH.OnlineOrderFlag = '1' THEN 1 ELSE 0 END AS 'Online_Orders',
		CASE WHEN SOH.OnlineOrderFlag = '0' THEN 1 ELSE 0 END AS 'Offline_Orders'
	
		--Link up all relevant database tables into this temp table as "##base"--
		FROM [AdventureWorks2016].[Sales].[SalesOrderHeader] AS SOH
		JOIN [AdventureWorks2016].[Sales].[SalesOrderDetail] AS SOD
		on SOH.SalesOrderID = SOD.SalesOrderID
		JOIN [AdventureWorks2016].[Production].[Product] AS PP
		on SOD.ProductID = PP.ProductID
		JOIN [AdventureWorks2016].[Production].[ProductSubcategory] AS PPSUBCAT
		on PP.ProductSubcategoryID = PPSUBCAT.ProductSubcategoryID
		JOIN [AdventureWorks2016].[Production].[ProductCategory] AS PPCAT
		on PPSUBCAT.ProductCategoryID = PPCAT.ProductCategoryID

--Pick up the timeframe aligned with the Aventure Works's fiscal year 2012-2014--
WHERE SOH.OrderDate BETWEEN '2012-07-01 00:00:00:000' AND '2015-06-30 23:59:59:000') t


--Converting and summaring the sales order for Bikes, Accessories, Clothing and Components in a temp table--
SELECT [SalesOrderID], 
		[FiscalYear], 
		[FiscalFQ], 
		sum(Bikes) AS [Bikes],
		sum(Accessories) AS [Accessories],
		sum(Clothing) AS [Clothing],
		sum(Components) AS [Components],
		[Offline_Orders], 
		[Online_Orders]

INTO ##Sum1_Result
FROM
(
SELECT distinct [SalesOrderID], [FiscalYear], [FiscalFQ], 
CASE WHEN [Name]='Bikes' then 1 ELSE 0 end as [Bikes]
,CASE WHEN [Name]='Accessories' then  1 ELSE 0 end as [Accessories]
,CASE WHEN [Name]='Clothing' then 1 ELSE 0 end as [Clothing]
,CASE WHEN [Name]='Components' then 1 ELSE 0 end as [Components]
,[Offline_Orders], [Online_Orders]

FROM ##base
) t2
GROUP BY [SalesOrderID], [FiscalYear], [FiscalFQ],[Offline_Orders], [Online_Orders]

--Summing up the online & offline orders of each product mix--
SELECT  [FiscalYear],
		[FiscalFQ], 
		[Bikes], 
		[Accessories], 
		[Clothing], 
		[Components],
		sum(Offline_Orders) as [T_Offline_Orders],
		sum(Online_Orders) as [T_Online_Orders]

INTO ##Sum2_Result
FROM 
(
SELECT*
FROM ##Sum1_Result
) t3
GROUP By FiscalYear, FiscalFQ, Bikes, Accessories, Clothing, Components


--PART II--
--Calculating the percentage of orders for each product mix within each financial quarter of financial year--
SELECT  [FiscalYear],
		[FiscalFQ], 
		[Bikes], 
		[Accessories], 
		[Clothing], 
		[Components],
		[T_Offline_Orders],
		[T_Online_Orders],
		CONCAT(CAST([T_Offline_Orders]*1.0/SUM(T_Offline_Orders) OVER(PARTITION BY [FiscalFQ], [FiscalYear])*100 AS decimal(5,2)),'%') AS 'Percentage_Of_Offline_Orders',
		CONCAT(CAST([T_Online_Orders]*1.0/SUM(T_Online_Orders) OVER(PARTITION BY [FiscalFQ], [FiscalYear])*100 AS decimal(5,2)),'%') AS 'Percentage_Of_Online_Orders'

FROM ##Sum2_Result

GROUP BY FiscalYear, FiscalFQ, Bikes, Accessories, Clothing, Components, T_Offline_Orders, T_Online_Orders
Order by FiscalYear