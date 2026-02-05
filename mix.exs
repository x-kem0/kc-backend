defmodule KcCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :kc_core,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {KC.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.21.1"},
      {:plug, "~> 1.19"},
      {:ex_aws_s3, "~> 2.5"},
      {:req, "~> 0.5.17"},
      {:bandit, "~> 1.10"},
      {:mr_mime, "~> 0.1.0"},
      {:thumbp, "~> 0.1.5"},
      {:styler, "~> 1.10", only: [:dev, :test], runtime: false}
    ]
  end
end
