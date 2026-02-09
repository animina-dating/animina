defmodule Animina.Accounts.SoftDelete do
  @moduledoc """
  User soft delete and reactivation functions.

  ## Soft Delete Semantics

  When a user is soft-deleted, their `deleted_at` field is set to a **future date**
  representing when the account will be permanently deleted (hard delete).

  - `deleted_at` in the future: User is within grace period and can reactivate
  - `deleted_at` in the past: Grace period expired, eligible for permanent deletion
  - `deleted_at` is nil: User is active

  The grace period is configured via the `:soft_delete_grace_days` system setting.
  """

  import Ecto.Query

  alias Animina.Accounts.{User, UserNotifier, UserToken}
  alias Animina.ActivityLog
  alias Animina.Repo
  alias Animina.TimeMachine
  alias Animina.Utils.PaperTrail, as: PT

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

        ActivityLog.log(
          "profile",
          "account_deleted",
          "#{user.display_name} deleted their account",
          actor_id: user.id,
          subject_id: user.id
        )

        {:ok, user}
      end
    end)
  end

  @doc """
  Gets a soft-deleted user by email and password within the grace period.
  A user is within the grace period if their `deleted_at` is in the future.
  Returns the most recently deleted user if multiple exist.
  """
  def get_deleted_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    now = TimeMachine.utc_now()

    user =
      from(u in User,
        where: u.email == ^email,
        where: not is_nil(u.deleted_at),
        where: u.deleted_at > ^now,
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
    result =
      user
      |> Ecto.Changeset.change(deleted_at: nil)
      |> Ecto.Changeset.unique_constraint(:email, name: :users_email_active_index)
      |> Ecto.Changeset.unique_constraint(:mobile_phone, name: :users_mobile_phone_active_index)
      |> PaperTrail.update(PT.opts(opts))
      |> PT.unwrap()

    case result do
      {:ok, user} ->
        ActivityLog.log(
          "profile",
          "account_reactivated",
          "#{user.display_name} reactivated their account",
          actor_id: user.id,
          subject_id: user.id
        )

        {:ok, user}

      error ->
        error
    end
  end

  @doc """
  Permanently deletes a user record (hard delete).
  """
  def hard_delete_user(%User{} = user, opts \\ []) do
    PaperTrail.delete(user, PT.opts(opts)) |> PT.unwrap()
  end

  @doc """
  Returns `true` if the user's `deleted_at` is in the future (within grace period).
  """
  def within_grace_period?(%User{deleted_at: nil}), do: false

  def within_grace_period?(%User{deleted_at: deleted_at}) do
    DateTime.after?(deleted_at, TimeMachine.utc_now())
  end

  @doc """
  Hard-deletes users whose `deleted_at` is in the past (grace period expired).
  """
  def purge_deleted_users do
    now = TimeMachine.utc_now()

    from(u in User,
      where: not is_nil(u.deleted_at),
      where: u.deleted_at < ^now
    )
    |> Repo.delete_all()
  end
end
