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
  alias AshAuthentication.{Errors.AuthenticationFailed, Info, Jwt}
  alias Ash.{Error.Unknown, Query, Resource.Preparation}
  require Ash.Query

  @doc false
  @impl true
  @spec prepare(Query.t(), keyword, Preparation.Context.t()) :: Query.t()
  def prepare(query, options, context) do

if  query.arguments != %{} && query.arguments.password && query.arguments.username_or_email do
    password =
      query.arguments.password


    query
    |> Query.filter(
      email == ^query.arguments.username_or_email or
        username == ^query.arguments.username_or_email
    )
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
        password = query.arguments.password

        if Bcrypt.verify_pass(password, Map.get(record, :hashed_password)) do
          {:ok,
           [
             maybe_generate_token(
               query.context[:token_type] || :user,
               record
             )
           ]}
        else
          {:error,
           AuthenticationFailed.exception(
             query: query,
             caused_by: %{
               module: __MODULE__,
               action: query.action,
               resource: query.resource,
               message: "Password is not valid"
             }
           )}
        end



    end)
  else
    query
  end
  end

  defp check_sign_in_token_configuration(query, strategy)
       when query.context.token_type == :sign_in and not strategy.sign_in_tokens_enabled? do
    Query.add_error(
      query,
      Unknown.exception(
        message: """
        Invalid configuration detected. A sign in token was requested for the #{strategy.name} strategy on #{inspect(query.resource)}, but that strategy
        does not support sign in tokens. See `sign_in_tokens_enabled?` for more.
        """
      )
    )
  end

  defp check_sign_in_token_configuration(query, _) do
    query
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
    {:ok, token, _claims} =  Jwt.token_for_user(record, %{"purpose" => to_string(purpose)})

    Ash.Resource.put_metadata(record, :token, token)
  end
end
