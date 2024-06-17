defmodule Animina.MyCustomSignInPreparation do
  @moduledoc """
  Prepare a query for sign in

  This preparation performs two jobs, one before the query executes and one
  after.

  Firstly, it constrains the query to match the identity field passed to the
  action.

  Secondly, it validates the supplied password using the configured hash
  provider, and if correct allows the record to be returned, otherwise returns
  an authentication failed error.
  """
  use Ash.Resource.Preparation
  alias Ash.Query
  require Ash.Query
  import AniminaWeb.Gettext
  alias AshAuthentication.{Errors.AuthenticationFailed, Jwt}

  @doc false
  @impl true
  def prepare(query, _options, _context) do
    if query.arguments != %{} && query.arguments.password && query.arguments.username_or_email do
      filter_for_username_or_email(query, argument_is_username(query.arguments.username_or_email))
    else
      query
    end
  end

  defp validate_password(record, query) do
    password = query.arguments.password

    if Bcrypt.verify_pass(password, Map.get(record, :hashed_password)) do
      case record.state do
        :normal ->
          {:ok,
           [
             maybe_generate_token(
               query.context[:token_type] || :user,
               record
             )
           ]}

        :under_investigation ->
          {:error,
           AuthenticationFailed.exception(
             query: query,
             caused_by: %{
               module: __MODULE__,
               action: query.action,
               resource: query.resource,
               message:
                 gettext("Account is under investigation, kindly try and log in after 24 hours")
             }
           )}

        :banned ->
          {:error,
           AuthenticationFailed.exception(
             query: query,
             caused_by: %{
               module: __MODULE__,
               action: query.action,
               resource: query.resource,
               message: gettext("Account is banned, Kindly Contact Support")
             }
           )}

        _ ->
          {:ok,
           [
             maybe_generate_token(
               query.context[:token_type] || :user,
               record
             )
           ]}
      end
    else
      {:error,
       AuthenticationFailed.exception(
         query: query,
         caused_by: %{
           module: __MODULE__,
           action: query.action,
           resource: query.resource,
           message: "Username or password is incorrect"
         }
       )}
    end
  end

  defp maybe_generate_token(purpose, record) when purpose in [:user, :sign_in] do
    if AshAuthentication.Info.authentication_tokens_enabled?(record.__struct__) do
      generate_token(purpose, record)
    else
      record
    end
  end

  defp generate_token(purpose, record)
       when purpose == :sign_in do
    {:ok, token, _claims} =
      Jwt.token_for_user(record, %{"purpose" => to_string(purpose)}, token_lifetime: 60)

    Ash.Resource.put_metadata(record, :token, token)
  end

  defp generate_token(purpose, record) do
    {:ok, token, _claims} = Jwt.token_for_user(record, %{"purpose" => to_string(purpose)})

    Ash.Resource.put_metadata(record, :token, token)
  end

  defp argument_is_username(argument) do
    if String.contains?(argument, "@") && String.at(argument, 0) != "@" do
      false
    else
      true
    end
  end

  #  the second parameter is for when the argument is a username
  defp filter_for_username_or_email(query, true) do
    username = format_username(query.arguments.username_or_email)

    query
    |> Query.filter(username == ^username)
    |> Query.before_action(fn query ->
      Ash.Query.ensure_selected(query, :hashed_password)
    end)
    |> Query.after_action(fn
      query, [] ->
        # If record is empty, return an error
        {:error,
         AuthenticationFailed.exception(
           query: query,
           caused_by: %{
             module: __MODULE__,
             action: query.action,
             resource: query.resource,
             message: "Username or password is incorrect"
           }
         )}

      query, [record] when is_binary(:erlang.map_get(:hashed_password, record)) ->
        validate_password(record, query)
    end)
  end

  defp filter_for_username_or_email(query, false) do
    query
    |> Query.filter(email == ^query.arguments.username_or_email)
    |> Query.before_action(fn query ->
      Ash.Query.ensure_selected(query, :hashed_password)
    end)
    |> Query.after_action(fn
      query, [] ->
        # If record is empty, return an error
        {:error,
         AuthenticationFailed.exception(
           query: query,
           caused_by: %{
             module: __MODULE__,
             action: query.action,
             resource: query.resource,
             message: "Username or password is incorrect"
           }
         )}

      query, [record] when is_binary(:erlang.map_get(:hashed_password, record)) ->
        validate_password(record, query)
    end)
  end

  defp format_username(username) do
    if String.at(username, 0) == "@" do
      String.slice(username, 1, String.length(username))
    else
      username
    end
  end
end
