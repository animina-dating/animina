# Discovery Algorithm

How ANIMINA decides which profiles to show to whom.

The discovery engine is a three-stage pipeline: **filter** candidates by hard constraints (distance, age, gender, height — all bidirectional), **score** the remaining candidates by flag compatibility, then **present** the top results across three distinct lists. A worked example traces two users through the entire pipeline at the end.

## The Flag System

Users describe themselves and their preferences through *flags* — short traits like "I love hiking" or "Vegan".

Each flag belongs to a **category** (e.g., "Lifestyle", "Languages", "What I'm Looking For"). A user assigns a flag one of three **colors**:

| Color | Meaning | Example |
|-------|---------|---------|
| **White** | "This describes me" | Alice marks "Loves hiking" white |
| **Green** | "I'm attracted to this" | Alice marks "Plays guitar" green |
| **Red** | "This is a dealbreaker" | Alice marks "Smoker" red |

Each colored flag also has an **intensity**:

| Intensity | Meaning |
|-----------|---------|
| **Hard** (default) | Non-negotiable — hard reds are absolute dealbreakers, hard greens are strong desires |
| **Soft** | Preference — soft reds are concerns (penalized but not excluded from Combined list), soft greens are nice-to-haves |

### Sensitive Categories

Some categories are marked `sensitive` (e.g., political views, religion). Flags in sensitive categories are **only included in matching** if *both* users have opted in to that category via `UserCategoryOptIn`. This prevents one user's sensitive traits from influencing matching without mutual consent.

## Step 1: Filtering

Before any scoring happens, the filter stage removes candidates who can't possibly match. The **Standard Filter** applies these checks in order:

1. **Exclude self**
2. **Exclude soft-deleted users** — `deleted_at` must be nil
3. **State filter** — only users in "normal" state
4. **Distance** — haversine distance from viewer's primary location must be within `search_radius` (default: 60 km)
5. **Bidirectional gender preference** — viewer must accept candidate's gender AND candidate must accept viewer's gender
6. **Bidirectional age range** — viewer's age range must include candidate's age AND candidate's age range must include viewer's age (default offsets: -6 / +2 years)
7. **Bidirectional height range** — same principle (defaults: 80–225 cm)
8. **Exclude dismissed users** — users the viewer clicked "Not interested" on
9. **Exclude recently shown** — users shown within the cooldown period (default: 30 days)
10. **Exclude incomplete profiles** — if enabled, users without a photo, height, or gender (default: disabled)
11. **Exclude users at daily inquiry limit** — if popularity protection is enabled, users who received 6+ inquiries today

**Bidirectional** means both sides must fit. If Alice (28) sets her age range to 25–35, she'll see Bob (31). But if Bob sets *his* range to 28–33, he'd also see Alice. If Bob had set his range to 20–27, neither would see the other — the filter is mutual.

### Relaxed Filter (for Wildcards)

The relaxed filter loosens constraints to broaden the pool:

- Gender, age, and height are **one-way** (only viewer's preferences apply)
- Distance radius is **doubled**
- Incomplete profiles are always included

## Step 2: Flag Matching

For each candidate that passes filtering, the system computes **flag overlap** via `Animina.Traits.Matching.compute_flag_overlap/2`.

The overlap identifies where one user's white flags intersect with the other's green or red flags (and vice versa):

| Overlap Type | Meaning |
|--------------|---------|
| `green_white_hard` | One user's green-hard flag matches the other's white flag — strong attraction signal |
| `green_white_soft` | One user's green-soft flag matches the other's white flag — mild attraction signal |
| `red_white_hard` | One user's red-hard flag matches the other's white flag — hard dealbreaker |
| `red_white_soft` | One user's red-soft flag matches the other's white flag — concern, not dealbreaker |
| `white_white` | Both users have the same flag as white — shared trait |

Green-white and red-white overlaps are **bidirectional**: if Alice has "Plays guitar" as green and Bob has it as white, that's a match. If Bob has "Loves hiking" as green and Alice has it as white, that's *also* a match. Both are included.

### Post-Filter Red Flag Rejection

After computing overlap, candidates are rejected in-memory based on the list type:

- **Combined / Attracted lists**: Reject candidates with any `red_white_hard` overlap
- **Safe list**: Reject candidates with *any* red overlap (hard or soft)

Soft-red candidates remain in Combined and Attracted lists but receive scoring penalties.

## Step 3: Scoring

Each surviving candidate gets a numeric score. The default **Weighted Scorer** computes:

```
score = 0
  + (each green_white_hard flag) × 20 × category_multiplier
  + (each green_white_soft flag) × 10 × category_multiplier
  + (each white_white flag)      ×  5 × category_multiplier
  + (each red_white_soft flag)   × -50 × category_multiplier   [Combined only]
  + new_user_boost      (100 if registered within 14 days, else 0)
  + incomplete_penalty   (-30 if missing photo/height/gender, else 0)
  + popularity_adjustment
```

### Category Multipliers

Not all flag categories are equally important. The scoring multiplier per category:

| Category | Multiplier |
|----------|------------|
| Languages | 3× |
| What I'm Looking For (Relationship Goals) | 2× |
| All others | 1× |

This means a green-hard match on "Speaks French" (Languages, 3×) is worth `20 × 3 = 60` points, while a green-hard match on "Loves hiking" (default, 1×) is worth `20 × 1 = 20` points.

### Popularity Adjustment

Based on the candidate's 7-day rolling average of daily inquiries received:

| 7-day average | Adjustment |
|---------------|------------|
| < 1.0 | +10 (visibility boost for less popular users) |
| > 4.0 | -15 (balance exposure for very popular users) |
| 1.0–4.0 | 0 |

### Scoring Variants by List

| Component | Combined | Safe | Attracted |
|-----------|----------|------|-----------|
| Green hard bonus | 20 × multiplier | 20 × multiplier | **40** × multiplier (doubled) |
| Green soft bonus | 10 × multiplier | 10 × multiplier | **20** × multiplier (doubled) |
| White-white bonus | 5 × multiplier | 5 × multiplier | — |
| Soft red penalty | -50 × multiplier | — | — |
| New user boost | 100 | 100 | 100 |
| Incomplete penalty | -30 | -30 | -30 |
| Popularity adj. | yes | yes | yes |

The **Attracted** list doubles green flag bonuses and ignores white-white and red penalties — it's purely about attraction signal.

## The Three Lists

After scoring, the top 8 candidates (configurable) per list are returned:

### Combined

The default, balanced list. Includes soft-red candidates but penalizes them. Candidates with hard-red matches are excluded entirely. The output includes `has_soft_red` and `soft_red_count` metadata so the UI can show a "Potential conflicts" warning badge.

### Safe

The most conservative list. Excludes *any* red flag match (hard or soft). Only green and white overlaps contribute to scoring. Best for risk-averse users.

### Attracted

Prioritizes attraction over caution. Green flag bonuses are doubled. White-white and red penalties are not applied. Hard-red matches are still excluded. Best for users who want to explore based on what they're drawn to.

## Wildcards

When a user has exhausted or wants to go beyond the main lists, **wildcards** provide a random selection from a broader pool.

Wildcards use the **Relaxed Filter** with parameters widened by 20%:

- Age offsets: expanded by 20% (minimum +1 year each direction)
- Height range: expanded by 10% each direction (clamped to 50–250 cm)
- Search radius: expanded by 20% (minimum +5 km)

Default wildcard count: 2 per request. Already-suggested users are excluded.

## Popularity Protection

An optional system (disabled by default) that prevents popular users from being overwhelmed.

### How It Works

1. When a user sends a first message (inquiry) to someone, `record_inquiry/2` logs it
2. Each user's daily inquiry count is tracked
3. A nightly job (2 AM UTC) computes 7-day and 30-day rolling averages
4. Users who received 6+ inquiries today are temporarily hidden from discovery
5. Rolling averages influence scoring adjustments (see above)

### Daily Limit

When enabled, users who have received `daily_inquiry_limit` (default: 6) or more inquiries today are excluded from all filter results. They become visible again the next day.

## Cooldown and Dismissals

### Cooldown

After a user is shown in a suggestion list, they won't appear again for the cooldown period (default: 30 days). Tracked via `SuggestionView` records with `shown_at` timestamps.

### Dismissals

When a user clicks "Not interested", a permanent `Dismissal` record is created. Dismissed users never appear again in any list for that viewer.

## Configuration

All settings are controlled via feature flags at `/admin/feature-flags`:

| Setting | Feature Flag | Default | Range |
|---------|-------------|---------|-------|
| Suggestions per list | `discovery_suggestions_per_list` | 8 | 1–50 |
| Cooldown period (days) | `discovery_cooldown_days` | 30 | 1–365 |
| New user boost period (days) | `discovery_new_user_boost_days` | 14 | 1–90 |
| Default search radius (km) | `discovery_default_search_radius` | 60 | 10–500 |
| Wildcard count | `discovery_wildcard_count` | 2 | 0–10 |
| Soft red penalty | `discovery_soft_red_penalty` | -50 | -200–0 |
| Green hard bonus | `discovery_green_hard_bonus` | 20 | 1–100 |
| Green soft bonus | `discovery_green_soft_bonus` | 10 | 1–50 |
| White-white bonus | `discovery_white_white_bonus` | 5 | 1–25 |
| New user boost | `discovery_new_user_boost` | 100 | 0–500 |
| Incomplete penalty | `discovery_incomplete_penalty` | -30 | -200–0 |
| Languages multiplier | `discovery_category_multiplier_languages` | 3 | — |
| Relationship goals multiplier | `discovery_category_multiplier_relationship_goals` | 2 | — |
| Default multiplier | `discovery_category_default_multiplier` | 1 | — |
| Scorer module | `discovery_scorer_module` | "weighted" | "weighted" / "simple" |
| Filter module | `discovery_filter_module` | "standard" | "standard" / "relaxed" |
| Exclude incomplete profiles | `discovery_exclude_incomplete_profiles` | false | — |
| Require mutual bookmark exclusion | `discovery_require_mutual_bookmark_exclusion` | true | — |
| Popularity protection enabled | `discovery_popularity_enabled` | false | — |
| Daily inquiry limit | `discovery_daily_inquiry_limit` | 6 | 1–50 |

## Worked Example

**Alice** (28, Berlin): Speaks French (white), Loves hiking (white), Plays guitar (green-hard), Vegan (green-soft), Smoker (red-hard), Heavy drinker (red-soft). Search radius: 50 km, age range: 25–35.

**Bob** (31, Potsdam, 35 km away): Plays guitar (white), Vegan (white), Loves hiking (white), Speaks French (white). Age range: 26–34.

### Filtering

1. Bob is not Alice — pass
2. Bob is not deleted — pass
3. Bob is in "normal" state — pass
4. Berlin to Potsdam is ~35 km, within Alice's 50 km radius — pass
5. Gender preferences match bidirectionally — pass
6. Alice (28) is in Bob's range (26–34) and Bob (31) is in Alice's range (25–35) — pass
7. Heights in range — pass
8. Not dismissed — pass
9. Not recently shown — pass

Bob passes all filters.

### Flag Overlap

| Alice's Flag | Alice's Color | Bob's Flag | Bob's Color | Overlap |
|--------------|---------------|------------|-------------|---------|
| Plays guitar | green-hard | Plays guitar | white | `green_white_hard` |
| Vegan | green-soft | Vegan | white | `green_white_soft` |
| Smoker | red-hard | — | — | no overlap (Bob has no Smoker flag) |
| Heavy drinker | red-soft | — | — | no overlap |
| Loves hiking | white | Loves hiking | white | `white_white` |
| Speaks French | white | Speaks French | white | `white_white` |

**Result**: `green_white_hard: 1, green_white_soft: 1, red_white_hard: 0, red_white_soft: 0, white_white: 2`

No red overlaps — Bob is eligible for all three lists.

### Scoring (Combined List, Weighted Scorer)

Assuming default category multipliers (1×) for all flags in this example:

```
green_white_hard:  1 × 20 × 1 =  20
green_white_soft:  1 × 10 × 1 =  10
white_white:       2 ×  5 × 1 =  10
red_white_soft:    0 × -50     =   0
new_user_boost:    Bob registered 2 months ago = 0
incomplete_penalty: Bob has photo + height + gender = 0
popularity_adj:    Bob's 7-day avg is 1.5 = 0
                              TOTAL = 40
```

If "Plays guitar" were in the Languages category (3× multiplier), the green-hard match alone would be worth `20 × 3 = 60` instead of 20.

### Result

Bob appears in Alice's:
- **Combined** list with score 40
- **Safe** list (no red overlap at all)
- **Attracted** list with score 50 (green bonuses doubled: `1×40 + 1×20 = 60`, no white-white bonus)

## Code Map

| Component | File(s) |
|-----------|---------|
| Public API | `lib/animina/discovery.ex` |
| Pipeline orchestration | `lib/animina/discovery/suggestion_generator.ex` |
| Settings & defaults | `lib/animina/discovery/settings.ex` |
| Filter orchestration | `lib/animina/discovery/candidate_filter.ex` |
| Standard filter | `lib/animina/discovery/filters/standard_filter.ex` |
| Relaxed filter | `lib/animina/discovery/filters/relaxed_filter.ex` |
| Filter helpers | `lib/animina/discovery/filters/filter_helpers.ex` |
| Filter behaviour | `lib/animina/discovery/behaviours/filter.ex` |
| Scorer orchestration | `lib/animina/discovery/candidate_scorer.ex` |
| Weighted scorer | `lib/animina/discovery/scorers/weighted_scorer.ex` |
| Simple scorer | `lib/animina/discovery/scorers/simple_scorer.ex` |
| Scorer behaviour | `lib/animina/discovery/behaviours/scorer.ex` |
| Flag overlap | `lib/animina/traits/matching.ex` |
| Popularity tracking | `lib/animina/discovery/popularity.ex` |
| Nightly aggregation | `lib/animina/discovery/popularity_aggregator.ex` |
| Schemas | `lib/animina/discovery/schemas/` (SuggestionView, Dismissal, Inquiry, PopularityStat, ProfileVisit) |
| Trait schemas | `lib/animina/traits/` (Category, Flag, UserFlag, UserCategoryOptIn, UserWhiteFlagCategoryPublish) |
