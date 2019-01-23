defmodule HPack.RFCSpec.DecodeTest do
  use ExUnit.Case, async: true
  import RFCBinaries

  setup do
    {:ok, table} = HPack.Table.start_link(10_000)
    {:ok, table: table}
  end

  # C.2.1 Literal Header Field with Indexing
  @tag :rfc
  test "Literal Header Field with Indexing", %{table: table} do
    hbf = ~b(
      400a 6375 7374 6f6d 2d6b 6579 0d63 7573 | @.custom-key.cus
      746f 6d2d 6865 6164 6572                | tom-header
    )

    [decoded_header | _] = HPack.decode(hbf, table)
    assert decoded_header == {"custom-key", "custom-header"}
    assert HPack.Table.size(table) == 55
  end

  # C.2.2 Literal Header Field without Indexing
  @tag :rfc
  test "Literal Header Field without Indexing", %{table: table} do
    hbf = ~b(040c 2f73 616d 706c 652f 7061 7468      | ../sample/path)

    [decoded_header | _] = HPack.decode(hbf, table)
    assert decoded_header == {":path", "/sample/path"}
    assert HPack.Table.size(table) == 0
  end

  # C.2.3 Literal Header Field Never Indexed
  @tag :rfc
  test "Literal Header Field Never Indexed", %{table: table} do
    hbf = ~b(
      1008 7061 7373 776f 7264 0673 6563 7265 | ..password.secre
      74                                      | t
    )

    [decoded_header | _] = HPack.decode(hbf, table)
    assert decoded_header == {"password", "secret"}
    assert HPack.Table.size(table) == 0
  end

  # C.2.4 Indexed Header Field
  @tag :rfc
  test "Indexed Header Field", %{table: table} do
    hbf = ~b(82 | .)

    [decoded_header | _] = HPack.decode(hbf, table)
    assert decoded_header == {":method", "GET"}
    assert HPack.Table.size(table) == 0
  end

  # C.3 Request Examples without Huffman Coding
  @tag :rfc
  test "Request Examples without Huffman Coding", %{table: table} do
    # C.3.1 First Request
    hbf = ~b(
      8286 8441 0f77 7777 2e65 7861 6d70 6c65 | ...A.www.example
      2e63 6f6d                               | .com
    )

    assert HPack.decode(hbf, table) == [
             {":method", "GET"},
             {":scheme", "http"},
             {":path", "/"},
             {":authority", "www.example.com"}
           ]

    assert HPack.Table.size(table) == 57

    # C.3.2 Second Request
    hbf = ~b(
      8286 84be 5808 6e6f 2d63 6163 6865      | ....X.no-cache
    )

    assert HPack.decode(hbf, table) == [
             {":method", "GET"},
             {":scheme", "http"},
             {":path", "/"},
             {":authority", "www.example.com"},
             {"cache-control", "no-cache"}
           ]

    assert HPack.Table.size(table) == 110

    # C.3.3 Third Request
    hbf = ~b(
      8287 85bf 400a 6375 7374 6f6d 2d6b 6579 | ....@.custom-key
      0c63 7573 746f 6d2d 7661 6c75 65        | .custom-value
    )

    assert HPack.decode(hbf, table) == [
             {":method", "GET"},
             {":scheme", "https"},
             {":path", "/index.html"},
             {":authority", "www.example.com"},
             {"custom-key", "custom-value"}
           ]

    assert HPack.Table.size(table) == 164
  end

  # C.4 Request Examples with Huffman Coding
  @tag :rfc
  test "Request Examples with Huffman Coding", %{table: table} do
    # C.4.1 First Request
    hbf = ~b(
      8286 8441 8cf1 e3c2 e5f2 3a6b a0ab 90f4 | ...A......:k....
      ff                                      | .
    )

    assert HPack.decode(hbf, table) == [
             {":method", "GET"},
             {":scheme", "http"},
             {":path", "/"},
             {":authority", "www.example.com"}
           ]

    assert HPack.Table.size(table) == 57

    # C.4.2 Second Request
    hbf = ~b(
      8286 84be 5886 a8eb 1064 9cbf           | ....X....d..
    )

    assert HPack.decode(hbf, table) == [
             {":method", "GET"},
             {":scheme", "http"},
             {":path", "/"},
             {":authority", "www.example.com"},
             {"cache-control", "no-cache"}
           ]

    assert HPack.Table.size(table) == 110

    # C.4.3 Third Request
    hbf = ~b(
      8287 85bf 4088 25a8 49e9 5ba9 7d7f 8925 | ....@.%.I.[.}..%
      a849 e95b b8e8 b4bf                     | .I.[....
    )

    assert HPack.decode(hbf, table) == [
             {":method", "GET"},
             {":scheme", "https"},
             {":path", "/index.html"},
             {":authority", "www.example.com"},
             {"custom-key", "custom-value"}
           ]

    assert HPack.Table.size(table) == 164
  end

  # C.5 Response Examples without Huffman Coding
  @tag :rfc
  test "Response Examples without Huffman Coding", %{table: table} do
    HPack.Table.resize(256, table)

    # C.5.1 First Response
    hbf = ~b(
      4803 3330 3258 0770 7269 7661 7465 611d | H.302X.privatea.
      4d6f 6e2c 2032 3120 4f63 7420 3230 3133 | Mon, 21 Oct 2013
      2032 303a 3133 3a32 3120 474d 546e 1768 |  20:13:21 GMTn.h
      7474 7073 3a2f 2f77 7777 2e65 7861 6d70 | ttps://www.examp
      6c65 2e63 6f6d                          | le.com
    )

    assert HPack.decode(hbf, table) == [
             {":status", "302"},
             {"cache-control", "private"},
             {"date", "Mon, 21 Oct 2013 20:13:21 GMT"},
             {"location", "https://www.example.com"}
           ]

    assert HPack.Table.size(table) == 222

    # C.5.2 Second Response
    hbf = ~b(
      4803 3330 37c1 c0bf                     | H.307...
    )

    assert HPack.decode(hbf, table) == [
             {":status", "307"},
             {"cache-control", "private"},
             {"date", "Mon, 21 Oct 2013 20:13:21 GMT"},
             {"location", "https://www.example.com"}
           ]

    assert HPack.Table.size(table) == 222

    # C.5.3 Third Response
    hbf = ~b(
      88c1 611d 4d6f 6e2c 2032 3120 4f63 7420 | ..a.Mon, 21 Oct
      3230 3133 2032 303a 3133 3a32 3220 474d | 2013 20:13:22 GM
      54c0 5a04 677a 6970 7738 666f 6f3d 4153 | T.Z.gzipw8foo=AS
      444a 4b48 514b 425a 584f 5157 454f 5049 | DJKHQKBZXOQWEOPI
      5541 5851 5745 4f49 553b 206d 6178 2d61 | UAXQWEOIU; max-a
      6765 3d33 3630 303b 2076 6572 7369 6f6e | ge=3600; version
      3d31                                    | =1
    )

    assert HPack.decode(hbf, table) == [
             {":status", "200"},
             {"cache-control", "private"},
             {"date", "Mon, 21 Oct 2013 20:13:22 GMT"},
             {"location", "https://www.example.com"},
             {"content-encoding", "gzip"},
             {"set-cookie", "foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1"}
           ]

    assert HPack.Table.size(table) == 215
  end

  # C.6 Response Examples with Huffman Coding
  @tag :rfc
  test "Response Examples with Huffman Coding", %{table: table} do
    HPack.Table.resize(256, table)

    # C.6.1 First Response
    hbf = ~b/
      4882 6402 5885 aec3 771a 4b61 96d0 7abe | H.d.X...w.Ka..z.
      9410 54d4 44a8 2005 9504 0b81 66e0 82a6 | ..T.D. .....f...
      2d1b ff6e 919d 29ad 1718 63c7 8f0b 97c8 | -..n..)...c.....
      e9ae 82ae 43d3                          | ....C.
    /

    assert HPack.decode(hbf, table) == [
             {":status", "302"},
             {"cache-control", "private"},
             {"date", "Mon, 21 Oct 2013 20:13:21 GMT"},
             {"location", "https://www.example.com"}
           ]

    assert HPack.Table.size(table) == 222

    # C.6.2 Second Response
    hbf = ~b(
      4883 640e ffc1 c0bf                     | H.d.....
    )

    assert HPack.decode(hbf, table) == [
             {":status", "307"},
             {"cache-control", "private"},
             {"date", "Mon, 21 Oct 2013 20:13:21 GMT"},
             {"location", "https://www.example.com"}
           ]

    assert HPack.Table.size(table) == 222

    # C.6.3 Third Response
    hbf = ~b/
      88c1 6196 d07a be94 1054 d444 a820 0595 | ..a..z...T.D. ..
      040b 8166 e084 a62d 1bff c05a 839b d9ab | ...f...-...Z....
      77ad 94e7 821d d7f2 e6c7 b335 dfdf cd5b | w..........5...[
      3960 d5af 2708 7f36 72c1 ab27 0fb5 291f | 9`..'..6r..'..).
      9587 3160 65c0 03ed 4ee5 b106 3d50 07   | ..1`e...N...=P.
    /

    assert HPack.decode(hbf, table) == [
             {":status", "200"},
             {"cache-control", "private"},
             {"date", "Mon, 21 Oct 2013 20:13:22 GMT"},
             {"location", "https://www.example.com"},
             {"content-encoding", "gzip"},
             {"set-cookie", "foo=ASDJKHQKBZXOQWEOPIUAXQWEOIU; max-age=3600; version=1"}
           ]

    assert HPack.Table.size(table) == 215
  end
end
