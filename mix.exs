defmodule HPack.Mixfile do
  use Mix.Project

  def project do
    [app: :hpack,
     version: "1.0.2",
     elixir: "~> 1.2",
     package: package(),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps(),
     dialyzer: [plt_file: ".plts/.local.plt"]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.11", only: :dev},
      {:dialyxir, "~> 0.3.5", only: :dev}
    ]
  end

  defp package do
    [
      source_url: "https://github.com/nesQuick/elixir-hpack",
      description: """
      Implementation of the [HPack](https://http2.github.io/http2-spec/compression.html) protocol, a compression format for efficiently representing HTTP header fields, to be used in HTTP/2.
      """,
      maintainers: ["Ole Michaelis <Ole.Michaelis@gmail.com>"],
      licenses: ["MIT"],
    ]
  end
end
