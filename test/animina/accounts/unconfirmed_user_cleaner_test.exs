defmodule Animina.Accounts.UnconfirmedUserCleanerTest do
  use Animina.DataCase

  alias Animina.Accounts
  alias Animina.Accounts.UnconfirmedUserCleaner

  import Animina.AccountsFixtures

  describe "UnconfirmedUserCleaner" do
    test "starts and runs cleanup on schedule" do
      {:ok, pid} = UnconfirmedUserCleaner.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "cleanup deletes expired unconfirmed users" do
      user = unconfirmed_user_fixture()
      {:ok, _pin} = Accounts.send_confirmation_pin(user)

      # Set sent_at to 61 minutes ago (beyond the default 60-minute pin_validity_minutes)
      Repo.update_all(
        from(u in Accounts.User, where: u.id == ^user.id),
        set: [confirmation_pin_sent_at: DateTime.add(DateTime.utc_now(), -61, :minute)]
      )

      # Trigger cleanup manually
      send(Process.whereis(UnconfirmedUserCleaner) || start_cleaner(), :cleanup)

      # Give it a moment to process
      Process.sleep(50)

      refute Repo.get(Accounts.User, user.id)
    end

    test "cleanup does not delete confirmed users" do
      user = user_fixture()

      send(Process.whereis(UnconfirmedUserCleaner) || start_cleaner(), :cleanup)
      Process.sleep(50)

      assert Repo.get(Accounts.User, user.id)
    end

    defp start_cleaner do
      {:ok, pid} = UnconfirmedUserCleaner.start_link([])
      pid
    end
  end
end
