defmodule Animina.Emails do
  @moduledoc """
  Context for email delivery and logging.

  Provides `deliver_and_log/2` as the standard email delivery function.
  All emails sent through this function are automatically logged to the
  `email_logs` table with delivery status.
  """

  import Ecto.Query

  alias Animina.Emails.EmailLog
  alias Animina.Mailer
  alias Animina.Repo

  @doc """
  Delivers a Swoosh email and logs the result.

  ## Options

    * `:email_type` - atom or string identifying the email type (required for logging)
    * `:user_id` - UUID of the associated user (optional)

  Returns `{:ok, email}` on success or `{:error, reason}` on failure.
  """
  def deliver_and_log(swoosh_email, opts \\ []) do
    recipient_email = extract_email(swoosh_email.to)

    log_attrs = %{
      email_type: to_string(opts[:email_type]),
      user_id: opts[:user_id],
      recipient: recipient_email,
      subject: swoosh_email.subject,
      body: swoosh_email.text_body || ""
    }

    case Mailer.deliver(swoosh_email) do
      {:ok, _meta} ->
        create_email_log(Map.put(log_attrs, :status, "sent"))
        {:ok, swoosh_email}

      {:error, reason} = error ->
        create_email_log(Map.merge(log_attrs, %{status: "error", error_message: inspect(reason)}))

        error
    end
  end

  defp extract_email([{_name, email}]), do: email
  defp extract_email([email]) when is_binary(email), do: email
  defp extract_email(email) when is_binary(email), do: email
  defp extract_email(_), do: "unknown"

  @doc """
  Creates an email log entry.
  """
  def create_email_log(attrs) do
    %EmailLog{}
    |> EmailLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Lists email logs with filtering, sorting, and pagination.

  ## Options

    * `:page` - page number (default: 1)
    * `:per_page` - results per page (default: 50)
    * `:sort_by` - column to sort by (default: :inserted_at)
    * `:sort_dir` - :asc or :desc (default: :desc)
    * `:filter_type` - filter by email_type
    * `:filter_status` - filter by status
    * `:user_id` - filter by user_id
  """
  def list_email_logs(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 50)
    sort_by = Keyword.get(opts, :sort_by, :inserted_at)
    sort_dir = Keyword.get(opts, :sort_dir, :desc)

    query =
      from(e in EmailLog,
        left_join: u in assoc(e, :user),
        preload: [user: u]
      )
      |> maybe_filter_type(Keyword.get(opts, :filter_type))
      |> maybe_filter_status(Keyword.get(opts, :filter_status))
      |> maybe_filter_user(Keyword.get(opts, :user_id))
      |> order_by([e], [{^sort_dir, field(e, ^sort_by)}])

    total_count = Repo.aggregate(query, :count)
    total_pages = max(ceil(total_count / per_page), 1)

    entries =
      query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      entries: entries,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Returns distinct email types that have been logged.
  """
  def distinct_email_types do
    from(e in EmailLog, select: e.email_type, distinct: true, order_by: e.email_type)
    |> Repo.all()
  end

  @doc """
  Counts email logs for a specific user.
  """
  def count_email_logs_for_user(user_id) do
    from(e in EmailLog, where: e.user_id == ^user_id)
    |> Repo.aggregate(:count)
  end

  defp maybe_filter_type(query, nil), do: query
  defp maybe_filter_type(query, type), do: where(query, [e], e.email_type == ^type)

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [e], e.status == ^status)

  defp maybe_filter_user(query, nil), do: query
  defp maybe_filter_user(query, user_id), do: where(query, [e], e.user_id == ^user_id)
end
