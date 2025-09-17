use jpk_wb_ssis

EXEC dbo.create_empty_fun @fun_name = 'SAFT_CLEAR_TXT'
go

ALTER FUNCTION dbo.SAFT_CLEAR_TXT(@msg nvarchar(256) )
RETURNS nvarchar(256)
AS
BEGIN
	IF (@msg IS NULL)  OR (RTRIM(@msg) = N'')
		RETURN N''

	SET @msg = LTRIM(RTRIM(@msg))
	/* clear potentially dangerous characters for XML within the string */
	/* \n in SEDOKUS means NEW LINE but for XML we have to remove it */
	SET @msg = REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(@msg,'\n',N' '),N'<',N'?'),N'>','?'),N':',N'?'),N'\',N'?')
	SET @msg = REPLACE(@msg,N'/',N'!')
	RETURN RTRIM(LEFT(@msg,255)) /* limit for SAFT text field is 255 */
END
go

EXEC dbo.create_empty_fun @fun_name = 'SAFT_RMV_PREFIX'
GO

ALTER FUNCTION dbo.SAFT_RMV_PREFIX(@msg nvarchar(20) )
RETURNS nvarchar(20)
AS
BEGIN
	IF LEN(@msg) < 3
		RETURN @msg
	IF (LEFT(@msg,1) BETWEEN 'a' AND 'z') OR (LEFT(@msg,1) BETWEEN 'A' AND 'Z')
		RETURN RTRIM(SUBSTRING(@msg,3,20))
	RETURN RTRIM(@msg)
END
GO

EXEC dbo.create_empty_proc @proc_name = 'SAFT_INI_DATA'
GO

ALTER PROCEDURE dbo.SAFT_INI_DATA(@ym nchar(6), @d1 datetime = null output, @dN datetime = null output)
/*
declare @d1 datetime,  @dn datetime
EXEC dbo.SAFT_INI_DATA @ym = '202502', @d1=@d1 output, @dn=@dn output
SELECT @d1, @dn
-- (No column name)	(No column name)
2023-03-01 00:00:00.000	2023-03-31 00:00:00.000
*/

AS
	SET @d1 = convert(datetime, substring(@ym,5,2) + '/01/' + left(@ym,4),101)	
	SET @dN = dateadd(DD, -1, dateadd(MM, 1, @d1))
GO

EXEC dbo.create_empty_fun @fun_name = 'SANITIZE_VATID'
GO

ALTER FUNCTION dbo.SANITIZE_VATID(@vatid nvarchar(20) )
RETURNS nvarchar(10)
AS
BEGIN

	SET @vatid = REPLACE(REPLACE(REPLACE(@vatid,N' ',N''),N':',''),N'-','')
	SET @vatid = dbo.SAFT_CLEAR_TXT(@vatid)
	/* clear potentially dangerous characters for XML within the string */
	IF @vatid LIKE 'VATID%'
		SET @vatid = RTRIM(SUBSTRING(@vatid,6,20))
	IF (@vatid LIKE 'NIP%') OR (@vatid LIKE 'VAT%')
		SET @vatid = RTRIM(SUBSTRING(@vatid,4,20))
	IF @vatid LIKE N'[A-Z][A-Z][1-9]%'
		SET @vatid = LTRIM(RTRIM(SUBSTRING(@vatid,3,20)))

	RETURN LEFT(@vatid,10)
END
GO

EXEC dbo.create_empty_fun @fun_name = 'SAFT_AMT_TRUE_FALSE'
GO

ALTER FUNCTION dbo.SAFT_AMT_TRUE_FALSE(@msg nvarchar(20) )
RETURNS nvarchar(6)
AS
BEGIN
	IF (@msg IS NULL) OR (RTRIM(@msg)=N'') OR (LTRIM(RTRIM(@msg)) = N'0.00')
		RETURN N'false'
	RETURN N'true'
END
GO

EXEC dbo.create_empty_fun @fun_name = 'SAFT_DATE'
GO

ALTER FUNCTION dbo.SAFT_DATE(@d datetime )
RETURNS nchar(10)
AS
BEGIN
	RETURN CONVERT(nchar(10), @d, 120)
END
GO


EXEC dbo.create_empty_fun @fun_name = 'SAFT_AMT_NULL'
GO


ALTER FUNCTION dbo.SAFT_AMT_NULL(@msg nvarchar(20), @curr_code nchar(3) )
RETURNS nvarchar(20)
AS
BEGIN
	IF (@msg IS NULL) OR (RTRIM(@msg)=N'') OR (LTRIM(RTRIM(@msg)) = N'0.00')
		RETURN NULL
	RETURN @msg
END

GO
EXEC dbo.create_empty_fun @fun_name = 'SAFT_EMPTY0'
GO


ALTER FUNCTION dbo.SAFT_EMPTY0(@msg nvarchar(40) )
RETURNS nvarchar(40)
AS
BEGIN
	IF @msg IS NULL OR LTRIM(@msg) = N''
		RETURN N'0'
	RETURN @msg
END
GO


EXEC dbo.create_empty_fun @fun_name = 'SAFT_GET_AMT'
GO


ALTER FUNCTION dbo.SAFT_GET_AMT(@amt money )
RETURNS nvarchar(20)
AS
BEGIN
	IF @amt IS NULL
		RETURN N''
	RETURN RTRIM(LTRIM(STR(@amt,18,2)))
END

GO


EXEC dbo.create_empty_proc @proc_name = 'Generate_XML_For_JPK_WB'
GO

ALTER PROCEDURE [dbo].[Generate_XML_For_JPK_WB]
(   
    @for_month             nchar(6),
    @entity                nchar(10),
    @account_number        nvarchar(34),
    @xml                   xml = null output,
    @return                nvarchar(20) = N'xml'
)
AS
BEGIN
    DECLARE @date_start datetime, 
            @date_end datetime, 
            @is_valid bit, 
            @error_message nvarchar(255), 
            @err bit,
			@tax_office_code nchar(4),
			@currency_code nchar(3),
			@header_id int;
    
    SET @err = 0;
    
    SELECT @is_valid = dbo.is_for_month_valid(@for_month);
    
    IF @is_valid = 0
    BEGIN
        SET @error_message = N'The given for_month value is invalid, correct syntax is YYYYMM';
        RAISERROR(@error_message, 16, 3);
        SET @err = -1;
        RETURN -1;
    END;

    SELECT @is_valid = dbo.is_account_number_valid(@account_number);

    IF @is_valid = 0
    BEGIN
        SET @error_message = N'The given account number is invalid';
        RAISERROR(@error_message, 16, 3);
        SET @err = -1;
        RETURN -1;
    END;

    EXEC dbo.SAFT_INI_DATA @ym = @for_month, @d1 = @date_start output, @dN = @date_end output;
    
	SELECT @tax_office_code = e.Tax_Office_Code FROM dbo.Entity e WHERE e.Entity_Identifier = @entity
	IF @tax_office_code is null or @tax_office_code = N''
	BEGIN
		SET @error_message = N'There is no such entity';
        RAISERROR(@error_message, 16, 3);
        SET @err = -1;
        RETURN -1;
	END

	IF NOT EXISTS (SELECT * FROM Entity e JOIN Account a ON a.[Entity_Id] = e.Entity_Identifier WHERE e.Entity_Identifier = @entity AND a.Account_Number = @account_number )
	BEGIN
		SET @error_message = N'The account doesnt exist or doesnt belong to the given entity';
        RAISERROR(@error_message, 16, 3);
        SET @err = -1;
        RETURN -1;
	END

	SELECT @currency_code = a.Currency_Code FROM dbo.Account a WHERE a.Account_Number = @account_number

	DECLARE @opening_balance NUMERIC(18,2), @closing_balance NUMERIC(18,2)
	
	SELECT 
		@header_id = h.Header_Id,
		@opening_balance = h.Opening_Balance,
		@closing_balance = h.Closing_Balance
	FROM Header h (NOLOCK)
	WHERE h.Account_Id = (SELECT a.Account_Id FROM Account a WHERE a.Account_Number = @account_number)
	AND h.[Month] = @for_month

	SELECT 
		ROW_NUMBER() OVER (ORDER BY i.Transaction_Date) AS RowId,
		i.Transaction_Date,
		tp.Party_Name,
		i.[Description],
		i.Amount,
		i.Balance
	INTO #tmp_items
	FROM Item_Line (NOLOCK) i
	JOIN Transaction_Party tp ON i.Transaction_Party_Id = tp.Transaction_Party_Id 
	WHERE i.Header_Id = @header_id
	ORDER BY i.Transaction_Date


	 SET @xml = null;

	;WITH XMLNAMESPACES(
		N'http://jpk.mf.gov.pl/wzor/2016/03/09/03092/' AS tns,
		N'http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2016/01/25/eD/DefinicjeTypy/' AS etd,
		N'http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2013/05/23/eD/KodyCECHKRAJOW/' AS kck,
		N'http://www.w3.org/2001/XMLSchema-instance' AS xsi
	)
	
	SELECT @xml=(SELECT 
		(
			SELECT  
				N'JPK_WB (1)'			AS [tns:KodFormularza/@kodSystemowy]	/* System code, was fixed in XSD */
			,	N'1-0'                  AS [tns:KodFormularza/@wersjaSchemy]    /* Schema veriosn, was fixed in XSD */
			,	N'JPK_WB'               AS [tns:KodFormularza]                  /* SAFT ID - fixed */
			,	N'1'					AS [tns:WariantFormularza]				/* SAFT variant - fixed */
			,	N'1'                    AS [tns:CelZlozenia]                    /* reason - fixed */
			,	GETDATE()				AS [tns:DataWytworzeniaJPK]                             /* creation date */
			,	dbo.SAFT_DATE(@date_start)		AS [tns:DataOd]                                        /* from date */
			,	dbo.SAFT_DATE(@date_end)		AS [tns:DataDo]                                        /* to date */
			,	@currency_code					AS [tns:DomyslnyKodWaluty]
			,	@tax_office_code				AS [tns:KodUrzedu]
			FOR XML PATH('tns:Naglowek'), TYPE
		),
		(
			SELECT
					( SELECT	
						dbo.SANITIZE_VATID(e.Vat_Id)			AS [etd:NIP],
						dbo.SAFT_CLEAR_TXT(e.[Entity_Name])		AS [etd:PelnaNazwa]
                                FROM Entity (NOLOCK) e WHERE e.Entity_Identifier = @entity
                        FOR XML PATH('tns:IdentyfikatorPodmiotu'), TYPE
					),

					( SELECT	e.Country_Code				AS [etd:KodKraju]
                        ,       e.Voivodeship       AS [etd:Wojewodztwo]
                        ,       e.District            AS [etd:Powiat]
                        ,       e.Municipality             AS [etd:Gmina]
                        ,       e.Street             AS [etd:Ulica]
                        ,       e.House_Number 			AS [etd:NrDomu]
                        ,       e.Apartment_Number		AS [etd:NrLokalu]
                        ,       e.City				AS [etd:Miejscowosc]
                        ,       e.Postal_Code		AS [etd:KodPocztowy]
						,		e.Post_Office		AS [etd:Poczta]
                                FROM Entity (NOLOCK) e WHERE e.Entity_Identifier = @entity
                        FOR XML PATH('tns:AdresPodmiotu'), TYPE
					)

			FOR XML PATH('tns:Podmiot1'), TYPE
		),
		RTRIM(LTRIM(@account_number)) as [tns:NumerRachunku],
		(
			SELECT
				dbo.SAFT_GET_AMT(@opening_balance) AS [tns:SaldoPoczatkowe],
				dbo.SAFT_GET_AMT(@closing_balance) AS [tns:SaldoKoncowe]
			FOR XML PATH('tns:Salda'), TYPE
		),
		(
			SELECT
				'G' as '@typ',
				ti.RowId	AS [tns:NumerWiersza],
				dbo.SAFT_DATE(ti.Transaction_Date) AS [tns:DataOperacji],
				dbo.SAFT_CLEAR_TXT(ti.Party_Name) AS [tns:NazwaPodmiotu],
				dbo.SAFT_CLEAR_TXT(ti.[Description]) AS [tns:OpisOperacji],
				dbo.SAFT_GET_AMT(ti.Amount) AS [tns:KwotaOperacji],
				dbo.SAFT_GET_AMT(ti.Balance) AS [tns:SaldoOperacji]
				FROM #tmp_items (NOLOCK) ti
			FOR XML PATH('tns:WyciagWiersz'), TYPE
		),
		(
			SELECT
				(SELECT COUNT(*) FROM #tmp_items) AS [tns:LiczbaWierszy],
				(SELECT SUM(ti.Amount) FROM #tmp_items ti WHERE ti.Amount <= 0) AS [tns:SumaObciazen],
				(SELECT SUM(ti.Amount) FROM #tmp_items ti WHERE ti.Amount > 0) AS [tns:SumaUznan]
			FOR XML PATH('tns:WyciagCtrl'), TYPE
		)
	FOR XML PATH(''), TYPE, ROOT('tns:JPK')
	)

	SET @xml.modify('declare namespace tns = "http://jpk.mf.gov.pl/wzor/2016/03/09/03092/"; insert attribute xsi:schemaLocation{"http://crd.gov.pl/wzor/2016/03/09/03092/Schemat_JPK-WB(1)_v1-0.xsd"} as last into (tns:JPK)[1]')

END
GO


DECLARE @xml xml
EXEC dbo.Generate_XML_For_JPK_WB @for_month = N'202503', @entity='PL00000001', @account_number=N'PL61109010140000071219812874', @xml=@xml output
SELECT @xml as 'xml'