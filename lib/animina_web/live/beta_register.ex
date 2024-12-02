defmodule AniminaWeb.BetaRegisterLive do
  use AniminaWeb, :live_view
  alias Animina.Accounts.User
  alias AniminaWeb.PotentialPartner
  alias AshPhoenix.Form

  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    potential_partners =
      PotentialPartner.potential_partners_on_registration(default_user_params())

    socket =
      socket
      |> assign(language: language)
      |> assign(current_user: nil)
      |> assign(active_tab: "register")
      |> assign(trigger_action: false)
      |> assign(current_user_credit_points: 0)
      |> assign(:number_of_potential_partners, Enum.count(potential_partners))
      |> assign(:errors, [])
      |> assign(
        :form,
        Form.for_create(User, :register_with_password, domain: Accounts, as: "user")
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_and_filter_potential_partners", %{"user" => user}, socket) do
    potential_partners = PotentialPartner.potential_partners_on_registration(user)

    {:noreply,
     socket
     |> assign(:number_of_potential_partners, Enum.count(potential_partners))}
  end

  defp default_user_params do
    %{
      "height" => "",
      "maximum_partner_height" => "",
      "minimum_partner_height" => "",
      "maximum_partner_age" => "",
      "minimum_partner_age" => "",
      "gender" => "male",
      "search_range" => "",
      "zip_code" => "",
      "birthday" => ""
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.initial_form
        number_of_potential_partners={@number_of_potential_partners}
        language={@language}
        form={@form}
        errors={@errors}
      />
    </div>
    """
  end
end
