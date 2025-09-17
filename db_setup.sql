
-- creating db
if not exists( select 1 from master..sysdatabases b where b.[name] = N'jpk_wb_ssis')
	create database jpk_wb_ssis
go

use jpk_wb_ssis
go

-- create tables
if not exists ( select 1 from sysobjects o where o.[name] = N'Header_Staging'  and (objectproperty(o.[id], N'IsUserTable')=1))
	CREATE TABLE [dbo].[Header_Staging] (
	[Entity] nvarchar(10),
	[Account_Number] nvarchar(34),
	[For_Month] nvarchar(6),
	[Currency_Code] nvarchar(3),
	[Opening_Balance] nvarchar(30),
	[Closing_Balance] nvarchar(30)
	)
GO

if not exists ( select 1 from sysobjects o where o.[name] = N'Item_Staging'  and (objectproperty(o.[id], N'IsUserTable')=1))
	CREATE TABLE [dbo].[Item_Staging] (
		[Entity] nvarchar(10),
		[Account_Number] nvarchar(34),
		[For_Month] nvarchar(6),
		[Date] nvarchar(10),
		[Transaction_Party] nvarchar(200),
		[Description] nvarchar(200),
		[Amount] nvarchar(30),
		[Balance] nvarchar(30)
	)
go

if not exists ( select 1 from sysobjects o where o.[name] = N'Error_Log' and (objectproperty(o.[id],N'IsUserTable')=1))
	CREATE TABLE [dbo].[Error_Log] (
			Error_Id	int NOT NULL IDENTITY CONSTRAINT PK_err_log PRIMARY KEY
		,	Module nvarchar(50) not null
		,	Err_Description nvarchar(200) NOT NULL
		,	Username nvarchar(50) NOT NULL DEFAULT USER_NAME()
		,	SUsername nvarchar(50) NOT NULL DEFAULT SUSER_NAME()
		,	Hostname nvarchar(50) NOT NULL DEFAULT HOST_NAME()
		,	Time_stamp datetime NOT NULL DEFAULT GETDATE()
	)
go

--dictionary for Tax Offices
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'Tax_Office' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1))
BEGIN
    CREATE TABLE dbo.Tax_Office (
			[Tax_Office_Code]		NCHAR(4)		NOT NULL PRIMARY KEY 
        ,	[Tax_Office_Name]		NVARCHAR(100)	NOT NULL 
        ,	[Tax_Office_Address]	NVARCHAR(255)	NOT NULL 
        ,	[City]					NVARCHAR(40)	NOT NULL 
        ,	[Postal_Code]			NCHAR(6)		NOT NULL 
    );
END
GO

--dictionary for currency codes
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name]  = 'Currency_Code' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1))
BEGIN
	CREATE TABLE dbo.Currency_Code
	(	
			[Currency_Code]		NCHAR(3) NOT NULL CONSTRAINT PK_currency_code PRIMARY KEY
		,	[Currency_Name]		NVARCHAR(50) NOT NULL
	) 
END
GO
 
--Entity would need to be registered first
IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'Entity' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1))
	BEGIN
		CREATE TABLE dbo.Entity 
		(	
			[Entity_Identifier]	NCHAR(10)		NOT NULL CONSTRAINT PK_entity_id PRIMARY KEY
		,	[Entity_Name]		NVARCHAR(100)	NOT NULL
		,	[Vat_Id]				NVARCHAR(20)	NOT NULL
		,	[Country_Code]      NCHAR(2)		NOT NULL
		,	[Country]			NVARCHAR(40)	NOT NULL
		,	[Voivodeship]       NVARCHAR(40)	NOT NULL  -- (Województwo in Poland)
		,	[District]			NVARCHAR(40)	NOT NULL  -- (Powiat in Poland)
		,	[Municipality]		NVARCHAR(40)	NOT NULL  -- (Gmina in Poland)
		,	[Street]			NVARCHAR(40)	NULL
		,	[House_Number]		NVARCHAR(10)	NOT NULL
		,	[Apartment_Number]	NVARCHAR(40)	NULL
		,	[City]				NVARCHAR(40)	NOT NULL  -- (Miejscowoœæ)
		,	[Postal_Code]		NCHAR(6)		NOT NULL
		,	[Post_Office]		NVARCHAR(40)	NOT NULL
		,	[Tax_Office_Code]   NCHAR(4)        NOT NULL
		,	CONSTRAINT FK_Tax_Office FOREIGN KEY (Tax_Office_Code) REFERENCES dbo.Tax_Office(Tax_Office_Code)
		)
	END
GO

IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'Account' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1))
BEGIN
    CREATE TABLE dbo.Account (
			[Account_Id]			INT				NOT NULL IDENTITY PRIMARY KEY
		,	[Account_Number]		NVARCHAR(34)	NOT NULL
		,	[Entity_Id]				NCHAR(10)		NOT NULL
		,	[Currency_Code]			NCHAR(3)		NOT NULL
		,	CONSTRAINT FK_Entity FOREIGN KEY ([Entity_Id]) REFERENCES dbo.Entity(Entity_Identifier)
		,	CONSTRAINT FK_Currency FOREIGN KEY ([Currency_Code]) REFERENCES dbo.Currency_Code(Currency_Code)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sysobjects WHERE name = 'Transaction_Party' AND OBJECTPROPERTY([ID], 'IsUserTable') = 1)
BEGIN
    CREATE TABLE dbo.Transaction_Party (
        [Transaction_Party_Id] INT NOT NULL IDENTITY PRIMARY KEY,
        [Party_Name] NVARCHAR(200) NOT NULL UNIQUE
    );
END
GO


IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'Header' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1))
BEGIN
    CREATE TABLE dbo.Header (
			[Header_Id]			INT				NOT NULL IDENTITY PRIMARY KEY
		,	[Account_Id]		INT				NOT NULL
		,	[Month]				NCHAR(6)		NOT NULL
		,	[Opening_Balance]	DECIMAL(18, 2)	NOT NULL
		,	[Closing_Balance]	DECIMAL(18, 2)	NOT NULL
		,CONSTRAINT FK_Account_Header FOREIGN KEY (Account_Id) REFERENCES dbo.Account(Account_Id)
    );
END
GO

IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'Item_Line' AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1))
BEGIN
    CREATE TABLE dbo.Item_Line (
			[Item_Line_Id]			INT NOT NULL IDENTITY PRIMARY KEY
		,	[Header_Id]				INT NOT NULL
		,   [Transaction_Party_Id]	INT NOT NULL
		,	[Transaction_Date]		DATE NOT NULL
		,	[Description]			NVARCHAR(200) NOT NULL
		,	[Amount]				DECIMAL(18, 2) NOT NULL
		,	[Balance]				DECIMAL(18, 2) NOT NULL
		,	CONSTRAINT FK_Header_Item FOREIGN KEY (Header_Id) REFERENCES dbo.Header(Header_Id)
		,	CONSTRAINT FK_Transaction_Party FOREIGN KEY (Transaction_Party_Id) REFERENCES dbo.Transaction_Party(Transaction_Party_Id)
    );
END
GO



------------------------ fill with dummy data
IF NOT EXISTS (SELECT 1 FROM dbo.Tax_Office)
BEGIN
    INSERT INTO dbo.Tax_Office (Tax_Office_Code, Tax_Office_Name, Tax_Office_Address, City, Postal_Code) VALUES 
    ('0202', 'Urz¹d Skarbowy Warszawa-Œródmieœcie', 'Szturmowa 2a', 'Warszawa', '00-000'),
    ('2403', 'Drugi Urz¹d Skarbowy Katowice', 'Szturmowa 3b', 'Katowice', '40-000'),
    ('1212', 'Urz¹d Skarbowy Kraków', 'Testowa 10', 'Kraków', '11-222');
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Currency_Code)
BEGIN
    INSERT INTO dbo.Currency_Code (Currency_Code, Currency_Name) VALUES
    ('PLN', 'Polish Zloty'),
	('USD', 'United States Dollar'),
    ('EUR', 'Euro'),
    ('GBP', 'British Pound'),
    ('JPY', 'Japanese Yen');
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Entity) BEGIN 
    INSERT INTO dbo.Entity ([Entity_Identifier], [Entity_Name], [Vat_Id], [Country_Code], [Country], [Voivodeship], [District], [Municipality], [Street], [House_Number], [Apartment_Number], [City], [Postal_Code], [Post_Office], [Tax_Office_Code]) VALUES 
    ('PL00000001', 'Example Corp', '1234563218', 'PL', 'Poland', 'Mazowieckie', 'Warszawa', 'Œródmieœcie', 'Szturmowa', '2a', null, 'Warsaw', '00-000', 'Warsaw', '0202'), 
    ('PL00000002', 'Dummy Corp', '9876543210', 'PL', 'Poland', 'Œl¹skie', 'Katowice', 'Œródmieœcie', 'Elegancka', '3b', '57', 'Katowice', '40-000', 'Katowice', '2403'), 
    ('PL00000003', 'Third Corporation', '5558887766', 'PL', 'Poland', 'Ma³opolskie', 'Kraków', 'Kraków', 'Testowa', '10', null, 'Kraków', '11-222', 'Kraków', '1212'); 
END 
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Account)
BEGIN
    INSERT INTO dbo.Account ([Account_Number], [Entity_Id], [Currency_Code])
	VALUES('PL61109010140000071219812874', 'PL00000001', 'PLN'),
	('PL27114020040000300201355387', 'PL00000001', 'EUR'),
	('PL10116022020000000234567890', 'PL00000001', 'USD'),
	('PL12345678901234567890123456789012', 'PL00000002', 'PLN'),
	('PL98347681275982357327527845', 'PL00000003', 'PLN')
END
GO


----------------PROCEDURES
if not exists ( select 1 from sysobjects o where o.[name] = N'create_empty_proc' 
and (objectproperty(o.[id],N'IsProcedure')=1))
BEGIN
	EXEC sp_sqlExec N'CREATE PROCEDURE dbo.create_empty_proc AS '
END
GO

ALTER PROCEDURE dbo.create_empty_proc (@proc_name nvarchar(100))
AS
	IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = @proc_name)
		AND		(OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1)
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE PROCEDURE dbo.' + @proc_name + N' AS '
		EXEC sp_sqlexec @sql
	END
GO

EXEC dbo.create_empty_proc @proc_name = 'create_empty_fun'
GO

ALTER PROCEDURE dbo.create_empty_fun (@fun_name nvarchar(100))
AS
	IF NOT EXISTS 
	(	SELECT 1 
		FROM sysobjects o 
		WHERE	(o.name = @fun_name)
		AND		(OBJECTPROPERTY(o.[ID], N'IsScalarFunction') = 1)
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE FUNCTION dbo.' + @fun_name + N' () returns money AS begin return 0 end '
		EXEC sp_sqlexec @sql
	END
GO

------------FUNCTIONS FOR CONVERSION
EXEC dbo.create_empty_fun 'text_to_money'
GO

ALTER FUNCTION dbo.text_to_money(@txt nvarchar(20) )
RETURNS MONEY
AS
BEGIN
	SET @txt = REPLACE(@txt, N' ', N'')

	if @txt LIKE N'%,[0-9][0-9][0-9]'
		SET @txt = REPLACE(@txt, N',','')

	IF @txt LIKE '%,%.%' 
	BEGIN
		SET @txt = REPLACE(@txt, N',', N'')
	END ELSE
	IF @txt LIKE '%.%,%'
	BEGIN
		SET @txt = REPLACE(@txt, N'.', N'')
	END
	SET @txt = REPLACE(@txt, N',', N'.')
	RETURN  CONVERT(DECIMAL(18,2), @txt)
END
GO

EXEC dbo.create_empty_fun 'text_to_date'
GO

ALTER FUNCTION dbo.text_to_date(@txt nvarchar(10) )
RETURNS DATETIME
AS
BEGIN
	IF @txt LIKE N'[1-3][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%'
		RETURN CONVERT(datetime, @txt, 112)

	SET @txt = REPLACE(@txt, N'-', N'.')
	SET @txt = REPLACE(@txt, N'/', N'.')

	IF @txt LIKE N'[1-3][0-9][0-9][0-9]_[0-9][0-9]%'
		RETURN CONVERT(datetime, @txt, 102)
	RETURN CONVERT(datetime, @txt, 104)
END
GO


--function to check is for month valid
EXEC dbo.create_empty_fun 'is_for_month_valid'
GO

ALTER FUNCTION dbo.is_for_month_valid (@for_month NVARCHAR(6))
RETURNS BIT
AS
BEGIN
    DECLARE @is_valid BIT

    IF @for_month NOT LIKE '[1-2][0-9][0-9][0-9][0-1][0-9]'
        OR CAST(LEFT(@for_month, 4) AS INT) NOT BETWEEN 1900 AND 2199
        OR CAST(RIGHT(@for_month, 2) AS INT) NOT BETWEEN 1 AND 12
        OR CAST(@for_month AS INT) > CAST(FORMAT(GETDATE(), 'yyyyMM') AS INT)
    BEGIN
        SET @is_valid = 0
    END
    ELSE
    BEGIN
        SET @is_valid = 1 
    END

    RETURN @is_valid
END
GO

--function to check if account number is valid
EXEC dbo.create_empty_fun 'is_account_number_valid'
GO

ALTER FUNCTION dbo.is_account_number_valid (@Account_Number NVARCHAR(34))
RETURNS BIT
AS
BEGIN
    IF @Account_Number LIKE '[A-Z][A-Z][0-9][0-9]%' 
       AND PATINDEX('%[^0-9A-Z]%', @Account_Number) = 0
       AND LEN(@Account_Number) BETWEEN 14 AND 34
    BEGIN
        RETURN 1
    END
    RETURN 0
END;
GO


------------PROCEDURE TO CHECK HEADER FILE
EXEC dbo.create_empty_proc @proc_name = 'check_header'
GO

ALTER PROCEDURE dbo.check_header(@err int = 0 output)
AS
	DECLARE @number_of_entities int, @number_of_months int, @number_of_invalid_account_numbers int, @error_message nvarchar(200), @module nvarchar(50);
	SET @module = N'check_header'


--------ENTITY VALIDATION
	SELECT @number_of_entities = COUNT(DISTINCT hs.[Entity]) FROM [dbo].[Header_Staging] hs

	IF (@number_of_entities is null) or (@number_of_entities = 0)
	BEGIN
		SET @error_message = N'The Header file is empty!';
		INSERT INTO [dbo].Error_Log (Module, Err_Description) VALUES(@module, @error_message);
		RAISERROR(@error_message, 16, 3)
		SET @err = -1
		RETURN -1 
	END

	IF NOT (@number_of_entities = 1)
	BEGIN
		SET @error_message = N'The Header file must contain only one Entity!';
		INSERT INTO [dbo].Error_Log (Module, Err_Description) VALUES(@module, @error_message);
		RAISERROR(@error_message, 16, 3)
		SET @err = -1
		RETURN -1 
	END

	INSERT INTO Error_Log (Module, Err_Description)
    SELECT TOP(1) @module, 
           N'Missing Entity: ' + hs.Entity
    FROM Header_Staging hs
    WHERE NOT EXISTS (
        SELECT 1 FROM Entity e WHERE e.Entity_Identifier = hs.Entity
    );

	IF @@ROWCOUNT > 0
	BEGIN
		RAISERROR(N'Some entities do not exist in the database, check error log table', 16, 3);
		SET @err = -1;
		RETURN -1;
	END;

------------FOR_MONTH VALIDATION

	SELECT @number_of_months = COUNT(*)
		FROM [dbo].[Header_Staging] hs
		WHERE dbo.is_for_month_valid(hs.For_Month) = 0;
	
	IF (@number_of_months > 0)
	BEGIN
		SET @error_message = N'The Header file contains an invalid For_Month field, proper syntax is YYYYMM';
		INSERT INTO [dbo].Error_Log (Module, Err_Description) VALUES(@module, @error_message);
		RAISERROR(@error_message, 16, 3)
		SET @err = -1
		RETURN -1 
	END

	SELECT @number_of_months = COUNT(DISTINCT hs.[For_Month]) FROM [dbo].[Header_Staging] hs

	IF NOT (@number_of_months = 1)
	BEGIN
		SET @error_message = N'The Header file must contain data for ONLY one month!';
		INSERT INTO [dbo].Error_Log (Module, Err_Description) VALUES(@module, @error_message);
		RAISERROR(@error_message, 16, 3)
		SET @err = -1
		RETURN -1 
	END

-------ACCOUNT NUMBER VALIDATION
		SELECT @number_of_invalid_account_numbers = COUNT(hs.Account_Number) 
			FROM [dbo].[Header_Staging] hs 
			WHERE
				dbo.is_account_number_valid(hs.Account_Number) = 0;

	IF (@number_of_invalid_account_numbers > 0)
	BEGIN
		SET @error_message = N'The Header file contains an invalid account number';
		INSERT INTO [dbo].Error_Log (Module, Err_Description) VALUES(@module, @error_message);
		RAISERROR(@error_message, 16, 3)
		SET @err = -1
		RETURN -1 
	END

	IF EXISTS( 	
				SELECT hs.Account_Number 
				FROM [dbo].[Header_Staging] hs
				GROUP BY hs.Account_Number
				HAVING COUNT(*) > 1
			 )
	BEGIN
		SET @error_message = N'The Header file contains repeated account numbers. Only one row per an account number is permitted.';
		INSERT INTO [dbo].Error_Log (Module, Err_Description) VALUES(@module, @error_message);
		RAISERROR(@error_message, 16, 3)
		SET @err = -1
		RETURN -1 
	END

	INSERT INTO Error_Log (Module, Err_Description)
    SELECT @module, 
           N'Missing Account Number: ' + hs.Account_Number
    FROM Header_Staging hs
    WHERE NOT EXISTS (
        SELECT 1 FROM Account a WHERE a.Account_Number = hs.Account_Number
    );

	IF @@ROWCOUNT > 0
	BEGIN
		RAISERROR(N'Some accounts do not exist in the database, check error log table', 16, 3);
		SET @err = -1;
		RETURN -1;
	END;

	-------CURRENCY VALIDATION
	INSERT INTO Error_Log(Module, Err_Description)
		SELECT @module, N'There is no such currency available: '
				+ hs.Currency_Code
			FROM Header_Staging hs
			WHERE NOT EXISTS (
				SELECT 1 
					from dbo.Currency_Code cc
					where cc.Currency_Code = hs.Currency_Code
					)
		if @@ROWCOUNT > 0
		begin
			RAISERROR(N'Some of the given currencies are invalid, check error log table', 16, 3)
			SET @err = -1
			RETURN -1
		end

	INSERT INTO Error_Log (Module, Err_Description)
    SELECT @module, 
           N'Wrong currency for account number: ' + hs.Account_Number
		   + N' | Expected: ' + a.Currency_Code
		   + N' | Given: ' + hs.Currency_Code
    FROM Header_Staging hs
	JOIN Account a ON hs.Account_Number = a.Account_Number 
    WHERE 
	hs.Currency_Code != a.Currency_Code

	IF @@ROWCOUNT > 0
	BEGIN
		RAISERROR(N'Currencies for some accounts do not match, check error log table', 16, 3);
		SET @err = -1;
		RETURN -1;
	END;
GO


------------PROCEDURE TO CHECK ITEM FILE
EXEC dbo.create_empty_proc @proc_name = 'check_item'
GO

ALTER PROCEDURE dbo.check_item(@err int = 0 output)
AS
	DECLARE @module nvarchar(50), @transaction_count int, @Considered_Month nchar(6)
	
	SET @module = N'check_item'
	SET @err = 0
	SET @transaction_count = @@TRANCOUNT


	EXEC dbo.check_header  @err = @err output

	IF NOT (@err = 0)
	BEGIN
		RAISERROR(N'The Header file is invalid',16, 3)
		return @err
	END 

	SELECT @Considered_Month=MAX(hs.For_Month) FROM Header_Staging hs

-------VALIDATION FOR ITEMS WITH MISSING HEADERS AND HEADERS WITH MISSING ITEMS
	INSERT INTO Error_Log (Module, Err_Description)
		SELECT @module, N'Missing Item for Header Row: '
				+ hs.Entity
				+ N' | Account Number:' + hs.Account_Number
				+ N' | For Month:' + hs.For_Month 
			FROM Header_Staging hs
			WHERE NOT EXISTS (
				SELECT 1 
					FROM Item_Staging its
					WHERE	(hs.Entity	= its.Entity)
					AND		(hs.Account_Number	= its.Account_Number)
					AND		(hs.For_Month	= its.For_Month)
			)

	IF @@ROWCOUNT > 0
	BEGIN
		RAISERROR(N'There are some header rows without any item rows, check error log table', 16, 3)
		SET @err = -1
		RETURN -1
	END

	INSERT INTO Error_Log (Module, Err_Description)
		SELECT @module, N'Missing Header for Item Row:'
				+ its.Entity
				+ N' | Account Number:' + its.Account_Number
				+ N' | For Month:' + its.For_Month 
			FROM Item_Staging its
			WHERE NOT EXISTS (
				SELECT 1 
					FROM Header_Staging hs
					WHERE	(its.Entity	= hs.Entity)
					AND		(its.Account_Number	= hs.Account_Number)
					AND		(its.For_Month	= hs.For_Month)
			)
	IF @@ROWCOUNT > 0
	BEGIN
		RAISERROR(N'There are some item rows without matching header rows, check error log table', 16, 3)
		SET @err = -1
		RETURN -1
	END

----ITEM LINE DATE VALIDATION
	INSERT INTO Error_Log (Module, Err_Description)
    SELECT @module, 
           N'Date out of range for For_Month: ' + its.For_Month
           + N' | Account Number: ' + its.Account_Number
           + N' | Date: ' + CONVERT(NVARCHAR(10), its.[Date], 120)
    FROM Item_Staging its
    WHERE its.For_Month = @Considered_Month
    AND (
        dbo.text_to_date(its.Date) < DATEFROMPARTS(LEFT(@Considered_Month, 4), RIGHT(@Considered_Month, 2), 1) 
        OR dbo.text_to_date(its.Date) > EOMONTH(DATEFROMPARTS(LEFT(@Considered_Month, 4), RIGHT(@Considered_Month, 2), 1))
    );

	IF @@ROWCOUNT > 0
	BEGIN
		RAISERROR(N'Some item rows have dates outside the specified For_Month, check error log table', 16, 3);
		SET @err = -1;
		RETURN -1;
	END;


-----BALANCE VALIDATION
	DECLARE @account_number nvarchar(34), @opening_balance NUMERIC(18,2), @closing_balance NUMERIC(18,2), @balance NUMERIC(18,2), @amount NUMERIC(18,2), @curr_balance NUMERIC(18,2), @err_msg nvarchar(200)
	
	DECLARE CC_balance_check INSENSITIVE CURSOR FOR 
		SELECT  hs.Account_Number, dbo.text_to_money(hs.Opening_Balance), dbo.text_to_money(hs.Closing_Balance)
			FROM Header_Staging hs
			ORDER BY 1
		OPEN CC_balance_check
		FETCH NEXT FROM CC_balance_check INTO @account_number, @opening_balance, @closing_balance
		WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @curr_balance = @opening_balance;
			DECLARE CC_item CURSOR FOR
				SELECT
					dbo.text_to_money(its.Amount), dbo.text_to_money(its.Balance)
				FROM Item_Staging its
				WHERE its.Account_Number = @account_number
				ORDER BY its.[Date];
			OPEN CC_item;
			FETCH NEXT FROM CC_item INTO @amount, @balance;
			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @curr_balance = @curr_balance + @amount;
				IF @curr_balance != @balance
				BEGIN
					SET @err_msg = 'Item Balance mismatch for Account: ' + @account_number + 
						  ', Expected: ' + CAST(@balance AS NVARCHAR(30)) + 
						  ', Found: ' + CAST(@curr_balance AS VARCHAR(30));
					INSERT INTO dbo.Error_Log (Module, Err_Description) VALUES(@module, @err_msg);
					CLOSE CC_item;
					DEALLOCATE CC_item;
					CLOSE CC_balance_check
					DEALLOCATE CC_balance_check
					RAISERROR(@err_msg, 16, 3)
					SET @err = -1
					RETURN -1
				END

				FETCH NEXT FROM CC_item INTO @amount, @balance;
			END

			IF @curr_balance != @closing_balance
			BEGIN
					SET @err_msg = 'Closing Balance mismatch for Account: ' + @account_number + 
						  ', Expected: ' + CAST(@closing_balance AS NVARCHAR(30)) + 
						  ', Found: ' + CAST(@curr_balance AS VARCHAR(30));
					INSERT INTO dbo.Error_Log (Module, Err_Description) VALUES(@module, @err_msg);
					CLOSE CC_item;
					DEALLOCATE CC_item;
					CLOSE CC_balance_check
					DEALLOCATE CC_balance_check
					RAISERROR(@err_msg, 16, 3)
					SET @err = -1
					RETURN -1
			END
			CLOSE CC_item;
			DEALLOCATE CC_item;
			FETCH NEXT FROM CC_balance_check INTO @account_number, @opening_balance, @closing_balance
		END
		CLOSE CC_balance_check
		DEALLOCATE CC_balance_check



---TRANSACTION

	IF @transaction_count = 0
			BEGIN TRAN TRAN_INSERT
		ELSE
			SAVE TRAN TRAN_INSERT
	
--insert client data
	insert into dbo.Transaction_Party(Party_Name)
		select distinct its.Transaction_Party
			from dbo.Item_Staging its
			where not exists 
			( select 1 
				from dbo.Transaction_Party tp
				where	(tp.Party_Name = its.Transaction_Party)
			)
	SELECT @err = @@ERROR
	
	IF @err = 0
	BEGIN
		--cleaning previous data for that month for the company
		DECLARE @Entity nchar(10), @For_Month NCHAR(6)

		SELECT @Entity=MAX(hs.Entity), @For_Month=MAX(hs.For_Month) FROM dbo.Header_Staging hs

		DELETE FROM dbo.Item_Line 
			FROM dbo.Item_Line JOIN dbo.Header ON (dbo.Header.Header_Id = dbo.Item_Line.Header_Id)
			JOIN dbo.Account ON (dbo.Header.Account_Id = dbo.Account.Account_Id)
			WHERE dbo.Account.[Entity_Id] = @Entity AND dbo.Header.[Month] = @For_Month
		
		SELECT @err = @@ERROR

		IF @err = 0
		BEGIN
			DELETE FROM dbo.Header
				FROM dbo.Header JOIN dbo.Account ON (dbo.Header.Account_Id = dbo.Account.Account_Id)
				WHERE dbo.Account.[Entity_Id] = @Entity AND dbo.Header.[Month] = @For_Month
			SELECT @err = @@ERROR
		END
	END


	DECLARE @id_header int, @account_id int

	DECLARE CC INSENSITIVE CURSOR FOR 
			SELECT  hs.Account_Number
				 FROM Header_Staging hs
				 ORDER BY 1
	
	OPEN CC
	FETCH NEXT FROM CC INTO @account_number
	WHILE @@FETCH_STATUS = 0 AND @err = 0
	BEGIN
		SELECT @account_id = MAX(a.Account_Id) FROM Account a WHERE a.Account_Number = @account_number

		INSERT INTO dbo.Header(Account_Id, [Month], Opening_Balance, Closing_Balance)
			SELECT @account_id, 
				hs.For_Month
			,	dbo.text_to_money(hs.Opening_Balance)
			,	dbo.text_to_money(hs.Closing_Balance)
				FROM Header_Staging hs
				WHERE hs.Account_Number = @account_number

		SELECT @err = @@ERROR, @id_header = SCOPE_IDENTITY()

		IF @err = 0
		BEGIN
			INSERT INTO dbo.Item_Line (Header_Id, Transaction_Party_Id, Transaction_Date, [Description], Amount, Balance) 
			SELECT 
					@id_header
				,	(SELECT TOP(1) tp.Transaction_Party_Id FROM Transaction_Party tp WHERE tp.Party_Name = its.Transaction_Party)
				,	dbo.text_to_date(its.Date)
				,	its.[Description]
				,	dbo.text_to_money(its.Amount)
				,	dbo.text_to_money(its.Balance)
					FROM Item_Staging its
					where its.Account_Number = @account_number

			SELECT @err = @@ERROR
		END
				
		FETCH NEXT FROM CC INTO @account_number
	END
	CLOSE CC
	DEALLOCATE CC
		
		IF @err = 0
		BEGIN
			DELETE FROM Header_Staging;
			DELETE FROM Item_Staging;
			SELECT @err = @@ERROR
		END


		IF @err = 0
		BEGIN
			IF @transaction_count = 0
				COMMIT TRAN TRAN_INSERT
		END
		ELSE
		BEGIN
			ROLLBACK TRAN TRAN_INSERT
		END
GO

