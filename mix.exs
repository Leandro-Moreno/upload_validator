defmodule UploadValidator.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/Leandro-Moreno/upload_validator"

  def project do
    [
      app: :upload_validator,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      name: "UploadValidator",
      description: "File upload validation via magic bytes. Detects spoofed extensions by checking actual file signatures.",
      source_url: @source_url
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:plug, "~> 1.14", optional: true},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Shiko" => "https://shiko.vet"
      },
      maintainers: ["Leandro Moreno"],
      files: ~w(lib mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "UploadValidator",
      source_url: @source_url
    ]
  end
end
