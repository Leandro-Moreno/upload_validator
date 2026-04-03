# UploadValidator

File upload validation via magic bytes for Elixir. Detects spoofed file extensions by checking the actual binary signature of uploaded files.

Built for and extracted from [Shiko](https://shiko.vet), a veterinary practice management platform.

## Why?

Checking file extensions is not enough. A user can rename `malware.exe` to `photo.jpg` and your app happily accepts it. This library reads the first bytes of the file and compares them against known signatures (magic bytes) to verify the file is what it claims to be.

## Installation

```elixir
def deps do
  [
    {:upload_validator, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
# Basic validation
UploadValidator.validate("photo.jpg", allowed: :images)
#=> :ok

# With size limit (5MB)
UploadValidator.validate("doc.pdf", allowed: :documents, max_bytes: 5_000_000)
#=> :ok

# Spoofed file (text file renamed to .jpg)
UploadValidator.validate("fake.jpg")
#=> {:error, :mime_type_mismatch}

# Works with Plug.Upload
UploadValidator.validate(upload, allowed: :images, max_bytes: 5_000_000)
#=> :ok

# Detect actual file type (ignores extension)
UploadValidator.detect_type("mystery_file.bin")
#=> {:ok, "image/png"}
```

## Presets

| Preset | Types |
|--------|-------|
| `:images` | JPEG, PNG, GIF, WebP, BMP, TIFF, SVG |
| `:documents` | PDF |
| `:audio` | MP3, WAV, OGG, FLAC, WebM audio |
| `:video` | MP4, WebM, AVI |
| `:all` | Everything above |

Or pass a list of specific MIME types: `allowed: ["image/png", "application/pdf"]`

## Custom file types

```elixir
UploadValidator.validate("data.csv",
  allowed: ["text/csv"],
  extra_signatures: %{"text/csv" => []}  # empty = skip magic byte check
)
```

## Error handling

```elixir
case UploadValidator.validate(path, allowed: :images) do
  :ok -> # proceed
  {:error, reason} -> UploadValidator.error_message(reason)
end
```

| Error | Message |
|-------|---------|
| `:file_too_large` | File exceeds maximum allowed size |
| `:invalid_file_type` | File type not allowed |
| `:mime_type_mismatch` | File content does not match its extension |
| `:empty_file` | File is empty |
| `:file_not_found` | File not found |

## License

MIT
