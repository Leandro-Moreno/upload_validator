defmodule UploadValidator.MimeTypes do
  @moduledoc """
  Extension-to-MIME mapping and type presets.
  """

  @extension_map %{
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png" => "image/png",
    ".gif" => "image/gif",
    ".webp" => "image/webp",
    ".bmp" => "image/bmp",
    ".tiff" => "image/tiff",
    ".tif" => "image/tiff",
    ".svg" => "image/svg+xml",
    ".pdf" => "application/pdf",
    ".mp3" => "audio/mpeg",
    ".wav" => "audio/wav",
    ".ogg" => "audio/ogg",
    ".flac" => "audio/flac",
    ".weba" => "audio/webm",
    ".mp4" => "video/mp4",
    ".webm" => "video/webm",
    ".avi" => "video/avi",
    ".zip" => "application/zip",
    ".gz" => "application/gzip",
    ".csv" => "text/csv"
  }

  @images ~w(image/jpeg image/png image/gif image/webp image/bmp image/tiff image/svg+xml)
  @documents ~w(application/pdf)
  @audio ~w(audio/mpeg audio/wav audio/ogg audio/flac audio/webm)
  @video ~w(video/mp4 video/webm video/avi)

  @doc "MIME types for the :images preset."
  @spec images() :: [String.t()]
  def images, do: @images

  @doc "MIME types for the :documents preset."
  @spec documents() :: [String.t()]
  def documents, do: @documents

  @doc "MIME types for the :audio preset."
  @spec audio() :: [String.t()]
  def audio, do: @audio

  @doc "MIME types for the :video preset."
  @spec video() :: [String.t()]
  def video, do: @video

  @doc "All known MIME types."
  @spec all() :: [String.t()]
  def all, do: @images ++ @documents ++ @audio ++ @video

  @doc "Resolves a MIME type from a filename extension."
  @spec from_extension(String.t()) :: {:ok, String.t()} | {:error, :invalid_file_type}
  def from_extension(filename) do
    ext = filename |> Path.extname() |> String.downcase()

    case Map.get(@extension_map, ext) do
      nil -> {:error, :invalid_file_type}
      mime -> {:ok, mime}
    end
  end
end
