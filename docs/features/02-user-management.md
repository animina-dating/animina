# 2. User Management & Authentication

**Status:** In Progress

---

## 2.1 User Registration

- **Registration form** with all profile fields collected upfront

### User-Entered Fields

- email
- password (min 12 chars)
- display_name (2-50 chars)
- birthday (legal age validation: 18+)
- gender (male, female, diverse)
- height (80-225cm)
- 1-4 Wohnsitze (residences), each consisting of:
  - country (preselected as Germany)
  - zip code (5 digits, with automatic city name lookup)
  - At least 1 Wohnsitz is required, up to 4 allowed
- mobile phone number (E.164 format)

### Auto-Filled Fields (editable)

These fields are pre-populated via LiveView when the user enters the fields above. After than field is filled out and only once (if the values change we keep the initially calculated values). They remain editable:

- **preferred partner gender(s)** - multi-select checkboxes (male, female, diverse); defaults to opposite gender (male→female, female→male, diverse→diverse)
- **partner minimum age offset** - years younger than user's age to search (calculated min >= 18)
  - Male users: defaults to 6 years younger
  - Female users: defaults to 2 years younger
  - Diverse users: defaults to 6 years younger
- **partner maximum age offset** - years older than user's age to search
  - Male users: defaults to 2 years older
  - Female users: defaults to 6 years older
  - Diverse users: defaults to 6 years older
- **partner height range** - defaults based on gender:
  - Male users: min = 80cm, max = user's height + 5cm
  - Female users: min = user's height - 5cm, max = 225cm
  - Diverse users: min = user's height - 15cm, max = 225cm
- **geographic search radius** - defaults to 60km

### Additional Required Fields

- legal terms acceptance checkbox

### Optional Fields

- occupation
- language preference

### Validation & Confirmation

- **Email confirmation via 6-digit PIN** (implemented):
  - After registration, a 6-digit PIN is emailed to the user
  - User enters PIN on `/users/confirm/:token` page
  - Maximum 3 attempts allowed; after 3 failures the account is deleted
  - PIN expires after 30 minutes; expired accounts are auto-deleted by a background GenServer (`UnconfirmedUserCleaner`, runs every 60 seconds)
  - On successful PIN entry, user is confirmed, logged in, and redirected to the waitlist page
- **Uniqueness constraints**: email (case-insensitive), mobile phone number

---

## 2.2 Authentication

- Email/password login
- Persistent session tokens
- Password reset via email link

---

## 2.3 Waitlist

- All new registrations placed on waitlist automatically
- Waitlisted users see "we either have too few or too many users for your town in our waitinglist" landing page after login
- Users remain on waitlist until manually granted access

---

## 2.4 User States

| State | Description |
|-------|-------------|
| `waitlisted` | On waitlist, cannot access platform features |
| `normal` | Active, fully visible |
| `hibernate` | Temporary self-deactivation |
| `archived` | User-deleted account |
