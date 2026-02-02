defmodule AniminaWeb.UserLive.TraitsWizard do
  use AniminaWeb, :live_view

  alias Animina.Traits
  alias AniminaWeb.TraitTranslations

  @step_colors %{1 => "white", 2 => "green", 3 => "red"}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-2xl px-4 py-8">
        <div class="breadcrumbs text-sm mb-6">
          <ul>
            <li>
              <.link navigate={~p"/users/settings"}>{gettext("Settings")}</.link>
            </li>
            <li>
              <.link patch={traits_path(1)}>{gettext("My Flags")}</.link>
            </li>
            <li>{step_label(@current_step)}</li>
          </ul>
        </div>

        <div class="text-center mb-8">
          <.header>
            {gettext("My Flags")}
            <:subtitle>{step_subtitle(@current_step)}</:subtitle>
          </.header>
        </div>

        <%!-- Step indicator --%>
        <div class="flex items-center justify-center gap-4 mb-8">
          <.step_dot
            step={1}
            current={@current_step}
            label={gettext("White Flags")}
            count={flag_count(@user_flags, "white")}
          />
          <div class={[
            "h-0.5 w-12",
            if(@current_step > 1, do: "bg-success", else: "bg-base-300")
          ]}>
          </div>
          <.step_dot
            step={2}
            current={@current_step}
            label={gettext("Partner Likes")}
            count={flag_count(@user_flags, "green")}
          />
          <div class={[
            "h-0.5 w-12",
            if(@current_step > 2, do: "bg-error", else: "bg-base-300")
          ]}>
          </div>
          <.step_dot
            step={3}
            current={@current_step}
            label={gettext("Partner No-Go")}
            count={flag_count(@user_flags, "red")}
          />
        </div>

        <%!-- Step heading --%>
        <h2 class={["text-lg font-semibold mb-2", step_color_class(@current_step)]}>
          {step_label(@current_step)}
        </h2>
        <p class="text-xs text-base-content/70 mb-4">
          {step_explanation(@current_step)}
        </p>

        <%!-- Intensity legend for green and red steps --%>
        <div :if={@current_step in [2, 3]} class="flex flex-wrap items-center gap-3 mb-6 text-xs">
          <span class="text-base-content/60">{gettext("Click to cycle:")}</span>
          <span class={[
            "btn btn-xs gap-1 pointer-events-none btn-dash",
            step_btn_class(@current_step)
          ]}>
            {intensity_soft_label(@current_step)}
          </span>
          <span class="text-base-content/40">&rarr;</span>
          <span class={[
            "btn btn-xs gap-1 pointer-events-none",
            step_btn_class(@current_step)
          ]}>
            {intensity_hard_label(@current_step)}
          </span>
          <span class="text-base-content/40">&rarr;</span>
          <span class="btn btn-xs gap-1 pointer-events-none btn-outline">
            {gettext("off")}
          </span>
        </div>

        <%!-- Core categories with their flags --%>
        <.category_flags
          categories={@core_categories}
          flags_by_category={@flags_by_category}
          user_flags={@user_flags}
          current_step={@current_step}
        />

        <%!-- Category picker --%>
        <.category_picker
          optin_categories={@optin_categories}
          selected_optin_ids={@selected_optin_ids}
          locked_category_ids={@locked_category_ids}
        />

        <%!-- Opted-in categories with their flags --%>
        <.category_flags
          categories={@selected_optin_categories}
          flags_by_category={@flags_by_category}
          user_flags={@user_flags}
          current_step={@current_step}
        />

        <%!-- Navigation buttons --%>
        <div class="flex justify-between items-center mt-8 pt-4 border-t border-base-300">
          <div>
            <button
              :if={@current_step > 1}
              phx-click="prev_step"
              class="btn btn-sm btn-outline"
            >
              {gettext("Back")}
            </button>
          </div>

          <div>
            <%= if @current_step < 3 do %>
              <button phx-click="next_step" class="btn btn-sm btn-primary">
                {gettext("Next")}
              </button>
            <% else %>
              <.link navigate={~p"/users/settings"} class="btn btn-sm btn-primary">
                {gettext("Finish")}
              </.link>
            <% end %>
          </div>
        </div>

        <%!-- Delete all flags --%>
        <div
          :if={
            flag_count(@user_flags, "white") + flag_count(@user_flags, "green") +
              flag_count(@user_flags, "red") > 0
          }
          class="mt-6 flex justify-center"
        >
          <button
            phx-click="delete_all_flags"
            data-confirm={delete_all_confirmation(@user_flags)}
            class="btn btn-sm btn-error btn-outline"
          >
            {gettext("Delete all flags")}
          </button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp category_picker(assigns) do
    ~H"""
    <div class="mb-6">
      <h3 class="text-xs font-semibold text-base-content/60 mb-2">
        {gettext("Optional Categories")}
      </h3>
      <div :for={{group_key, group_label} <- picker_groups()} class="mb-2">
        <span class="text-xs text-base-content/50 mr-2">{group_label}</span>
        <div class="inline-flex flex-wrap gap-x-4 gap-y-1">
          <label
            :for={cat <- Enum.filter(@optin_categories, &(&1.picker_group == group_key))}
            phx-click="toggle_optin"
            phx-value-category-id={cat.id}
            class={[
              "inline-flex items-center gap-1.5 text-sm",
              if(cat.id in @locked_category_ids,
                do: "cursor-not-allowed opacity-60",
                else: "cursor-pointer"
              )
            ]}
          >
            <input
              type="checkbox"
              class="checkbox checkbox-sm checkbox-primary"
              checked={cat.id in @selected_optin_ids}
              disabled={cat.id in @locked_category_ids}
            />
            <span :if={cat.sensitive}>🔒</span>
            {TraitTranslations.translate(cat.name)}
          </label>
        </div>
      </div>
    </div>
    """
  end

  defp category_flags(assigns) do
    ~H"""
    <div :for={category <- @categories} class="mb-8">
      <h3 class="text-sm font-semibold text-base-content mb-3">
        {TraitTranslations.translate(category.name)}
      </h3>

      <div class="flex flex-wrap gap-2">
        <button
          :for={flag <- all_flags_for_category(@flags_by_category, category)}
          phx-click={!flag_taken?(@user_flags, flag.id, @current_step) && "toggle_flag"}
          phx-value-flag-id={flag.id}
          disabled={flag_taken?(@user_flags, flag.id, @current_step)}
          title={flag_tooltip(@user_flags, flag.id, @current_step)}
          class={[
            "btn btn-sm gap-1",
            if(flag_taken?(@user_flags, flag.id, @current_step),
              do: "btn-disabled",
              else: flag_btn_class(@user_flags, flag.id, @current_step)
            )
          ]}
        >
          <span>{flag.emoji}</span> {TraitTranslations.translate(flag.name)}
        </button>
      </div>
    </div>
    """
  end

  defp picker_groups do
    [
      {"lifestyle", gettext("Lifestyle")},
      {"interests", gettext("Interests")},
      {"going_out", gettext("Going Out & Travels")},
      {"sensitive", gettext("Sensitive")}
    ]
  end

  defp step_dot(assigns) do
    ~H"""
    <div
      class="flex flex-col items-center cursor-pointer"
      phx-click="goto_step"
      phx-value-step={@step}
    >
      <div class="relative">
        <div class={[
          "w-10 h-10 rounded-full flex items-center justify-center text-base font-bold",
          if(@step <= @current,
            do: step_dot_active_class(@step),
            else: step_dot_inactive_class(@step)
          )
        ]}>
          {@step}
        </div>
        <span
          :if={@count > 0}
          class="absolute -top-1 -right-1 flex items-center justify-center rounded-full bg-base-content text-base-100 text-[9px] font-bold min-w-[16px] h-[16px] px-0.5 leading-none"
        >
          {@count}
        </span>
      </div>
      <span class={["text-xs mt-1", step_label_class(@step, @current)]}>{@label}</span>
    </div>
    """
  end

  defp step_dot_active_class(1), do: "bg-primary text-primary-content"
  defp step_dot_active_class(2), do: "bg-success text-success-content"
  defp step_dot_active_class(3), do: "bg-error text-error-content"

  defp step_dot_inactive_class(1), do: "bg-base-300 text-base-content/50"
  defp step_dot_inactive_class(2), do: "bg-base-300 text-success/60 ring-2 ring-success/30"
  defp step_dot_inactive_class(3), do: "bg-base-300 text-error/60 ring-2 ring-error/30"

  defp step_label_class(_step, _current), do: "text-base-content/70"

  defp step_label(1), do: gettext("About Me")
  defp step_label(2), do: gettext("I Like in a Partner")
  defp step_label(3), do: gettext("Partner Deal Breakers")

  defp step_page_title(1), do: gettext("My Flags — About Me")
  defp step_page_title(2), do: gettext("My Flags — I Like in a Partner")
  defp step_page_title(3), do: gettext("My Flags — Partner Deal Breakers")

  defp step_explanation(1), do: gettext("Select traits that describe who you are.")

  defp step_explanation(2),
    do:
      gettext(
        "Select traits you'd like your partner to have. Click once for nice to have, again for must have."
      )

  defp step_explanation(3),
    do:
      gettext(
        "Select traits you don't want in a partner. Click once for prefer not, again for deal breaker."
      )

  defp step_subtitle(1),
    do: gettext("Traits that describe who you are")

  defp step_subtitle(2),
    do: gettext("Traits you'd like your partner to have")

  defp step_subtitle(3),
    do: gettext("Traits that are deal-breakers in a partner")

  defp intensity_hard_label(2), do: gettext("must have")
  defp intensity_hard_label(3), do: gettext("deal breaker")

  defp intensity_soft_label(2), do: gettext("nice to have")
  defp intensity_soft_label(3), do: gettext("prefer not")

  defp step_color(step), do: Map.fetch!(@step_colors, step)

  defp step_color_class(1), do: "text-base-content"
  defp step_color_class(2), do: "text-success"
  defp step_color_class(3), do: "text-error"

  defp step_btn_class(1), do: "btn-neutral"
  defp step_btn_class(2), do: "btn-success"
  defp step_btn_class(3), do: "btn-error"

  defp flag_btn_class(user_flags, flag_id, step) do
    color = step_color(step)

    case find_user_flag(user_flags, flag_id, color) do
      nil -> "btn-outline"
      %{intensity: "hard"} -> step_btn_class(step)
      %{intensity: "soft"} -> "btn-dash #{step_btn_class(step)}"
    end
  end

  defp flag_tooltip(user_flags, flag_id, step) when step in [2, 3] do
    color = step_color(step)

    case find_user_flag(user_flags, flag_id, color) do
      nil ->
        if step == 2,
          do: gettext("click to set as nice to have"),
          else: gettext("click to set as prefer not")

      %{intensity: "soft"} ->
        if step == 2,
          do: gettext("nice to have — click to change to must have"),
          else: gettext("prefer not — click to change to deal breaker")

      %{intensity: "hard"} ->
        if step == 2,
          do: gettext("must have — click to remove"),
          else: gettext("deal breaker — click to remove")
    end
  end

  defp flag_tooltip(_user_flags, _flag_id, _step), do: nil

  # A flag is "taken" on step 2 (green) if it's already selected as red, and vice versa.
  defp flag_taken?(user_flags, flag_id, 2),
    do: Enum.any?(user_flags, &(&1.flag_id == flag_id && &1.color == "red" && !&1.inherited))

  defp flag_taken?(user_flags, flag_id, 3),
    do: Enum.any?(user_flags, &(&1.flag_id == flag_id && &1.color == "green" && !&1.inherited))

  defp flag_taken?(_user_flags, _flag_id, _step), do: false

  defp find_user_flag(user_flags, flag_id, color) do
    Enum.find(user_flags, &(&1.flag_id == flag_id && &1.color == color && !&1.inherited))
  end

  defp flag_count(user_flags, color) do
    Enum.count(user_flags, &(&1.color == color && !&1.inherited))
  end

  defp all_flags_for_category(flags_by_category, category) do
    Map.get(flags_by_category, category.id, [])
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    core_categories = Traits.list_core_categories()
    optin_categories = Traits.list_optin_categories()
    selected_optin_ids = Traits.list_user_optin_category_ids(user)

    selected_optin_categories =
      Enum.filter(optin_categories, &(&1.id in selected_optin_ids))

    all_visible = core_categories ++ selected_optin_categories

    flags_by_category =
      Map.new(all_visible, fn cat ->
        {cat.id, Traits.list_top_level_flags_by_category(cat)}
      end)

    user_flags = load_all_user_flags(user)

    {:ok,
     socket
     |> assign(:core_categories, core_categories)
     |> assign(:optin_categories, optin_categories)
     |> assign(:selected_optin_ids, selected_optin_ids)
     |> assign(:selected_optin_categories, selected_optin_categories)
     |> assign(:flags_by_category, flags_by_category)
     |> assign(:user_flags, user_flags)
     |> assign(:locked_category_ids, locked_category_ids(user_flags, flags_by_category))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    step = step_from_param(params["step"])

    {:noreply,
     socket
     |> assign(:current_step, step)
     |> assign(:page_title, step_page_title(step))}
  end

  @impl true
  def handle_event("next_step", _params, socket) do
    step = min(socket.assigns.current_step + 1, 3)
    {:noreply, push_patch(socket, to: traits_path(step))}
  end

  def handle_event("prev_step", _params, socket) do
    step = max(socket.assigns.current_step - 1, 1)
    {:noreply, push_patch(socket, to: traits_path(step))}
  end

  def handle_event("goto_step", %{"step" => step_str}, socket) do
    step = String.to_integer(step_str)

    if step in 1..3 do
      {:noreply, push_patch(socket, to: traits_path(step))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("toggle_optin", %{"category-id" => category_id}, socket) do
    # Prevent unchecking a category that has active flags
    if category_id in socket.assigns.locked_category_ids do
      {:noreply, socket}
    else
      user = socket.assigns.current_scope.user
      category = Traits.get_category!(category_id)
      {:ok, _} = Traits.toggle_category_optin(user, category)

      selected_optin_ids = Traits.list_user_optin_category_ids(user)

      selected_optin_categories =
        Enum.filter(socket.assigns.optin_categories, &(&1.id in selected_optin_ids))

      all_visible = socket.assigns.core_categories ++ selected_optin_categories

      flags_by_category =
        rebuild_flags_by_category(all_visible, socket.assigns.flags_by_category)

      {:noreply,
       socket
       |> assign(:selected_optin_ids, selected_optin_ids)
       |> assign(:selected_optin_categories, selected_optin_categories)
       |> assign(:flags_by_category, flags_by_category)}
    end
  end

  def handle_event("toggle_flag", %{"flag-id" => flag_id}, socket) do
    user = socket.assigns.current_scope.user
    step = socket.assigns.current_step
    color = step_color(step)
    user_flag = find_user_flag(socket.assigns.user_flags, flag_id, color)

    do_toggle_flag(socket, user, user_flag, flag_id, step, color)
  end

  def handle_event("delete_all_flags", _params, socket) do
    user = socket.assigns.current_scope.user
    {:ok, _count} = Traits.delete_all_user_flags(user)

    {:noreply,
     socket
     |> put_flash(:info, gettext("All flags have been deleted."))
     |> reload_user_flags(user)}
  end

  # 3-state cycle for green/red: soft → hard → remove
  # In exclusive_hard categories, skip hard and go to remove when other flags exist
  defp do_toggle_flag(socket, user, %{intensity: "soft"} = user_flag, _flag_id, step, color)
       when step in [2, 3] do
    if Traits.exclusive_hard_has_others?(user.id, user_flag.flag_id, color) do
      {:ok, _} = Traits.remove_user_flag(user, user_flag.id)
      {:noreply, reload_user_flags(socket, user)}
    else
      case Traits.update_user_flag_intensity(user_flag.id, "hard") do
        {:ok, _} ->
          {:noreply, reload_user_flags(socket, user)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, gettext("Could not update flag."))}
      end
    end
  end

  # White flags: simple toggle; Green/red hard flags: remove on third click
  defp do_toggle_flag(socket, user, %{} = user_flag, _flag_id, _step, _color) do
    {:ok, _} = Traits.remove_user_flag(user, user_flag.id)
    {:noreply, reload_user_flags(socket, user)}
  end

  # Not selected — add as soft for green/red, hard for white
  defp do_toggle_flag(socket, user, nil, flag_id, step, color) do
    initial_intensity = if step in [2, 3], do: "soft", else: "hard"

    case Traits.find_existing_flag_in_category(user.id, flag_id, color) do
      %{id: existing_id} -> Traits.remove_user_flag(user, existing_id)
      nil -> :ok
    end

    case Traits.add_user_flag(%{
           user_id: user.id,
           flag_id: flag_id,
           color: color,
           intensity: initial_intensity,
           position: next_position(socket.assigns.user_flags, color)
         }) do
      {:ok, _user_flag} ->
        {:noreply, reload_user_flags(socket, user)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("Could not add flag."))}
    end
  end

  defp load_all_user_flags(user) do
    Traits.list_user_flags(user, "white") ++
      Traits.list_user_flags(user, "green") ++
      Traits.list_user_flags(user, "red")
  end

  defp next_position(user_flags, color) do
    user_flags
    |> Enum.filter(&(&1.color == color))
    |> length()
    |> Kernel.+(1)
  end

  defp reload_user_flags(socket, user) do
    user_flags = load_all_user_flags(user)

    socket
    |> assign(:user_flags, user_flags)
    |> assign(
      :locked_category_ids,
      locked_category_ids(user_flags, socket.assigns.flags_by_category)
    )
  end

  defp locked_category_ids(user_flags, flags_by_category) do
    user_flag_ids = MapSet.new(user_flags, & &1.flag_id)

    flags_by_category
    |> Enum.filter(fn {_cat_id, flags} ->
      Enum.any?(flags, &(&1.id in user_flag_ids))
    end)
    |> Enum.map(fn {cat_id, _flags} -> cat_id end)
  end

  defp rebuild_flags_by_category(all_visible, existing_flags_by_category) do
    Map.new(all_visible, fn cat ->
      case Map.fetch(existing_flags_by_category, cat.id) do
        {:ok, flags} -> {cat.id, flags}
        :error -> {cat.id, Traits.list_top_level_flags_by_category(cat)}
      end
    end)
  end

  defp traits_path(step) do
    ~p"/users/settings/traits?step=#{@step_colors[step]}"
  end

  defp step_from_param("green"), do: 2
  defp step_from_param("red"), do: 3
  defp step_from_param(_), do: 1

  defp delete_all_confirmation(user_flags) do
    white = flag_count(user_flags, "white")
    green = flag_count(user_flags, "green")
    red = flag_count(user_flags, "red")

    gettext(
      "Are you sure that you want to delete all %{white} white, %{green} green and %{red} red flags of yours?",
      white: white,
      green: green,
      red: red
    )
  end
end
