defmodule Membrane.Generator.Plugin.Mixfile do
  use Mix.Project

  @version "0.8.0"
  @github_url "https://github.com/membraneframework/membrane_generator_plugin"

  def project do
    [
      app: :membrane_generator_plugin,
      version: @version,
      elixir: "~> 1.12",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: dialyzer(),
      # hex
      description: "Plugin containing media generators",
      package: package(),
      # docs
      name: "Membrane Generator plugin",
      source_url: @github_url,
      homepage_url: "https://membraneframework.org",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: []
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:membrane_core, "~> 0.11.2"},
      {:membrane_raw_audio_format, "~> 0.10.0"},
      {:membrane_raw_video_format, "~> 0.2"},
      {:membrane_audio_mix_plugin, "~> 0.10", only: :test},
      {:membrane_h264_ffmpeg_plugin, "~> 0.20", only: :test},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp dialyzer() do
    opts = [
      plt_local_path: "priv/plts",
      flags: [:error_handling]
    ]

    if System.get_env("CI") == "true" do
      [plt_core_path: "priv/plts"] ++ opts
    else
      opts
    end
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      },
      files: ["lib", "mix.exs", "README*", "LICENSE*", ".formatter.exs"]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      formatters: ["html"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane]
    ]
  end
end
