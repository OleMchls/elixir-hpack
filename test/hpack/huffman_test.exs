defmodule HuffmanTest do
  use ExUnit.Case, async: true

  doctest HPack.Huffman

  alias HPack.Huffman

  test "decode a simple character" do
    assert "%" == Huffman.decode(<< 0x15::6 >>)
  end

  test "decode a sentence" do
    hello_world = <<
      0x27::6, 0x5::5, 0x28::6, 0x28::6, 0x7::5, 0x14::6,
      0x78::7, 0x7::5, 0x2c::6, 0x28::6, 0x24::6, 0x3f8::10
    >>
    assert "hello world!" == Huffman.decode(hello_world)
  end

  test "decode with padding" do
    hello = <<
      0x27::6, 0x5::5, 0x28::6, 0x28::6, 0x7::5, 0b1111::4
    >>
    assert "hello" == Huffman.decode(hello)
  end

end
