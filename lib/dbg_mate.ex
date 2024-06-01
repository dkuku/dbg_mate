defmodule DbgMate do
  @moduledoc """
  This package includes custom dbg functions

  ### DbgMate.Backport.dbg
  Backport module currently includes dbg implementation for:

  ### DbgMate.Inspect.dbg
  Wraps your code in IO.inspect calls used for showing the intermediate results.
  The difference between the upstream dbg function is that it displays as the code
  is executed and is not waiting until a block of code finishes.

  ### DbgMate.Inspect.dbg_tc
  Wraps your code in IO.inspect calls used for showing the intermediate results
  and additionally shows the time it took to execute every line.

  To use it just set the config value in config or run this before your dbg call

  ```
  Application.put_env(:elixir, :dbg_callback, {DbgMate,Backport, :dbg, []})
  ```
  """
end
