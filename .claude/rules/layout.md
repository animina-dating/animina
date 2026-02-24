---
paths:
  - "lib/animina_web/live/**"
  - "lib/animina_web/components/layouts*"
---

# Layout Convention

Every LiveView **must** wrap its content in `<Layouts.app flash={@flash} current_scope={@current_scope}>`. This shared layout component (`lib/animina_web/components/layouts.ex`) renders the ANIMINA navigation bar (with auth-aware links) and footer. Pages must **never** render their own inline nav or footer — use the shared layout so all pages look consistent.

**Page Width:** The layout automatically provides a `max-w-7xl` container with responsive padding (`px-4 sm:px-6 lg:px-8 py-8`). Pages should NOT add their own outer container. Instead:

- **Form pages** (settings, login, registration): Use `<div class="max-w-2xl mx-auto">` or `<div class="max-w-md mx-auto">` for narrower forms
- **Content pages** (moodboard, admin): Content will fill the max-w-7xl container by default
- **Full-width pages** (landing pages with background sections): Use `<Layouts.app ... full_width={true}>` to skip the container entirely and manage your own widths per section

LiveViews that need `@current_scope` must be inside a `live_session` with `on_mount: [{AniminaWeb.UserAuth, :mount_current_scope}]` in the router.
