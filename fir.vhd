LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

ENTITY fir IS
   PORT(
      ck 		: in std_logic;   --one bit input clock	signal
      res_n 	: in std_logic;	   --one bit input reset signal active low 0x00
      enable 	: in std_logic;    --one bit input enable  active high
      set_a 	: in std_logic;    --one bit input enable loading of coefficients active high
      a_in  	: in std_logic;    --one bit   serial port for loading coeficients
      x_in 		: in std_logic_vector (7 downto 0); -- 8bit signal. filter input
      y_out 	: out std_logic_vector (7 downto 0);-- 8bit output of the filter with decimation 0.1(in signal processing, decimation by a factor of 10
	   --actually means keeping only every tenth sample. consider first lecture of the FIR designing. )
	   
	   
      ready 	: out std_logic;   --one bit signal to the control unit that the coeficient loading have completed succesfully 
	 valid_out: out std_logic; --one bit signal to the control unit that the filter output is valid 
      loading : out std_logic     -- one bit signal to the control unit that the coefficients are being loaded serially
         );


END fir ;


ARCHITECTURE decimated_fir OF fir IS

   constant shift_reg_width : integer := 80; -- coeff_width * num_coeff

   type control_signal_1 is (select_9, select_7, select_5, select_3, select_1 ); -- types for control signal 0 (enumerater )            	
   type control_signal_2 is (select_8, select_6, select_4, select_2, select_0 ); -- types for control signal 1             	
                                
   type ctrl_state_type is (S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11);
   type load_coeff_state_type is (S0, S1, S2, s3);
   type valid_out_state_type is (S0, S1);
   
   attribute syn_keep : boolean;   --true only in case of assigning to, in line (77 ) true only in case of y_int assign to syn_keep
   attribute s : string;

   signal a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, x_odd, x_even : std_logic_vector (7 downto 0);  
                                        -- internal registers                                                                        
   signal acc1, acc2 : std_logic_vector (15 downto 0);  -- internal registers

   signal y_int : std_logic_vector (15 downto 0);

   signal rp1, rp2 : std_logic_vector (15 downto 0);

   signal load_odd, load_even : std_logic;  -- enable x registers
   signal load_out : std_logic;

   signal mux1_ctrl : control_signal_1;
   signal mux2_ctrl : control_signal_2;

   signal mult1_in1, mult1_in2, mult2_in1, mult2_in2 : std_logic_vector (7 downto 0);

   signal shift_reg, enable_set_reg : std_logic; -- control setting a registers

   signal load_rp1_acc1, load_rp2_acc2, reset_acc1, reset_acc2: std_logic;  -- load rp registers

   signal state, nextstate : ctrl_state_type;

   signal load_coeff_state, load_coeff_nextstate : load_coeff_state_type;

   signal valid_out_state, valid_out_nextstate : valid_out_state_type;

   signal j : integer range 1 to 81;

   signal out_sign1, out_sign2 : signed (15 downto 0);  

   signal mult1_in1_sign, mult2_in1_sign : signed (7 downto 0); 
   signal mult1_in2_sign, mult2_in2_sign : signed (7 downto 0); 

   signal out1 : std_logic_vector (15 downto 0); 
   signal out2 : std_logic_vector (15 downto 0); 
   
   attribute syn_keep of y_int : signal is true;
   attribute s of y_int : signal is "yes";


   --attribute noreduce of y_int : signal is "yes";
   --attribute keep of out1 : signal is "true";


BEGIN

---------------------------------------------------------------------------------  
--   CONTROL PATH
---------------------------------------------------------------------------------  

  -- purpose: update control FSM state
  -- type   : sequential
  -- inputs : ck, res_n
  -- outputs: load_coeff_state 
	
-------------------------------------process state coeficients load-------------------------------------  
fsm_load_coeff: process (ck, res_n)
  
  begin 
    if res_n = '0' then      --activate on low            
      load_coeff_state <= S0;
	  
	  
	  
    elsif ck'event and ck = '1' then    -- on rising edge 
     load_coeff_state <= load_coeff_nextstate; --(s1,s2,s3) below
    end if;
  end process fsm_load_coeff;
---------------------------------------------------------------------------------------------------------	    
	    
	    
---------------------------------process next coef load------------------------------------------------------------
fsm_nextstate_load_coeff: process (load_coeff_state, enable, set_a, j) --finite state machine(page 4 )
  
  begin  
    case load_coeff_state is
      --------------------------------------------s0-----------------------------------------------------------------    
      when S0  => if enable = '0' and set_a = '1' then ----enable & set_a active high
                    load_coeff_nextstate <= S1;
                  else
                    load_coeff_nextstate <= S0;
                  end if;
      -------------------------------------------s1--------------------------------------------------------------------
      when S1 => if enable = '1' or set_a = '0' then 
      			 load_coeff_nextstate <= S0;
   			  elsif j = shift_reg_width then  ---if j=80
      			 load_coeff_nextstate <= S2;
 			  else
 			      load_coeff_nextstate <= S1;
 			  end if;
      -------------------------------------------s2---------------------------------------------------------------------			  
      when S2 => if enable = '1' then
	 			 load_coeff_nextstate <= S0;
			  elsif set_a = '0' then -- ACK
			  	 load_coeff_nextstate <= S3;
                 else -- loop until ACK
			  	 load_coeff_nextstate <= S2;
	            end if;
      --------------------------------------s3-------------------------------------------------------------------------		    
      when S3 => load_coeff_nextstate <= S0;
      when others => null;
    end case;
  end process fsm_nextstate_load_coeff;
	    
-----------------------------------------------------------------output_load process-------------------------------------------------------	    
  

fsm_output_load_coeff: process (load_coeff_state) -----again ASM page number 4------------------------------------
  
  begin  
    case load_coeff_state is
--------------------------------------------s0----------------------------------------------------------------- 	    
      when S0 => ready <= '0';
      		  shift_reg <= '0';
      		  enable_set_reg <= '0';
--------------------------------------------s1----------------------------------------------------------------- 	    
      when S1 => ready <= '0';
      	       shift_reg <= '1';
      		  enable_set_reg <= '0';
	
--------------------------------------------s2(only at state 2 the coeff has loaded compleately)----------------------------------------------------------------- 	
      when S2 => ready <= '1';
      	       shift_reg <= '0';
      	       enable_set_reg <= '0';	
--------------------------------------------s3------------------------------------------------------------------------------------------------------------------- 
	 when S3 => ready <= '0';
			  shift_reg <= '0';
			  enable_set_reg <= '1';
      when others => null;
    end case;
  
  end process fsm_output_load_coeff;
-----------------------------------------------------------------------------------------------------------------	    
-------------------------------------------------------------shift register loading coeffs(pg 5)--------------------------------------------------------- 
 loading <= shift_reg; -- ACK        
     		   
shift_coeff : process (res_n, ck) -- implement shift register controlled by load_coeff_fsm
	begin
		
		if res_n = '0' then    --ten bits as described before for coefs             
      		a0 <= (others => '0');
      		a1 <= (others => '0');
      		a2 <= (others => '0');
      		a3 <= (others => '0');
      		a4 <= (others => '0');
      		a5 <= (others => '0');
      		a6 <= (others => '0');
      		a7 <= (others => '0');
      		a8 <= (others => '0');
      		a9 <= (others => '0');
			j <= 1;
		
      	elsif ck'event and ck = '1' then
			
			if shift_reg = '1' then
				
				a9(a9'high) <= a_in;  --if 
				                 
				for i in 0 to (a0'high - 1) loop                     ---- loading coeff (from a0 to a9) via shift register
					a0(i) <= a0(i+1);
				end loop;
				a0(a0'high) <= a1(0);

				for i in 0 to (a1'high - 1) loop
					a1(i) <= a1(i+1);
				end loop;
				a1(a1'high) <= a2(0);

				for i in 0 to (a2'high - 1) loop
					a2(i) <= a2(i+1);
				end loop;
				a2(a2'high) <= a3(0);

				for i in 0 to (a3'high - 1) loop
					a3(i) <= a3(i+1);
				end loop;
				a3(a3'high) <= a4(0);

				for i in 0 to (a4'high - 1) loop
					a4(i) <= a4(i+1);
				end loop;
				a4(a4'high) <= a5(0);

				for i in 0 to (a5'high - 1) loop
					a5(i) <= a5(i+1);
				end loop;
				a5(a5'high) <= a6(0);

				for i in 0 to (a6'high - 1) loop
					a6(i) <= a6(i+1);
				end loop;
				a6(a6'high) <= a7(0);

				for i in 0 to (a7'high - 1) loop
					a7(i) <= a7(i+1);
				end loop;
				a7(a7'high) <= a8(0);

				for i in 0 to (a8'high - 1) loop
					a8(i) <= a8(i+1);
				end loop;
				a8(a8'high) <= a9(0);

				for i in 0 to (a9'high - 1) loop
					a9(i) <= a9(i+1);
				end loop;
				
				j <= j+1;
			else 
				j <= 1;
			end if;	
		end if;	
end process shift_coeff;		  
-------------------------------------------------------control of data path(page 7)-------------------------------------------------------------------------------------------------
fsm_ctrlpath: process (ck, res_n)
  
  
 begin 
    if res_n = '0' then      --activate on low            
      state <= S0;
	  
    elsif ck'event and ck = '1' then    -- on rising edge 
     state <= nextstate; --(s1,s2,s3,...s11) below
     end if;
  end process fsm_ctrlpath;

  -- purpose: set next state for control FSM
  -- type   : combinational
  -- inputs : state, enable, enable_set_reg, set_a
  -- outputs: nextstate
 -------------------------------------------------------------------------------------------------------------------------------------------------------------------- 
					       
					       
					       
 fsm_nextstate_ctrlpath: process (state, enable, enable_set_reg, set_a)
  
  begin  -- process fsm_ctrl_nextstate
    case state is
      when S0  => if enable_set_reg = '1' then
                    nextstate <= S1;
                  else -- unsensitive to enable if enable_set_reg is low
                    nextstate <= S0;
                  end if;
      when S1 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '1' then
               	    nextstate <= S2;
                  else
                    nextstate <= S1;
                  end if;
      when S2 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '0' then
                    nextstate <= S1;
                  else
                    nextstate <= S3;
                  end if;
      when S3 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '0' then
                    nextstate <= S1;
                  else
                    nextstate <= S4;
                  end if;
      when S4 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '0' then
                    nextstate <= S1;
                  else
                    nextstate <= S5;
                  end if;
      when s5 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '0' then
                    nextstate <= S1;
                  else
                    nextstate <= S6;
                  end if;
      when S6 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '0' then
                    nextstate <= S1;
                  else
                    nextstate <= S7;
                  end if;
      when S7 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '0' then
                    nextstate <= S1;
                  else
                    nextstate <= S8;
                  end if;
      when S8 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '0' then
                    nextstate <= S1;
                  else
                    nextstate <= S9;
                  end if;
      when S9 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '0' then
                    nextstate <= S1;
                  else
                    nextstate <= S10;
                  end if;
      when s10 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '0' then
                    nextstate <= S1;
                  else
                    nextstate <= S11;
                  end if;
      when S11 => if set_a = '1' then
                    nextstate <= S0;
                  elsif enable = '0' then
                    nextstate <= S1;
                  else
                    nextstate <= S2;
                  end if;
      when others => nextstate<= S0;
    end case;
  end process fsm_nextstate_ctrlpath;
--------------------------------------------------------------------------------------------------------------------------------------------------------
  -- purpose: set control FSM outputs
  -- type   : combinational
  -- inputs : ck, res_n
  -- outputs: mux1_ctrl, mux2_ctrl, load_odd, load_even, load_rp1_acc1, load_rp2_acc2, load_out, reset_acc2
  
 fsm_output_ctrlpath_state: process (ctrlpath_state)
  
  begin  -- process fsm_ctrl_output
  -- INSERIRE QUI LOGICA DI PILOTAGGIO DELLE USCITE - GRUPPO1
  -- asynchronous reset (active low)
  case ctrlpath_state is:
--------------------------------------------------------------------s0-----------------------------------------------------------------------------------					       
   when   s0 
	load_odd=0;
	load_even=0;				       
	mux1_ctrl= select_1;			       
 	mux2_ctrl=select_0;
  	load_rp1_acc1=0;
	load_rp2_acc2=0;				       
	load_out=0;				   --
	reset_acc2=0;				       
 -------------------------------------------------------------------s1-----------------------------------------------------------------------------------
	  when   s1 
	load_odd=0;
	load_even=0;				       
	mux1_ctrl= select_1;			       
 	mux2_ctrl=select_0;
  	load_rp1_acc1=0;
	load_rp2_acc2=0;				       
	load_out=0;				   --
	reset_acc2=0;	
					       
--------------------------------------------------------------------s2---------------------------------------------------------------------------------					       
	when   s2 
	load_odd=1;
	load_even=0;				       
	mux1_ctrl= select_1;			       
 	mux2_ctrl=select_0;
  	load_rp1_acc1=1;
	load_rp2_acc2=0;				       
	load_out=0;				   --
	reset_acc2=0;		
--------------------------------------------------------------------s3---------------------------------------------------------------------------------				       
	when   s3 
	load_odd=0;
	load_even=1;				       
	mux1_ctrl= select_9;			       
 	mux2_ctrl=select_0;
  	load_rp1_acc1=0;
	load_rp2_acc2=1;				       
	load_out=0;				   --
	reset_acc2=0;		
					       
--------------------------------------------------------------------s4--------------------------------------------------------------------------------					       
        when   s4 
	load_odd=1;
	load_even=0;				       
	mux1_ctrl= select_9;			       
 	mux2_ctrl=select_8;
  	load_rp1_acc1=1;
	load_rp2_acc2=0;				       
	load_out=0;				   --
	reset_acc2=0;	
					       
--------------------------------------------------------------------s5---------------------------------------------------------------------------------					       
	when   s5 
	load_odd=0;
	load_even=1;				       
	mux1_ctrl= select_7;			       
 	mux2_ctrl=select_8;
  	load_rp1_acc1=0;
	load_rp2_acc2=1;				       
	load_out=0;				   --
	reset_acc2=0;	
					       
---------------------------------------------------------------------s6--------------------------------------------------------------------------------					       
	when   s6 
	load_odd=1;
	load_even=0;				       
	mux1_ctrl= select_7;			       
 	mux2_ctrl=select_6;
  	load_rp1_acc1=1;
	load_rp2_acc2=0;				       
	load_out=0;				   --
	reset_acc2=0;	
					       
----------------------------------------------------------------------s7-------------------------------------------------------------------------------					       
	when   s7 
	load_odd=0;
	load_even=1;				       
	mux1_ctrl= select_5;			       
 	mux2_ctrl=select_6;
  	load_rp1_acc1=0;
	load_rp2_acc2=1;				       
	load_out=0;				   --
	reset_acc2=0;	
					       
-----------------------------------------------------------------------s8------------------------------------------------------------------------------					       
	 when   s8 
	load_odd=1;
	load_even=0;				       
	mux1_ctrl= select_5;			       
 	mux2_ctrl=select_4;
  	load_rp1_acc1=1;
	load_rp2_acc2=0;				       
	load_out=0;				   --
	reset_acc2=0;
					       
-----------------------------------------------------------------------s9------------------------------------------------------------------------------					       
	when   s9 
	load_odd=0;
	load_even=1;				       
	mux1_ctrl= select_3;			       
 	mux2_ctrl=select_4;
  	load_rp1_acc1=0;
	load_rp2_acc2=1;				       
	load_out=0;				   --
	reset_acc2=0;	
					       
------------------------------------------------------------------------s10-----------------------------------------------------------------------------					       
	when   s10 
	load_odd=1;
	load_even=0;				       
	mux1_ctrl= select_3;			       
 	mux2_ctrl=select_2;
  	load_rp1_acc1=1;
	load_rp2_acc2=0;				       
	load_out=0;				   --
	reset_acc2=0;	
					       
					       
-------------------------------------------------------------------------s11----------------------------------------------------------------------------					       
	when   s11 
	load_odd=0;
	load_even=1;				       
	mux1_ctrl= select_1;			       
 	mux2_ctrl=select_2;
  	load_rp1_acc1=0;
	load_rp2_acc2=1;				       
	load_out=0;				   --
	reset_acc2=0;		
					       
					       
					       
   end process fsm_output_ctrlpath_state;
					       
					       


 ------------------------------------------------------------------------------
 -- COMBINATIONAL LOGIC (DATA PATH)
 ------------------------------------------------------------------------------

  mult1_in1 <= x_odd;

  mult2_in1 <= x_even;

  mux1 : mult1_in2 <= a9 when mux1_ctrl = select_9 else
                      a7 when mux1_ctrl = select_7 else
                      a5 when mux1_ctrl = select_5 else
                      a3 when mux1_ctrl = select_3 else
                      a1 when mux1_ctrl = select_1 else
                      a9;

  mux2 : mult2_in2 <= a8 when mux2_ctrl = select_8 else
                      a6 when mux2_ctrl = select_6 else
                      a4 when mux2_ctrl = select_4 else
                      a2 when mux2_ctrl = select_2 else
                      a0 when mux2_ctrl = select_0 else
                      a8;

   -- casting to signed (implement 2's complement arithmetic)
   mult1_in1_sign <= signed( mult1_in1 );
   mult1_in2_sign <= signed( mult1_in2 );
   mult2_in1_sign <= signed( mult2_in1 );
   mult2_in2_sign <= signed( mult2_in2 );
   -- multipliers
   out_sign1 <= mult1_in1_sign * mult1_in2_sign;
   out_sign2 <= mult2_in1_sign * mult2_in2_sign;
   out1 <= conv_std_logic_vector (out_sign1,16);
   out2 <= conv_std_logic_vector (out_sign2,16);
     
   -- control signal
   reset_acc1 <= load_out;
  
-------------------------------------------------------------------------------
  -- REGISTERS (DATA PATH)
-------------------------------------------------------------------------------

  --INSERIRE QUI IMPLEMENTAZIONE REGISTRI X_ODD, X_EVEN

  --
 
  
  rp_registers: process (ck, res_n)
  
  begin  -- process rp_registers
    if res_n = '0' then                 -- asynchronous reset (active low)
      rp1 <= (others => '0');
      rp2 <= (others => '0');
    elsif ck'event and ck = '1' then    -- rising clock edge
      if load_rp1_acc1 = '1' then 
         rp1 <= out1;
      end if;
      if load_rp2_acc2 = '1' then
         rp2 <= out2;
      end if;
    end if;
  end process rp_registers;

   -- purpose: load acc registers
   -- type   : sequential
   -- inputs : ck, res_n
   -- outputs: acc1, acc2
  
  acc_registers: process (ck, res_n)
   
   begin  -- process acc_registers
     if res_n = '0' then                -- asynchronous reset (active low)
       acc1 <= (others => '0');
       acc2 <= (others => '0');
     elsif ck'event and ck = '1' then   -- rising clock edge
       if load_rp1_acc1 = '1' then
       	if reset_acc1 = '1' then
       		acc1 <= rp1;
       	else  
       		acc1 <= acc1 + rp1;
       	end if;
       end if;
       if load_rp2_acc2 = '1' then
       	if reset_acc2 = '1' then
       		acc2 <= rp2;
       	else  
       		acc2 <= acc2 + rp2;
       	end if;
       end if;
     end if;
   end process acc_registers; 
    
  
  -- purpose: load output
  -- type   : sequential
  -- inputs : ck, res_n
  -- outputs: y_int
  
 y_int_register: process (ck, res_n)
  begin  -- process y_register
    if res_n = '0' then                 -- asynchronous reset (active low)
      y_int <= (others => '0');
    elsif ck'event and ck = '1' then    -- rising clock edge
      if load_out = '1' then
        y_int <= acc1 + acc2;
      end if;
    end if;
  end process y_int_register;
  
  y_out <= y_int (14 downto 7); -- truncated output
  
  -----------------------------------------------------------------------------
  -- VALID_OUT FSM
  -----------------------------------------------------------------------------
  
  fsm_valid_out: process (ck, res_n)
  
  begin 
    if res_n = '0' then                 
      valid_out_state <= S0;
    elsif ck'event and ck = '1' then    
     valid_out_state <= valid_out_nextstate;
    end if;
  end process fsm_valid_out;

fsm_nextstate_valid_out: process (valid_out_state, enable, set_a, load_out)
  
  begin  
    case valid_out_state is
      when S0  => if load_out = '1' then
                    valid_out_nextstate <= S1;
				  else 
				  	valid_out_nextstate <= S0;
                  end if;      
      when S1 => if enable = '0' or set_a = '1' then 
      			 valid_out_nextstate <= S0;
 			  else
 			      valid_out_nextstate <= S1;
 			  end if;
      when others => null;
    end case;
  end process fsm_nextstate_valid_out;

  -- drive valid_out
  valid_out <= '1' when valid_out_state = S1 else
  			'0'; 
  
END decimated_fir;
