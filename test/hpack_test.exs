defmodule HPackTest do
  use ExUnit.Case

  alias HPack.Table

  doctest HPack

  setup do
    {:ok, table} = Table.start_link(1000)
    {:ok, table: table}
  end

  test "decode from static table", %{table: table} do
    assert hd(HPack.decode(<<0x82>>, table)) == {":method", "GET"}
  end

  test "decode big number (Index5+)", %{table: table} do
    # make it big enough
    Table.resize(1_000_000_000, table)
    1..1337 |> Enum.map(fn i -> Table.add({"h-#{i}", "v-#{i}"}, table) end)

    # Maximum Dynamic Table Size Change header to 1337
    hbf = <<0b00111111, 0b10011010, 0b00001010>>
    headers = HPack.decode(hbf, table)

    assert Table.size(table) <= 1337
    assert headers == []
  end

  test "encode big number (Index7+)", %{table: table} do
    super_long_value =
      "very long long value Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Lorem ipsum dolor sit amet, consetetur sadipscing elitr, sed diam nonumy eirmod tempor invidunt ut labore et dolore magna aliquyam erat, sed diam voluptua. At vero eos et accusam et justo duo dolores et ea rebum. Stet clita kasd gubergren, no sea takimata sanctus est Lorem ipsum dolor sit amet. Duis autem vel eum iriure dolor in hendrerit in vulputate velit esse molestie consequat, vel illum dolore eu feugiat nulla facilisis at vero eros et accumsan et iusto odio dignissim qui blandit praesent luptatum zzril delenit augue duis dolore te feugait nulla facilisi. Lorem ipsum dolor sit amet, consectetuer adipiscing elit, sed diam nonummy nibh euismod tincidunt ut laoreet dolore magna aliquam erat volutpat. Ut wisi enim ad minim veniam,"

    hbf = HPack.encode([{"short-key", super_long_value}], table)

    {:ok, decode_table} = Table.start_link(1000)

    assert HPack.decode(hbf, decode_table) == [{"short-key", super_long_value}]
  end

  @doc """
  Failing request

  Nignx 200OK response

  <<0, 0, 108, 1, 4, 0, 0, 0, 1, 136, 118, 137, 170, 99, 85, 229, 128, 174, 16,
    174, 207, 97, 150, 208, 122, 190, 148, 0, 84, 134, 217, 148, 16, 2, 226, 130,
    102, 227, 46, 92, 101, 229, 49, 104, 223, 95, 135, 73, 124, 165, 137, 211, 77,
    31, 92, 3, 54, 49, 50, 108, 150, 223, 61, 191, 74, 9, 229, 50, 219, 66, 130,
    0, 92, 80, 32, 184, 38, 238, 9, 149, 49, 104, 223, 0, 131, 42, 71, 55, 140,
    254, 91, 117, 247, 228, 145, 246, 86, 19, 141, 127, 63, 0, 137, 25, 8, 90,
    210, 181, 131, 170, 98, 163, 132, 143, 210, 74, 143>>

  %Http2.Frame{flags: %Http2.Frame.Headers.Flags{end_headers: true,
    end_stream: false, padded: false, priority: false}, length: 108,
   payload: %Http2.Frame.Headers.Payload{exclusive: false,
    header_block_fragment: <<see below>>, pad_length: 0, stream_dependency: 0, weight: 0},
   stream_id: 1, type: :headers}

  hbf: <<136, 118, 137, 170, 99, 85, 229, 128, 174, 16, 174, 207, 97, 150, 208, 122,
    190, 148, 0, 84, 134, 217, 148, 16, 2, 226, 130, 102, 227, 46, 92, 101, 229,
    49, 104, 223, 95, 135, 73, 124, 165, 137, 211, 77, 31, 92, 3, 54, 49, 50, 108,
    150, 223, 61, 191, 74, 9, 229, 50, 219, 66, 130, 0, 92, 80, 32, 184, 38, 238,
    9, 149, 49, 104, 223, 0, 131, 42, 71, 55, 140, 254, 91, 117, 247, 228, 145,
    246, 86, 19, 141, 127, 63, 0, 137, 25, 8, 90, 210, 181, 131, 170, 98, 163,
    132, 143, 210, 74, 143>>

  hbf size (as specified in frame length): 108
  hbf size (retrieved binary): 108

  """
  @tag :regression
  test "decode nginx 200 OK" do
    data =
      <<136, 118, 137, 170, 99, 85, 229, 128, 174, 16, 174, 207, 97, 150, 208, 122, 190, 148, 0,
        84, 134, 217, 148, 16, 2, 226, 130, 102, 224, 69, 113, 145, 41, 139, 70, 255, 95, 135, 73,
        124, 165, 137, 211, 77, 31, 92, 3, 54, 49, 50, 108, 150, 223, 61, 191, 74, 9, 229, 50,
        219, 66, 130, 0, 92, 80, 32, 184, 38, 238, 9, 149, 49, 104, 223, 0, 131, 42, 71, 55, 140,
        254, 91, 117, 247, 228, 145, 246, 86, 19, 141, 127, 63, 0, 137, 25, 8, 90, 210, 181, 131,
        170, 98, 163, 132, 143, 210, 74, 143>>

    {:ok, pid} = HPack.Table.start_link(4_096)
    assert [_head | _tail] = HPack.decode(data, pid)
  end
end
