/**
Steps:

1. Create a database named db_{yourfirstname}

2. Create Customer table with at least the following columns: (1/2 mark)

ID INT NOT NULL

CustomerID INT NOT NULL

FirstName Nvarchar(50 ) NOT NULL

LastName Nvarchar(50) NOT NULL

3. Create Orders table as follows: (1/2 mark) 

OrderID INT Not NULL

CustomerID INT NOT NULL

OrderDate datetime Not NULL

4. Use triggers to impose the following constraints (4 marks)

a)A Customer with Orders cannot be deleted from Customer table. 

b)Create a custom error and use Raiserror to notify when delete Customer with Orders fails.

c)If CustomerID is updated in Customers, referencing rows in Orders must be updated accordingly.

d)Updating and Insertion of rows in Orders table must verify that CustomerID exists in Customer table, otherwise Raiserror to notify.

5. Create a scalar function named fn_CheckName(@FirstName, @LastName) to check that the FirstName and LastName are not the same. (2 marks)

6. Create a stored procedure called sp_InsertCustomer that would take Firstname and Lastname and optional CustomerID as parameters and Insert into Customer table.

a) If CustomerID is not provided, increment the last CustomerID and use that.

b) Use the fn_CheckName function to verify that the customer name is correct. Do not insert record if verification fails. (4 marks) 

7. Log all updates to Customer table to CusAudit table. Indicate the previous and new values of data, the date and time and the login name of the person who made the changes. (4 marks) 
*/

CREATE DATABASE db_AbdulMoizRaza;


USE db_AbdulMoizRaza;

CREATE TABLE dbo.Customer(
	ID INT IDENTITY(1,1) NOT NULL,
	CustomerID INT PRIMARY KEY CLUSTERED NOT NULL,
	FirstName NVARCHAR(50) NOT NULL,
	LastName NVARCHAR(50) NOT NULL,
);
GO;
CREATE TABLE dbo.Orders(
	OrderID INT PRIMARY KEY CLUSTERED NOT NULL,
	CustomerID INT NOT NULL ,
	OrderDate DateTime NOT NULL,
	FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID),
);
GO;
CREATE OR ALTER TRIGGER [dbo].[T_DeleteCustomerTable]
ON [dbo].[Customer]
INSTEAD OF DELETE
AS
BEGIN
	if exists(Select * from [dbo].Orders where CustomerID IN (Select CustomerID from deleted))
	BEGIN
		RAISERROR(50001,16,1);
		RETURN;
	END
	
	DELETE FROM [dbo].[Customer] WHERE CustomerID IN (Select CustomerID from deleted);
END
GO;
EXEC sp_addmessage @msgnum = 50001, 
                   @severity = 16, 
                   @msgtext = 'Cannot delete customer because they have some orders.', 
                   @lang = 'us_english';
GO;
/**
Test Code
INSERT INTO [dbo].[Customer] 
VALUES (1,'John','Kim');
INSERT INTO [dbo].[Customer] 
VALUES (2,'ABC','DEF');
Select * from [dbo].[Customer];
Select * from [dbo].[Orders];

INSERT INTO [dbo].[Orders] 
VALUES (1,1,GETDATE());


DELETE FROM [dbo].[Customer] WHERE CustomerID = 1; // Error
DELETE FROM [dbo].[Customer] WHERE CustomerID = 2;
*/

CREATE OR ALTER TRIGGER [dbo].[T_UpdateCustomerTable]
ON [dbo].[Customer]
AFTER UPDATE
AS
BEGIN
	if exists(Select * from [dbo].Orders where CustomerID IN (Select CustomerID from deleted))
	BEGIN
		DECLARE @OldCustID INT;
		DECLARE @NewCustID INT;
		SELECT TOP 1 @OldCustID = CustomerID FROM deleted;
		SELECT TOP 1 @NewCustID = CustomerID FROM inserted;
		UPDATE [dbo].Orders 
		SET CustomerID = @NewCustID 
		WHERE CustomerID = @OldCustID;
	END
END
GO;
/*
Test Code
SELECT * FROM [dbo].[Orders]; 
SELECT * FROM [dbo].[Customer]; 
DELETE FROM [dbo].[Orders];
INSERT INTO [dbo].[Orders] 
VALUES (2,3,GETDATE());



ALTER TABLE [dbo].[Orders] NOCHECK CONSTRAINT FK__Orders__Customer__38996AB5;
DROP TRIGGER [dbo].[T_InsertOrderTable];
UPDATE [dbo].[Customer]
SET CustomerID = 2
WHERE CustomerID = 5

ALTER TABLE [dbo].[Orders] CHECK CONSTRAINT FK__Orders__Customer__38996AB5;
*/

CREATE OR ALTER TRIGGER [dbo].[T_InsertOrderTable]
ON [dbo].[Orders]
AFTER UPDATE,INSERT
AS
BEGIN
	if not exists(Select * from [dbo].Customer where CustomerID in (Select CustomerID from inserted))
	BEGIN
		RAISERROR('Valid CustomerID value is missing in the updated row.', 16, 1);
		ROLLBACK TRANSACTION;
		RETURN;
	END
END
GO
/*
Test Code
SELECT * FROM [dbo].[Orders]; 
SELECT * FROM [dbo].[Customer]; 
UPDATE [dbo].[Orders]
SET CustomerID = 5
WHERE CustomerID = 1

INSERT INTO [dbo].[Orders] 
VALUES (3,5,GETDATE());

*/

Create Function fn_CheckName
(
   @FirstName NVARCHAR(50),
   @LastName NVARCHAR(50)
)
RETURNS BIT
AS
BEGIN
	IF @FirstName = @LastName
		RETURN 0
	RETURN 1
END
GO;
/*

Print 'FNCHECKNAME IS ' + cast (dbo.fn_CheckName('ABC','def') as nvarchar(10))
INSERT INTO [dbo].[Customer] 
VALUES (3,'ABC','DEF');

SELECT CustomerID from [dbo].[Customer] where ID IN (Select MAX(ID) from [dbo].[Customer]); 
SELECT * FROM [dbo].[Customer]; 
*/

CREATE OR ALTER PROC dbo.sp_InsertCustomer
	@FirstName NVARCHAR(50),
	@LastName NVARCHAR(50),
	@CustomerID INT = NULL
AS
	IF @CustomerID IS NULL
		BEGIN
			SELECT @CustomerID = 1 + CustomerID from [dbo].[Customer] where ID IN (Select MAX(ID) from [dbo].[Customer]); 
		END
	IF dbo.fn_CheckName(@FirstName,@LastName) = 1
		INSERT INTO [dbo].[Customer] 
		VALUES (@CustomerID,@FirstName,@LastName);
	ELSE
		RAISERROR('FirstName and LastName should not be same',16,1);
GO

/*
SELECT * FROM [dbo].[Customer]; 

EXECUTE dbo.sp_InsertCustomer @FirstName=N'Moiz',@LastName=N'Bhutta'
*/

CREATE TABLE CusAudit (
    AuditID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    OldFirstName NVARCHAR(50) NOT NULL,
    OldLastName NVARCHAR(50) NOT NULL,
    NewFirstName NVARCHAR(50) NULL,
    NewLastName NVARCHAR(50) NULL,
    ChangeDateTime DATETIME NOT NULL,
    ChangedBy NVARCHAR(MAX) NOT NULL
);
GO

CREATE OR ALTER TRIGGER InsertOrUpdateCustLog
ON [dbo].[Customer]
AFTER UPDATE
AS
	INSERT INTO [dbo].[CusAudit](CustomerID,OldFirstName,OldLastName,NewFirstName,NewLastName,ChangeDateTime,ChangedBy)
	SELECT 
		OLD.CustomerID,
		OLD.FirstName AS OldFirstName,
		OLD.LastName AS OldLastName,
		NEW.FirstName AS NewFirstName,
		NEW.LastName AS NewLastName,
		GETDATE() AS ChangeDateTime,
		SUSER_NAME() AS ChangedBy
	FROM INSERTED AS NEW
	JOIN DELETED AS OLD ON New.CustomerID = Old.CustomerID;
GO

/*
SELECT * FROM [dbo].[Customer];
SELECT * FROM [dbo].[CusAudit];

UPDATE [dbo].[Customer]
SET FirstName = 'Abdul Moiz Raza',
LastName = 'Bhutta'
WHERE CustomerID = 6
*/