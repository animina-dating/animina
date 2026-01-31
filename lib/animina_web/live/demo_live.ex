defmodule AniminaWeb.DemoLive do
  @moduledoc """
  Demo LiveView page for Animina - a UX playground showcasing the design system.

  This page demonstrates the "Coastal Morning" design aesthetic:
  - Clean, fresh, modern yet approachable
  - Warm and welcoming without being childish
  - Trustworthy and calm like a beach morning walk
  """
  use AniminaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Welcome"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <!-- Hero Section -->
      <section class="relative overflow-hidden">
        <!-- Subtle gradient background -->
        <div class="absolute inset-0 bg-gradient-to-b from-accent/10 via-transparent to-transparent" />

        <div class="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-16 sm:py-24 lg:py-32">
          <div class="text-center max-w-3xl mx-auto">
            <h1 class="text-3xl sm:text-4xl md:text-5xl font-light tracking-tight text-base-content leading-tight">
              {gettext("Find meaningful")}
              <span class="block text-primary font-normal">{gettext("connections")}</span>
            </h1>
            <p class="mt-6 text-lg sm:text-xl text-base-content/70 leading-relaxed max-w-2xl mx-auto">
              {gettext(
                "Animina brings together people who value authenticity. No games, no pretense—just genuine conversations and real connections."
              )}
            </p>
            <div class="mt-10 flex flex-col sm:flex-row gap-4 justify-center">
              <a
                href="#"
                class="inline-flex items-center justify-center px-8 py-3 text-lg font-medium text-white bg-primary rounded-xl hover:bg-primary/90 transition-all duration-200 shadow-md hover:shadow-lg hover:-translate-y-0.5"
              >
                {gettext("Get started")}
              </a>
              <a
                href="#"
                class="inline-flex items-center justify-center px-8 py-3 text-lg font-medium text-primary bg-primary/10 rounded-xl hover:bg-primary/20 transition-colors duration-200"
              >
                {gettext("Learn more")}
              </a>
            </div>
          </div>
        </div>
      </section>
      
    <!-- Featured Profiles Section -->
      <section class="py-16 sm:py-24 bg-base-200/50">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12">
            <h2 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("People you might like")}
            </h2>
            <p class="mt-3 text-lg text-base-content/60">
              {gettext("Authentic profiles from your area")}
            </p>
          </div>

          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 lg:gap-8">
            <!-- Profile Card 1 -->
            <.profile_card
              image_url="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=400&h=500&fit=crop&crop=face"
              name="Julia"
              age={29}
              location="Berlin"
              bio="Coffee enthusiast, amateur chef, and weekend hiker. Looking for someone to explore the city with."
              photographer="Christopher Campbell"
            />
            
    <!-- Profile Card 2 -->
            <.profile_card
              image_url="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&h=500&fit=crop&crop=face"
              name="Thomas"
              age={34}
              location="Munich"
              bio="Architect by day, jazz lover by night. I believe the best conversations happen over good food."
              photographer="Joseph Gonzalez"
            />
            
    <!-- Profile Card 3 -->
            <.profile_card
              image_url="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400&h=500&fit=crop&crop=face"
              name="Sofia"
              age={27}
              location="Hamburg"
              bio="Bookworm, yoga practitioner, and documentary enthusiast. Seeking genuine connection over casual chat."
              photographer="Aiony Haust"
            />
          </div>
        </div>
      </section>
      
    <!-- Features Section -->
      <section class="py-16 sm:py-24">
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <div class="text-center mb-12 sm:mb-16">
            <h2 class="text-2xl sm:text-3xl font-light text-base-content">
              {gettext("Why Animina?")}
            </h2>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-8 lg:gap-12">
            <.feature_card
              icon="hero-shield-check"
              title={gettext("Verified profiles")}
              description={
                gettext(
                  "Every profile is verified to ensure you're connecting with real people who share your values."
                )
              }
            />

            <.feature_card
              icon="hero-chat-bubble-left-right"
              title={gettext("Meaningful conversations")}
              description={
                gettext(
                  "Our matching focuses on compatibility and shared interests, not just appearances."
                )
              }
            />

            <.feature_card
              icon="hero-heart"
              title={gettext("Real connections")}
              description={
                gettext(
                  "Animina is designed for those seeking genuine relationships, not endless swiping."
                )
              }
            />
          </div>
        </div>
      </section>
      
    <!-- Testimonial Section -->
      <section class="py-16 sm:py-24 bg-primary/5">
        <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8 text-center">
          <blockquote>
            <p class="text-xl sm:text-2xl font-light text-base-content leading-relaxed italic">
              {gettext(
                "I was tired of dating apps that felt like a game. Animina felt different from the start—more thoughtful, more genuine. I met my partner here, and we're now planning our future together."
              )}
            </p>
            <footer class="mt-8">
              <div class="flex items-center justify-center gap-4">
                <img
                  src="https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=80&h=80&fit=crop&crop=face"
                  alt="Portrait of Anna. Photo by Brooke Cagle on Unsplash"
                  class="w-14 h-14 rounded-full object-cover border-2 border-secondary/50"
                />
                <div class="text-start">
                  <p class="text-base font-medium text-base-content">Anna & David</p>
                  <p class="text-base text-base-content/60">{gettext("Together since 2023")}</p>
                </div>
              </div>
            </footer>
          </blockquote>
        </div>
      </section>
      
    <!-- CTA Section -->
      <section class="py-16 sm:py-24">
        <div class="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="text-2xl sm:text-3xl font-light text-base-content">
            {gettext("Ready to find your person?")}
          </h2>
          <p class="mt-4 text-lg text-base-content/70">
            {gettext("Join thousands of people who chose authenticity over algorithms.")}
          </p>
          <div class="mt-8">
            <a
              href="#"
              class="inline-flex items-center justify-center px-10 py-4 text-lg font-medium text-white bg-primary rounded-xl hover:bg-primary/90 transition-all duration-200 shadow-md hover:shadow-lg hover:-translate-y-0.5"
            >
              {gettext("Create your profile")}
              <.icon name="hero-arrow-right" class="ms-2 size-5 rtl:rotate-180" />
            </a>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  # Profile Card Component
  attr :image_url, :string, required: true
  attr :name, :string, required: true
  attr :age, :integer, required: true
  attr :location, :string, required: true
  attr :bio, :string, required: true
  attr :photographer, :string, required: true

  defp profile_card(assigns) do
    ~H"""
    <article class="group bg-base-200 rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-all duration-300">
      <div class="aspect-[4/5] relative overflow-hidden">
        <img
          src={@image_url}
          alt={"Portrait of #{@name}. Photo by #{@photographer} on Unsplash"}
          class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
          loading="lazy"
        />
        <div class="absolute inset-0 bg-gradient-to-t from-black/60 via-transparent to-transparent" />
        <div class="absolute bottom-0 inset-x-0 p-4 sm:p-5">
          <h3 class="text-xl font-medium text-white">
            {@name}, {@age}
          </h3>
          <p class="flex items-center gap-1 text-base text-white/80 mt-1">
            <.icon name="hero-map-pin" class="size-4" />
            {@location}
          </p>
        </div>
      </div>
      <div class="p-4 sm:p-5">
        <p class="text-base text-base-content/70 leading-relaxed line-clamp-2">
          {@bio}
        </p>
        <div class="mt-4 flex gap-2">
          <button
            type="button"
            class="flex-1 px-4 py-2.5 text-base font-medium text-white bg-primary rounded-lg hover:bg-primary/90 transition-colors"
          >
            {gettext("Connect")}
          </button>
          <button
            type="button"
            class="p-2.5 text-base-content/60 hover:text-primary border border-base-300 rounded-lg hover:border-primary/50 transition-colors"
            aria-label={gettext("Save profile")}
          >
            <.icon name="hero-bookmark" class="size-5" />
          </button>
        </div>
      </div>
    </article>
    """
  end

  # Feature Card Component
  attr :icon, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp feature_card(assigns) do
    ~H"""
    <div class="text-center">
      <div class="inline-flex items-center justify-center w-14 h-14 rounded-xl bg-accent/30 mb-5">
        <.icon name={@icon} class="size-7 text-primary" />
      </div>
      <h3 class="text-xl font-medium text-base-content mb-3">
        {@title}
      </h3>
      <p class="text-base text-base-content/70 leading-relaxed">
        {@description}
      </p>
    </div>
    """
  end
end
