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
      |> assign(:user_white_flags, [])
      |> assign(:user_green_flags, [])
      |> assign(:user_red_flags, [])
      |> assign(:number_of_potential_partners, Enum.count(potential_partners))
      |> assign(:errors, [])
      |> assign(
        :form,
        Form.for_create(User, :register_with_password, domain: Accounts, as: "user")
      )

    {:ok, socket}
  end

  @impl true

  def handle_params(%{"step" => "user_details"}, _url, socket) do
    {:noreply,
     socket
     |> assign(:step, "user_details")}
  end

  def handle_params(%{"step" => step}, _url, socket) do
    {color, page_title_str, title_str, info_text_str} =
      step_info(step, socket.assigns.language, @max_flags)

    {:noreply, assign_flags(socket, color, page_title_str, title_str, info_text_str)}
  end

  def handle_params(_, _url, socket) do
    {:noreply, socket |> assign(:step, "filter_potential_partners")}
  end

  defp step_info("select_white_flags", language, _) do
    {
      :white,
      with_locale(language, fn -> gettext("Select your own flags") end),
      with_locale(language, fn -> gettext("Choose Your Own Flags") end),
      with_locale(language, fn ->
        gettext(
          "We use flags to match people. You can select red and green flags later. But first tell us something about yourself and select up to %{number_of_flags} flags that describe yourself. The ones selected first are the most important."
        )
      end)
    }
  end

  defp step_info("select_green_flags", language, number_of_flags) do
    {
      :green,
      with_locale(language, fn -> gettext("Select your green flags") end),
      with_locale(language, fn -> gettext("Choose Your Green Flags") end),
      with_locale(language, fn ->
        gettext(
          "Choose up to %{number_of_flags} flags that you want your partner to have. The ones selected first are the most important.",
          number_of_flags: number_of_flags
        )
      end)
    }
  end

  defp step_info("select_red_flags", language, number_of_flags) do
    {
      :red,
      with_locale(language, fn -> gettext("Select your red flags") end),
      with_locale(language, fn -> gettext("Choose Your Red Flags") end),
      with_locale(language, fn ->
        gettext(
          "Choose up to %{number_of_flags} flags that you don't want to have in a partner. The ones selected first are the most important.",
          number_of_flags: number_of_flags
        )
      end)
    }
  end

  defp assign_flags(socket, color, page_title_str, title_str, info_text_str) do
    socket
    |> assign(:color, color)
    |> assign(:categories, fetch_categories())
    |> assign(:title, title_str)
    |> assign(:info_text, info_text_str)
    |> assign(:page_title, page_title_str)
    |> assign(:step, "select_flags")
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

  def handle_event("select_flag", %{"color" => color, "flagid" => flagid}, socket) do
    socket = update_flags_array(:add, color, flagid, socket)
    {:noreply, socket}
  end

  def handle_event("remove_flag", %{"color" => color, "flagid" => flagid}, socket) do
    socket = update_flags_array(:remove, color, flagid, socket)
    {:noreply, socket}
  end

  def handle_event("move_to_next_step", %{"color" => color}, socket) do
    case color do
      "white" ->
        {:noreply,
         socket
         |> push_patch(to: "/beta?step=select_green_flags")}

      "green" ->
        {:noreply,
         socket
         |> push_patch(to: "/beta?step=select_red_flags")}

      "red" ->
        {:noreply,
         socket
         |> push_patch(to: "/beta?step=user_details")}
    end
  end

  def handle_event("move_to_previous_step", %{"color" => color}, socket) do
    case color do
      "white" ->
        {:noreply,
         socket
         |> push_patch(to: "/beta")}

      "green" ->
        {:noreply,
         socket
         |> push_patch(to: "/beta?step=select_white_flags")}

      "red" ->
        {:noreply,
         socket
         |> push_patch(to: "/beta?step=select_green_flags")}

      "user_details" ->
        {:noreply,
         socket
         |> push_patch(to: "/beta?step=select_red_flags")}
    end
  end

  defp update_flags_array(:add, color, flagid, socket) do
    assign_key = get_assign_key(color)

    socket
    |> assign(assign_key, socket.assigns[assign_key] ++ [flagid])
  end

  defp update_flags_array(:remove, color, flagid, socket) do
    assign_key = get_assign_key(color)

    socket
    |> assign(assign_key, List.delete(socket.assigns[assign_key], flagid))
  end

  defp get_assign_key("white"), do: :user_white_flags
  defp get_assign_key("red"), do: :user_red_flags
  defp get_assign_key("green"), do: :user_green_flags

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

      <.user_details_form
        :if={@step == "user_details"}
        language={@language}
        form={@form}
        errors={@errors}
      />

      <.flags_for_selection
        :if={@step == "select_flags"}
        color={@color}
        categories={@categories}
        user_white_flags={@user_white_flags}
        user_green_flags={@user_green_flags}
        user_red_flags={@user_red_flags}
        title={@title}
        info_text={@info_text}
        language={@language}
      />
    </div>
    """
  end
end
