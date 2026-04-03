defmodule UploadValidator do
  @moduledoc """
  File upload validation via magic bytes (file signatures).

  Detects spoofed file extensions by reading the actual binary header and
  comparing it against known signatures. Supports images, documents, audio,
  and video out of the box, and can be extended with custom signatures.

  Born from [Shiko](https://shiko.vet), a veterinary practice management
  platform where we needed to make sure uploaded files (X-rays, lab results,
  pet photos) were actually what they claimed to be.

  ## Quick start

      # Validate a file path
      UploadValidator.validate("photo.jpg", allowed: :images)

      # Validate with size limit
      UploadValidator.validate("doc.pdf", allowed: :documents, max_bytes: 10_000_000)

      # Validate a Plug.Upload (requires :plug dependency)
      UploadValidator.validate(upload, allowed: [:image, :pdf])

      # Validate with custom types
      UploadValidator.validate("data.csv", allowed: ["text/csv"],
        extra_signatures: %{"text/csv" => []}
      )

  ## How it works

  1. Reads the first 16 bytes of the file (the header)
  2. Determines the declared MIME type from the file extension
  3. Checks the header against known magic byte signatures for that type
  4. If they don't match, the file is rejected as spoofed
  """

  alias UploadValidator.{Signatures, MimeTypes}

  @type error :: :file_too_large | :invalid_file_type | :mime_type_mismatch | :empty_file | :file_not_found
  @type option ::
          {:allowed, atom | [atom | String.t()]}
          | {:max_bytes, pos_integer()}
          | {:extra_signatures, map()}

  @doc """
  Validates a file by path, binary content, or Plug.Upload.

  ## Options

    - `:allowed` - atom preset (`:images`, `:documents`, `:audio`, `:video`, `:all`)
      or a list of MIME types like `["image/png", "application/pdf"]`. Default: `:all`
    - `:max_bytes` - maximum file size in bytes. Default: no limit
    - `:extra_signatures` - additional magic byte signatures to recognize.
      Map of `%{"mime/type" => [<<signature_bytes>>]}`. Signatures with empty
      list `[]` skip magic byte check for that type.

  ## Returns

    - `:ok` on success
    - `{:error, reason}` on failure

  ## Examples

      iex> UploadValidator.validate("photo.jpg", allowed: :images, max_bytes: 5_000_000)
      :ok

      iex> UploadValidator.validate("script.jpg")  # a JS file renamed to .jpg
      {:error, :mime_type_mismatch}
  """
  @spec validate(String.t() | struct(), [option()]) :: :ok | {:error, error()}
  def validate(input, opts \\ [])

  def validate(path, opts) when is_binary(path) do
    allowed = resolve_allowed(opts[:allowed] || :all, opts[:extra_signatures])
    max_bytes = opts[:max_bytes]
    extra_sigs = opts[:extra_signatures] || %{}

    with :ok <- check_exists(path),
         :ok <- check_not_empty(path),
         :ok <- check_size(path, max_bytes),
         {:ok, header} <- read_header(path),
         {:ok, mime} <- MimeTypes.from_extension(path),
         :ok <- check_allowed(mime, allowed),
         :ok <- check_magic_bytes(header, mime, extra_sigs) do
      :ok
    end
  end

  # Accepts any struct with :path and :filename fields (e.g. Plug.Upload)
  def validate(%{path: path, filename: filename}, opts) do
    allowed = resolve_allowed(opts[:allowed] || :all, opts[:extra_signatures])
    max_bytes = opts[:max_bytes]
    extra_sigs = opts[:extra_signatures] || %{}

    with :ok <- check_exists(path),
         :ok <- check_not_empty(path),
         :ok <- check_size(path, max_bytes),
         {:ok, header} <- read_header(path),
         {:ok, mime} <- MimeTypes.from_extension(filename),
         :ok <- check_allowed(mime, allowed),
         :ok <- check_magic_bytes(header, mime, extra_sigs) do
      :ok
    end
  end

  @doc """
  Detects the actual MIME type of a file by reading its magic bytes.

  Ignores the file extension and reports what the bytes say.

  ## Examples

      iex> UploadValidator.detect_type("photo.jpg")
      {:ok, "image/jpeg"}

      iex> UploadValidator.detect_type("script_renamed.jpg")  # actually a PNG
      {:ok, "image/png"}
  """
  @spec detect_type(String.t()) :: {:ok, String.t()} | {:error, :unknown_type | :empty_file}
  def detect_type(path) when is_binary(path) do
    case read_header(path) do
      {:ok, header} -> Signatures.detect(header)
      error -> error
    end
  end

  @doc """
  Returns a user-friendly error message.

  ## Examples

      iex> UploadValidator.error_message(:file_too_large)
      "File exceeds maximum allowed size"
  """
  @spec error_message(error()) :: String.t()
  def error_message(:file_too_large), do: "File exceeds maximum allowed size"
  def error_message(:invalid_file_type), do: "File type not allowed"
  def error_message(:mime_type_mismatch), do: "File content does not match its extension"
  def error_message(:empty_file), do: "File is empty"
  def error_message(:file_not_found), do: "File not found"
  def error_message(:unknown_type), do: "Could not determine file type"
  def error_message(_), do: "Invalid file"

  # Private

  defp check_exists(path) do
    if File.exists?(path), do: :ok, else: {:error, :file_not_found}
  end

  defp check_not_empty(path) do
    case File.stat(path) do
      {:ok, %{size: 0}} -> {:error, :empty_file}
      {:ok, _} -> :ok
      {:error, _} -> {:error, :file_not_found}
    end
  end

  defp check_size(_path, nil), do: :ok

  defp check_size(path, max_bytes) do
    case File.stat(path) do
      {:ok, %{size: size}} when size <= max_bytes -> :ok
      {:ok, _} -> {:error, :file_too_large}
      {:error, _} -> {:error, :file_not_found}
    end
  end

  defp read_header(path) do
    case File.read(path) do
      {:ok, <<header::binary-size(16), _::binary>>} -> {:ok, header}
      {:ok, data} when byte_size(data) > 0 -> {:ok, data}
      {:ok, ""} -> {:error, :empty_file}
      {:error, _} -> {:error, :file_not_found}
    end
  end

  defp check_allowed(mime, allowed) do
    if mime in allowed, do: :ok, else: {:error, :invalid_file_type}
  end

  defp check_magic_bytes(header, mime, extra_sigs) do
    all_sigs = Map.merge(Signatures.all(), extra_sigs)

    case Map.get(all_sigs, mime) do
      nil -> {:error, :invalid_file_type}
      [] -> :ok
      signatures -> match_any_signature(header, signatures)
    end
  end

  defp match_any_signature(header, signatures) do
    if Enum.any?(signatures, fn sig ->
         sig_size = byte_size(sig)
         header_size = byte_size(header)
         sig_size <= header_size and binary_part(header, 0, sig_size) == sig
       end) do
      :ok
    else
      {:error, :mime_type_mismatch}
    end
  end

  defp resolve_allowed(preset, extra_sigs) when is_atom(preset) do
    base =
      case preset do
        :images -> MimeTypes.images()
        :documents -> MimeTypes.documents()
        :audio -> MimeTypes.audio()
        :video -> MimeTypes.video()
        :all -> MimeTypes.all()
      end

    extra_types = if extra_sigs, do: Map.keys(extra_sigs), else: []
    Enum.uniq(base ++ extra_types)
  end

  defp resolve_allowed(list, _extra_sigs) when is_list(list), do: list
end
