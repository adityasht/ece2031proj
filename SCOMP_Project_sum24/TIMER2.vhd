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
		  Mode0,
		  Mode1,
		  Mode2,
		  Mode3,
		  Mode4,
		  Mode5,
		  Mode6,
        Mode7			:		IN    STD_LOGIC;
        IO_DATA		:		INOUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		  TIME_Out		:		OUT STD_LOGIC_VECTOR(23 DOWNTO 0);
		  HexDisp_Out	:		OUT STD_LOGIC_VECTOR(23 DOWNTO 0)
    );
END TIMER2;

ARCHITECTURE a OF TIMER2 IS
    SIGNAL COUNT     : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL IO_COUNT  : STD_LOGIC_VECTOR(15 DOWNTO 0); -- a stable copy of the count for the IO
    SIGNAL OUT_EN    : STD_LOGIC;

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
    OUT_EN <= (Mode1 AND NOT(IO_WRITE));

    PROCESS (CLOCK, RESETN, Mode2, IO_WRITE)
    BEGIN
        IF (RESETN = '0' OR (Mode2 AND IO_WRITE) = '1') THEN
            COUNT <= x"0000";
        ELSIF (rising_edge(CLOCK)) THEN
            COUNT <= COUNT + 1;
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
	 PROCESS (CLOCK, RESETN, COUNT, HexDisp_Out)
		  variable temp : integer;
        variable thousands, hundreds, tens, ones : integer;
	 BEGIN
	     temp 			:= IEEE.NUMERIC_STD.to_integer(IEEE.NUMERIC_STD.unsigned(COUNT));
		  thousands		:= temp / 1000;
        temp			:= temp mod 1000;
        hundreds		:= temp / 100;
        temp			:= temp mod 100;
        tens			:= temp / 10;
        ones			:= temp mod 10;
        
		  HexDisp_Out(15 downto 12) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(thousands, 4));
        HexDisp_Out(11 downto 8) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(hundreds, 4));
        HexDisp_Out(7 downto 4) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(tens, 4));
        HexDisp_Out(3 downto 0) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(ones, 4));
    END PROCESS;

END a;