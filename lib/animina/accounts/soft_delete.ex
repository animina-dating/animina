defmodule Animina.Accounts.SoftDelete do
  @moduledoc """
  User soft delete and reactivation functions.
  """

  import Ecto.Query

  alias Animina.Accounts.{User, UserNotifier, UserToken}
  alias Animina.Repo
  alias Animina.Utils.PaperTrail, as: PT

  @grace_period_days 30

  @doc """
  Returns `true` if the user has been soft-deleted.
  """
  def user_deleted?(nil), do: false
  def user_deleted?(%User{deleted_at: nil}), do: false
  def user_deleted?(%User{deleted_at: _}), do: true

  @doc """
  Soft-deletes a user by setting `deleted_at`, deleting all session tokens,
  and sending a goodbye email.
  """
  def soft_delete_user(%User{} = user, opts \\ []) do
    pt_opts = PT.opts(opts)

    Repo.transact(fn ->
      with {:ok, user} <-
             user
             |> User.soft_delete_changeset()
             |> PaperTrail.update(pt_opts)
             |> PT.unwrap() do
        Repo.delete_all(from(t in UserToken, where: t.user_id == ^user.id))
        UserNotifier.deliver_account_deletion_goodbye(user)
        {:ok, user}
      end
    end)
  end

  @doc """
  Gets a soft-deleted user by email and password within the 30-day grace period.
  Returns the most recently deleted user if multiple exist.
  """
  def get_deleted_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@grace_period_days, :day)

    user =
      from(u in User,
        where: u.email == ^email,
        where: not is_nil(u.deleted_at),
        where: u.deleted_at > ^cutoff,
        order_by: [desc: u.deleted_at],
        limit: 1
      )
      |> Repo.one()

    if User.valid_password?(user, password), do: user
  end

  @doc """
  Reactivates a soft-deleted user by clearing `deleted_at`.
  Returns `{:error, changeset}` if the email or phone is now claimed by another active user.
  """
  def reactivate_user(%User{} = user, opts \\ []) do
    user
    |> Ecto.Changeset.change(deleted_at: nil)
    |> Ecto.Changeset.unique_constraint(:email, name: :users_email_active_index)
    |> Ecto.Changeset.unique_constraint(:mobile_phone, name: :users_mobile_phone_active_index)
    |> PaperTrail.update(PT.opts(opts))
    |> PT.unwrap()
  end

  @doc """
  Permanently deletes a user record (hard delete).
  """
  def hard_delete_user(%User{} = user, opts \\ []) do
    PaperTrail.delete(user, PT.opts(opts)) |> PT.unwrap()
  end

  @doc """
  Returns `true` if the user's `deleted_at` is within the 30-day grace period.
  """
  def within_grace_period?(%User{deleted_at: nil}), do: false

  def within_grace_period?(%User{deleted_at: deleted_at}) do
    cutoff = DateTime.utc_now() |> DateTime.add(-@grace_period_days, :day)
    DateTime.after?(deleted_at, cutoff)
  end

  @doc """
  Hard-deletes users whose `deleted_at` is older than 30 days.
  """
  def purge_deleted_users do
    cutoff = DateTime.utc_now() |> DateTime.add(-30, :day)

    from(u in User,
      where: not is_nil(u.deleted_at),
      where: u.deleted_at < ^cutoff
    )
    |> Repo.delete_all()
  end
end
