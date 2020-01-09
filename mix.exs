defmodule Kvasir.HTTP.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :kvasir_http,
      description: "Kvasir documentation and [live] inspector.",
      version: @version,
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),

      # Docs
      name: "kvasir_http",
      source_url: "https://github.com/IanLuites/kvasir_http",
      homepage_url: "https://github.com/IanLuites/kvasir_http",
      docs: [
        main: "readme",
        extras: ["README.md"],
        source_url: "https://github.com/IanLuites/kvasir_http"
      ]
    ]
  end

  def package do
    [
      name: :kvasir_http,
      maintainers: ["Ian Luites"],
      licenses: ["MIT"],
      files: [
        # Elixir
        "lib/kvasir/http",
        "lib/kvasir/http.ex",
        ".formatter.exs",
        "mix.exs",
        "README*",
        "LICENSE*"
      ],
      links: %{
        "GitHub" => "https://github.com/IanLuites/kvasir_http"
      }
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:buckaroo, "~> 0.2"},
      {:earmark, "~> 1.4"},
      {:kvasir, git: "https://github.com/IanLuites/kvasir", branch: "release/v1.0"}
    ]
  end
end
