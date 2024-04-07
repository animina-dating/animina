defmodule AniminaWeb.ProfileComponents do
  @moduledoc """
  Provides Profile UI components.
  """
  use Phoenix.Component
  alias AniminaWeb.StoryComponent

  def stories_component(assigns) do
    ~H"""
    <div class="grid items-start gap-5 md:grid-cols-3" id="stream_stories" phx-update="stream">
      <div :for={{dom_id, story} <- @streams.stories} id={"#{dom_id}"}>
        <.live_component
          module={StoryComponent}
          id={"story_#{story.id}"}
          story={story}
          language={@language}
          for_current_user={@current_user.id == @user.id}
        />
      </div>
    </div>
    """
  end

  def profile_location_card(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-gray-600 dark:text-gray-100">
      <svg
        width="20px"
        height="20px"
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        stroke="#004EA0"
      >
        <g id="SVGRepo_bgCarrier" stroke-width="0"></g>
        <g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g>
        <g id="SVGRepo_iconCarrier">
          <path
            d="M12 21C15.5 17.4 19 14.1764 19 10.2C19 6.22355 15.866 3 12 3C8.13401 3 5 6.22355 5 10.2C5 14.1764 8.5 17.4 12 21Z"
            stroke="#004EA0"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
          </path>

          <path
            d="M12 12C13.1046 12 14 11.1046 14 10C14 8.89543 13.1046 8 12 8C10.8954 8 10 8.89543 10 10C10 11.1046 10.8954 12 12 12Z"
            stroke="#004EA0"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
          </path>
        </g>
      </svg>
      <%= @user.city.zip_code %> <%= @user.city.name %>
    </div>
    """
  end

  def profile_gender_card(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-gray-600 dark:text-gray-100">
      <svg
        height="20px"
        width="20px"
        version="1.1"
        id="_x32_"
        xmlns="http://www.w3.org/2000/svg"
        xmlns:xlink="http://www.w3.org/1999/xlink"
        viewBox="0 0 512 512"
        xml:space="preserve"
        fill="#004EA0"
      >
        <g id="SVGRepo_bgCarrier" stroke-width="0"></g>
        <g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g>
        <g id="SVGRepo_iconCarrier">
          <style type="text/css">
            .st0{fill:#004EA0;}
          </style>

          <g>
            <path
              class="st0"
              d="M267.817,171.048c-12.343-12.388-27.371-22.176-44.078-28.53c-7.888,8.766-13.259,19.438-15.502,31.01 c-0.61,3.12-0.976,6.248-1.144,9.361c1.373,0.472,2.716,0.976,4.029,1.548c14.555,6.171,27.051,16.501,35.808,29.515 c7.033,10.405,11.702,22.451,13.274,35.504c0.412,3.257,0.61,6.576,0.61,9.963c0,11.306-2.273,21.956-6.377,31.674 c-5.096,11.985-12.984,22.588-22.886,30.835c-2.105,1.777-4.318,3.426-6.606,4.974c-13.014,8.788-28.546,13.884-45.497,13.884 c-11.275,0-21.909-2.281-31.643-6.378c-14.586-6.171-27.036-16.508-35.824-29.515c-8.758-12.992-13.854-28.561-13.854-45.474 c0-11.298,2.243-21.932,6.362-31.674c5.539-13.075,14.464-24.487,25.678-33.008c-0.214-2.953-0.306-5.905-0.306-8.857 c0-15.165,2.38-29.965,6.912-43.956c-17.348,6.309-32.91,16.34-45.665,29.126c-22.611,22.543-36.648,53.919-36.602,88.37 c-0.045,34.459,13.992,65.835,36.602,88.385c18.827,18.857,43.788,31.696,71.556,35.426v38.952h-57.901v33.55h57.901V512h33.566 v-56.268h57.947v-33.55H196.23v-38.952c27.784-3.73,52.775-16.569,71.587-35.426c6.286-6.286,11.886-13.228,16.752-20.742 c12.587-19.491,19.896-42.781,19.865-67.643c0-5.835-0.412-11.61-1.175-17.24C299.43,214.562,286.583,189.769,267.817,171.048z"
            >
            </path>

            <path
              class="st0"
              d="M349.015,0v33.551h51.203l-52.912,52.912c-22.276-16.981-49.052-25.564-75.691-25.54 c-31.903-0.024-64.019,12.22-88.37,36.617c-17.424,17.378-28.622,38.714-33.627,61.12c-0.061,0.274-0.091,0.549-0.168,0.778 c-0.198,0.87-0.366,1.747-0.533,2.579c-0.306,1.617-0.58,3.227-0.839,4.836c-0.168,0.969-0.305,1.984-0.412,2.952 c-0.198,1.473-0.366,2.983-0.488,4.493c-0.076,0.87-0.168,1.748-0.213,2.617c-0.03,0.435-0.061,0.877-0.091,1.343 c-0.077,0.877-0.107,1.777-0.138,2.646c-0.061,1.648-0.107,3.326-0.107,4.974c0,1.274,0.046,2.548,0.077,3.852 c0.061,1.282,0.138,2.548,0.198,3.861l0.198,2.822c0,0.466,0.076,0.938,0.106,1.442c2.686,27.874,14.723,55.124,36.037,76.4 c12.908,12.916,28.012,22.436,44.078,28.516c4.866-5.363,8.834-11.572,11.687-18.255c2.944-7.01,4.623-14.426,4.958-22.077 c-10.908-3.921-21.1-10.23-29.888-19.018c-7.949-7.987-13.899-17.118-17.851-26.914c-2.822-6.92-4.638-14.166-5.432-21.475 c-0.518-4.326-0.64-8.689-0.442-13.014c0.061-1.076,0.137-2.113,0.198-3.158c0.076-0.77,0.137-1.541,0.274-2.319 c0-0.298,0.061-0.595,0.092-0.9c0.076-0.74,0.168-1.51,0.305-2.243c0.168-1.007,0.336-2.052,0.534-3.051 c0.884-4.57,2.151-9.063,3.829-13.427c0.306-0.801,0.61-1.571,0.977-2.38c0.336-0.839,0.701-1.678,1.098-2.517 c0.336-0.839,0.733-1.679,1.175-2.487c0.366-0.831,0.808-1.64,1.282-2.441c2.212-4.104,4.822-8.055,7.812-11.817 c0.61-0.77,1.251-1.54,1.877-2.281c1.388-1.579,2.792-3.12,4.302-4.63c1.876-1.877,3.784-3.624,5.767-5.234 c6.5-5.401,13.624-9.635,21.1-12.648c14.662-5.942,30.804-7.453,46.199-4.463c15.41,2.99,29.995,10.36,41.988,22.344 c7.98,7.987,13.884,17.118,17.836,26.906c5.981,14.662,7.492,30.773,4.501,46.176c-3.021,15.394-10.406,29.988-22.337,41.973 c-2.624,2.616-5.37,5.035-8.223,7.178c0.167,2.952,0.259,5.905,0.259,8.818c0.046,15.036-2.35,29.858-6.942,43.956 c16.707-6.042,32.375-15.769,45.726-29.119c24.366-24.327,36.648-56.443,36.617-88.377c0.03-26.647-8.559-53.377-25.571-75.691 l52.912-52.912v51.226h33.55V0H349.015z"
            >
            </path>
          </g>
        </g>
      </svg>
      <%= @user.gender %>
    </div>
    """
  end

  def profile_age_card(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-gray-600 dark:text-gray-100">
      <svg
        width="20px"
        height="20px"
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <g id="SVGRepo_bgCarrier" stroke-width="0"></g>
        <g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g>
        <g id="SVGRepo_iconCarrier">
          <path
            fill-rule="evenodd"
            clip-rule="evenodd"
            d="M13.9999 3.125C13.9999 4.16053 13.1044 5 11.9999 5C10.8953 5 9.99988 4.16053 9.99988 3.125C9.99988 2.08947 11.9999 0 11.9999 0C11.9999 0 13.9999 2.08947 13.9999 3.125ZM0.460826 13.6423L2.31939 14.8317L4.02549 22.2249C4.1302 22.6786 4.53422 23 4.99988 23H18.9999C19.4655 23 19.8696 22.6786 19.9743 22.2249L21.6804 14.8317L23.5389 13.6423C24.0041 13.3446 24.1399 12.7261 23.8421 12.2609C23.5444 11.7958 22.926 11.66 22.4608 11.9577L21.9256 12.3003C21.5906 9.92302 19.5498 8 16.9717 8H12.9999V7C12.9999 6.44772 12.5522 6 11.9999 6C11.4476 6 10.9999 6.44772 10.9999 7V8H7.02808C4.44994 8 2.40918 9.92302 2.0742 12.3003L1.53893 11.9577C1.07376 11.66 0.455319 11.7958 0.157608 12.2609C-0.140103 12.7261 -0.0043478 13.3446 0.460826 13.6423ZM5.79539 21L4.65309 16.05C6.02133 16.4189 7.50983 16.1952 8.72873 15.3826L10.3358 14.3113C11.3435 13.6395 12.6563 13.6395 13.664 14.3113L15.271 15.3826C16.4899 16.1952 17.9784 16.4189 19.3467 16.05L18.2044 21H5.79539ZM16.9717 10C18.8713 10 20.2847 11.74 19.9135 13.588L19.6617 13.7492C18.6588 14.391 17.3712 14.379 16.3804 13.7185L14.7734 12.6472C13.0939 11.5275 10.9059 11.5275 9.22638 12.6472L7.61933 13.7185C6.62859 14.379 5.34099 14.391 4.33807 13.7492L4.08623 13.588C3.71509 11.74 5.12847 10 7.02808 10H11.9999H16.9717ZM8.99993 18C8.99993 17.4477 8.55221 17 7.99993 17C7.44764 17 6.99993 17.4477 6.99993 18V19C6.99993 19.5523 7.44764 20 7.99993 20C8.55221 20 8.99993 19.5523 8.99993 19V18ZM12.9999 18C12.9999 17.4477 12.5522 17 11.9999 17C11.4476 17 10.9999 17.4477 10.9999 18V19C10.9999 19.5523 11.4476 20 11.9999 20C12.5522 20 12.9999 19.5523 12.9999 19V18ZM16.9999 18C16.9999 17.4477 16.5522 17 15.9999 17C15.4476 17 14.9999 17.4477 14.9999 18V19C14.9999 19.5523 15.4476 20 15.9999 20C16.5522 20 16.9999 19.5523 16.9999 19V18Z"
            fill="#004EA0"
          >
          </path>
        </g>
      </svg>
      <%= @user.age %>
    </div>
    """
  end

  def profile_occupation_card(assigns) do
    ~H"""
    <div class="flex items-center gap-2 text-gray-600 dark:text-gray-100">
      <svg
        width="20px"
        height="20px"
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
      >
        <g id="SVGRepo_bgCarrier" stroke-width="0"></g>
        <g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g>
        <g id="SVGRepo_iconCarrier">
          <path
            d="M4 12H3V8C3 6.89543 3.89543 6 5 6H9M4 12V18C4 19.1046 4.89543 20 6 20H18C19.1046 20 20 19.1046 20 18V12M4 12H10M20 12H21V8C21 6.89543 20.1046 6 19 6H15M20 12H14M14 12V10H10V12M14 12V14H10V12M9 6V5C9 3.89543 9.89543 3 11 3H13C14.1046 3 15 3.89543 15 5V6M9 6H15"
            stroke="#004EA0"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
          </path>
        </g>
      </svg>
      <%= @user.occupation %>
    </div>
    """
  end

  def square_user_profile_photo(assigns) do
    ~H"""
    <div class="md:w-[400px] md:h-[400px] w-[100%] h-[300px] flex-grow border-[4px] rounded-md border-[#1672DF]">
      <img src={"/uploads/#{@user.profile_photo.filename}"} class="object-cover h-[100%] w-[100%] " />
    </div>
    """
  end

  def profile_about_story_card(assigns) do
    ~H"""
    <div :if={@about_story != nil} class="flex flex-col gap-2">
      <p class="dark:text-gray-100 text-[#414753]  font-semibold">
        <%= @title %>
      </p>
      <p class="text-sm dark:text-white ">
        <%= @about_story.content %>
      </p>
    </div>
    """
  end

  def height_visualization_card(assigns) do
    ~H"""
    <div class="flex flex-col gap-4">
      <div class="w-[100%] flex justify-between items-center">
        <p class="dark:text-gray-100 text-[#414753] font-semibold">
          <%= @title %>
        </p>

        <div class="border-[1px] border-[#004EA0]   text-sm p-1 rounded-md text-[#004EA0] ">
          <%= @user.height %> <%= @measurement_unit %>
        </div>
      </div>
      <.height_visualization_image
        current_user={@current_user}
        profile_user_height_for_figure={@profile_user_height_for_figure}
        current_user_height_for_figure={@current_user_height_for_figure}
        profile_user={@user}
      />
    </div>
    """
  end

  def height_visualization_image(assigns) do
    ~H"""
    <div class="flex  bg-[#B2CCEF] gap-8 w-[100%] dark:bg-gray-800 items-start rounded-md p-4 py-6">
      <div class="flex w-[100%]   gap-0">
        <p class="h-[100px] dark:bg-white bg-black w-[2px] " />
        <div class="h-[100%] w-[100%] flex  relative">
          <p class="absolute  dark:text-white -top-[12px] text-xs  pb-2">200cm</p>

          <p class="w-[100%]   absolute top-[2px] mb-[180px] h-[1px] dark:bg-white bg-black" />
          <p class="absolute top-[16px] dark:text-white text-xs  pb-3">150cm</p>
          <p class="w-[100%]   absolute top-[30px]  h-[1px] dark:bg-white bg-black" />

          <p class="absolute top-[40px] dark:text-white  text-xs pb-3">100cm</p>
          <p class="w-[100%]   absolute top-[54px] h-[1px] dark:bg-white bg-black" />

          <p class="absolute top-[64px] dark:text-white text-xs  pb-3">50cm</p>
          <p class="w-[100%]   absolute top-[80px] h-[1px] dark:bg-white bg-black" style="z-index:1" />
        </div>
      </div>

      <div class="flex md:-ml-48  -ml-40 items-end gap-8">
        <.figure
          height={@current_user_height_for_figure}
          avatar={@current_user.profile_photo.filename}
          username={@current_user.username}
        />

        <.figure
          height={@profile_user_height_for_figure}
          username={@profile_user.username}
          avatar={@profile_user.profile_photo.filename}
        />
      </div>
    </div>
    """
  end

  def figure(assigns) do
    ~H"""
    <div class="flex gap-2 items-end justify-end" style={"height:#{@height}px"}>
      <div class="md:w-[40px] dark:bg-white h-[100%] bg-black w-[35px] flex flex-col justify-end   items-center ">
        <div style="z-index:2" class="w-[100%]  pb-1 flex justify-center items-center">
          <.user_mini_avatar avatar={@avatar} />
        </div>
      </div>
    </div>
    """
  end

  def user_mini_avatar(assigns) do
    ~H"""
    <div class="border-[1px] rounded-full bg-white h-[24px] w-[24px] border-[#1672DF]">
      <img
        src={"/uploads/#{@avatar}"}
        class="object-cover h-[100%] rounded-full  w-[100%] object-cover  "
      />
    </div>
    """
  end

  def flags_card(assigns) do
    ~H"""
    <div class="space-y-4" id="stream_flags" phx-update="stream">
      <div :for={{dom_id, category} <- @streams.flags} class="space-y-2" id={"#{dom_id}"}>
        <.each_flag_card category={category} />
      </div>
    </div>
    """
  end

  def each_flag_card(assigns) do
    ~H"""
    <h3 class="dark:text-white text-[#414753] dark:text-white  truncate">
      <%= @category.name %>
    </h3>

    <ol class="flex flex-wrap w-full gap-2">
      <li :for={user_flag <- @category.flags}>
        <div class="cursor-pointer text-indigo-500 shadow-sm rounded-full px-3 py-1.5 text-sm font-semibold leading-6  focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 hover:bg-white/80  dark:bg-gray-800 bg-white  shadow-black/50 focus-visible:outline-white  ">
          <span :if={user_flag.flag.emoji} class="pr-1.5">
            <%= user_flag.flag.emoji %>
          </span>

          <%= user_flag.flag.name %>
        </div>
      </li>
    </ol>
    """
  end
end
