# ANIMINA Dating Platform

ANIMINA is a web based dating platform. In case you have a question do not
hesitate to contact Stefan Wintermeyer <sw@wintermeyer-consulting.de>

![Screenshot of an admin ANIMINA view](https://github.com/animina-dating/animina/blob/main/priv/static/images/admin-screenshot.png?raw=true)

> [!NOTE]
> Project founder Stefan Wintermeyer gave a (German) talk about the first
> ANIMINA Beta at [FrOSCon](https://froscon.org).
>
> - [video recording](https://media.ccc.de/v/froscon2024-3060-parship_tinder_animina_und_co)
> - [slides](https://speakerdeck.com/wintermeyer/disassembling-online-dating-froscon-2024)

## Tech Stack

Elixir 1.19, Phoenix 1.8, LiveView, Tailwind CSS (DaisyUI), PostgreSQL, TOAST UI Editor (WYSIWYG Markdown)

## Architecture

```
lib/animina/              # Business logic (contexts)
  accounts/               # Users, auth, roles, locations, soft delete
  photos/                 # Upload, processing, moderation, signed URLs
  traits/                 # Categories, flags, matching (white/green/red)
  moodboard/              # Profile moodboard items (photos + stories)
  messaging/              # Conversations, messages, read receipts
  discovery/              # Partner suggestions, scoring, popularity
  geo_data/               # City/zip code lookups
  feature_flags/          # FunWithFlags wrappers
  utils/                  # Shared helpers (timezone, paper_trail)

lib/animina_web/          # Web layer
  live/                   # LiveView pages
    user_live/            # User settings, profile, moodboard editor
    admin/                # Admin panel (roles, photos, flags, queues)
    components/           # Reusable LiveComponents
  components/             # Function components (layouts, core)
  helpers/                # Shared helpers for LiveViews
```

All schemas use UUIDs for primary keys. Real-time updates use Phoenix PubSub. Feature flags via [FunWithFlags](https://github.com/tompave/fun_with_flags) with admin UI at `/admin/feature-flags`.

## Getting Started

**Prerequisites:** macOS or Linux, [PostgreSQL](https://www.postgresql.org), [mise](https://mise.jdx.dev) for version management (Erlang/OTP 28.3, Elixir 1.19 — pinned in `.tool-versions`)

```bash
git clone git@github.com:animina-dating/animina.git
cd animina
mise install
mix deps.get
cd assets && npm install && cd ..
mix ecto.setup
mix phx.server
```

Visit `http://localhost:4000` to see the landing page. Register at `/users/register`.

## Development

- `mix test` — run tests
- `mix precommit` — full quality check (compile, format, credo, test)
- `mix dev:reset` — reset database and seed 50 test accounts (dev only)

### Dev Test Accounts

In development, run `mix dev:reset` to create 50 test accounts with full profiles, traits, and moodboards. The login page shows a one-click panel for instant access. All accounts use password `password12345`.

## Roles and Admin Access

Three roles: `user` (implicit), `moderator` (photo reviews), and `admin` (full access). Grant admin privileges to the first user via IEx:

```elixir
iex -S mix

user = Animina.Accounts.get_user_by_email("admin@example.com")
Animina.Accounts.assign_role(user, "admin")
```

After that, manage roles through `/admin/roles`. Admin pages: `/admin/feature-flags`, `/admin/photo-reviews`, `/admin/photos/:id/history`, `/admin/logs` (email, Ollama, and activity logs).

## Photo System

Polymorphic photo upload and processing system. Any schema (User, Event, Group) can own photos via `owner_type` + `owner_id`.

### Features

- **Background processing**: Resize to max 1200px, convert to WebP, strip EXIF metadata, generate pixelated variant and 768px thumbnail (for AI analysis and UX)
- **Content moderation**: Ollama vision model checks photos for family-friendly content and face detection (for avatars)
- **Face detection** (avatars only): Ensures profile photos contain exactly one person facing the camera
- **Hotlink protection**: Daily-rotating HMAC-signed URLs — old URLs expire at midnight UTC
- **State machine**: `pending → processing → nsfw_checking → [ollama_checking] → face_checking → approved` (with `pending_ollama` retry queue and `error`/`no_face_error`/`underage_error` fallbacks)
- **Appeal system**: Users can request human review of rejected photos; moderators approve/reject via `/admin/photo-reviews`
- **Blacklist**: Perceptual hashing (dhash) blocks re-uploads of rejected content; NSFW photos auto-blacklisted
- **Image cropping**: Mobile-friendly Cropper.js integration. Avatar photos require mandatory square cropping; gallery photos offer optional square cropping
- **Audit logging**: Complete history of all photo events (AI decisions, appeals, moderator actions) at `/admin/photos/:id/history`
- **Feature flags**: Admin-controllable toggles at `/admin/feature-flags` to enable/disable processing steps, set auto-approve values, or add artificial delays for UX testing. Also includes system settings for referral threshold (default: 3) and soft delete grace period (default: 28 days). Every Ollama API call is logged to the database and viewable at `/admin/logs/ollama`. All system emails are logged and viewable at `/admin/logs/emails`. A unified activity log at `/admin/logs/activity` captures auth, social, profile, admin, and system events with real-time streaming, filters, and user search
- **Cold deploy resilience**: Photos stuck in intermediate processing states are automatically recovered and re-processed on server restart

### Usage

```elixir
# Upload a photo for a user (type: "avatar")
{:ok, photo} = Animina.Photos.upload_photo("User", user.id, "/path/to/file.jpg",
  type: "avatar",
  original_filename: "selfie.jpg",
  content_type: "image/jpeg"
)

# Get a user's avatar
photo = Animina.Photos.get_user_avatar(user.id)

# Get signed URL for display (auto-serves pixelated if NSFW)
url = Animina.Photos.get_user_avatar_url(user.id)
# => "/photos/abc123signature/photo-uuid.webp"

# List all approved photos for an owner
photos = Animina.Photos.list_photos("User", user.id)

# List photos by type
avatars = Animina.Photos.list_photos("User", user.id, "avatar")
```

### Configuration

```elixir
# config/config.exs
config :animina, Animina.Photos,
  upload_dir: "uploads",           # Base directory for uploads
  max_upload_size: 10_000_000,     # 10 MB
  max_dimension: 1200,             # Longest edge in pixels
  thumbnail_dimension: 768,        # Thumbnail for AI analysis and UX (768px optimal for qwen3-vl 32px patches)
  webp_quality: 80,                # WebP compression quality
  nsfw_threshold_high: 0.85,       # Above = definitely NSFW
  nsfw_threshold_low: 0.3,         # Below = definitely SFW
  face_detection_enabled: true,    # Enable face detection for avatars
  face_threshold_high: 0.7,        # Above = face detected
  face_threshold_low: 0.3,         # Below = no face (or escalate to Ollama)
  ollama_url: "http://localhost:11434/api",  # Single instance (backward compatible)
  ollama_model: "qwen3-vl:8b",
  ollama_timeout: 120_000,          # Per-instance timeout
  ollama_total_timeout: 300_000,    # Total timeout across all failover attempts
  ollama_circuit_breaker_threshold: 3,  # Failures before marking instance unhealthy
  ollama_circuit_breaker_reset_ms: 60_000,  # Cooldown before retrying unhealthy instance
  # Multi-instance failover (optional):
  # ollama_instances: [
  #   %{url: "http://localhost:11434/api", timeout: 120_000, priority: 1},
  #   %{url: "http://backup:11434/api", timeout: 180_000, priority: 2}
  # ],
  blacklist_hamming_threshold: 10  # Max hamming distance for blacklist match
```

**Multi-instance failover:** Configure multiple Ollama instances for high availability. The system tries instances in priority order and fails over on connection errors or server issues. Circuit breaker pattern prevents repeated requests to unhealthy instances.

Runtime override via environment variable:
```bash
OLLAMA_URLS="http://server1:11434/api,http://server2:11434/api"
```

### File Storage

```
uploads/
  originals/                       # Never publicly accessible
    {owner_type}/{owner_id}/{photo_id}.{ext}
  processed/                       # Served via signed URLs
    {owner_type}/{owner_id}/
      {photo_id}.webp              # Main processed photo (1200px max)
      {photo_id}_thumb.webp        # Thumbnail (768px max, used for AI analysis)
```

### Dependencies

The photo system requires these additional dependencies (already in `mix.exs`):
- `image` — libvips-based image processing
- `ollama` — Content moderation and face detection via Ollama API
- `fun_with_flags` — Feature flag management with Ecto persistence

**Ollama setup:** For content moderation and face detection, install [Ollama](https://ollama.ai) and pull the vision model:
```bash
ollama pull qwen3-vl:8b
```

## Trait System (Flags)

Users express personality and preferences through a three-color flag system:

- **White flags**: "This describes me" — personal traits (e.g., "I love hiking", "I'm introverted")
- **Green flags**: "I'm attracted to this" — desired traits in a partner
- **Red flags**: "This is a dealbreaker" — traits to avoid in a partner

Flags are organized into categories. The discovery system uses bidirectional flag matching to score compatibility: a user's white flags are checked against others' green/red flags and vice versa. Users manage their flags at `/settings/profile/traits`.

## Moodboard

Each user has a public moodboard (`/users/:user_id`) — a visual profile composed of photos, stories (Markdown text), and combined photo+caption cards. Owners edit their moodboard at `/settings/profile/moodboard` with drag-and-drop reordering and inline story editing via TOAST UI Editor.

## Messaging System

Real-time 1:1 messaging between users at `/messages`.

### Features

- **Chat slot system**: Max 6 active conversations (configurable), max 2 new conversations per day (configurable)
- **"Let Go"**: Permanently close a conversation to free a slot — mutual closure with dismissal records
- **"Love Emergency"**: Reopen a closed conversation at the cost of closing 4 others (configurable)
- **Closed conversation archive**: Last 10 closed conversations shown at bottom of messages page with profile cards
- **Real-time messages** via PubSub with typing indicators (auto-timeout after 3s)
- **Read receipts** with double-check icon on the last read message
- **Markdown rendering** — bold, italic, links rendered via Earmark with XSS protection
- **Unread badge** — real-time unread count in the navigation bar across all pages
- **Enter-to-send** with Shift+Enter for newlines and auto-growing textarea
- **Smart scroll** — only auto-scrolls on new messages if you're near the bottom
- **Date separators** between messages from different days ("Today", "Yesterday", weekday, date)
- **Message grouping** — consecutive messages from the same sender within 2 minutes are visually clustered
- **Message deletion** — trash icon on hover for own unread messages; deleting updates recipient's unread count
- **Blocking** per conversation

## Discovery System

The partner discovery system suggests compatible matches with a daily set model:

- **Daily discovery sets**: A fixed set of suggestions generated once per day (Berlin time), no refresh
- **Slot-aware gating**: Discovery hides suggestions when chat slots are full or daily new-chat limit is reached

### Features

- **Bidirectional matching**: Both users must fit each other's criteria
- **Static daily sets**: Suggestions persist across page reloads (generated once per Berlin calendar day)
- **Profile visit tracking**: "Visited" badge on discover cards for profiles you've viewed
- **Active chat indicator**: "Chat" badge on discover cards for users you have conversations with
- **Privacy-safe conflict warnings**: Generic "Potential conflicts" without counts to prevent flag reverse-engineering
- **Cooldown period**: Users reappear after 30 days (configurable)
- **Popular user protection**: Users receiving 6+ daily inquiries are temporarily hidden
- **Scoring adjustments**: Low-popularity users get visibility boosts; high-popularity users get balanced exposure
- **Closed conversation exclusion**: Users from closed conversations are permanently excluded from discovery

### Configuration

Configure via feature flags at `/admin/feature-flags`:
- `chat_max_active_slots` — max active conversations per user (default: 6)
- `chat_daily_new_limit` — max new conversations per day (default: 2)
- `chat_love_emergency_cost` — conversations to close to reopen one (default: 4)
- `discovery_daily_set_size` — scored suggestions per daily set (default: 6)
- `discovery_popularity_enabled` — master toggle (default: off)
- `discovery_daily_inquiry_limit` — threshold before hiding (default: 6)
- `discovery_popularity_score_bonus` — boost for low-popularity users (default: +10)
- `discovery_popularity_score_penalty` — penalty for high-popularity users (default: -15)

## Security Features

### Multi-Device Session Management

Users can view and manage their active sessions at `/settings/sessions`:
- Lists all active sessions with browser/OS, IP address, and last active time
- Current session identified with "This device" badge
- Per-session "Log out" button and "Log out all other devices" button
- Revoking a session broadcasts a PubSub disconnect to close the LiveView

### 48-Hour Undo for Email/Password Changes

When a user changes their email or password, a security event is created:
- **Email changes**: Notification sent to the OLD email with undo and confirm links
- **Password changes**: Notification sent to the current email with undo and confirm links
- **48-hour cooldown**: Further email/password changes are blocked during the review period
- **Undo link**: Reverts the change and kills all sessions (victim can regain access)
- **Confirm link**: Approves the change and clears the cooldown immediately
- **Password reset NOT blocked**: The forgot-password flow remains available as a recovery mechanism

## Legal Compliance

German DSGVO/GDPR compliant with:
- **Terms of Service (AGB)** at `/agb` — covers moderation rights, user obligations, admin access to content
- **Privacy Policy** at `/datenschutz` — detailed data processing disclosures including admin/moderator access
- **Imprint** at `/impressum`
- **Re-consent flow**: Existing users must accept updated ToS on next login; new users accept during registration
- **Self-service account deletion** at `/settings/account` with 30-day grace period

## Documentation

- [CLAUDE.md](CLAUDE.md) — development conventions and coding guidelines
- [DEPLOYMENT.md](DEPLOYMENT.md) — production deployment with hot code upgrades and CI/CD
- [TRANSLATING.md](TRANSLATING.md) — i18n workflow for all 9 languages
- [DESIGN.md](DESIGN.md) — design system ("Coastal Morning" theme, DaisyUI components)
- [DISCOVERY_ALGORITHM.md](DISCOVERY_ALGORITHM.md) — how the matching algorithm works (filtering, scoring, examples)
- [docs/features/](docs/features/) — detailed feature specifications

## License

[MIT](LICENSE.md)
