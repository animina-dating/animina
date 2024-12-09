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

      <p class="mt-3 text-base font-semibold dark:text-white">
        <%= with_locale(@language, fn -> %>
          <%= gettext("Potential Matches Counter:") %> <%= @number_of_potential_partners %>
        <% end) %>
      </p>

      <.form
        :let={f}
        id="beta_user_registration_form"
        for={@form}
        class="mt-6 space-y-6 group"
        phx-change="validate_and_filter_potential_partners"
        phx-submit="submit"
        phx-debounce="500"
      >
        <h2 class="mt-3 text-2xl font-semibold dark:text-white">
          <%= with_locale(@language, fn -> %>
            <%= gettext("Find your match") %>
          <% end) %>
        </h2>

        <.gender_select f={f} language={@language} />

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
                unless(@form.valid? == false,
                  do: "",
                  else: "opacity-40 cursor-not-allowed hover:bg-blue-500 active:bg-blue-500"
                ),
            disabled: @form.valid? == false
          ) %>
        </div>
      </.form>
    </div>
    """
  end

  defp get_field_errors(field, _name) do
    Enum.map(field.errors, &translate_error(&1))
  end

  defp gender_select(assigns) do
    ~H"""
    <div class="flex flex-col items-start">
      <label
        for="user_gender"
        class="block text-sm font-medium leading-6 text-gray-900 dark:text-white"
      >
        <%= with_locale(@language, fn -> %>
          <%= gettext("You are searching for a") %>
        <% end) %>
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
              checked: true
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
              class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
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
              class: "h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-500"
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

  def eighteen_years_before_now do
    date =
      Date.utc_today()
      |> Timex.shift(years: -18)

    Integer.to_string(date.day) <>
      "." <> Integer.to_string(date.month) <> "." <> Integer.to_string(date.year)
  end
end
