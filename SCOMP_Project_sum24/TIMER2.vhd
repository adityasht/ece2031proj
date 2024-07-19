
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

    PROCESS (CLOCK, RESETN, IO_WRITE, STstate, CDstate, CS0, CS5)
    BEGIN
		  IF (RESETN = '0' OR (CS0 = '1' AND IO_WRITE = '0')) THEN
            COUNT <= x"00000000";
		  ELSIF rising_edge(CLOCK) THEN
			  IF (STstate = play) THEN
					COUNT <= COUNT + 1;
			  ELSIF (STstate = pause) THEN
					COUNT <= COUNT;
			  END IF;
        END IF;
		  
		  IF (RESETN = '0' OR (CS0 = '1' AND IO_WRITE = '1')) THEN
            COUNTDOWN <= x"0000EA60";
		  ELSIF rising_edge(CLOCK) THEN
			  IF (CS5 = '1' AND IO_WRITE = '1') THEN
					COUNTDOWN <= x"0000" & IO_DATA;  -- Read 16-bit input and extend to 32 bits
			  ELSIF (CDstate = play) THEN
					COUNTDOWN <= COUNTDOWN - 1;
			  ELSIF (CDstate = pause) THEN
					COUNTDOWN <= COUNTDOWN;
			  END IF;
        END IF;
    END PROCESS;

    -- Use a latch to prevent IO_COUNT from changing while an IO operation is occurring.
	PROCESS (CLOCK, RESETN)
    VARIABLE latched_data : STD_LOGIC_VECTOR(31 DOWNTO 0);
	BEGIN
		 IF RESETN = '0' THEN
			  IO_COUNT <= (OTHERS => '0');
			  latched_data := (OTHERS => '0');
		 ELSIF rising_edge(CLOCK) THEN
			  -- Latch the data when any CS signal goes high
			  IF CS1 = '1' THEN
					latched_data := COUNT;
			  ELSIF CS2 = '1' THEN
					latched_data := TIME_OUT_HEX0;
			  ELSIF CS3 = '1' THEN
					latched_data := TIME_OUT_HEX1;
			  ELSIF CS6 = '1' THEN
					latched_data := TIME_OUT_HEX2;
			  ELSIF CS7 = '1' THEN
					latched_data := TIME_OUT_HEX3;
			  END IF;

			  -- Always update IO_COUNT with the latched data
			  IO_COUNT <= latched_data;
		 END IF;
	END PROCESS;

	PROCESS (CLOCK)
		 VARIABLE TEMP: INTEGER;
		 VARIABLE H_TENS, H_ONES, M_TENS, M_ONES, S_TENS, S_ONES, Cs_TENS, Cs_ONES: INTEGER;
	BEGIN
		 IF rising_edge(CLOCK) THEN
			  IF CS2 = '1' OR CS3 = '1' THEN
					TEMP := IEEE.NUMERIC_STD.to_integer(IEEE.NUMERIC_STD.unsigned(COUNT));
					
					H_TENS := TEMP / 3600000; 
					TEMP := TEMP mod 3600000;
					
					H_ONES := TEMP / 360000;    
					TEMP := TEMP mod 360000;
					
					M_TENS := TEMP / 60000;
					TEMP := TEMP mod 60000;
					
					M_ONES := TEMP / 6000;
					TEMP := TEMP mod 6000;
					
					S_TENS := TEMP / 1000;
					TEMP := TEMP mod 1000;
					
					S_ONES := TEMP / 100;
					TEMP := TEMP mod 100;
					
					Cs_TENS := TEMP / 10;
					Cs_ONES := TEMP mod 10;
					
					TIME_OUT_HEX1(15 downto 0) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(H_TENS, 4) & IEEE.NUMERIC_STD.to_unsigned(H_ONES, 4) &
																 IEEE.NUMERIC_STD.to_unsigned(M_TENS, 4) & IEEE.NUMERIC_STD.to_unsigned(M_ONES, 4));
					TIME_OUT_HEX0(15 downto 0) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(S_TENS, 4) & IEEE.NUMERIC_STD.to_unsigned(S_ONES, 4) &
																 IEEE.NUMERIC_STD.to_unsigned(Cs_TENS, 4) & IEEE.NUMERIC_STD.to_unsigned(Cs_ONES, 4));
			  END IF;

			  IF CS6 = '1' OR CS7 = '1' THEN
					TEMP := IEEE.NUMERIC_STD.to_integer(IEEE.NUMERIC_STD.unsigned(COUNTDOWN));
					
					H_TENS := TEMP / 3600000; 
					TEMP := TEMP mod 3600000;
					
					H_ONES := TEMP / 360000;    
					TEMP := TEMP mod 360000;
					
					M_TENS := TEMP / 60000;
					TEMP := TEMP mod 60000;
					
					M_ONES := TEMP / 6000;
					TEMP := TEMP mod 6000;
					
					S_TENS := TEMP / 1000;
					TEMP := TEMP mod 1000;
					
					S_ONES := TEMP / 100;
					TEMP := TEMP mod 100;
					
					Cs_TENS := TEMP / 10;
					Cs_ONES := TEMP mod 10;
					
					TIME_OUT_HEX3(15 downto 0) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(H_TENS, 4) & IEEE.NUMERIC_STD.to_unsigned(H_ONES, 4) &
																 IEEE.NUMERIC_STD.to_unsigned(M_TENS, 4) & IEEE.NUMERIC_STD.to_unsigned(M_ONES, 4));
					TIME_OUT_HEX2(15 downto 0) <= std_logic_vector(IEEE.NUMERIC_STD.to_unsigned(S_TENS, 4) & IEEE.NUMERIC_STD.to_unsigned(S_ONES, 4) &
																 IEEE.NUMERIC_STD.to_unsigned(Cs_TENS, 4) & IEEE.NUMERIC_STD.to_unsigned(Cs_ONES, 4));
			  END IF;
		 END IF;
	END PROCESS;
END a;

