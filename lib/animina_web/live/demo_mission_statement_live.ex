defmodule AniminaWeb.DemoMissionStatementLive do
  @moduledoc """
  Mission Statement page for ANIMINA - our core values and vision.
  """
  use AniminaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Mission Statement – ANIMINA"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <!-- Hero Section with Mission Statement -->
      <section class="relative overflow-hidden">
        <div class="absolute inset-0 bg-gradient-to-b from-accent/10 via-transparent to-transparent" />

        <div class="relative mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-16 sm:py-24 lg:py-32">
          <div class="text-center max-w-4xl mx-auto">
            <a
              href="/"
              class="inline-flex items-center gap-2 text-base text-primary hover:text-primary/80 mb-8 transition-colors"
            >
              <.icon name="hero-arrow-left" class="size-5 rtl:rotate-180" /> {gettext(
                "Back to home page"
              )}
            </a>

            <h1 class="text-3xl sm:text-4xl md:text-5xl lg:text-6xl font-light tracking-tight text-base-content leading-tight">
              {gettext("Dating that is")}
              <span class="text-primary font-normal">{gettext("fair")}</span>
              {gettext("and")} <span class="text-primary font-normal">{gettext("transparent")}</span>
            </h1>
            <p class="mt-8 text-lg sm:text-xl text-base-content/70 leading-relaxed max-w-3xl mx-auto">
              {gettext(
                "No hidden costs, no secret algorithms, no premium traps. Real people, real connections – for everyone."
              )}
            </p>
          </div>
        </div>
      </section>
      
    <!-- Mission Details -->
      <section class="py-16 sm:py-24 bg-base-200/50">
        <div class="mx-auto max-w-4xl px-4 sm:px-6 lg:px-8">
          <div class="prose prose-lg max-w-none">
            <.mission_block
              title={gettext("Respect as a foundation")}
              icon="hero-shield-check"
            >
              {gettext(
                "Every user defines their own boundaries – those who repeatedly cross them will be blocked. And anyone can report inappropriate behavior. Respectful interaction is our top priority."
              )}
            </.mission_block>

            <.mission_block
              title={gettext("Fun without addiction")}
              icon="hero-face-smile"
            >
              {gettext(
                "Dating should be fun, but not addictive – in real life you don't meet 50 new people every day either. That's why we deliberately avoid manipulative designs like endless swiping or push notifications that keep pulling you back."
              )}
            </.mission_block>

            <.mission_block
              title={gettext("For everyone")}
              icon="hero-heart"
            >
              {gettext(
                "We care about everyone. No matter who you are – you are welcome at ANIMINA. No discrimination through algorithms that only favor certain people. Our code is open source – anyone can verify that we treat everyone equally."
              )}
            </.mission_block>

            <.mission_block
              title={gettext("Fairness through limitation")}
              icon="hero-hand-raised"
            >
              {gettext(
                "On traditional platforms both sides struggle: Attractive people drown in requests, less popular ones barely get any. With us, everyone can only send 5 requests per day – just like in real life. This makes dating fairer for everyone."
              )}
            </.mission_block>

            <.mission_block
              title={gettext("Personality over superficiality")}
              icon="hero-puzzle-piece"
            >
              {gettext(
                "Our unique three-color system helps you find people who truly match you. White flags show who you are. Green ones what you're looking for. Red ones what's a no-go. Profiles with depth instead of superficial swiping."
              )}
            </.mission_block>
          </div>
        </div>
      </section>
      
    <!-- CTA Section -->
      <section class="py-16 sm:py-24">
        <div class="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8 text-center">
          <h2 class="text-2xl sm:text-3xl font-light text-base-content">
            {gettext("Ready for real dating?")}
          </h2>
          <p class="mt-4 text-lg text-base-content/70">
            {gettext("No tricks, no hidden costs. Simply meet people who match you.")}
          </p>
          <div class="mt-8">
            <a
              href="/users/register"
              class="inline-flex items-center justify-center px-10 py-4 text-lg font-medium text-white bg-primary rounded-xl hover:bg-primary/90 transition-all duration-200 shadow-md hover:shadow-lg hover:-translate-y-0.5"
            >
              {gettext("Register now")}
              <.icon name="hero-arrow-right" class="ms-2 size-5 rtl:rotate-180" />
            </a>
          </div>
          <p class="mt-4 text-base text-base-content/70">
            {gettext("Free. Forever. For everyone.")}
          </p>
        </div>
      </section>
    </Layouts.app>
    """
  end

  # Mission block component
  attr :title, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp mission_block(assigns) do
    ~H"""
    <div class="flex gap-6 mb-10 p-6 rounded-2xl bg-base-100 shadow-sm">
      <div class="flex-shrink-0">
        <div class="inline-flex items-center justify-center w-14 h-14 rounded-xl bg-accent/30">
          <.icon name={@icon} class="size-7 text-primary" />
        </div>
      </div>
      <div>
        <h3 class="text-xl font-medium text-base-content mb-3">
          {@title}
        </h3>
        <p class="text-base text-base-content/70 leading-relaxed">
          {render_slot(@inner_block)}
        </p>
      </div>
    </div>
    """
  end
end
