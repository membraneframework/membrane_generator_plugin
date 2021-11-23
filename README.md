# Membrane Generator Plugin

[![Hex.pm](https://img.shields.io/hexpm/v/membrane_generator_plugin.svg)](https://hex.pm/packages/membrane_generator_plugin)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/membrane_generator_plugin)
[![CircleCI](https://circleci.com/gh/membraneframework/membrane_generator_plugin.svg?style=svg)](https://circleci.com/gh/membraneframework/membrane_generator_plugin)

This repository contains audio generator.

It is part of [Membrane Multimedia Framework](https://membraneframework.org).

## Installation

The package can be installed by adding `membrane_generator_plugin` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:membrane_generator_plugin, "~> 0.2.0"}
  ]
end
```

## Usage Example

### Silence generator
```elixir
defmodule AudioGenerating.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_) do
    children = [
      generator: %Membrane.SilenceGenerator{
        caps: %Membrane.Caps.Audio.Raw{
          channels: 1,
          sample_rate: 16_000,
          format: :s16le
        },
        duration: Membrane.Time.milliseconds(100)
      },
      sink: %Membrane.File.Sink{location: "/tmp/output.raw"},
    ]

    links = [
      link(:generator)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
```

### Blank Video Generator
```elixir
defmodule VideoGenerating.Pipeline do
  use Membrane.Pipeline

  @impl true
  def handle_init(_) do
    children = [
      generator: %Membrane.SilenceGenerator{
        caps: %Membrane.Caps.Video.Raw{
          format: :I420,
          height: 720,
          width: 1280,
          framerate: {30, 1},
          aligned: true
        },
        duration: Membrane.Time.milliseconds(100)
      },
      sink: %Membrane.File.Sink{location: "/tmp/output.raw"},
    ]

    links = [
      link(:generator)
      |> to(:sink)
    ]

    {{:ok, spec: %ParentSpec{children: children, links: links}}, %{}}
  end
end
```

## Copyright and License

Copyright 2021, [Software Mansion](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_generator_plugin)

[![Software Mansion](https://logo.swmansion.com/logo?color=white&variant=desktop&width=200&tag=membrane-github)](https://swmansion.com/?utm_source=git&utm_medium=readme&utm_campaign=membrane_generator_plugin)

Licensed under the [Apache License, Version 2.0](LICENSE)
