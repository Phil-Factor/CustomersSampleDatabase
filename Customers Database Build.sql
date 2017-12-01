/*
USE master;
GO

IF NOT EXISTS
  (SELECT name FROM sys.databases WHERE name LIKE 'customersAnother')
  CREATE DATABASE CustomersAnother
GO

USE Customers;
GO
*/
--only create the Customer schema if it does not exist
IF EXISTS (SELECT * FROM sys.schemas WHERE schemas.name LIKE 'Customer') SET NOEXEC ON;
GO

CREATE SCHEMA Customer;
GO

--
SET NOEXEC OFF;

--delete the table with all the foreign key references in it
IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.Abode'))
  DROP TABLE Customer.Abode;

IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.NotePerson'))
  DROP TABLE Customer.NotePerson;
GO

IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.Phone'))
  DROP TABLE Customer.Phone;
GO

IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.CreditCard'))
  DROP TABLE Customer.CreditCard;
GO
IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.EmailAddress'))
  DROP TABLE Customer.EmailAddress;
GO
IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.Person'))
  DROP TABLE Customer.Person;
GO

CREATE TABLE Customer.Person
  (
  person_ID INT NOT NULL IDENTITY PRIMARY KEY,
  Title NVARCHAR(8) NULL,
  FirstName VARCHAR(40) NOT NULL,
  MiddleName VARCHAR(40) NULL,
  LastName VARCHAR(40) NOT NULL,
  Suffix NVARCHAR(10) NULL,
  ModifiedDate DATETIME NOT NULL DEFAULT GetDate()
  );



IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.Address'))
  DROP TABLE Customer.Address;
GO

CREATE TABLE Customer.Address
  (
  AddressID INT NOT NULL IDENTITY PRIMARY KEY,
  AddressLine1 NVARCHAR(60) NOT NULL,
  AddressLine2 NVARCHAR(60) NULL,
  City NVARCHAR(30) NOT NULL,
  County NVARCHAR(30) NOT NULL,
  PostCode NVARCHAR(15) NOT NULL,
  ModifiedDate DATETIME NOT NULL DEFAULT GetDate()
  );
GO
IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.AddressType'))
  DROP TABLE Customer.AddressType;
GO

CREATE TABLE Customer.AddressType
  (
  TypeOfAddress VARCHAR(40) NOT NULL PRIMARY KEY,
  ModifiedDate DATETIME NOT NULL DEFAULT GetDate()
  );
GO

IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.Abode'))
  DROP TABLE Customer.Abode;
GO

CREATE TABLE Customer.Abode
  (
  Abode_ID INT NOT NULL IDENTITY PRIMARY KEY,
  Person_id INT NOT NULL FOREIGN KEY REFERENCES Customer.Person,
  Address_id INT NOT NULL FOREIGN KEY REFERENCES Customer.Address,
  TypeOfAddress VARCHAR(40) NOT NULL FOREIGN KEY REFERENCES Customer.AddressType,
  Start_date DATETIME NOT null,
  End_date DATETIME NULL,
  ModifiedDate DATETIME NOT NULL DEFAULT GetDate()
  );

IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.PhoneType'))
  DROP TABLE Customer.PhoneType;
GO

CREATE TABLE Customer.PhoneType
  (
  TypeOfPhone VARCHAR(40) PRIMARY KEY,
  ModifiedDate DATETIME NOT NULL DEFAULT GetDate()
  );

CREATE TABLE Customer.Phone
  (
  Phone_ID INT NOT NULL IDENTITY PRIMARY KEY,
  Person_id INT FOREIGN KEY REFERENCES Customer.Person,
  TypeOfPhone VARCHAR(40) FOREIGN KEY REFERENCES Customer.PhoneType,
  DiallingNumber VARCHAR(20),
  Start_date DATETIME,
  End_date DATETIME,
  ModifiedDate DATETIME NOT NULL DEFAULT GetDate()
  );

IF EXISTS
  (SELECT * FROM sys.objects WHERE objects.object_id LIKE Object_Id('Customer.Note'))
  DROP TABLE Customer.Note;
GO

CREATE TABLE Customer.Note
  (
  Note_id INT NOT NULL IDENTITY PRIMARY KEY,
  Note VARCHAR(8000),
  InsertionDate DATETIME NOT NULL DEFAULT GetDate(),
  ModifiedDate DATETIME NOT NULL DEFAULT GetDate()
  );


go
CREATE TABLE Customer.NotePerson
  (
  NoteCustomer_id INT NOT NULL IDENTITY PRIMARY KEY,
  Person_id INT FOREIGN KEY REFERENCES Customer.Person,
  Note_id INT FOREIGN KEY REFERENCES Customer.Note,
  InsertionDate DATETIME NOT NULL DEFAULT GetDate(),
  ModifiedDate DATETIME NOT NULL DEFAULT GetDate()
  );

CREATE TABLE Customer.CreditCard
  (
  CreditCardID INT NOT NULL IDENTITY PRIMARY KEY,
  Person_id INT NULL FOREIGN KEY REFERENCES Customer.Person,
  CardNumber VARCHAR(20) NOT NULL,
  ValidFrom DATE NOT NULL,
  ValidTo DATE NOT NULL,
  CVC CHAR(3) NOT NULL,
  ModifiedDate DATETIME NOT NULL DEFAULT(GetDate())
  );

CREATE TABLE Customer.EmailAddress
  (EmailID INT NOT NULL IDENTITY(1, 1),
   Person_id INT NULL FOREIGN KEY REFERENCES Customer.Person,
   EmailAddress VARCHAR(40) NOT NULL,
   StartDate DATE NOT NULL,
   EndDate DATE NULL,
   ModifiedDate DATETIME NOT NULL DEFAULT(GetDate())
  );

GO
CREATE OR ALTER FUNCTION customer.JSONversion()
RETURNS NVARCHAR(MAX)
--WITH SCHEMABINDING
AS
  BEGIN
    RETURN
      (SELECT Coalesce(Title + ' ', '') + FirstName + ' ' + Coalesce(MiddleName + ' ', '')
                     + Coalesce(Suffix, '') AS [full name], Person_id AS [Person Key],
         Title AS [name.title], FirstName AS [name.First name], MiddleName AS [name.middle name],
         LastName AS [name.Last Name], Suffix AS [name.suffix],
         (SELECT TypeOfAddress AS type,
            Coalesce(AddressLine1 + ' ', '') + ' ' + Coalesce(AddressLine2 + ' ', '') + ', ' + City
            + ', ' + County + ' ' + PostCode AS [Full Address], Start_date AS [dates.moved in],
            End_date AS [dates.moved out]
            FROM Customer.Abode AS A
              INNER JOIN Customer.Address AS A2
                ON A2.AddressID = A.Address_id
            WHERE A.Person_id = Person.person_ID
         FOR JSON PATH) AS Addresses,
         (SELECT N.Note AS text, N.InsertionDate AS date
            FROM Customer.Note AS N
              INNER JOIN Customer.NotePerson AS NP
                ON N.Note_id = NP.Note_id
            WHERE NP.Person_id = Person.person_ID
         FOR JSON PATH) AS Notes,
         (SELECT TypeOfPhone, DiallingNumber, Start_date AS [dates.from], End_date AS [dates.to]
            FROM Customer.Phone AS P
              INNER JOIN Customer.Person AS pp
                ON pp.person_ID = P.Phone_ID
            WHERE pp.person_ID = Person.person_ID
         FOR JSON PATH) AS Phones,
         (SELECT EmailAddress, Startdate AS [dates.from], Enddate AS [dates.to]
            FROM Customer.EmailAddress AS E
              INNER JOIN Customer.Person AS pe
                ON pe.person_ID = E.person_ID
         FOR JSON PATH) AS EmailAddresses,
         (SELECT CardNumber, ValidFrom, ValidTo, CVC
            FROM Customer.CreditCard AS CCC
              INNER JOIN Customer.Person AS ppc
                ON ppc.person_ID = CCC.Person_id
            WHERE ppc.person_ID = Person.person_ID
         FOR JSON PATH) AS Cards
         FROM Customer.Person
      FOR JSON PATH);
  END;
GO
-- create all the extended properties
DECLARE @TheScript NVARCHAR(MAX) =
  (SELECT 'EXEC sys.sp_addextendedproperty @name = N''MS_Description'',  @value = N'''+ Explanation + ''',
  @level0type =  N''SCHEMA'', @level0name = N''' + theSchema + ''',
  @level1type = N''TABLE'',  @level1name = N''' + TheTable + ''', 
  @level2type = N''COLUMN'', @level2name = N''' + ColumnName + ''';
  '
  FROM
         (VALUES
('FirstName','First name of the person.','Customer','Person'),
('LastName','Last name of the person.','Customer','Person'),
('MiddleName','Middle name or middle initial of the person.','Customer','Person'),
('ModifiedDate','Date and time the record was last updated.','Customer','Person'),
('person_ID','Primary key for Person records.','Customer','Person'),
('Suffix','Surname suffix. For example, Sr. or Jr.','Customer','Person'),
('Title','A courtesy title. For example, Mr. or Ms.','Customer','Person'),
('AddressID','Primary key for Address records.','Customer','Address'),
('AddressLine1','First street address line.','Customer','Address'),
('AddressLine2','Second street address line.','Customer','Address'),
('City','Name of the city.','Customer','Address'),
('County','the county associated with the address','Customer','Address'),
('ModifiedDate','Date and time the record was last updated.','Customer','Address'),
('PostCode','Postal code for the street address.','Customer','Address'),
('ModifiedDate','When the type of address was first defined','Customer','AddressType'),
('TypeOfAddress','a string describing a type of address','Customer','AddressType'),
('Abode_ID','the surrogate key for an abode','Customer','Abode'),
('Address_id','the address concerned','Customer','Abode'),
('End_date','when the address stopped being associated with the customer','Customer','Abode'),
('ModifiedDate','when this record was last modified','Customer','Abode'),
('Person_id','the person associated with the address','Customer','Abode'),
('Start_date','when the person started being associated with the address','Customer','Abode'),
('TypeOfAddress','the type of address','Customer','Abode'),
('ModifiedDate','when thedefinition of the type of phone was last modified','Customer','PhoneType'),
('TypeOfPhone','a description of the type of phone (e.g. Mobile, work, home)','Customer','PhoneType'),
('DiallingNumber','the actual number to dial','Customer','Phone'),
('End_date','When the phone number stopped being associated with the person','Customer','Phone'),
('ModifiedDate','when the phone record was last modified','Customer','Phone'),
('Person_id','the person associated with the phone','Customer','Phone'),
('Phone_ID','surrogate key for the record of the phone association','Customer','Phone'),
('Start_date','when the customer started being associated with the phone','Customer','Phone'),
('TypeOfPhone','the type of phone, defined in a separate table','Customer','Phone'),
('InsertionDate','when the note was recorded in the database','Customer','Note'),
('ModifiedDate','when the note was last modified','Customer','Note'),
('Note','record of a communication from the person','Customer','Note'),
('Note_id','the surrogate key for the note','Customer','Note'),
('InsertionDate','when the association between customer and note was inserted','Customer','NotePerson'),
('ModifiedDate','when the association between customer and note note was last modified','Customer','NotePerson'),
('Note_id','the note that is associated with the customer','Customer','NotePerson'),
('NoteCustomer_id','the surrogate key for the association between customer and note','Customer','NotePerson'),
('Person_id','the person who is associated with the note','Customer','NotePerson'),
('CardNumber','the credit card number','Customer','CreditCard'),
('CreditCardID','the surrogate key for the credit card','Customer','CreditCard'),
('CVC','the number on the back of the card','Customer','CreditCard'),
('ModifiedDate','when this record was last modified','Customer','CreditCard'),
('Person_id','the person owning the credit card','Customer','CreditCard'),
('ValidFrom','the date from when the card is valid','Customer','CreditCard'),
('ValidTo','the date to which the card remains valid','Customer','CreditCard'),
('EmailAddress','the email address','Customer','EmailAddress'),
('EmailID','the surrogate key for the email address','Customer','EmailAddress'),
('EndDate','when the email stopped being valid','Customer','EmailAddress'),
('ModifiedDate','when the email record was last modified','Customer','EmailAddress'),
('Person_id','the person associated with the email address','Customer','EmailAddress'),
('StartDate','the time when we created the record','Customer','EmailAddress')
	   ) AS Properties(ColumnName, Explanation, theSchema, TheTable)
 FOR XML PATH (''), TYPE).value('.', 'varchar(max)')
 --SELECT @TheScript
 EXEC sys.sp_executesql  @stmt = @TheScript 
 --Run time-compiled Transact-SQL statements can expose applications to malicious attacks.

 /*

 SELECT '('''+col.name
   +''','''+Coalesce(Cast(ep.value AS NVARCHAR(100)),'')
   +''','''+ OBJECT_SCHEMA_NAME(col.object_id)
   +''','''+OBJECT_NAME(col.object_id)+'''),'
 FROM sys.columns col 
 LEFT OUTER JOIN sys.extended_properties ep
 ON ep.major_id=col.Object_id AND class=1 AND ep.minor_id=col.column_id
 WHERE OBJECT_SCHEMA_NAME(col.object_id) <>'sys'
 */
