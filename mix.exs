defmodule DbgMate.MixProject do
  use Mix.Project

  def project do
    [
      app: :dbg_mate,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: description()
    ]
  end

  defp description do
    "This package includes custom dbg functions"
  end

  defp package do
    [
      # These are the default files included in the package
      files: [
        "lib",
        "mix.exs",
        "README*"
      ],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/dkuku/dbg_mate"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    []
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
