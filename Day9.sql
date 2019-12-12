DROP TABLE IF EXISTS IntCodeInputs
CREATE TABLE IntCodeInputs (
	InputNumber INT,
	Input INT
);

DROP TABLE IF EXISTS IntCodeOutputs
CREATE TABLE IntCodeOutputs (
	OutputNumber INT,
	Output INT
);
GO

CREATE OR ALTER PROCEDURE FetchOperand (@Mode int, @ProgramPointer INT, @Offset int, @Operand INT OUTPUT, @RelativeBase INT)
AS

	IF @Mode = 0
		SELECT @Operand = code FROM #opcodes where Position = (SELECT code from #OpCodes where Position = @ProgramPointer + @Offset)
	if @Mode = 1
		SELECT @Operand = code FROM #opcodes where Position = @ProgramPointer + @Offset
	IF @Mode = 2
		SELECT @Operand = code FROM #opcodes where Position = (SELECT code from #OpCodes where Position = @ProgramPointer + @Offset + @RelativeBase)
GO

CREATE OR ALTER PROCEDURE dbo.TestIntMachine (@opcodes varchar(8000))
AS

create table #opcodes (
	RowNo int identity (0,1), 
	Position INT,
	ParameterMode1 AS (substring(right('0000' + cast(code as varchar(6)),5), 3, 1)),
	ParameterMode2 AS (substring(right('0000' + cast(code as varchar(6)),5), 2, 1)),
	ParameterMode3 AS (substring(right('0000' + cast(code as varchar(6)),5), 1, 1)),
	Command AS cast((substring(right('0000' + cast(code as varchar(6)),5), 4, 2)) as int),
	Code bigint
)
INSERT INTO #opcodes (Code)
SELECT value
FROM STRING_SPLIT(@opcodes, ',')

UPDATE #opcodes
	SET Position = RowNo;

ALTER TABLE #opcodes
	DROP COLUMN RowNo;

declare @currentPosition int = 0,
	@CurrentOpCode int = 0,
	@Mode1 int,
	@Mode2 int,
	@Mode3 int,
	@Operand1 int, 
	@Operand2 int,
	@Operand3 int,
	@InputOffset INT = 1,
	@OutputOffset int = 1,
	@RelativeBase INT = 0;

while @CurrentOpCode != 99
	begin
		select @CurrentOpCode = Command,
				@mode1 = ParameterMode1,
				@mode2 = ParameterMode2,
				@Mode3 = ParameterMode3
			from #opcodes where Position = @currentPosition

		if @CurrentOpCode = 1
			-- add
			begin

				EXEC FetchOperand @Mode1, @CurrentPosition, 1, @Operand1 OUTPUT, @RelativeBase
				EXEC FetchOperand @Mode2, @CurrentPosition, 2, @Operand2 OUTPUT, @RelativeBase
				EXEC FetchOperand @Mode3, @CurrentPosition, 3, @Operand3 OUTPUT, @RelativeBase
				
				UPDATE #opcodes 
					SET code = @Operand1 + @Operand2
						WHERE Position = @Operand3

				set @currentPosition = @currentPosition + 4;
			end

		if @CurrentOpCode = 2
			-- multiply
			begin
				EXEC FetchOperand @Mode1, @CurrentPosition, 1, @Operand1 OUTPUT, @RelativeBase
				EXEC FetchOperand @Mode2, @CurrentPosition, 2, @Operand2 OUTPUT, @RelativeBase
				EXEC FetchOperand @Mode3, @CurrentPosition, 3, @Operand3 OUTPUT, @RelativeBase
				
				UPDATE #opcodes 
					SET code = @Operand1 * @Operand2
						WHERE Position = @Operand3

				set @currentPosition = @currentPosition + 4;
			end

		if @CurrentOpCode = 3
			-- input
			begin

				EXEC FetchOperand @Mode1, @CurrentPosition, 1, @Operand1 OUTPUT, @RelativeBase

				update #opcodes	
					SET code = (SELECT Input from IntCodeOutputs WHERE InputNumber = @InputOffset)
					WHERE Position = @Operand1

				SET @InputOffset += 1;
				SET @currentPosition += 2;
			end

		if @CurrentOpCode = 4
			-- output
			begin

				EXEC FetchOperand @Mode1, @CurrentPosition, 1, @Operand1 OUTPUT, @RelativeBase

				Insert into IntCodeOutputs (OutputNumber, Output)
				values (@Operand1, @OutputOffset)

				SET @OutputOffset += 1;
				SET @currentPosition += 2;
			end

		if @CurrentOpCode = 5
			-- jump if true
			begin

				EXEC FetchOperand @Mode1, @CurrentPosition, 1, @Operand1 OUTPUT, @RelativeBase
				EXEC FetchOperand @Mode2, @CurrentPosition, 2, @Operand2 OUTPUT, @RelativeBase

				if @Operand1 > 0
					set @currentPosition = @Operand2
				else 
					set @currentPosition = @currentPosition + 3;

			end

		if @CurrentOpCode = 6
			-- jump if false
			begin
				EXEC FetchOperand @Mode1, @CurrentPosition, 1, @Operand1 OUTPUT, @RelativeBase
				EXEC FetchOperand @Mode2, @CurrentPosition, 2, @Operand2 OUTPUT, @RelativeBase

				if @Operand1 = 0
					set @currentPosition = @Operand2
				else 
					set @currentPosition = @currentPosition + 3;
			end

		if @CurrentOpCode = 7
			-- is less than
			begin

				EXEC FetchOperand @Mode1, @CurrentPosition, 1, @Operand1 OUTPUT, @RelativeBase
				EXEC FetchOperand @Mode2, @CurrentPosition, 2, @Operand2 OUTPUT, @RelativeBase
				EXEC FetchOperand @Mode3, @CurrentPosition, 3, @Operand3 OUTPUT, @RelativeBase

				update #opcodes set code = case when @Operand1 < @Operand2 then 1 else 0 end
					where Position = (SELECT code from #OpCodes where Position = @CurrentPosition + 3)

				set @currentPosition = @currentPosition + 4;
			end

		if @CurrentOpCode = 8
			-- is equals
			begin

				EXEC FetchOperand @Mode1, @CurrentPosition, 1, @Operand1 OUTPUT, @RelativeBase
				EXEC FetchOperand @Mode2, @CurrentPosition, 2, @Operand2 OUTPUT, @RelativeBase
				EXEC FetchOperand @Mode3, @CurrentPosition, 3, @Operand3 OUTPUT, @RelativeBase

				update #opcodes set code = case when @Operand1 = @Operand2 then 1 else 0 end
					where Position = (SELECT code from #OpCodes where Position = @CurrentPosition + 3)

				set @currentPosition = @currentPosition + 4;
			end

		if @CurrentOpCode = 9
			--Opcode 9 adjusts the relative base by the value of its only parameter. The relative base increases (or decreases, if the value is negative) by the value of the parameter.
			begin
				EXEC FetchOperand @Mode1, @CurrentPosition, 1, @Operand1 OUTPUT, @RelativeBase

				set @RelativeBase += @Operand1;

				set @currentPosition = @currentPosition + 2;
			end

	end

