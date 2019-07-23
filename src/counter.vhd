library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is
  port(
    clk : in std_logic;
    led : out std_logic_vector(7 downto 0)
  );
end counter;

architecture arch of counter is
  signal x : unsigned(7 downto 0);

  signal col      : unsigned(4 downto 0);
  signal offset_x : unsigned(2 downto 0);

  signal ram_addr : std_logic_vector(5 downto 0);
  signal ram_dout : std_logic_vector(7 downto 0);

  signal rom_addr : std_logic_vector(14 downto 0);
  signal rom_dout : std_logic_vector(7 downto 0);

  signal hi_byte    : std_logic_vector(7 downto 0);
  signal pixel_pair : std_logic_vector(7 downto 0);
  signal code       : unsigned(9 downto 0);
  signal color      : std_logic_vector(3 downto 0);
  signal pixel      : std_logic_vector(3 downto 0);
begin
  ram : entity work.single_port_rom
  generic map (
    ADDR_WIDTH    => 6,
    INIT_FILE     => "rom/tiles.mif",
    INSTANCE_NAME => "ram"
  )
  port map (
    clk  => not clk,
    addr => ram_addr,
    dout => ram_dout
  );

  rom : entity work.single_port_rom
  generic map (
    ADDR_WIDTH => 15,
    INIT_FILE  => "rom/cpu_8k.mif",
    INSTANCE_NAME => "rom"
  )
  port map (
    clk  => not clk,
    addr => rom_addr,
    dout => rom_dout
  );

  counter: process(clk)
  begin
    if rising_edge(clk) then
      x <= x + 1;
    end if;
  end process;

  process(clk, x)
  begin
    if rising_edge(clk) then
      case to_integer(offset_x) is
        when 2 => -- fetch high byte
          ram_addr <= std_logic_vector('1' & col);
        when 3 => -- latch high byte
          hi_byte <= ram_dout;
        when 4 => -- fetch low byte
          ram_addr <= std_logic_vector('0' & col);
        when 5 => -- latch code
          code <= unsigned(hi_byte(1 downto 0) & ram_dout);
        when 7 => -- latch colour
          color <= hi_byte(7 downto 4);
        when others => null;
      end case;
    end if;
  end process;

  latch_pixel_pair : process(clk)
  begin
    if rising_edge(clk) then
      if x(0) = '1' then
        pixel_pair <= rom_dout;
      end if;
    end if;
  end process;

  col <= x(7 downto 3);
  offset_x <= x(2 downto 0);

  rom_addr <= std_logic_vector(code & "000" & (x(2 downto 1)+1));

  pixel <= pixel_pair(7 downto 4) when x(0) = '1' else pixel_pair(3 downto 0);

  led <= color & pixel;
end arch;
