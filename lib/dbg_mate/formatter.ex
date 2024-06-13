defmodule DbgMate.Formatter do
  def new(options \\ []) do
    compile(options[:format])
  end

  @default_pattern "$line | $duration | $code: $result"
  @valid_patterns [:line, :duration, :code, :result, :startts, :endts]
  @spec compile(binary | nil) :: [binary]
  @spec compile(pattern) :: pattern when pattern: {module, function :: atom}
  def compile(pattern_or_function)

  def compile(nil), do: compile(@default_pattern)
  def compile({mod, fun}) when is_atom(mod) and is_atom(fun), do: {mod, fun}

  def compile(str) when is_binary(str) do
    regex = ~r/(?<head>)\$[a-z]+(?<tail>)/

    for part <- Regex.split(regex, str, on: [:head, :tail], trim: true) do
      case part do
        "$" <> code -> compile_code(String.to_atom(code))
        _ -> part
      end
    end
  end

  defp compile_code(key) when key in @valid_patterns, do: key

  defp compile_code(key) when is_atom(key) do
    raise ArgumentError, "$#{key} is an invalid format pattern"
  end

  def format(config, meta, start_time, end_time, ast, result) do
    for config_option <- config do
      output(config_option, meta, start_time, end_time, ast, result)
    end
  end

  defp output(:duration, _, start_time, end_time, _, _),
    do: get_duration_string(start_time, end_time)

  defp output(:line, meta, _, _, _, _), do: String.pad_leading("#{meta[:line]}", 3)
  defp output(:start_time, _, start_time, _, _, _), do: to_string(start_time)
  defp output(:end_time, _, _, end_time, _, _), do: to_string(end_time)
  defp output(:code, _, _, _, code, _), do: code
  defp output(:result, _, _, _, _, result), do: inspect(result)
  defp output(other, _, _, _, _, _), do: other

  defp get_duration_string(start_time, end_time) do
    duration = end_time - start_time

    case System.convert_time_unit(duration, :native, :microsecond) do
      duration when duration < 1000 -> "#{duration}us"
      duration when duration < 1_000_000 -> "#{div(duration, 1000)}ms"
      duration when duration < 1_000_000_000 -> "#{div(duration, 1_000_000)}s "
    end
    |> String.pad_leading(6)
  end
end
