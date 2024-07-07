Library std;
use std.textio.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.std_logic_textio.ALL;

entity tb_fir is
	
end tb_fir;

architecture struct of tb_fir is
	
	Component fir
		port (	
				enable 	: in std_logic;
				set_a 	: in std_logic;
				ready 	: out std_logic;
				ck 		: in std_logic;
				res_n 	: in std_logic;
				x_in 	: in std_logic_vector (7 downto 0);	
				y_out 	: out std_logic_vector (7 downto 0);
				a_in 	: in std_logic;
				valid_out : out std_logic;
				loading : out std_logic
		);
	end component;
	
	for all : fir USE ENTITY work.fir(decimated_fir);
--	for all : fir USE ENTITY work.fir(beh); -- per simulazione post-sintesi
--	for all : fir USE ENTITY work.fir(structure); -- per simulazione post-pr
	
	type coeff_vector_type is array (0 to 9) of std_logic_vector (7 downto 0); 	

	file file_in : text open read_mode is "C:\Esercitazione2\files\file_in.txt" ;
	file file_coeff : text open read_mode is "C:\Esercitazione2\files\file_coeff.txt";
	file file_out : text open write_mode is "C:\Esercitazione2\files\file_out.txt" ;
	signal  tb_ck 		: std_logic;
	signal  tb_res_n 	: std_logic;
	signal  tb_enable 	: std_logic;
	signal  tb_ready 	: std_logic;
	signal  tb_set_a 	: std_logic;
	signal  tb_x_in 	: std_logic_vector (7 downto 0) := (others => '0');	
	signal  tb_y_out 	: std_logic_vector (7 downto 0);
	signal  tb_a_in 	: std_logic;
	signal  tb_valid_out : std_logic;
	signal tb_loading : std_logic;
	constant half_ck_period: time := 5 ns; -- semiperiodo 56MHz ck

	-- simulation control internal signal
	signal close_files: std_logic :='0';	

	begin
	
	I1 : fir
      	PORT MAP (
         			ck       => tb_ck,
         			res_n    => tb_res_n,
         			x_in	 	  => tb_x_in,
         			y_out	 	 => tb_y_out,
         			enable 	 => tb_enable,
         			set_a 	  => tb_set_a,
         			ready 	  => tb_ready,
         			a_in 	 	 => tb_a_in,
				valid_out => tb_valid_out,
				loading => tb_loading
      			);
	
clk : process 
	begin
		
		tb_ck <= '0';
		wait for half_ck_period;
		tb_ck <= '1';
		wait for half_ck_period;
	end process clk;	
		
simulation: process
  variable linea : line;
  variable data_word : std_logic_vector (7 downto 0);
  variable coeff : coeff_vector_type;
  variable count : integer;
  begin 
  	-- read coeff_file
	count := 0;
	while not (endfile(file_coeff)) loop
		readline(file_coeff,linea);
		read (linea,data_word);
		for i in 7 downto 0 loop
			coeff(count)(i) := data_word(i);
		end loop;
		count := count + 1;
	end loop;
	-- start simulating
	tb_res_n <= '0';
	tb_set_a <= '0';
	tb_a_in <= '0';
	tb_enable <= '0';
	tb_x_in <= (others => '0');
	wait for 50 ns;
	tb_res_n <= '1';
	wait for 35 ns;
	wait until tb_ck'event and tb_ck = '1';	 
	tb_set_a <= '1';
	--wait until tb_loading = '1';
	wait until tb_ck'event and tb_ck = '0';
	for i in 0 to 9 loop -- serially load coefficients
		for j in 0 to 7 loop
			wait until tb_ck'event and tb_ck = '0';
			tb_a_in <= coeff(i)(j);
		end loop;
	end loop;
	wait until tb_ready = '1';
	wait for 48 ns;
	tb_set_a <= '0';
	wait for 55 ns;
	tb_enable <= '1';
	for i in 1 to 3 loop  -- account for FIR internal latency
		wait until tb_ck'event and tb_ck = '0';
	end loop;
	while not (endfile(file_in)) loop
		readline(file_in,linea);
		read (linea,data_word);
		tb_x_in <= data_word;
		wait until tb_ck'event and tb_ck = '0';
	end loop;
	tb_enable <= '0';
	close_files <= '1';
	wait; 
  end process simulation;
  
  write_output_file: process
  variable linea : line;
  variable data_word : std_logic_vector (7 downto 0);
  begin 
  	wait until tb_valid_out'event and tb_valid_out = '1';
	loop
		wait until tb_y_out'event or (close_files'event and close_files = '1');
	
		if close_files'event and close_files = '1' then
			file_close(file_out);
			file_close(file_in);
			file_close(file_coeff);
			assert false report "END OF SIMULATION" severity failure; 
		else
			data_word := tb_y_out;	
			write (linea,data_word);
			writeline (file_out,linea);
		end if;
	end loop;		
  end process write_output_file;

  
end struct;			