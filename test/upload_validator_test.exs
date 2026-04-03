defmodule UploadValidatorTest do
  use ExUnit.Case

  @fixtures_dir Path.join(__DIR__, "fixtures")

  setup_all do
    File.mkdir_p!(@fixtures_dir)

    # Create real test files with proper magic bytes
    jpeg = <<0xFF, 0xD8, 0xFF, 0xE0>> <> :crypto.strong_rand_bytes(100)
    png = <<0x89, 0x50, 0x4E, 0x47>> <> :crypto.strong_rand_bytes(100)
    pdf = <<0x25, 0x50, 0x44, 0x46>> <> :crypto.strong_rand_bytes(100)
    gif = <<0x47, 0x49, 0x46, 0x38>> <> :crypto.strong_rand_bytes(100)
    fake_jpg = "this is not a jpeg at all, just plain text"

    File.write!(Path.join(@fixtures_dir, "valid.jpg"), jpeg)
    File.write!(Path.join(@fixtures_dir, "valid.png"), png)
    File.write!(Path.join(@fixtures_dir, "valid.pdf"), pdf)
    File.write!(Path.join(@fixtures_dir, "valid.gif"), gif)
    File.write!(Path.join(@fixtures_dir, "spoofed.jpg"), fake_jpg)
    File.write!(Path.join(@fixtures_dir, "empty.jpg"), "")
    File.write!(Path.join(@fixtures_dir, "big.jpg"), jpeg <> :crypto.strong_rand_bytes(5_000_000))

    on_exit(fn -> File.rm_rf!(@fixtures_dir) end)
    :ok
  end

  describe "validate/2" do
    test "accepts a valid JPEG" do
      assert :ok = UploadValidator.validate(fixture("valid.jpg"))
    end

    test "accepts a valid PNG" do
      assert :ok = UploadValidator.validate(fixture("valid.png"))
    end

    test "accepts a valid PDF" do
      assert :ok = UploadValidator.validate(fixture("valid.pdf"))
    end

    test "rejects a spoofed file (text disguised as JPEG)" do
      assert {:error, :mime_type_mismatch} = UploadValidator.validate(fixture("spoofed.jpg"))
    end

    test "rejects an empty file" do
      assert {:error, :empty_file} = UploadValidator.validate(fixture("empty.jpg"))
    end

    test "rejects a non-existent file" do
      assert {:error, :file_not_found} = UploadValidator.validate("/tmp/nope_doesnt_exist.jpg")
    end

    test "rejects unknown extension" do
      path = Path.join(@fixtures_dir, "data.xyz")
      File.write!(path, <<0xFF, 0xD8, 0xFF>>)
      assert {:error, :invalid_file_type} = UploadValidator.validate(path)
    end

    test "enforces max_bytes" do
      assert {:error, :file_too_large} =
               UploadValidator.validate(fixture("big.jpg"), max_bytes: 1_000_000)
    end

    test "passes when under max_bytes" do
      assert :ok = UploadValidator.validate(fixture("valid.jpg"), max_bytes: 1_000_000)
    end

    test "filters by :images preset" do
      assert :ok = UploadValidator.validate(fixture("valid.jpg"), allowed: :images)
      assert {:error, :invalid_file_type} = UploadValidator.validate(fixture("valid.pdf"), allowed: :images)
    end

    test "filters by :documents preset" do
      assert :ok = UploadValidator.validate(fixture("valid.pdf"), allowed: :documents)
      assert {:error, :invalid_file_type} = UploadValidator.validate(fixture("valid.jpg"), allowed: :documents)
    end

    test "filters by explicit MIME list" do
      assert :ok = UploadValidator.validate(fixture("valid.png"), allowed: ["image/png"])
      assert {:error, :invalid_file_type} = UploadValidator.validate(fixture("valid.jpg"), allowed: ["image/png"])
    end

    test "accepts Plug.Upload-like struct" do
      upload = %{path: fixture("valid.jpg"), filename: "photo.jpg"}
      assert :ok = UploadValidator.validate(upload)
    end

    test "supports extra_signatures for custom types" do
      path = Path.join(@fixtures_dir, "custom.csv")
      File.write!(path, "name,email\njohn,john@example.com")

      assert :ok =
               UploadValidator.validate(path,
                 allowed: ["text/csv"],
                 extra_signatures: %{"text/csv" => []}
               )
    end
  end

  describe "detect_type/1" do
    test "detects JPEG" do
      assert {:ok, "image/jpeg"} = UploadValidator.detect_type(fixture("valid.jpg"))
    end

    test "detects PNG" do
      assert {:ok, "image/png"} = UploadValidator.detect_type(fixture("valid.png"))
    end

    test "detects PDF" do
      assert {:ok, "application/pdf"} = UploadValidator.detect_type(fixture("valid.pdf"))
    end

    test "returns unknown for unrecognized bytes" do
      path = Path.join(@fixtures_dir, "unknown.bin")
      File.write!(path, "random bytes here")
      assert {:error, :unknown_type} = UploadValidator.detect_type(path)
    end
  end

  describe "error_message/1" do
    test "returns human-friendly messages" do
      assert "File exceeds maximum allowed size" = UploadValidator.error_message(:file_too_large)
      assert "File type not allowed" = UploadValidator.error_message(:invalid_file_type)
      assert "File content does not match its extension" = UploadValidator.error_message(:mime_type_mismatch)
      assert "File is empty" = UploadValidator.error_message(:empty_file)
      assert "File not found" = UploadValidator.error_message(:file_not_found)
    end
  end

  defp fixture(name), do: Path.join(@fixtures_dir, name)
end
