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

  -- A register that holds the colour and code for a single tile in the
  -- tilemap. The 16-bit tile data values aren't stored contiguously in RAM,
  -- instead they are split into high and low bytes. The high bytes are stored
  -- in the upper-half of the RAM, while the low bytes are stored in the
  -- lower-half.
  signal tile_data : std_logic_vector(15 downto 0);

  -- A register that holds next two 4-bit pixels to be rendered.
  signal gfx_data : std_logic_vector(7 downto 0);

  signal code  : unsigned(9 downto 0);
  signal color : std_logic_vector(3 downto 0);
  signal pixel : std_logic_vector(3 downto 0);
begin
  ram: entity work.single_port_rom
  generic map(
    ADDR_WIDTH    => 6,
    INIT_FILE     => "rom/tiles.mif",
    INSTANCE_NAME => "ram"
  )
  port map(
    clk  => not clk,
    addr => ram_addr,
    dout => ram_dout
  );

  rom: entity work.single_port_rom
  generic map(
    ADDR_WIDTH => 15,
    INIT_FILE  => "rom/cpu_8k.mif",
    INSTANCE_NAME => "rom"
  )
  port map(
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

  fsm: process(clk)
  begin
    if rising_edge(clk) then
      case to_integer(offset_x) is
        when 2 =>
          -- load high byte
          ram_addr <= std_logic_vector('1' & col);

        when 3 =>
          -- latch high byte
          tile_data(15 downto 8) <= ram_dout;

          -- load low byte
          ram_addr <= std_logic_vector('0' & col);

        when 4 =>
          -- latch low byte
          tile_data(7 downto 0) <= ram_dout;

        when 5 =>
          -- latch code
          code <= unsigned(tile_data(9 downto 0));

        when 7 =>
          -- latch colour
          color <= tile_data(15 downto 12);

        when others => null;
      end case;
    end if;
  end process;

  -- latch gfx data every two pixels
  latch_gfx_data: process(clk)
  begin
    if rising_edge(clk) then
      if x(0) = '1' then
        gfx_data <= rom_dout;
      end if;
    end if;
  end process;

  col <= x(7 downto 3);
  offset_x <= x(2 downto 0);

  -- load gfx data
  rom_addr <= std_logic_vector(code & "000" & (x(2 downto 1)+1));

  -- decode the high/low pixel from the gfx data
  pixel <= gfx_data(7 downto 4) when x(0) = '1' else gfx_data(3 downto 0);

  -- palette index
  led <= color & pixel;
end arch;
