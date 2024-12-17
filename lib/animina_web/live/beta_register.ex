defmodule AniminaWeb.BetaRegisterLive do
  use AniminaWeb, :live_view
  alias Animina.Accounts.User
  alias Animina.BirthdayValidator
  alias Animina.Traits
  alias AniminaWeb.PotentialPartner
  alias AshPhoenix.Form

  @max_flags Application.compile_env(:animina, AniminaWeb.FlagsLive)[:max_selected]
  @impl true
  def mount(_params, %{"language" => language} = _session, socket) do
    potential_partners =
      PotentialPartner.potential_partners_on_registration(default_user_params())

    socket =
      socket
      |> assign(language: language)
      |> assign(current_user: nil)
      |> assign(birthday_error: nil)
      |> assign(active_tab: "register")
      |> assign(trigger_action: false)
      |> assign(current_user_credit_points: 0)
      |> assign(:step, "filter_potential_partners")
      |> assign(:number_of_potential_partners, Enum.count(potential_partners))
      |> assign(:errors, [])
      |> assign(
        :form,
        Form.for_create(User, :register_with_password, domain: Accounts, as: "user")
      )

    {:ok, socket}
  end

  @impl true

  def handle_params(%{"step" => "select_white_flags"}, _url, socket) do
    {:noreply,
     socket
     |> assign(:color, :white)
     |> assign(categories: fetch_categories())
     |> assign(
       title: with_locale(socket.assigns.language, fn -> gettext("Choose Your Own Flags") end)
     )
     |> assign(
       info_text:
         with_locale(socket.assigns.language, fn ->
           gettext(
             "We use flags to match people. You can select red and green flags later. But first tell us something about yourself and select up to %{number_of_flags} flags that describe yourself. The ones selected first are the most important.",
             number_of_flags: @max_flags
           )
         end)
     )
     |> assign(
       page_title:
         with_locale(socket.assigns.language, fn -> gettext("Select your own flags") end)
     )
     |> assign(:step, "select_flags")}
  end

  def handle_params(%{"step" => "select_green_flags"}, _url, socket) do
    {:noreply,
     socket
     |> assign(
       page_title:
         with_locale(socket.assigns.language, fn -> gettext("Select your green flags") end)
     )
     |> assign(:color, :green)
     |> assign(categories: fetch_categories())
     |> assign(
       title: with_locale(socket.assigns.language, fn -> gettext("Choose Your Green Flags") end)
     )
     |> assign(
       info_text:
         with_locale(socket.assigns.language, fn ->
           gettext(
             "Choose up to %{number_of_flags} flags that you want your partner to have. The ones selected first are the most important.",
             number_of_flags: @max_flags
           )
         end)
     )
     |> assign(:step, "select_flags")}
  end

  def handle_params(%{"step" => "select_red_flags"}, _url, socket) do
    {:noreply,
     socket
     |> assign(:color, :red)
     |> assign(
       page_title:
         with_locale(socket.assigns.language, fn -> gettext("Select your red flags") end)
     )
     |> assign(categories: fetch_categories())
     |> assign(
       title: with_locale(socket.assigns.language, fn -> gettext("Choose Your Red Flags") end)
     )
     |> assign(
       info_text:
         with_locale(socket.assigns.language, fn ->
           gettext(
             "Choose up to %{number_of_flags} flags that you don't want to have in a partner. The ones selected first are the most important.",
             number_of_flags: @max_flags
           )
         end)
     )
     |> assign(:step, "select_flags")}
  end

  def handle_params(_, _url, socket) do
    {:noreply, socket |> assign(:step, "filter_potential_partners")}
  end

  @impl true
  def handle_event("validate_and_filter_potential_partners", %{"user" => user}, socket) do
    potential_partners = PotentialPartner.potential_partners_on_registration(user)

    case BirthdayValidator.validate_birthday(user["birthday"]) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:birthday_error, nil)
         |> assign(:number_of_potential_partners, Enum.count(potential_partners))}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:birthday_error, reason)
         |> assign(:number_of_potential_partners, Enum.count(potential_partners))}
    end
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

  defp fetch_categories do
    Traits.Category
    |> Ash.Query.for_read(:read)
    |> Ash.read!()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.initial_form
        :if={@step == "filter_potential_partners"}
        number_of_potential_partners={@number_of_potential_partners}
        language={@language}
        birthday_error={@birthday_error}
        form={@form}
        errors={@errors}
      />

      <.flags_for_selection
        :if={@step == "select_flags"}
        color={@color}
        categories={@categories}
        title={@title}
        info_text={@info_text}
        language={@language}
      />
    </div>
    """
  end
end
