# Discovery Algorithm

How ANIMINA decides which profiles to show to whom.

The discovery system uses a **SpotlightPool** — a flat filter pipeline with no scoring. Candidates pass through a series of bidirectional filters, then a daily **Spotlight** picks 6 pool candidates (round-robin across cycles) plus 2 wildcards from an expanded pool. The same set is shown all day, resetting at Berlin midnight.

## The Flag System

Users describe themselves and their preferences through *flags* — short traits like "I love hiking" or "Vegan".

Each flag belongs to a **category** (e.g., "Lifestyle", "Languages", "What I'm Looking For"). A user assigns a flag one of three **colors**:

| Color | Meaning | Example |
|-------|---------|---------|
| **White** | "This describes me" | Alice marks "Loves hiking" white |
| **Green** | "I'm attracted to this" | Alice marks "Plays guitar" green |
| **Red** | "This is a dealbreaker" | Alice marks "Smoker" red |

Red flags have an **intensity** of either **hard** (non-negotiable) or **soft** (preference). Only hard-red flags participate in discovery filtering.

## SpotlightPool: The Filter Pipeline

The SpotlightPool applies these filters in order to produce the base candidate set:

```
from(u in User)
|> exclude_self(viewer)
|> exclude_blacklisted(viewer)
|> exclude_report_invisible(viewer)
|> exclude_soft_deleted()
|> filter_by_state()
|> filter_by_distance(viewer)
|> filter_by_gender(viewer)
|> filter_by_age(viewer)
|> filter_by_height(viewer)
|> exclude_hard_red_conflicts(viewer)
|> Repo.all()
```

### Filter Details

1. **Exclude self** — the viewer is never shown to themselves.

2. **Exclude blacklisted** — bidirectional contact blacklist. If the viewer has blacklisted a candidate's email or phone number, or the candidate has blacklisted the viewer's email or phone number, the candidate is excluded. Entries are stored in `contact_blacklist_entries` and managed at `/my/settings/blocked-contacts`.

3. **Exclude report-invisible** — when a user reports another user, both become mutually invisible to each other in discovery. The `report_invisibilities` table stores two rows per report (one for each direction). This filter queries all `hidden_user_id` values where the viewer is the `user_id` and excludes those candidates. Because two rows are created per report, the invisibility is always bidirectional — user A cannot see user B, and user B cannot see user A. Invisibility entries use phone hashes in addition to user IDs, so they survive account deletion and re-registration.

4. **Exclude soft-deleted** — users with a non-nil `deleted_at` are excluded.

5. **State filter** — only users in "normal" state (completed onboarding) are shown.

6. **Distance** — haversine distance from viewer's primary location must be within both the viewer's `search_radius` (default: 60 km) and the candidate's `search_radius`. This is bidirectional: both users must be within each other's radius.

7. **Bidirectional gender preference** — the viewer must accept the candidate's gender AND the candidate must accept the viewer's gender.

8. **Bidirectional age range** — the viewer's age range must include the candidate's age AND the candidate's age range must include the viewer's age (default offsets: -6 / +2 years).

9. **Bidirectional height range** — the viewer's height range must include the candidate's height AND the candidate's height range must include the viewer's height (defaults: 80-225 cm). Users without a height set pass through.

10. **Exclude hard-red conflicts** — bidirectional hard-red flag filtering. If any of the viewer's hard-red flags match a candidate's white flags, that candidate is excluded. If any of the candidate's hard-red flags match the viewer's white flags, that candidate is also excluded.

**Bidirectional** means both sides must fit. If Alice (28) sets her age range to 25-35, she'll see Bob (31). But if Bob sets *his* range to 28-33, he'd also see Alice. If Bob had set his range to 20-27, neither would see the other.

### Admin Funnel View

The `build_with_funnel/1` variant runs each filter step individually and returns per-step counts showing how many candidates survive each stage and how many are dropped. This is used in the admin panel for diagnostics.

The `build_with_pool_count/1` variant returns both the "area pool" count (candidates after the distance filter) and the final candidate list after all filters.

## Wildcards

The **WildcardPool** uses the same base filters (self, blacklist, soft-deleted, state, gender) but with relaxed parameters:

- Distance radius: viewer's radius expanded by 20%, candidate's radius unchanged
- Age offsets: viewer's offsets expanded by 20%, candidate's offsets unchanged
- Height filter: **not applied**
- Hard-red conflict filter: **not applied**

Wildcards cast a wider net to introduce variety beyond the strict match pool.

## Daily Spotlight

The Spotlight system presents a fixed daily set of candidates that persists across page reloads:

1. User visits `/discover`
2. System computes today's Berlin date
3. Checks `spotlight_entries` table for existing entries for `[user_id, today]`
4. If entries exist, loads and returns them in order
5. If no entries, seeds a new set:
   - Builds the SpotlightPool for the viewer
   - Removes permanent exclusions (dismissed users + existing conversation partners)
   - Removes candidates already shown in the current cycle
   - Picks 6 random candidates from the remaining pool
   - Picks 2 random wildcards from the WildcardPool (excluding permanent exclusions and pool picks)
   - Persists all entries to the database

### Round-Robin Cycles

To ensure all candidates get shown over time, the system tracks a **cycle number**:

- Each non-wildcard spotlight entry has a `cycle_number`
- Already-shown candidates within the current cycle are excluded from future daily sets
- When fewer candidates remain than needed (pool exhausted), the cycle increments and the shown history resets
- This guarantees every candidate in the pool eventually gets shown before any repeats

### Moodboard Access

A user can view another user's full moodboard if any of these conditions are met:

- They are the profile owner
- They are an admin or moderator
- They have an active (non-blocked) conversation
- They appear in each other's today spotlight (bidirectional)

## Dismissals

When a user clicks "Not interested", a permanent `Dismissal` record is created. Dismissed users never appear again in any spotlight for that viewer.

## Popularity Protection

An optional system (disabled by default) that prevents popular users from being overwhelmed:

- When a user sends a first message to someone, `record_inquiry/2` logs it
- Each user's daily inquiry count is tracked
- Users who exceeded the daily limit can be temporarily hidden from discovery

## Code Map

| Component | File(s) |
|-----------|---------|
| Public API | `lib/animina/discovery.ex` |
| SpotlightPool (filter pipeline) | `lib/animina/discovery/spotlight_pool.ex` |
| WildcardPool (relaxed filters) | `lib/animina/discovery/wildcard_pool.ex` |
| Spotlight (daily set) | `lib/animina/discovery/spotlight.ex` |
| Filter helpers | `lib/animina/discovery/filters/filter_helpers.ex` |
| Popularity tracking | `lib/animina/discovery/popularity.ex` |
| Report invisibility schema | `lib/animina/reports/report_invisibility.ex` |
| Report invisibility logic | `lib/animina/reports/invisibility.ex` |
| Schemas | `lib/animina/discovery/schemas/` (SpotlightEntry, Dismissal, Inquiry, PopularityStat, ProfileVisit) |
| Trait schemas | `lib/animina/traits/` (Category, Flag, UserFlag) |
