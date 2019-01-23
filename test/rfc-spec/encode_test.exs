defmodule HPack.RFCSpec.EncodeTest do
  use ExUnit.Case, async: true
  import RFCBinaries

  setup do
    {:ok, table} = HPack.Table.start_link(10_000)
    {:ok, table: table}
  end

  # C.2.4 Indexed Header Field
  @tag :rfc
  test "Indexed Header Field", %{table: table} do
    headers = [{":method", "GET"}]
    assert HPack.encode(headers, table) == ~b(82 | .)
  end

  # C.4 Request Examples with Huffman Coding
  @tag :rfc
  test "Request Examples with Huffman Coding", %{table: table} do
    # C.4.1 First Request
    headers = [
      {":method", "GET"},
      {":scheme", "http"},
      {":path", "/"},
      {":authority", "www.example.com"}
    ]

    assert HPack.encode(headers, table) == ~b(
      8286 8441 8cf1 e3c2 e5f2 3a6b a0ab 90f4 | ...A......:k....
      ff                                      | .
    )

    # C.4.2 Second Request
    headers = [
      {":method", "GET"},
      {":scheme", "http"},
      {":path", "/"},
      {":authority", "www.example.com"},
      {"cache-control", "no-cache"}
    ]

    assert HPack.encode(headers, table) == ~b(
      8286 84be 5886 a8eb 1064 9cbf           | ....X....d..
    )

    # C.4.3 Third Request
    headers = [
      {":method", "GET"},
      {":scheme", "https"},
      {":path", "/index.html"},
      {":authority", "www.example.com"},
      {"custom-key", "custom-value"}
    ]

    assert HPack.encode(headers, table) == ~b(
      8287 85bf 4088 25a8 49e9 5ba9 7d7f 8925 | ....@.%.I.[.}..%
      a849 e95b b8e8 b4bf                     | .I.[....
    )
  end

  # C.6 Response Examples with Huffman Coding
  @tag :rfc
  test "Request Examples with Huffman Coding (256 bytes table)", %{table: table} do
    HPack.Table.resize(256, table)

    # C.6.1 First Response
    headers = [
      {":status", "302"},
      {"cache-control", "private"},
      {"date", "Mon, 21 Oct 2013 20:13:21 GMT"},
      {"location", "https://www.example.com"}
    ]

    assert HPack.encode(headers, table) == ~b/
      4882 6402 5885 aec3 771a 4b61 96d0 7abe | H.d.X...w.Ka..z.
      9410 54d4 44a8 2005 9504 0b81 66e0 82a6 | ..T.D. .....f...
      2d1b ff6e 919d 29ad 1718 63c7 8f0b 97c8 | -..n..)...c.....
      e9ae 82ae 43d3                          | ....C.
    /

    # C.6.2 Second Response
    headers = [
      {":status", "307"},
      {"cache-control", "private"},
      {"date", "Mon, 21 Oct 2013 20:13:21 GMT"},
      {"location", "https://www.example.com"}
    ]

    assert HPack.encode(headers, table) == ~b(
      4883 640e ffc1 c0bf                     | H.d.....
    )

    # C.6.3 Third Response
    headers = [
      {":status", "200"},
      {"cache-control", "private"},
      {"date", "Mon, 21 Oct 2013 20:13:22 GMT"},
      {"location", "https://www.example.com"},
      {"content-encoding", "gzip"},
      {"set-cookie", "foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1"}
    ]

    assert HPack.encode(headers, table) == ~b/
      88c1 6196 d07a be94 1054 d444 a820 0595 | ..a..z...T.D. ..
      040b 8166 e084 a62d 1bff c05a 839b d9ab | ...f...-...Z....
      77ad 94e7 821d d7f2 e6c7 b335 dfdf cd5b | w..........5...[
      3960 d5af 2708 7f36 72c1 ab27 0fb5 291f | 9`..'..6r..'..).
      9587 3160 65c0 03ed 4ee5 b106 3d50 07   | ..1`e...N...=P.
    /
  end
end
