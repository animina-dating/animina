# 5. Matching & Discovery

**Status:** Not Started

---

## 5.1 Potential Partner Matching
Filters potential matches based on:
- Gender preference (user's preference vs profile's gender)
- Age range (within user's min/max partner age)
- Height range (within user's min/max partner height)
- Geographic distance (haversine formula, within search radius km)
- Results randomized for variety

## 5.2 Exclusion Rules
Excludes from matching:
- User's own profile
- Users under investigation
- Banned users
- Archived users
- Hibernating users
- Incognito users
- Users with incomplete registration
- Optionally: already-bookmarked users

## 5.3 Discovery Features
- "Recently registered" users feed (filterable by gender, date range)
- Dashboard shows limited number of active potential partners
- Results paginated with configurable limits
