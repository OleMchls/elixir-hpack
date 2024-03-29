defmodule HPack.Mixfile do
  use Mix.Project

  def project do
    [
      app: :hpack,
      version: "3.0.1",
      elixir: "~> 1.9",
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [plt_add_deps: :project]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.2", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      source_url: "https://github.com/OleMchls/elixir-hpack",
      description: """
      Implementation of the [HPack](https://http2.github.io/http2-spec/compression.html) protocol, a compression format for efficiently representing HTTP header fields, to be used in HTTP/2.
      """,
      maintainers: ["Ole Michaelis <Ole.Michaelis@gmail.com>"],
      links: %{"HPack" => "https://http2.github.io/http2-spec/compression.html"},
      licenses: ["MIT"]
    ]
  end
end
