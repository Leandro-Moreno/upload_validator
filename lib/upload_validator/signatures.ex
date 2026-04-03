defmodule UploadValidator.Signatures do
  @moduledoc """
  Magic byte signatures for known file types.

  Each entry maps a MIME type to a list of valid binary prefixes.
  A file is considered valid if its first bytes match any of the signatures.
  """

  @signatures %{
    # Images
    "image/jpeg" => [<<0xFF, 0xD8, 0xFF>>],
    "image/png" => [<<0x89, 0x50, 0x4E, 0x47>>],
    "image/gif" => [<<0x47, 0x49, 0x46, 0x38>>],
    "image/webp" => [<<0x52, 0x49, 0x46, 0x46>>],
    "image/bmp" => [<<0x42, 0x4D>>],
    "image/tiff" => [<<0x49, 0x49, 0x2A, 0x00>>, <<0x4D, 0x4D, 0x00, 0x2A>>],
    "image/svg+xml" => [<<0x3C, 0x3F, 0x78, 0x6D>>, <<0x3C, 0x73, 0x76, 0x67>>],

    # Documents
    "application/pdf" => [<<0x25, 0x50, 0x44, 0x46>>],

    # Audio
    "audio/mpeg" => [<<0xFF, 0xFB>>, <<0xFF, 0xF3>>, <<0xFF, 0xF2>>, <<0x49, 0x44, 0x33>>],
    "audio/wav" => [<<0x52, 0x49, 0x46, 0x46>>],
    "audio/ogg" => [<<0x4F, 0x67, 0x67, 0x53>>],
    "audio/flac" => [<<0x66, 0x4C, 0x61, 0x43>>],
    "audio/webm" => [<<0x1A, 0x45, 0xDF, 0xA3>>],

    # Video
    "video/mp4" => [<<0x00, 0x00, 0x00>>, <<0x66, 0x74, 0x79, 0x70>>],
    "video/webm" => [<<0x1A, 0x45, 0xDF, 0xA3>>],
    "video/avi" => [<<0x52, 0x49, 0x46, 0x46>>],

    # Archives
    "application/zip" => [<<0x50, 0x4B, 0x03, 0x04>>],
    "application/gzip" => [<<0x1F, 0x8B>>]
  }

  @doc "Returns all known signatures."
  @spec all() :: map()
  def all, do: @signatures

  @doc """
  Detects the MIME type from a binary header.

  Tries each known signature against the header and returns the first match.
  """
  @spec detect(binary()) :: {:ok, String.t()} | {:error, :unknown_type}
  def detect(header) when is_binary(header) do
    result =
      Enum.find_value(@signatures, fn {mime, sigs} ->
        if Enum.any?(sigs, &prefix_match?(header, &1)), do: mime
      end)

    case result do
      nil -> {:error, :unknown_type}
      mime -> {:ok, mime}
    end
  end

  defp prefix_match?(header, sig) do
    sig_size = byte_size(sig)
    byte_size(header) >= sig_size and binary_part(header, 0, sig_size) == sig
  end
end
