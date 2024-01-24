defmodule Animina.Accounts.UserTest do
  use Animina.DataCase, async: true

  alias Animina.Accounts.User

  describe "gravatar_hash calculation" do
    test "calculates the gravatar_hash correctly" do
      bob =
        Ash.Seed.seed!(%User{
          email: "bob@example.com",
          username: "bob",
          hashed_password: "zzzzzzzzzzz"
        })
        |> Animina.Accounts.load!(:gravatar_hash)

      assert bob.gravatar_hash == "4b9bb80620f03eb3719e0a061c14283d"
    end
  end
end
