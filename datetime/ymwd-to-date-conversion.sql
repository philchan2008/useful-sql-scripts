DECLARE @duration_string VARCHAR(10) = '1y2m3w4d' --1y2m3w4d for debugging purposes
--
--select @duration_string
print 'Retention Parameter: ' + cast(@duration_string as varchar(255))
-- Initialize variables to hold the values
DECLARE @years INT = 0, @months INT = 0, @weeks INT = 0, @days INT = 0
-- Extract years
IF CHARINDEX('y', @duration_string) > 0
	SET @years = CAST(SUBSTRING(@duration_string, 1, CHARINDEX('y', @duration_string) - 1) AS INT)
-- Extract months
IF CHARINDEX('m', @duration_string) > 0
	SET @months = CAST(SUBSTRING(@duration_string,
		CASE WHEN CHARINDEX('y', @duration_string) > 0 THEN CHARINDEX('y', @duration_string) + 1 ELSE 0 END,
		CHARINDEX('m', @duration_string) -
		CASE WHEN CHARINDEX('y', @duration_string) > 0 THEN CHARINDEX('y', @duration_string) + 1 ELSE 0 END) AS INT)
-- Extract weeks
IF CHARINDEX('w', @duration_string) > 0
	SET @weeks = CAST(SUBSTRING(@duration_string,
		CASE WHEN CHARINDEX('m', @duration_string) > 0 THEN CHARINDEX('m', @duration_string) + 1 ELSE
			CASE WHEN CHARINDEX('y', @duration_string) > 0 THEN CHARINDEX('y', @duration_string) + 1 ELSE 0 END END,
		CHARINDEX('w', @duration_string) -
		CASE WHEN CHARINDEX('m', @duration_string) > 0 THEN CHARINDEX('m', @duration_string) + 1 ELSE
			CASE WHEN CHARINDEX('y', @duration_string) > 0 THEN CHARINDEX('y', @duration_string) + 1 ELSE 0 END END) AS INT)
-- Extract days
IF CHARINDEX('d', @duration_string) > 0
BEGIN
	DECLARE @start_day INT;
	IF CHARINDEX('w', @duration_string) > 0
		SET @start_day = CHARINDEX('w', @duration_string) + 1
	ELSE IF CHARINDEX('m', @duration_string) > 0
		SET @start_day = CHARINDEX('m', @duration_string) + 1
	ELSE IF CHARINDEX('y', @duration_string) > 0
		SET @start_day = CHARINDEX('y', @duration_string) + 1
	ELSE
		SET @start_day = 1
	SET @days = CAST(SUBSTRING(@duration_string, @start_day, LEN(@duration_string) - @start_day) AS INT)
END
-- Select the results
--SELECT @years AS Years, @months AS Months, @weeks AS Weeks, @days AS Days;
--
-- Select the results
print 'Retention years: ' + cast(@years as varchar(10)) + ', Months: ' +
	cast(@months as varchar(10)) + ', Weeks: ' + cast(@weeks as varchar(10)) +
	', Days: ' + cast(@days as varchar(10))
--
DECLARE @retentionDate DATE
SET @retentionDate = DATEADD(DAY, -1*@days,
						DATEADD(MONTH, -1*@months,
						DATEADD(WEEK, -1*@weeks,
						DATEADD(YEAR, -1*@years, getdate()))))
print 'Retention Date: ' +
	cast(convert(varchar(20),@retentionDate,112) as varchar(255))
--

