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

Elixir 1.19, Phoenix 1.8, LiveView, Tailwind CSS, PostgreSQL

## Getting Started

**Prerequisites:** macOS or Linux, [PostgreSQL](https://www.postgresql.org), [mise](https://mise.jdx.dev) for version management (Erlang/OTP 28.3, Elixir 1.19 — pinned in `.tool-versions`)

```bash
git clone git@github.com:animina-dating/animina.git
cd animina
mise install
mix deps.get
mix ecto.setup
mix phx.server
```

Visit `http://localhost:4000` to see the landing page. Register at `/users/register`.

## Development

- `mix test` — run tests
- `mix precommit` — full quality check (compile, format, credo, test)

## Admin Access

Grant admin privileges to the first user via IEx:

```elixir
iex -S mix

user = Animina.Accounts.get_user_by_email("admin@example.com")
Animina.Accounts.assign_role(user, "admin")
```

After that, manage roles for other users through the web admin panel at `/admin/roles`.

## Photo System

Polymorphic photo upload and processing system. Any schema (User, Event, Group) can own photos via `owner_type` + `owner_id`.

### Features

- **Background processing**: Resize to max 1200px, convert to WebP, strip EXIF metadata, generate pixelated variant and 400px thumbnail (for AI analysis and UX)
- **NSFW detection**: Layered approach — Bumblebee ViT classifier (fast, ~200ms) as primary; Ollama vision model as secondary for borderline cases (0.3-0.85 score range)
- **Face detection** (avatars only): Ensures profile photos contain a human face. Uses Bumblebee with `nateraw/vit-age-classifier` as a proxy (high-confidence age prediction = face present); Ollama fallback for borderline cases
- **Single combined Ollama prompt**: When any check needs Ollama escalation, a single combined prompt handles both NSFW and avatar suitability checks — simpler code, fewer states to maintain
- **Child photo filter**: Rejects avatars where the detected age range is under 20 (labels: `0-2`, `3-9`, `10-19`). Uses the same age classifier model as face detection for conservative age estimation
- **Hotlink protection**: Daily-rotating HMAC-signed URLs — old URLs expire at midnight UTC
- **State machine**: `pending → processing → nsfw_checking → [ollama_checking] → face_checking → approved` (with `pending_ollama` retry queue and `error`/`no_face_error`/`underage_error` fallbacks)
- **Appeal system**: Users can request human review of rejected photos; moderators approve/reject via `/admin/photo-reviews`
- **Blacklist**: Perceptual hashing (dhash) blocks re-uploads of rejected content; NSFW photos auto-blacklisted
- **Audit logging**: Complete history of all photo events (AI decisions, appeals, moderator actions) at `/admin/photos/:id/history`
- **Feature flags**: Admin-controllable toggles at `/admin/feature-flags` to enable/disable processing steps, set auto-approve values, or add artificial delays for UX testing
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
  thumbnail_dimension: 400,        # Thumbnail for AI analysis and UX
  webp_quality: 80,                # WebP compression quality
  pixelate_scale: 0.05,            # 5% = heavy pixelation
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
    {photo_id}.webp                # Main processed photo (1200px max)
    {photo_id}_pixelated.webp      # Blurred variant
    {photo_id}_thumb.webp          # Thumbnail (400px max, used for AI analysis)
```

### Dependencies

The photo system requires these additional dependencies (already in `mix.exs`):
- `image` — libvips-based image processing
- `bumblebee` — ML model loading for NSFW classification
- `exla` — Hardware-accelerated inference backend
- `ollama` — Secondary NSFW/face classification via Ollama API
- `fun_with_flags` — Feature flag management with Ecto persistence

**Ollama setup:** For NSFW and face detection fallback, install [Ollama](https://ollama.ai) and pull the vision model:
```bash
ollama pull qwen3-vl:8b
```

## Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) — production deployment with hot code upgrades and CI/CD
- [TRANSLATING.md](TRANSLATING.md) — i18n workflow for all 9 languages
- [DESIGN.md](DESIGN.md) — design guidelines
- [docs/features/](docs/features/) — detailed feature specifications

## License

[MIT](LICENSE.md)
