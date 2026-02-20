defmodule AniminaWeb.PhotoControllerTest do
  use AniminaWeb.ConnCase

  alias Animina.Photos

  import Animina.PhotosFixtures

  describe "GET /photos/:signature/:filename" do
    test "serves an approved photo with valid signature", %{conn: conn} do
      photo = approved_photo_fixture()
      {_main, _thumb} = create_processed_files(photo)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      url = Photos.signed_url(photo)
      conn = get(conn, url)
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/webp"]
    end

    test "returns 404 for invalid signature", %{conn: conn} do
      photo = approved_photo_fixture()
      create_processed_files(photo)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      conn = get(conn, "/photos/invalid_sig_xxxxx/#{photo.id}.webp")
      assert conn.status == 404
    end

    test "returns 404 for non-existent photo", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      sig = Photos.compute_signature(fake_id)
      conn = get(conn, "/photos/#{sig}/#{fake_id}.webp")
      assert conn.status == 404
    end

    test "returns 404 for pending photo (not yet processed)", %{conn: conn} do
      photo = photo_fixture()
      create_processed_files(photo)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      sig = Photos.compute_signature(photo.id)
      conn = get(conn, "/photos/#{sig}/#{photo.id}.webp")
      assert conn.status == 404
    end

    test "serves photo in ollama_checking state (file exists)", %{conn: conn} do
      photo = ollama_checking_photo_fixture()
      create_processed_files(photo)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      url = Photos.signed_url(photo)
      conn = get(conn, url)
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/webp"]
    end

    test "serves thumbnail variant directly", %{conn: conn} do
      photo = approved_photo_fixture()
      create_processed_files(photo)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      url = Photos.signed_url(photo, :thumbnail)
      conn = get(conn, url)
      assert conn.status == 200
    end

    test "serves pixel variant and lazy-generates it from main", %{conn: conn} do
      photo = approved_photo_fixture()

      # Create a real main variant (Image library needs a real image to pixelate)
      dir = Photos.processed_path_dir(photo.owner_type, photo.owner_id)
      File.mkdir_p!(dir)
      main_path = Photos.processed_path(photo, :main)
      {:ok, image} = Image.new(100, 100, color: :green)
      {:ok, _} = Image.write(image, main_path)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      # Pixel file should not exist yet
      pixel_path = Photos.processed_path(photo, :pixel)
      refute File.exists?(pixel_path)

      # Request pixel variant — should lazy-generate and serve
      url = Photos.signed_url(photo, :pixel)
      conn = get(conn, url)
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["image/webp"]

      # File should now be cached on disk
      assert File.exists?(pixel_path)
    end

    test "yesterday's signature returns 404", %{conn: conn} do
      photo = approved_photo_fixture()
      create_processed_files(photo)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      # Compute a signature using a different date (simulating yesterday)
      yesterday_secret =
        :crypto.mac(
          :hmac,
          :sha256,
          Photos.url_secret_salt(),
          Date.utc_today() |> Date.add(-1) |> Date.to_iso8601()
        )

      old_sig =
        :crypto.mac(:hmac, :sha256, yesterday_secret, photo.id)
        |> Base.url_encode64(padding: false)
        |> binary_part(0, 16)

      conn = get(conn, "/photos/#{old_sig}/#{photo.id}.webp")
      assert conn.status == 404
    end

    # Security tests for cross-user photo access
    test "signature for one photo cannot access another photo", %{conn: conn} do
      photo1 = approved_photo_fixture()
      photo2 = approved_photo_fixture()
      create_processed_files(photo1)
      create_processed_files(photo2)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      # Get signature for photo1, try to access photo2 with it
      sig1 = Photos.compute_signature(photo1.id)
      conn = get(conn, "/photos/#{sig1}/#{photo2.id}.webp")
      assert conn.status == 404
    end

    test "signature is tied to specific photo ID", %{conn: conn} do
      user1_id = Ecto.UUID.generate()
      user2_id = Ecto.UUID.generate()

      photo1 = approved_photo_fixture(%{owner_type: "User", owner_id: user1_id})
      photo2 = approved_photo_fixture(%{owner_type: "User", owner_id: user2_id})
      create_processed_files(photo1)
      create_processed_files(photo2)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      # User1's photo signature cannot be used to access User2's photo
      sig1 = Photos.compute_signature(photo1.id)

      # Valid access to photo1
      conn1 = get(conn, "/photos/#{sig1}/#{photo1.id}.webp")
      assert conn1.status == 200

      # Invalid access to photo2 using photo1's signature
      conn2 = get(conn, "/photos/#{sig1}/#{photo2.id}.webp")
      assert conn2.status == 404
    end

    test "cannot guess other users' photo IDs in URL", %{conn: conn} do
      # Even if someone guesses a valid photo ID, they need a valid signature
      user_id = Ecto.UUID.generate()
      photo = approved_photo_fixture(%{owner_type: "User", owner_id: user_id})
      create_processed_files(photo)

      on_exit(fn -> File.rm_rf!(Photos.processed_dir()) end)

      # Try various invalid signatures with the correct photo ID
      invalid_signatures = [
        "AAAAAAAAAAAAAAAA",
        "0000000000000000",
        "________________",
        Base.url_encode64("invalid_secret") |> binary_part(0, 16)
      ]

      for invalid_sig <- invalid_signatures do
        conn = get(conn, "/photos/#{invalid_sig}/#{photo.id}.webp")
        assert conn.status == 404
      end
    end
  end
end
