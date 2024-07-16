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
USE LPM.LPM_COMPONENTS.ALL;
USE IEEE.NUMERIC_STD.ALL;

--Reset: 000 
--Basic Countdown: 001
--Basic Stopwatch: 010
--HEX_Out, LED_Out, INT Countdown1: 011
--HEX_Out, LED_Out,  PAUSE Stopwatch1: 100
--Full Countdown2: 101
--Full Stopwatch2: 110
--_____________: 111

ENTITY TIMER2 IS
    PORT(CLOCK,
        RESETN,
        IO_WRITE,
        CS0,
		  CS1,
		  CS2,
		  CS3,
		  CS4,
		  CS5,
		  CS6,
		  CS7			: IN    STD_LOGIC;
        IO_DATA 	: INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
END TIMER2;

ARCHITECTURE a OF TIMER2 IS
    SIGNAL COUNT     : STD_LOGIC_VECTOR(15 DOWNTO 0);
	 SIGNAL COUNTDOWN     : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL IO_COUNT  : STD_LOGIC_VECTOR(15 DOWNTO 0); -- a stable copy of the count for the IO
    SIGNAL OUT_EN    : STD_LOGIC;
	 SIGNAL TIME_OUT_HEX0   : STD_LOGIC_VECTOR(15 DOWNTO 0);
	 SIGNAL TIME_OUT_HEX1   : STD_LOGIC_VECTOR(15 DOWNTO 0);

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
    OUT_EN <= (CS2 AND NOT(IO_WRITE));

    PROCESS (CLOCK, RESETN, CS2, IO_WRITE)
    BEGIN
        IF (RESETN = '0' OR (CS0) = '1') THEN
            COUNT <= x"0000";
        ELSIF (rising_edge(CLOCK)) THEN
            COUNT <= COUNT + 1;
        END IF;
    END PROCESS;

    -- Use a latch to prevent IO_COUNT from changing while an IO operation is occuring.
    -- Note that this is only safe because the clock used for this peripheral
    -- is derived from the same clock used for SCOMP; they're not separate
    -- clock domains.
    PROCESS (CS2, COUNT, IO_COUNT, TIME_OUT_HEX1, TIME_OUT_HEX0)
			variable TEMP_IO_COUNT2, TEMP_IO_COUNT3 : std_logic_vector(15 DOWNTO 0);
    BEGIN
	 
			TEMP_IO_COUnt2 := TIME_OUT_HEX0;
			TEMP_IO_COUnt3 := TIME_OUT_HEX1;
			
			IF CS3 = '1' THEN
				 IO_COUNT <= TEMP_IO_COUnt3;
				 TEMP_IO_COUNT3 := TEMP_IO_COUNT3;
			ELSIF CS2 = '1' THEN
				 IO_COUNT <= TEMP_IO_COUNT2;
				 TEMP_IO_COUNT2 := TEMP_IO_COUNT2;
			END IF;
			
    END PROCESS;
	 

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
        
        TIME_OUT_HEX1(15 downto 12) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(H_TENS, 4));
        TIME_OUT_HEX1(11 downto 8)  <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(H_ONES, 4));
        TIME_OUT_HEX1(7 downto 4)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(M_TENS, 4));
        TIME_OUT_HEX1(3 downto 0)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(M_ONES, 4));
        TIME_OUT_HEX0(15 downto 12) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(S_TENS, 4));
        TIME_OUT_HEX0(11 downto 8)  <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(S_ONES, 4));
        TIME_OUT_HEX0(7 downto 4)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(Cs_TENS, 4));
        TIME_OUT_HEX0(3 downto 0)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(Cs_ONES, 4));

	 END PROCESS;

END a;