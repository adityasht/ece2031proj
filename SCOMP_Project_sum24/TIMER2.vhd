-- TIMER2.VHD (a peripheral for SCOMP)
-- 2024.07.08
--
-- This timer provides a 16 bit counter value with a resolution of the CLOCK period.
-- Writing any value to timer resets to 0x0000, but the timer continues to run.
-- The counter value rolls over to 0x0000 after a clock tick at 0xFFFF.

LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
USE LPM.LPM_COMPONENTS.ALL;

--Reset: 000 
--Basic Stopwatch Start: 001
--HEX_Out, LED_Out, INT Countdown1: 011
--HEX_Out, LED_Out,  PAUSE Stopwatch1: 100
--Full Countdown2: 101
--Full Stopwatch2: 110
--_____________: 111

ENTITY TIMER2 IS
    PORT(CLOCK,
        RESETN,
        IO_WRITE,
		  Mode0,
		  Mode1,
		  Mode2,
		  Mode3,
		  Mode4,
		  Mode5,
		  Mode6,
        Mode7			:		IN    STD_LOGIC;
        IO_DATA		:		INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
		  
    );
END TIMER2;

ARCHITECTURE a OF TIMER2 IS
	 SIGNAL COUNT			: STD_LOGIC_VECTOR(23 DOWNTO 0);
	 SIGNAL COUNTDOWN		: STD_LOGIC_VECTOR(23 DOWNTO 0);
	 
    SIGNAL IO_COUNT  	: STD_LOGIC_VECTOR(15 DOWNTO 0); -- a stable copy of the count for the IO
    SIGNAL OUT_EN    	: STD_LOGIC;
	 
	 SIGNAL HR_M_Dec		: STD_LOGIC_VECTOR(15 DOWNTO 0);
	 SIGNAL S_Cs_Dec		: STD_LOGIC_VECTOR(15 DOWNTO 0);

    BEGIN

    -- Use Intel LPM IP to create tristate drivers
    IO_BUS: lpm_bustri
    GENERIC MAP (
        lpm_width => 16
    )
    PORT MAP (
        data     => IO_COUNT,
        enabledt => OUT_EN,
        tridata  => IO_DATA
    );

    -- IO data should be driven when SCOMP is requesting data
	 OUT_EN <= (NOT(IO_WRITE));

    PROCESS (CLOCK, RESETN, IO_WRITE)
    BEGIN
        IF (RESETN = '0' OR (Mode0) = '1') THEN
            COUNT <= x"000000";
				COUNTDOWN <= x"FFFFFF";
				
        ELSIF (rising_edge(CLOCK)) THEN
            COUNT <= COUNT + 1;
				COUNTDOWN <= COUNTDOWN - 1;
        END IF;
    END PROCESS;
	 
	 PROCESS (Mode2, COUNT, IO_COUNT, HR_M_Dec, S_Cs_Dec)
			variable TEMP_IO_COUNT2, TEMP_IO_COUNT3 : std_logic_vector(15 DOWNTO 0);
    BEGIN
	 
			TEMP_IO_COUnt2 := S_Cs_Dec;
			TEMP_IO_COUnt3 := HR_M_Dec;
			
			IF Mode3 = '1' THEN
				 IO_COUNT <= TEMP_IO_COUnt3;
				 TEMP_IO_COUNT3 := TEMP_IO_COUNT3;
			ELSIF Mode2 = '1' THEN
				 IO_COUNT <= TEMP_IO_COUNT2;
				 TEMP_IO_COUNT2 := TEMP_IO_COUNT2;
			END IF;
			
    END PROCESS;

    -- Use a latch to prevent IO_COUNT from changing while an IO operation is occuring.
    -- Note that this is only safe because the clock used for this peripheral
    -- is derived from the same clock used for SCOMP; they're not separate
    -- clock domains.
    PROCESS (Mode2, COUNT, IO_COUNT)
    BEGIN
        IF Mode2 = '1' THEN
            IO_COUNT <= IO_COUNT;
        ELSE
            IO_COUNT <= COUNT;
        END IF;
    END PROCESS;
	 
	 -- Converts Numbers into Decimal form for input to the HEx Display
	 PROCESS (CLOCK, COUNT)
    variable TEMP: INTEGER;
    variable H_TENS, H_ONES, M_TENS, M_ONES, S_TENS, S_ONES, Cs_TENS, Cs_ONES: INTEGER;
	 BEGIN
  
        TEMP := IEEE.NUMERIC_STD.to_integer(IEEE.NUMERIC_STD.unsigned(COUNT));
        
        H_TENS := TEMP / 360000; 
        H_ONES := (TEMP / 36000) mod 10;    
        TEMP := TEMP mod 36000;
        
        M_TENS := TEMP / 6000;          -- Calculate tens of minutes
        M_ONES := (TEMP mod 6000) / 600; -- Calculate ones of minutes
        TEMP := TEMP mod 600;
        
        S_TENS := TEMP / 100;           -- Calculate tens of seconds
        S_ONES := (TEMP mod 100) / 10;  -- Calculate ones of seconds
        
        Cs_TENS := (TEMP mod 10);       -- Calculate tens of centiseconds
        Cs_ONES := TEMP mod 10;         -- Calculate ones of centiseconds
        
        HR_M_Dec(15 downto 12) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(H_TENS, 4));
        HR_M_Dec(11 downto 8)  <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(H_ONES, 4));
        HR_M_Dec(7 downto 4)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(M_TENS, 4));
        HR_M_Dec(3 downto 0)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(M_ONES, 4));
        S_Cs_Dec(15 downto 12) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(S_TENS, 4));
        S_Cs_Dec(11 downto 8)  <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(S_ONES, 4));
        S_Cs_Dec(7 downto 4)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(Cs_TENS, 4));
        S_Cs_Dec(3 downto 0)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(Cs_ONES, 4));

	 END PROCESS;

END a;