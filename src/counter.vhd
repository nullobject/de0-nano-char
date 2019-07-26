library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.types.all;

entity counter is
  port (
    clk : in std_logic;
    led : out byte_t
  );
end counter;

architecture arch of counter is
  -- video signals
  signal video_pos   : pos_t;
  signal video_sync  : sync_t;
  signal video_blank : blank_t;

  -- RAM signals
  signal ram_addr : std_logic_vector(5 downto 0);
  signal ram_dout : byte_t;

  -- ROM signals
  signal tile_rom_addr : std_logic_vector(14 downto 0);
  signal tile_rom_dout : byte_t;

  -- The register that contains the colour and code of the next tile to be
  -- rendered.
  --
  -- These 16-bit words aren't stored contiguously in RAM, instead they are
  -- split into high and low bytes. The high bytes are stored in the upper-half
  -- of the RAM, while the low bytes are stored in the lower-half.
  signal tile_data : std_logic_vector(15 downto 0);

  -- The register that contains next two 4-bit pixels to be rendered.
  signal gfx_data : byte_t;

  -- tile code
  signal code : unsigned(9 downto 0);

  -- tile colour
  signal color : nibble_t;

  -- pixel data
  signal pixel : nibble_t;

  -- extract the components of the video position vectors
  alias col      : unsigned(4 downto 0) is video_pos.x(7 downto 3);
  alias row      : unsigned(4 downto 0) is video_pos.y(7 downto 3);
  alias offset_x : unsigned(2 downto 0) is video_pos.x(2 downto 0);
  alias offset_y : unsigned(2 downto 0) is video_pos.y(2 downto 0);
begin
  ram : entity work.single_port_rom
  generic map (
    ADDR_WIDTH         => 6,
    INIT_FILE          => "rom/tiles.mif",
    ENABLE_RUNTIME_MOD => "YES"
  )
  port map (
    clk  => not clk,
    addr => ram_addr,
    dout => ram_dout
  );

  rom : entity work.single_port_rom
  generic map (
    ADDR_WIDTH => 15,
    INIT_FILE  => "rom/cpu_8k.mif"
  )
  port map (
    clk  => not clk,
    addr => tile_rom_addr,
    dout => tile_rom_dout
  );

  sync_gen : entity work.sync_gen
  port map (
    clk   => clk,
    cen   => '1',
    pos   => video_pos,
    sync  => video_sync,
    blank => video_blank
  );

  -- load tile data for each 8x8 tile
  tile_data_pipeline : process (clk)
  begin
    if rising_edge(clk) then
      case to_integer(offset_x) is
        when 2 =>
          -- load high byte from the char RAM
          ram_addr <= std_logic_vector('1' & col);

        when 3 =>
          -- latch high byte
          tile_data(15 downto 8) <= ram_dout;

          -- load low byte from the char RAM
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

  -- load graphics data from the tile ROM
  tile_rom_addr <= std_logic_vector(code & offset_y & (offset_x(2 downto 1)+1));

  -- latch graphics data when rendering odd pixels
  latch_gfx_data : process (clk)
  begin
    if rising_edge(clk) then
      if video_pos.x(0) = '1' then
        gfx_data <= tile_rom_dout;
      end if;
    end if;
  end process;

  -- decode high/low pixels from the graphics data
  pixel <= gfx_data(7 downto 4) when video_pos.x(0) = '1' else gfx_data(3 downto 0);

  -- palette index
  led <= color & pixel;
end arch;
