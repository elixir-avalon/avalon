defmodule Avalon.MixProject do
  use Mix.Project

  def project do
    [
      app: :avalon,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Avalon.Application, []}
    ]
  end

  defp deps do
    [
      {:elixir_uuid, "~> 1.2"},
      {:ex_doc, "~> 0.36", only: :dev, runtime: false},
      {:nimble_json_schema, github: "elixir-avalon/nimble_json_schema"},
      {:nimble_options, "~> 1.0"},
      {:telemetry, "~> 1.0"}
    ]
  end
end
