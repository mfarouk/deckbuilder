DECLARE 
      @i int = 0, 
      @od Sales.SalesOrderDetailType_ondisk, 
      @SalesOrderID int, 
      @DueDate datetime2 = dateadd(month,1,sysdatetime()), 
      @CustomerID int = rand() * 8000, 
      @BillToAddressID int = rand() * 10000, 
      @ShipToAddressID int = rand() * 10000, 
      @ShipMethodID int = (rand() * 5) + 1; 

INSERT INTO @od 
SELECT OrderQty, ProductID, SpecialOfferID 
FROM Demo.DemoSalesOrderDetailSeed 
WHERE OrderID= cast((rand()*106) + 1 as int); 

WHILE (@i < 20) 
BEGIN; 
      EXEC Sales.usp_InsertSalesOrder_ondisk @SalesOrderID OUTPUT, @DueDate, @CustomerID, @BillToAddressID, @ShipToAddressID, @ShipMethodID, @od; 
      SET @i += 1 
END
