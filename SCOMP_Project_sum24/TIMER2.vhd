
LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;
USE LPM.LPM_COMPONENTS.ALL;
USE IEEE.NUMERIC_STD.ALL;

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
		  CS7,
        CS8         : IN    STD_LOGIC;
        IO_DATA     : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
END TIMER2;

ARCHITECTURE a OF TIMER2 IS
    SIGNAL COUNT     : STD_LOGIC_VECTOR(31 DOWNTO 0);
	 SIGNAL COUNTDOWN     : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL IO_COUNT  : STD_LOGIC_VECTOR(31 DOWNTO 0); -- a stable copy of the count for the IO
    SIGNAL OUT_EN    : STD_LOGIC;
    SIGNAL TIME_OUT_HEX0   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL TIME_OUT_HEX1   : STD_LOGIC_VECTOR(31 DOWNTO 0);
	 SIGNAL TIME_OUT_HEX2   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    SIGNAL TIME_OUT_HEX3   : STD_LOGIC_VECTOR(31 DOWNTO 0);
    TYPE STATE_TYPE IS (pause, play);
	 SIGNAL STstate, CDstate : STATE_TYPE;
	 SIGNAL WR_CS1, WR_CS2, WR_CS3, WR_CS4, WR_CS5, WR_CS6, WR_CS7 : std_logic_vector(1 DOWNTO 0);
	 
	 
BEGIN

    -- Use Intel LPM IP to create tristate drivers
    IO_BUS: lpm_bustri
    GENERIC MAP (
        lpm_width => 16
    )
    PORT MAP (
        data     => IO_COUNT(15 DOWNTO 0),
        enabledt => OUT_EN,
        tridata  => IO_DATA
    );
	 OUT_EN <= (NOT(IO_WRITE));

	 
	 
	 PROCESS(CLOCK, RESETN)
	  BEGIN
		 IF RESETN = '0' THEN
			STstate <= pause;
		 ELSIF CLOCK'EVENT AND CLOCK = '1' THEN
			CASE STstate IS
			  WHEN pause =>
				 CASE CS4 IS
					WHEN '1' =>
					  STstate <= play;
					WHEN OTHERS =>
					  STstate <= pause;
				 END CASE;
			  WHEN play =>
				 CASE CS1 IS
					WHEN '1' =>
					  STstate <= pause;
					WHEN OTHERS =>
					  STstate <= play;
				 END CASE;
			END CASE;
		 END IF;
	  END PROCESS;
	  
	  PROCESS(CLOCK, RESETN)
	  BEGIN
		 IF RESETN = '0' THEN
			CDstate <= pause;
		 ELSIF CLOCK'EVENT AND CLOCK = '1' THEN
			CASE CDstate IS
			  WHEN pause =>
				 CASE CS8 IS
					WHEN '1' =>
					  CDstate <= play;
					WHEN OTHERS =>
					  CDstate <= pause;
				 END CASE;
			  WHEN play =>
				 CASE CS5 IS
					WHEN '1' =>
					  CDstate <= pause;
					WHEN OTHERS =>
					  CDstate <= play;
				 END CASE;
			END CASE;
		 END IF;
	  END PROCESS;
    -- IO data should be driven when SCOMP is requesting data

    PROCESS (CLOCK, RESETN)
    BEGIN
        IF (RESETN = '0' OR CS0 = '1') THEN
            COUNT <= x"00000000";
        ELSIF (rising_edge(CLOCK) AND STstate = play) THEN
            COUNT <= COUNT + 1;
		  ELSIF (rising_edge(CLOCK) AND STstate = pause) THEN
            COUNT <= COUNT;
        END IF;
		  
		  IF (RESETN = '0' OR (CS0 = '1' AND IO_WRITE = '1')) THEN
            COUNTDOWN <= x"0000EA60";
		  ELSIF (rising_edge(CLOCK) AND CS5 = '1' AND IO_WRITE = '1') THEN
            COUNTDOWN(15 downto 0) <= IO_DATA;
        ELSIF (rising_edge(CLOCK)) THEN -- AND CDstate = play) THEN
            COUNTDOWN <= COUNTDOWN - 1;
		  --ELSIF (rising_edge(CLOCK) AND CDstate = pause) THEN
            --COUNTDOWN <= COUNTDOWN;
        END IF;
    END PROCESS;

    -- Use a latch to prevent IO_COUNT from changing while an IO operation is occurring.
    PROCESS (CS2, COUNT, IO_COUNT, TIME_OUT_HEX1, TIME_OUT_HEX0)
			variable TEMP_IO_COUNT1, TEMP_IO_COUNT2, TEMP_IO_COUNT3, TEMP_IO_COUNT6, TEMP_IO_COUNT7 : std_logic_vector(31 DOWNTO 0);
    BEGIN
			
			TEMP_IO_COUNT1 := COUNT;
			TEMP_IO_COUnt2 := TIME_OUT_HEX0;
			TEMP_IO_COUnt3 := TIME_OUT_HEX1;
			TEMP_IO_COUnt6 := TIME_OUT_HEX2;
			TEMP_IO_COUnt7 := TIME_OUT_HEX3;
			
			IF CS3 = '1' THEN
				 IO_COUNT <= TEMP_IO_COUnt3;
				 TEMP_IO_COUNT3 := TEMP_IO_COUNT3;
			ELSIF CS2 = '1' THEN
				 IO_COUNT <= TEMP_IO_COUNT2;
				 TEMP_IO_COUNT2 := TEMP_IO_COUNT2;
			ELSIF CS6 = '1' THEN
				 IO_COUNT <= TEMP_IO_COUNT6;
				 TEMP_IO_COUNT6 := TEMP_IO_COUNT6;
			ELSIF CS7 = '1' THEN
				 IO_COUNT <= TEMP_IO_COUNT7;
				 TEMP_IO_COUNT7 := TEMP_IO_COUNT7;
			--ELSIF CS1 = '1' THEN
				 --IO_COUNT <= TEMP_IO_COUNT1;
				 --TEMP_IO_COUNT1 := TEMP_IO_COUNT1;
			END IF;
			
    END PROCESS;

    PROCESS (CLOCK, COUNT)
        variable TEMP: INTEGER;
        variable H_TENS, H_ONES, M_TENS, M_ONES, S_TENS, S_ONES, Cs_TENS, Cs_ONES: INTEGER;
    BEGIN
        TEMP := IEEE.NUMERIC_STD.to_integer(IEEE.NUMERIC_STD.unsigned(COUNT));
        
        H_TENS := TEMP / 3600000; 
        TEMP := TEMP mod 3600000;
        
        H_ONES := TEMP / 360000;    
        TEMP := TEMP mod 360000;
        
        M_TENS := TEMP / 60000;          -- Calculate tens of minutes
        TEMP := TEMP mod 60000;
        
        M_ONES := TEMP / 6000;           -- Calculate ones of minutes
        TEMP := TEMP mod 6000;
        
        S_TENS := TEMP / 1000;           -- Calculate tens of seconds
        TEMP := TEMP mod 1000;
        
        S_ONES := TEMP / 100;            -- Calculate ones of seconds
        TEMP := TEMP mod 100;
        
        Cs_TENS := TEMP / 10;            -- Calculate tens of centiseconds
        Cs_ONES := TEMP mod 10;         -- Calculate ones of centiseconds
        
        TIME_OUT_HEX1(15 downto 12)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(H_TENS, 4));
        TIME_OUT_HEX1(11 downto 8)    <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(H_ONES, 4));
        TIME_OUT_HEX1(7 downto 4)     <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(M_TENS, 4));
        TIME_OUT_HEX1(3 downto 0)     <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(M_ONES, 4));
        TIME_OUT_HEX0(15 downto 12)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(S_TENS, 4));
        TIME_OUT_HEX0(11 downto 8)    <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(S_ONES, 4));
        TIME_OUT_HEX0(7 downto 4)     <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(Cs_TENS, 4));
        TIME_OUT_HEX0(3 downto 0)     <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(Cs_ONES, 4));
    END PROCESS;
	 
	 PROCESS (CLOCK, COUNTDOWN)
        variable TEMP: INTEGER;
        variable H_TENS, H_ONES, M_TENS, M_ONES, S_TENS, S_ONES, Cs_TENS, Cs_ONES: INTEGER;
    BEGIN
        TEMP := IEEE.NUMERIC_STD.to_integer(IEEE.NUMERIC_STD.unsigned(COUNTDOWN));
        
        H_TENS := TEMP / 3600000; 
        TEMP := TEMP mod 3600000;
        
        H_ONES := TEMP / 360000;    
        TEMP := TEMP mod 360000;
        
        M_TENS := TEMP / 60000;          -- Calculate tens of minutes
        TEMP := TEMP mod 60000;
        
        M_ONES := TEMP / 6000;           -- Calculate ones of minutes
        TEMP := TEMP mod 6000;
        
        S_TENS := TEMP / 1000;           -- Calculate tens of seconds
        TEMP := TEMP mod 1000;
        
        S_ONES := TEMP / 100;            -- Calculate ones of seconds
        TEMP := TEMP mod 100;
        
        Cs_TENS := TEMP / 10;            -- Calculate tens of centiseconds
        Cs_ONES := TEMP mod 10;         -- Calculate ones of centiseconds
        
        TIME_OUT_HEX3(15 downto 12)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(H_TENS, 4));
        TIME_OUT_HEX3(11 downto 8)    <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(H_ONES, 4));
        TIME_OUT_HEX3(7 downto 4)     <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(M_TENS, 4));
        TIME_OUT_HEX3(3 downto 0)     <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(M_ONES, 4));
        TIME_OUT_HEX2(15 downto 12)   <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(S_TENS, 4));
        TIME_OUT_HEX2(11 downto 8)    <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(S_ONES, 4));
        TIME_OUT_HEX2(7 downto 4)     <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(Cs_TENS, 4));
        TIME_OUT_HEX2(3 downto 0)     <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(Cs_ONES, 4));
    END PROCESS;

END a;

