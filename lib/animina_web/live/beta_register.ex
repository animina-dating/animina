defmodule AniminaWeb.BetaRegisterLive do
  use AniminaWeb, :live_view
  alias Animina.Accounts.User
  alias AshPhoenix.Form

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    socket =
      socket
      |> assign(language: language)
      |> assign(current_user: nil)
      |> assign(active_tab: "register")
      |> assign(trigger_action: false)
      |> assign(current_user_credit_points: 0)
      |> assign(:errors, [])
      |> assign(
        :form,
        Form.for_create(User, :register_with_password, domain: Accounts, as: "user")
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.initial_form language={@language} form={@form} errors={@errors} />
    </div>
    """
  end
end
