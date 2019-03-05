-------------------------------------------------------------------------------
--  Odsek za racunarsku tehniku i medjuracunarske komunikacije
--  Autor: LPRS2  <lprs2@rt-rk.com>                                           
--                                                                             
--  Ime modula: top                                                           
--                                                                             
--  Opis:                                                               
--                                                                             
--    vrh hijerarhije                                              
--                                                                             
-------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY top IS PORT (
                    i_clk    : in std_logic;
                    in_rst   : in std_logic;
                    i_sw     : in std_logic_vector(7 downto 0);
                    in_btn   : in std_logic_vector(4 downto 0);
                    o_led    : out std_logic_vector(7 downto 0);
                    o_7_segm : out std_logic_vector(6 downto 0)
                   );
END top;

ARCHITECTURE rtl OF top IS

-- instanciranje svih komponenti koje se nalaze u sistemu

-------------------------------------------------------------------
-- generator takta
-------------------------------------------------------------------
COMPONENT clk_gen IS PORT (
                           clkin_i       : IN  STD_LOGIC;
                           rst_i         : IN  STD_LOGIC;
                           clk_50MHz_o   : OUT STD_LOGIC;
                           clk_27MHz_o   : OUT STD_LOGIC;
                           reset_o       : OUT STD_LOGIC
                          );
END COMPONENT clk_gen;

-------------------------------------------------------------------
-- brojac taktova
-------------------------------------------------------------------
COMPONENT clk_counter IS
                    GENERIC(
                            max_cnt : STD_LOGIC_VECTOR(25 DOWNTO 0) := "10111110101111000010000000" -- 50 000 000
                           );
                    PORT   (
                             clk_i     : IN  STD_LOGIC;
                             rst_i     : IN  STD_LOGIC;
                             cnt_en_i  : IN  STD_LOGIC;
                             cnt_rst_i : IN  STD_LOGIC;
                             one_sec_o : OUT STD_LOGIC
                           );
END COMPONENT clk_counter;

-------------------------------------------------------------------
-- tajmer, prosiruje se za dva ulaza radi dodtnog zadatka
-------------------------------------------------------------------
COMPONENT timer_counter IS PORT (
                                 clk_i           : IN  STD_LOGIC;
                                 rst_i           : IN  STD_LOGIC;
                                 one_sec_i       : IN  STD_LOGIC;
                                 cnt_en_i        : IN  STD_LOGIC;
                                 cnt_rst_i       : IN  STD_LOGIC;
                                 button_min_i    : IN  STD_LOGIC;
                                 button_hour_i   : IN  STD_LOGIC;
                                 led_o           : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
                                );
END COMPONENT timer_counter;

-------------------------------------------------------------------
-- automat tajmera (fsm)
-------------------------------------------------------------------
COMPONENT timer_fsm IS PORT (
                             clk_i             : IN  STD_LOGIC;
                             rst_i             : IN  STD_LOGIC;
                             reset_switch_i    : IN  STD_LOGIC;
                             start_switch_i    : IN  STD_LOGIC;
                             stop_switch_i     : IN  STD_LOGIC;
                             continue_switch_i : IN  STD_LOGIC;
                             cnt_en_o          : OUT STD_LOGIC;
                             cnt_rst_o         : OUT STD_LOGIC
                            );
END COMPONENT timer_fsm;

-- dodatni modul koji sluzi da se pritisak tastera pravilno registruje
-- tj da se otklone oscilacije koje se javljaju prilikom pritiska

COMPONENT debouncer IS GENERIC(
                               one_pulse : STD_LOGIC := '0'
                              );
                        PORT (
                               pb_i                     : IN  STD_LOGIC;
                               clk_100Hz_i              : IN  STD_LOGIC;
                               rst_i                    : IN  STD_LOGIC;
                               pb_debounced_o           : OUT STD_LOGIC;
                               pb_debounced_one_pulse_o : OUT STD_LOGIC
                             );
END COMPONENT debouncer;

-- signali za povezivanje komponenti
SIGNAL clk_50MHz_s        : STD_LOGIC;
SIGNAL clk_27MHz_s       : STD_LOGIC;
SIGNAL clk_100Hz_s       : STD_LOGIC;
SIGNAL rst_locked_s      : STD_LOGIC;
SIGNAL one_sec_s         : STD_LOGIC;
SIGNAL led_s             : STD_LOGIC_VECTOR(7 DOWNTO 0);
SIGNAL cnt_rst_s         : STD_LOGIC;
SIGNAL cnt_en_s          : STD_LOGIC;
SIGNAL button_min_s      : STD_LOGIC;
SIGNAL button_hour_s     : STD_LOGIC;

BEGIN

clk_gen_i:clk_gen             PORT MAP(
                                       clkin_i     => i_clk        ,
                                       rst_i       => not in_rst  ,
                                       clk_50MHz_o => clk_50MHz_s     ,
                                       clk_27MHz_o => clk_27MHz_s     ,
                                       reset_o     => rst_locked_s
                                      );

clk_counter_i:clk_counter     PORT MAP(
                                       clk_i     => clk_50MHz_s   ,
                                       rst_i     => rst_locked_s ,
                                       cnt_en_i  => cnt_en_s     ,
                                       cnt_rst_i => cnt_rst_s    ,
                                       one_sec_o => one_sec_s
                                      );

-- clk_counter modul koji ce se iskoristiti za generisanje takta od 100Hz
clk_counter_100Hz_i:clk_counter GENERIC MAP(
                                             max_cnt => "00000001111010000100100000" 
															                                              -- DODATI KONSTANTU -- 500 000 Hz
					
                                           )
                                PORT MAP(
                                         clk_i     => clk_50MHz_s   ,
                                         rst_i     => rst_locked_s ,
                                         cnt_en_i  => '1'          ,
                                         cnt_rst_i => cnt_rst_s    ,
                                         one_sec_o => clk_100Hz_s
                                        );

-- dva debouncer modula za dva tastera koja su dodata
debouncer1_i:debouncer          PORT MAP(
                                          pb_i                              => in_btn(0)     , -- za minute
                                          clk_100Hz_i                       => clk_100Hz_s   ,
                                          rst_i                             => rst_locked_s  ,
                                          pb_debounced_one_pulse_o => open                   ,  
                                          pb_debounced_o                    => button_min_s
                                         );
                                
debouncer2_i:debouncer          PORT MAP(
                                          pb_i                              => in_btn(1)     , -- za sate
                                          clk_100Hz_i                       => clk_100Hz_s   ,
                                          rst_i                             => rst_locked_s  ,
                                          pb_debounced_one_pulse_o => open                   ,
                                          pb_debounced_o                => button_hour_s
                                         );

timer_counter_i:timer_counter PORT MAP(
                                       clk_i     => clk_50MHz_s   ,
                                       rst_i     => rst_locked_s ,
                                       one_sec_i => one_sec_s    ,
                                       cnt_en_i  => cnt_en_s     ,
                                       cnt_rst_i => cnt_rst_s    ,
                                       button_min_i    => button_min_s  ,
                                       button_hour_i   => button_hour_s ,
                                       led_o     => led_s
                                      );

timer_fsm_i:timer_fsm         PORT MAP(
                                       clk_i             => clk_50MHz_s   ,
                                       rst_i             => rst_locked_s ,
                                       reset_switch_i    => i_sw(0)      , -- RESET    PREKIDAC
                                       stop_switch_i     => i_sw(1)      , -- STOP     PREKIDAC
                                       start_switch_i    => i_sw(2)      , -- START    PREKIDAC
                                       continue_switch_i => i_sw(3)      , -- CONTINUE PREKIDAC
                                       cnt_en_o          => cnt_en_s     ,
                                       cnt_rst_o         => cnt_rst_s
                                      );

-- povezivanje signala na izlane pinove LE dioda

o_led  <= led_s;
o_7_segm <= (others => '0');

END rtl;
