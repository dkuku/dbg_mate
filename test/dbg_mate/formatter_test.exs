defmodule DbgMate.FormatterTest do
  use ExUnit.Case, async: true

  alias DbgMate.Formatter

  test "default format" do
    compiled = Formatter.compile(nil)
    assert compiled == [:line, " | ", :duration, " | ", :code, ": ", :result]
  end

  test "custom format" do
    compiled = Formatter.compile("$line $startts $endts $duration $code $result")

    assert compiled == [
             :line,
             " ",
             :startts,
             " ",
             :endts,
             " ",
             :duration,
             " ",
             :code,
             " ",
             :result
           ]
  end
end
