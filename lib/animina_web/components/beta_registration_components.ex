defmodule AniminaWeb.BetaRegistrationComponents do
  @moduledoc """
  Provides Waitlist UI components.
  """
  use Phoenix.Component
  import AniminaWeb.Gettext
  use PhoenixHTMLHelpers
  import AniminaWeb.CoreComponents
  import AniminaWeb.AniminaComponents
  import Gettext, only: [with_locale: 2]

  def initial_form(assigns) do
    ~H"""
    <div>
      <.notification_box
        message={
          with_locale(@language, fn ->
            gettext(
              "Our competitors charge monthly, even if you don’t find a match. We only charge €20 after you find yours. And it's free for beta testers! 🎉"
            )
          end)
        }
        avatars_urls={[
          "/images/unsplash/men/prince-akachi-4Yv84VgQkRM-unsplash.jpg",
          "/images/unsplash/women/stefan-stefancik-QXevDflbl8A-unsplash.jpg"
        ]}
      />

      <div class="mt-3 text-base flex gap-2 items-center font-semibold dark:text-white">
        <p>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Potential Matches Counter:") %>
          <% end) %>
        </p>
        <%= if @searching_potential_partners do %>
          <.loading_dots />
        <% else %>
          <%= @number_of_potential_partners %>
        <% end %>
      </div>

      <.form
        :let={f}
        id="beta_user_registration_form"
        for={@form}
        class="mt-6 space-y-6 group"
        phx-change="validate_and_filter_potential_partners"
        phx-submit="proceed_to_flag_selection"
        phx-debounce="500"
      >
        <h2 class="mt-3 text-2xl font-semibold dark:text-white">
          <%= with_locale(@language, fn -> %>
            <%= gettext("Find your match") %>
          <% end) %>
        </h2>

        <.gender_select
          f={f}
          language={@language}
          default_gender={@default_gender}
          title={
            with_locale(@language, fn ->
              gettext("You are searching for a")
            end)
          }
        />

        <div class="w-[100%] md:grid grid-cols-2 gap-8">
          <.height_select f={f} language={@language} />
          <.birthday_select f={f} language={@language} birthday_error={@birthday_error} />
          <.zip_code_select f={f} language={@language} />
        </div>

        <h2 class="mt-3 text-2xl font-semibold dark:text-white">
          <%= with_locale(@language, fn -> %>
            <%= gettext("Narrow Down Your Search") %>
          <% end) %>
        </h2>
        <div class="w-[100%] md:grid grid-cols-2 gap-8">
          <.minimum_partner_age f={f} language={@language} />
          <.maximum_partner_age f={f} language={@language} />
          <.minimum_partner_height f={f} language={@language} />
          <.maximum_partner_height f={f} language={@language} />
          <.search_range f={f} language={@language} />
        </div>

        <div class="w-[100%] flex justify-start">
          <%= submit("Proceed",
            class:
              "flex  justify-center rounded-md bg-indigo-600 dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
                unless(@birthday_error != nil,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @birthday_error != nil,
            phx_hook: "ScrollToTop",
            id: "proceed_to_flag_selection"
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  def user_details_form(assigns) do
    ~H"""
    <.form
      :let={f}
      id="beta_user_registration_form"
      for={@form}
      class="mt-6 space-y-6 group"
      phx-change="validate_final_user_details"
      phx-trigger-action={@trigger_action}
      action={@action}
      method="POST"
      phx-submit="submit"
      phx-debounce="500"
    >
      <.notification_box
        message={
          with_locale(@language, fn ->
            gettext(
              "Our competitors charge monthly, even if you don’t find a match. We only charge €20 after you find yours. And it's free for beta testers! 🎉"
            )
          end)
        }
        avatars_urls={[
          "/images/unsplash/men/prince-akachi-4Yv84VgQkRM-unsplash.jpg",
          "/images/unsplash/women/stefan-stefancik-QXevDflbl8A-unsplash.jpg"
        ]}
      />

      <.previous_step color="user_details" language={@language} />

      <p class="mt-3 text-base font-semibold dark:text-white">
        <%= with_locale(@language, fn -> %>
          <%= gettext("Your Information") %>
        <% end) %>
      </p>
      <.gender_select
        f={f}
        language={@language}
        default_gender={@default_gender}
        title={
          with_locale(@language, fn ->
            gettext("You are")
          end)
        }
      />

      <div class="w-[100%] md:grid grid-cols-2 gap-8">
        <.username_input f={f} language={@language} />

        <.name_input f={f} language={@language} />

        <.email_input f={f} language={@language} />

        <.password_input f={f} language={@language} />

        <.country_input f={f} language={@language} />
        <.mobile_number_input f={f} language={@language} />
      </div>
      <div class="w-[100%] md:grid grid-cols-2 gap-8">
        <.preapproved_communication_only f={f} language={@language} />

        <.profile_private_input f={f} language={@language} />
      </div>

      <.legal_terms_accepted f={f} language={@language} />
      <%= text_input(f, :language, type: :hidden, value: @language) %>

      <div class="w-[100%] flex justify-start">
        <%= submit("Proceed",
          class:
            "flex  justify-center rounded-md bg-indigo-600 dark:bg-indigo-500 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 " <>
              unless(@form.valid? == false,
                do: "",
                else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
              ),
          disabled: @form.valid? == false
        ) %>
      </div>
    </.form>
    """
  end

  def flags_for_selection(assigns) do
    ~H"""
    <div class="relative px-5 space-y-4">
      <.previous_step color={@color} language={@language} />

      <div class="flex items-center justify-between">
        <h2 class="font-bold dark:text-white md:text-xl"><%= @title %></h2>

        <div>
          <button
            phx-click="move_to_next_step"
            phx-value-color={@color}
            phx-hook="ScrollToTop"
            id="move_to_next_step"
            class="flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 "
          >
            <%= with_locale(@language, fn -> %>
              <%= gettext("Proceed ") %>
            <% end) %>
          </button>
        </div>
      </div>

      <p class="dark:text-white"><%= @info_text %></p>

      <div :for={category <- @categories}>
        <div class="py-4 space-y-2">
          <h3 class="font-semibold text-gray-800 dark:text-white truncate">
            <%= with_locale(@language, fn -> %>
              <%= Gettext.gettext(AniminaWeb.Gettext, Ash.CiString.value(category.name)) %>
            <% end) %>
          </h3>

          <ol class="flex flex-wrap gap-2 w-full">
            <li
              :for={flag <- category.flags}
              :if={
                Enum.member?(
                  opposite_color_flags_selected(
                    @color,
                    @user_green_flags,
                    @user_red_flags,
                    @user_white_flags
                  ),
                  flag.id
                ) == false
              }
            >
              <div
                phx-value-flag={flag.name}
                phx-value-flagid={flag.id}
                phx-click={
                  if flag.id in flags_to_check_against(
                       @color,
                       @user_green_flags,
                       @user_red_flags,
                       @user_white_flags
                     ),
                     do: "remove_flag",
                     else: "select_flag"
                }
                phx-value-color={@color}
                aria-label="button"
                class={"rounded-full cursor-pointer flex gap-2 items-center  px-3 py-1.5 text-sm font-semibold leading-6  focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2
                #{if flag.id in flags_to_check_against(@color, @user_green_flags, @user_red_flags, @user_white_flags),
                  do: "#{selected_button_colors(@color)}",
                  else: "#{default_button_colors(@color)}"
                }"

            }
              >
                <span :if={flag.emoji} class="pr-1.5"><%= flag.emoji %></span>

                <%= with_locale(@language, fn -> %>
                  <%= Gettext.gettext(AniminaWeb.Gettext, Ash.CiString.value(flag.name)) %>
                <% end) %>

                <span
                  :if={
                    Enum.member?(
                      flags_to_check_against(
                        @color,
                        @user_green_flags,
                        @user_red_flags,
                        @user_white_flags
                      ),
                      flag.id
                    )
                  }
                  class={"inline-flex items-center justify-center w-4 h-4 ms-2 text-xs font-semibold rounded-full " <> get_position_colors(@color)}
                >
                  <%= get_flag_index(
                    flags_to_check_against(
                      @color,
                      @user_green_flags,
                      @user_red_flags,
                      @user_white_flags
                    ),
                    flag.id
                  ) + 1 %>
                </span>
              </div>
            </li>
          </ol>
        </div>
      </div>

      <button class="flex w-full justify-center rounded-md bg-indigo-600 px-3 py-1.5 text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 ">
        <%= with_locale(@language, fn -> %>
          <%= gettext("Save flags") %>
        <% end) %>
      </button>
    </div>
    """
  end

  defp default_button_colors(:green),
    do: "hover:bg-green-50 bg-green-100 focus-visible:outline-green-100 text-green-600"

  defp default_button_colors(:red),
    do: "hover:bg-red-50 bg-red-100 focus-visible:outline-red-100 text-red-600"

  defp default_button_colors(_),
    do: "hover:bg-indigo-50 bg-indigo-100 focus-visible:outline-indigo-100 text-indigo-600"

  defp selected_button_colors(:green),
    do: "hover:bg-green-500  bg-green-600 focus-visible:outline-green-600 text-white shadow-sm"

  defp selected_button_colors(:red),
    do: "hover:bg-rose-500  bg-rose-600 focus-visible:outline-rose-600 text-white shadow-sm"

  defp selected_button_colors(_),
    do: "hover:bg-indigo-500  bg-indigo-600 focus-visible:outline-indigo-600 text-white shadow-sm"

  defp get_position_colors(:green), do: "text-green-600 bg-green-200"
  defp get_position_colors(:red), do: "text-rose-600 bg-rose-200"
  defp get_position_colors(_), do: "text-indigo-600 bg-indigo-200"

  defp opposite_color_flags_selected(:green, _user_green_flags, user_red_flags, _user_white_flags) do
    user_red_flags
  end

  defp opposite_color_flags_selected(:red, user_green_flags, _user_red_flags, _user_white_flags) do
    user_green_flags
  end

  defp opposite_color_flags_selected(:white, _, _, _) do
    []
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end

  defp get_flag_index(flags, flag_id) do
    case Enum.find_index(flags, fn id -> id == flag_id end) do
      nil -> length(flags) + 1
      index -> index
    end
  end

  defp flags_to_check_against(:green, user_green_flags, _user_red_flags, _user_white_flags) do
    user_green_flags
  end

  defp flags_to_check_against(:red, _user_green_flags, user_red_flags, _user_white_flags) do
    user_red_flags
  end

  defp flags_to_check_against(:white, _user_green_flags, _user_red_flags, user_white_flags) do
    user_white_flags
  end

  defp gender_select(assigns) do
    ~H"""
    <div class="flex flex-col items-start">
      <label
        for="user_gender"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= @title %>
      </label>
      <div class="mt-2" phx-no-format>
          <%
            item_code = "male"
            item_title =  with_locale(@language, fn -> gettext("Male") end)
          %>
          <div class="flex items-center mb-4">
            <%= radio_button(@f, :gender, item_code,
              id: "gender_" <> item_code,
              class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500",
              checked: @default_gender == "male"
            ) %>
            <%= label(@f, :gender, item_title,
              for: "gender_" <> item_code,
              class: "ml-3 block text-sm font-medium dark:text-white text-gray-700"
            ) %>
          </div>

          <%
            item_code = "female"
            item_title =  with_locale(@language, fn -> gettext("Female") end)
          %>
          <div class="flex items-center mb-4">
            <%= radio_button(@f, :gender, item_code,
              id: "gender_" <> item_code,
              class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500",
              checked: @default_gender == "female"
            ) %>
            <%= label(@f, :gender, item_title,
              for: "gender_" <> item_code,
              class: "ml-3 block text-sm font-medium dark:text-white text-gray-700"
            ) %>
          </div>

          <%
            item_code = "diverse"
            item_title = with_locale(@language, fn -> gettext("Diverse") end)

          %>
          <div class="flex items-center mb-4">
            <%= radio_button(@f, :gender, item_code,
              id: "gender_" <> item_code,
              class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500",
               checked: @default_gender == "diverse"
            ) %>
            <%= label(@f, :gender, item_title,
              for: "gender_" <> item_code,
              class: "ml-3 block text-sm font-medium dark:text-white text-gray-700"
            ) %>
          </div>
        </div>
    </div>
    """
  end

  defp zip_code_select(assigns) do
    ~H"""
    <div class="flex flex-col items-start">
      <label
        for="user_zip_code"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Your Zip Code") %>
        <% end) %>
      </label>
      <div phx-feedback-for={@f[:zip_code].name} class="w-[100%] mt-2">
        <%= text_input(@f, :zip_code,
          class:
            "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
              unless(get_field_errors(@f[:zip_code], :zip_code) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              ),
          # Easter egg (Bundestag)
          placeholder: "11011",
          value: @f[:zip_code].value,
          inputmode: "numeric",
          required: true,
          autocomplete: gettext("postal code"),
          "phx-debounce": "blur"
        ) %>

        <.error :for={msg <- get_field_errors(@f[:zip_code], :zip_code)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Zip code") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp country_input(assigns) do
    ~H"""
    <div>
      <label
        for="user_country"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Country") %>
        <% end) %>
      </label>
      <div phx-feedback-for={@f[:country].name} class="mt-2">
        <%= select(
          @f,
          :country,
          [{with_locale(@language, fn -> gettext("Germany") end), "Germany"}],
          class:
            "block w-full select-styling-root rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white dark:[color-scheme:dark] shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
              unless(get_field_errors(@f[:country], :country) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              )
        ) %>

        <.error :for={msg <- get_field_errors(@f[:country], :country)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Country") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp height_select(assigns) do
    ~H"""
    <div class="flex flex-col items-start">
      <label
        for="user_height"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Your Height") %>
        <% end) %>
        <span class="text-gray-400 dark:text-gray-100">
          <%= with_locale(@language, fn -> %>
            (<%= gettext("in cm") %>)
          <% end) %>
        </span>
      </label>
      <div phx-feedback-for={@f[:height].name} class="mt-2 w-[100%]">
        <%= number_input(@f, :height,
          class:
            "block w-full rounded-md border-0 py-1.5 text-gray-900  dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
              unless(get_field_errors(@f[:height], :height) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              ),
          placeholder: "160",
          inputmode: "numeric",
          required: true,
          value: @f[:height].value,
          "phx-debounce": "blur"
        ) %>

        <.error :for={msg <- get_field_errors(@f[:height], :height)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Height") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp birthday_select(assigns) do
    ~H"""
    <div>
      <label
        for="user_birthday"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Your Birthday (dd/mm/yyyy)") %>
        <% end) %>
      </label>

      <div phx-feedback-for={@f[:birthday].name} class="mt-2">
        <%= text_input(@f, :birthday,
          class:
            "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white dark:[color-scheme:dark] shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
              unless(@birthday_error == nil,
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              ),
          placeholder: eighteen_years_before_now(),
          value: @f[:birthday].value,
          required: true,
          autocomplete: gettext("bday"),
          "phx-debounce": "blur"
        ) %>

        <.error :if={@birthday_error != nil}>
          <%= @birthday_error %>
        </.error>
      </div>
    </div>
    """
  end

  defp search_range(assigns) do
    ~H"""
    <div>
      <label
        for="form_search_range"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Search range") %>
        <% end) %>
      </label>
      <div phx-feedback-for={@f[:search_range].name} class="mt-2">
        <%= select(
          @f,
          :search_range,
          [
            {"2 km", 2},
            {"5 km", 5},
            {"10 km", 10},
            {"20 km", 20},
            {"30 km", 30},
            {"50 km", 50},
            {"75 km", 75},
            {"100 km", 100},
            {"150 km", 150},
            {"200 km", 200},
            {"300 km", 300}
          ],
          prompt: with_locale(@language, fn -> gettext("doesn't matter") end),
          class:
            "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700 dark:text-white text-gray-900 shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
              unless(get_field_errors(@f[:search_range], :search_range) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              )
        ) %>

        <.error :for={msg <- get_field_errors(@f[:search_range], :search_range)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Search range") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp minimum_partner_height(assigns) do
    ~H"""
    <div>
      <label
        for="form_minimum_partner_height"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Minimum Partner Height") %>
        <% end) %>
      </label>
      <div phx-feedback-for={@f[:minimum_partner_height].name} class="mt-2">
        <%= select(
          @f,
          :minimum_partner_height,
          [{with_locale(@language, fn -> gettext("doesn't matter") end), nil}] ++
            Enum.map(140..210, &{"#{&1} cm", &1}),
          class:
            "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset focus:ring-2 dark:bg-gray-700 dark:text-white focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
              unless(
                get_field_errors(@f[:minimum_partner_height], :minimum_partner_height) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              ),
          autofocus: true
        ) %>

        <.error :for={msg <- get_field_errors(@f[:minimum_partner_height], :minimum_partner_height)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Minimum Partner Height") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp maximum_partner_height(assigns) do
    ~H"""
    <div>
      <label
        for="form_maximum_partner_height"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Maximum Partner Height") %>
        <% end) %>
      </label>
      <div phx-feedback-for={@f[:maximum_partner_height].name} class="mt-2">
        <%= select(
          @f,
          :maximum_partner_height,
          [{with_locale(@language, fn -> gettext("doesn't matter") end), nil}] ++
            Enum.map(140..210, &{"#{&1} cm", &1}),
          class:
            "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
              unless(
                get_field_errors(@f[:maximum_partner_height], :maximum_partner_height) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              )
        ) %>

        <.error :for={msg <- get_field_errors(@f[:maximum_partner_height], :maximum_partner_height)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Maximum Partner Height") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp minimum_partner_age(assigns) do
    ~H"""
    <div>
      <label
        for="form_minimum_partner_age"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Minimum Partner Age") %>
        <% end) %>
      </label>
      <div phx-feedback-for={@f[:minimum_partner_age].name} class="mt-2">
        <%= select(@f, :minimum_partner_age, Enum.map(18..110, &{&1, &1}),
          prompt: with_locale(@language, fn -> gettext("doesn't matter") end),
          value: @f[:minimum_partner_age].value,
          class:
            "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
              unless(get_field_errors(@f[:minimum_partner_age], :minimum_partner_age) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              )
        ) %>

        <.error :for={msg <- get_field_errors(@f[:minimum_partner_age], :minimum_partner_age)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Minimum Partner Age") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp maximum_partner_age(assigns) do
    ~H"""
    <div>
      <label
        for="form_maximum_partner_age"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Maximum Partner Age") %>
        <% end) %>
      </label>
      <div phx-feedback-for={@f[:maximum_partner_age].name} class="mt-2">
        <%= select(@f, :maximum_partner_age, Enum.map(18..110, &{&1, &1}),
          prompt: with_locale(@language, fn -> gettext("doesn't matter") end),
          class:
            "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:text-sm sm:leading-6 " <>
              unless(get_field_errors(@f[:maximum_partner_age], :maximum_partner_age) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              )
        ) %>

        <.error :for={msg <- get_field_errors(@f[:maximum_partner_age], :maximum_partner_age)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Maximum Partner Age") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp username_input(assigns) do
    ~H"""
    <div>
      <label
        for="user_username"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Username") %>
        <% end) %>
      </label>
      <div phx-feedback-for={@f[:username].name} class="mt-2">
        <%= text_input(
          @f,
          :username,
          class:
            "block w-full rounded-md border-0 py-1.5 text-gray-900 dark:bg-gray-700 dark:text-white shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
              unless(get_field_errors(@f[:username], :username) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              ),
          placeholder: with_locale(@language, fn -> gettext("Pusteblume1977") end),
          value: @f[:username].value,
          type: :text,
          required: true,
          autocomplete: :username,
          "phx-debounce": "200"
        ) %>
        <.error :for={msg <- get_field_errors(@f[:username], :username)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Username") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp name_input(assigns) do
    ~H"""
    <div>
      <label for="user_name" class="block text-sm font-medium leading-6 text-gray-900 dark:text-white">
        <%= with_locale(@language, fn -> %>
          <%= gettext("Name") %>
        <% end) %>
      </label>
      <div phx-feedback-for={@f[:name].name} class="mt-2">
        <%= text_input(@f, :name,
          class:
            "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700 dark:text-white text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
              unless(get_field_errors(@f[:name], :name) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              ),
          placeholder: with_locale(@language, fn -> gettext("Alice") end),
          value: @f[:name].value,
          type: :text,
          required: true,
          autocomplete: "given-name"
        ) %>
        <.error :for={msg <- get_field_errors(@f[:name], :name)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Name") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp email_input(assigns) do
    ~H"""
    <div>
      <label
        for="user_email"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("E-mail address") %>
        <% end) %>
      </label>
      <div phx-feedback-for={@f[:email].name} class="mt-2">
        <%= text_input(@f, :email,
          class:
            "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700  dark:text-white text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
              unless(get_field_errors(@f[:email], :email) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              ),
          placeholder: with_locale(@language, fn -> gettext("alice@example.net") end),
          value: @f[:email].value,
          required: true,
          autocomplete: :email,
          "phx-debounce": "200"
        ) %>
        <.error :for={msg <- get_field_errors(@f[:email], :email)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("E-mail address") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp password_input(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between">
        <label
          for="user_password"
          class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
        >
          <%= with_locale(@language, fn -> %>
            <%= gettext("Password") %>
          <% end) %>
        </label>
      </div>
      <div phx-feedback-for={@f[:password].name} class="mt-2">
        <%= password_input(@f, :password,
          class:
            "block w-full rounded-md border-0 py-1.5 dark:bg-gray-700 dark:text-white text-gray-900 shadow-sm ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
              unless(get_field_errors(@f[:password], :password) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              ),
          placeholder: with_locale(@language, fn -> gettext("Password") end),
          value: @f[:password].value,
          autocomplete: with_locale(@language, fn -> gettext("new password") end),
          "phx-debounce": "blur"
        ) %>

        <.error :for={msg <- get_field_errors(@f[:password], :password)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Password") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp mobile_number_input(assigns) do
    ~H"""
    <div>
      <label
        for="user_mobile_phone"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Mobile phone number") %>
        <% end) %>
        <span class="text-gray-400 dark:text-gray-100">
          <%= with_locale(@language, fn -> %>
            (<%= gettext("to receive a verification code") %>)
          <% end) %>
        </span>
      </label>
      <div phx-feedback-for={@f[:mobile_phone].name} class="w-[100%] mt-2">
        <%= text_input(@f, :mobile_phone,
          class:
            "block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm dark:bg-gray-700 dark:text-white ring-1 ring-inset placeholder:text-gray-400 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
              unless(get_field_errors(@f[:mobile_phone], :mobile_phone) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              ),
          placeholder: "0151-12345678",
          inputmode: "numeric",
          value: @f[:mobile_phone].value,
          "phx-debounce": "blur"
        ) %>

        <.error :for={msg <- get_field_errors(@f[:mobile_phone], :mobile_phone)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("Mobile phone number") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp legal_terms_accepted(assigns) do
    ~H"""
    <div class="relative flex gap-x-3">
      <div phx-feedback-for={@f[:legal_terms_accepted].name} class="flex items-center h-6">
        <%= checkbox(@f, :legal_terms_accepted,
          class:
            "h-4 w-4 rounded border-gray-300 text-indigo-600  focus:ring-indigo-600 focus:ring-2 focus:ring-inset sm:text-sm  phx-no-feedback:ring-gray-300 phx-no-feedback:focus:ring-indigo-600 sm:leading-6 " <>
              unless(get_field_errors(@f[:legal_terms_accepted], :legal_terms_accepted) == [],
                do: "ring-red-600 focus:ring-red-600",
                else: "ring-gray-300 focus:ring-indigo-600"
              )
        ) %>
      </div>
      <div class="text-sm leading-6">
        <label for="comments" class="font-medium text-gray-900 dark:text-white">
          <%= with_locale(@language, fn -> %>
            <%= gettext("I accept the legal terms of animina.") %>
          <% end) %>
        </label>
        <p class="text-gray-500 dark:text-gray-100">
          <%= with_locale(@language, fn -> %>
            <%= gettext(
              "Warning: We will sell your data to the Devil and Santa Claus. Seriously, if you don't trust us, a dating platform is not a good place to share your personal information."
            ) %>
          <% end) %>
        </p>
        <.error :for={msg <- get_field_errors(@f[:legal_terms_accepted], :legal_terms_accepted)}>
          <%= with_locale(@language, fn -> %>
            <%= gettext("I accept the legal terms of animina") <> " " <> msg %>
          <% end) %>
        </.error>
      </div>
    </div>
    """
  end

  defp preapproved_communication_only(assigns) do
    ~H"""
    <div class="flex items-center gap-2 mb-4">
      <%= checkbox(@f, :preapproved_communication_only,
        id: "preapproved_communication_only",
        class:
          "h-4 w-4 rounded border-gray-300 text-indigo-600  focus:ring-indigo-600 focus:ring-2 focus:ring-inset sm:text-sm   sm:leading-6 "
      ) %>
      <p class="text-gray-500 dark:text-gray-100">
        <%= with_locale(@language, fn -> %>
          <%= gettext("Only users who I liked can initiate a chat.") %>
        <% end) %>
      </p>
    </div>
    """
  end

  defp profile_private_input(assigns) do
    ~H"""
    <div class="flex items-center gap-2 mb-4">
      <%= checkbox(@f, :is_private,
        id: "is_private",
        class:
          "h-4 w-4 rounded border-gray-300 text-indigo-600  focus:ring-indigo-600 focus:ring-2 focus:ring-inset sm:text-sm  sm:leading-6 "
      ) %>
      <p class="text-gray-500 dark:text-gray-100">
        <%= with_locale(@language, fn -> %>
          <%= gettext("My profile is only visible for animina users.") %>
        <% end) %>
      </p>
    </div>
    """
  end

  defp previous_step(assigns) do
    ~H"""
    <div class="flex items-start">
      <button
        phx-click="move_to_previous_step"
        phx-value-color={@color}
        phx-hook="ScrollToTop"
        id="move_to_previous_step"
        class="flex  justify-center    text-sm font-semibold text-white shadow-sm  focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 "
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("Back") %>
        <% end) %>
      </button>
    </div>
    """
  end

  defp loading_dots(assigns) do
    ~H"""
    <div class="flex space-x-2 animate-pulse">
      <div class="w-2 h-2 bg-gray-500 rounded-full"></div>
      <div class="w-2 h-2 bg-gray-500 rounded-full"></div>
      <div class="w-2 h-2 bg-gray-500 rounded-full"></div>
    </div>
    """
  end

  def eighteen_years_before_now do
    date =
      Date.utc_today()
      |> Timex.shift(years: -18)

    Integer.to_string(date.day) <>
      "." <> Integer.to_string(date.month) <> "." <> Integer.to_string(date.year)
  end
end
