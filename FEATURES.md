# ANIMINA Feature Specification (Technology-Agnostic)

A comprehensive feature specification for rebuilding the ANIMINA dating platform. This document describes WHAT the application does, not HOW it's implemented.

---

## 1. USER MANAGEMENT & AUTHENTICATION

### 1.1 Registration
- **Multi-step onboarding flow** with progress tracking
- Required fields: email, username (2-15 chars, alphanumeric with dots/hyphens), name, birthday (legal age validation), gender, zip code, country, mobile phone
- Optional fields: height (40-250cm), occupation, language preference
- Legal terms acceptance required
- Email confirmation via 6-digit PIN (3 attempts before account deletion)
- Registration completion requires: profile photo + "About me" story with photo

### 1.2 Authentication
- Email/password login (can sign in with username OR email)
- Password strength validation against common password blacklist
- Persistent session tokens
- Password reset via email link

### 1.3 User States (Visibility Control)
| State | Description |
|-------|-------------|
| `normal` | Active, fully visible |
| `validated` | Admin-verified account |
| `under_investigation` | Flagged for review, hidden from public |
| `banned` | Permanently restricted |
| `incognito` | User-chosen hidden mode, can't receive messages |
| `hibernate` | Temporary self-deactivation |
| `archived` | User-deleted account |

State transitions are controlled with specific rules (e.g., only admins can ban/unban).

### 1.4 Roles & Permissions
- **User role**: Default for all users
- **Admin role**: Platform management, can view all profiles, manage reports, control waitlist

### 1.5 Waitlist System
- Triggers when registration rate exceeds hourly threshold
- Waitlisted users see a "too successful" page
- Admins manually grant access to waitlisted users
- Email notifications for both admins and users

---

## 2. USER PROFILE

### 2.1 Basic Profile Information
- Name, username, email (hidden from public)
- Birthday (with calculated age display)
- Gender
- Height
- Occupation
- Country, city (resolved from zip code)
- Mobile phone (hidden from public)
- Language preference

### 2.2 Partner Preferences
- Preferred partner gender
- Minimum/maximum partner age (min 18)
- Minimum/maximum partner height
- Geographic search radius (in km)
- Communication preference: "preapproved only" (only users you've liked can message you)

### 2.3 Visibility Settings
- Incognito mode hides profile completely

### 2.4 Profile Completion Requirements
- Must have profile photo
- Must have "About me" story with at least one photo
- Registration marked complete only when requirements met
- Incomplete profiles are not visible to other users

---

## 3. PERSONALITY TRAITS SYSTEM (FLAGS)

### 3.1 Flag Types (Three Colors)
| Color | Purpose | Description |
|-------|---------|-------------|
| **White** | About Me | Traits that describe the user |
| **Green** | Attracted To | Traits user wants in a partner |
| **Red** | Deal Breakers | Traits user does NOT want in a partner |

### 3.2 Flag Categories
Flags are organized into semantic categories:
- Character (honesty, courage, resilience, etc.)
- Lifestyle
- Hobbies & Interests
- Values
- And more...

### 3.3 Flag Selection Rules
- Configurable maximum number of flags per color
- Position/order indicates importance (first = most important)
- Same flag cannot have multiple colors for the same user
- Some flags are "photo-flaggable" (can be applied to photos)

### 3.4 Flag Matching
- System identifies intersecting flags between users
- Shows which white flags (about me) overlap
- Shows which of user A's green flags match user B's white flags
- Detects red flag conflicts (incompatibilities)

---

## 4. PROFILE CONTENT (STORIES & PHOTOS)

### 4.1 Headlines System
46 predefined story prompts organized as:
- **Personal narratives**: "The story behind my smile", "A challenge I've overcome", etc.
- **Temporal**: Monday through Sunday
- **Seasonal**: Spring, Summer, Fall, Winter
- **Special**: "About me" (mandatory for profile completion)
- **Lifestyle/Interests**: "My favorite recipe", "A hobby I've picked up", etc.

Headlines can be activated/deactivated by admins.

### 4.2 Stories
- Text content associated with a headline (max 1,024 characters)
- Position ordering within profile
- Can have associated photos
- One "About me" story required per user
- Minimum number of stories required for registration completion

### 4.3 Posts (Blog-Style)
- Title + content (max 8,192 characters)
- Auto-generated URL slug
- Date-based filtering/querying
- Separate from profile stories (more blog-like)

### 4.4 Photos
- Multiple photos per user
- Profile photo (standalone) vs story photos
- Required metadata: filename, mime type, dimensions, file size

**Photo States:**
| State | Description |
|-------|-------------|
| `pending_review` | Awaiting moderation |
| `in_review` | Being reviewed |
| `approved` | Visible to others |
| `rejected` | Failed moderation |
| `nsfw` | Flagged as explicit |
| `error` | Processing failed |

**Photo Processing:**
- Automatic optimization into multiple sizes:
  - Thumbnail: 100x100px
  - Normal: 600x600px
  - Big: 1000px width
- Format conversion for web optimization
- Optional NSFW detection via machine learning
- Optional auto-tagging via AI

---

## 5. MATCHING & DISCOVERY

### 5.1 Potential Partner Matching
Filters potential matches based on:
- Gender preference (user's preference vs profile's gender)
- Age range (within user's min/max partner age)
- Height range (within user's min/max partner height)
- Geographic distance (haversine formula, within search radius km)
- Results randomized for variety

### 5.2 Exclusion Rules
Excludes from matching:
- User's own profile
- Users under investigation
- Banned users
- Archived users
- Hibernating users
- Incognito users
- Users with incomplete registration
- Optionally: already-bookmarked users

### 5.3 Discovery Features
- "Recently registered" users feed (filterable by gender, date range)
- Dashboard shows limited number of active potential partners
- Results paginated with configurable limits

---

## 6. USER INTERACTIONS

### 6.1 Reactions
Three reaction types:
| Type | Effect |
|------|--------|
| **Like** | Express romantic interest, auto-creates bookmark |
| **Block** | Prevent user from seeing you or contacting you |
| **Hide** | Temporarily hide user from your search results |

- One reaction type per sender-receiver pair
- Reactions can be reversed (unlike, unblock, unhide)
- Removing a like deletes associated bookmark

### 6.2 Bookmarks
Two bookmark reasons:
- **Liked**: Auto-created when liking a profile
- **Visited**: Created when viewing a profile

Features:
- Last visit timestamp tracking
- Sort by: most frequently visited, longest total duration, most recent
- Used for "who visited my profile" features

### 6.3 Visit Tracking
- Records every profile visit with duration (milliseconds)
- Aggregates total visits and total time per profile
- Enables engagement analytics

### 6.4 Messaging
- Direct messages between users (max 1,024 characters)
- Read/unread status with timestamp
- Conversation history retrieval
- Unread message count display

**Rate Limiting:**
- Max 10 messages/minute to same recipient
- Max 20 messages/minute from user total
- Max 50 messages/hour to same recipient
- Max 250 messages/day from user total

**Communication Gating:**
- If "preapproved communication only" enabled, only users the profile has liked can message them
- Blocked users cannot send messages

---

## 7. REPORTING & MODERATION

### 8.1 User Reports
- Users can report other users with description (max 1,024 characters)
- Report captures accused user's state at time of report

**Report States:**
| State | Description |
|-------|-------------|
| `pending` | Awaiting admin review |
| `under_review` | Admin is reviewing |
| `accepted` | Report validated, user banned |
| `denied` | Report dismissed, user normalized |

### 8.2 Report Actions
- Creating report automatically puts accused user "under investigation"
- Accepting report bans the accused user
- Denying report returns user to previous valid state
- Admins can add internal memo (max 1,024 characters)

### 8.3 Admin Notifications
- Email sent to admin when new report submitted
- Admin panel for reviewing pending reports

---

## 8. GEOGRAPHIC FEATURES

### 9.1 City Database
- Zip code lookup
- Latitude/longitude coordinates
- County and state/region information
- Fast indexed lookups

### 9.2 Distance Calculation
- Haversine formula for calculating distance between coordinates
- Finds all cities within specified radius (km)
- Used for partner matching geographic filtering

### 9.3 User Location
- Zip code entry during registration
- City auto-resolved from zip code
- City displayed on profile

---

## 9. NOTIFICATIONS

### 10.1 Real-Time Notifications (In-App)
- New messages received
- Reactions (likes/blocks) created/removed
- Bookmarks created/updated
- Profile visits
- User flag changes
- Story updates

### 10.2 Email Notifications
- PIN code for email confirmation
- Password reset link
- Report submitted (to admin)
- Added to waitlist (to admin)
- Removed from waitlist (to user)

---

## 10. ADMIN FEATURES

### 11.1 User Management
- View all profiles regardless of privacy/state
- Change user states (ban, unban, investigate, normalize)
- Promote/demote admin role
- Manage waitlist access

### 11.2 Report Management
- Review pending reports
- Accept or deny reports
- Add internal memos
- View report history

### 11.3 Content Management
- Manage headlines (activate/deactivate)
- Photo moderation (approve/reject)

---

## 11. REGISTRATION ONBOARDING FLOW

Step-by-step registration:

1. **Filter Potential Partners** - Set initial preferences, see potential match count
2. **Select White Flags** - Choose traits about yourself (most important first)
3. **Select Green Flags** - Choose traits you want in a partner
4. **Select Red Flags** - Choose deal-breaker traits
5. **User Details** - Complete remaining profile fields
6. **Email Validation** - Confirm email via PIN
7. **Preferences Setup** - Set partner age/height/gender/distance preferences
8. **Profile Photo** - Upload required profile photo
9. **About Me Story** - Create required "About me" story with photo

Progress tracked so users can resume interrupted registration.

---

## 12. ACCOUNT MANAGEMENT

### 13.1 Profile Editing
- Update all profile fields
- Change password
- Update partner preferences
### 12.2 Profile Visibility Controls
- Activate/deactivate profile
- Enter incognito mode
- Hibernate account
- Archive (delete) account

### 12.3 Account Deletion
- Safety countdown (10 seconds) before deletion enabled
- Requires PIN confirmation
- Irreversible action

---

## 13. SECURITY FEATURES

### 14.1 Input Validation
- Username: 2-15 chars, alphanumeric + dots/hyphens
- Name: 1-50 chars
- Height: 40-250 cm
- Minimum partner age: >= 18
- Password: validated against common password blacklist
- Phone number: international format validation

### 14.2 Uniqueness Constraints
- Email (case-insensitive)
- Username (case-insensitive)
- Mobile phone number

### 14.3 Access Control
- Route protection based on authentication state
- Role-based access (user vs admin)
- State-based visibility rules
- Automatic logout for banned/archived users

---

## 14. MOBILE-FIRST DESIGN REQUIREMENTS

- Responsive design prioritizing mobile experience
- Dark mode support
- Touch-friendly interface
- Minimal JavaScript, server-rendered interactions
- Image optimization for mobile bandwidth

---

## Summary

ANIMINA is a dating platform with:
- **Multi-step onboarding** with progress tracking
- **Three-color personality trait system** for compatibility matching
- **Story-based profiles** with headlines and photos
- **Geographic matching** within configurable radius
- **Comprehensive moderation** with reports and user state management
- **Visibility controls** including incognito mode
- **Real-time notifications** for all interactions
- **Rate-limited messaging** with communication gating options

The platform emphasizes profile completeness and thoughtful matching through the personality flag system.

---

## APPENDIX A: COMPLETE LIST OF HEADLINES (46 total)

Story prompts users can choose from when creating profile content:

| # | Headline |
|---|----------|
| 1 | The story behind my smile in this photo |
| 2 | Caught in the moment doing what I love |
| 3 | A place I'd go back to in a heartbeat |
| 4 | My idea of a perfect day |
| 5 | Just me enjoying my favorite hobby |
| 6 | The adventure that left me speechless |
| 7 | A talent I'm proud of |
| 8 | A tradition I hold dear |
| 9 | A meal I can cook to perfection |
| 10 | My favorite meal |
| 11 | A book that changed my perspective |
| 12 | The joy of finding something new |
| 13 | A moment of pure bliss |
| 14 | An achievement I'm really proud of |
| 15 | A lesson learned the hard way |
| 16 | Something I've created |
| 17 | A glimpse into my daily life |
| 18 | A place where I feel most at peace |
| 19 | A friendship that means the world to me |
| 20 | A challenge I've overcome |
| 21 | My favorite way to relax |
| 22 | An unforgettable night out |
| 23 | A family tradition I love |
| 24 | An impulse decision that was totally worth it |
| 25 | A moment that took my breath away |
| 26 | Just a casual day out |
| 27 | My favorite childhood memory |
| 28 | A pet I adore |
| 29 | Something that always makes me laugh |
| 30 | A hobby I've recently picked up |
| 31 | A dream I'm chasing |
| 32 | Out of my comfort zone |
| 33 | Monday |
| 34 | Tuesday |
| 35 | Wednesday |
| 36 | Thursday |
| 37 | Friday |
| 38 | Saturday |
| 39 | Sunday |
| 40 | Spring |
| 41 | Summer |
| 42 | Fall |
| 43 | Winter |
| 44 | **About me** *(required for profile completion)* |
| 45 | My family |
| 46 | My favorite recipe |

---

## APPENDIX B: COMPLETE LIST OF FLAGS BY CATEGORY

### Character (20 flags)
| Emoji | Flag Name |
|-------|-----------|
| 🌼 | Modesty |
| ⚖️ | Sense of Justice |
| 🤝 | Honesty |
| 🦁 | Courage |
| 🪨 | Resilience |
| 🔑 | Sense of Responsibility |
| 😄 | Humor |
| 💖 | Caring |
| 🎁 | Generosity |
| 🤗 | Self-Acceptance |
| 👨‍👩‍👧‍👦 | Family-Oriented |
| 🧠 | Intelligence |
| 🌍 | Love of Adventure |
| 🏃 | Active |
| 💞 | Empathy |
| 🎨 | Creativity |
| ☀️ | Optimism |
| 💐 | Being Romantic |
| 💪 | Self-Confidence |
| 🌐 | Social Awareness |

### Family Planning (3 flags)
| Emoji | Flag Name |
|-------|-----------|
| 👨‍👩‍👧‍👦 | Have Children |
| 👨‍👩‍👧‍👦❌ | Want No More Children |
| 👨‍👩‍👧‍👦➕ | Open to More Children |

### Substance Use (3 flags)
| Emoji | Flag Name |
|-------|-----------|
| 🚬 | Smoking |
| 🍻 | Alcohol |
| 🌿 | Marijuana |

### Animals (10 flags)
| Emoji | Flag Name |
|-------|-----------|
| 🐶 | Dog |
| 🐱 | Cat |
| 🐭 | Mouse |
| 🐰 | Rabbit |
| 🐹 | Guinea Pig |
| 🐹 | Hamster |
| 🐦 | Bird |
| 🐠 | Fish |
| 🦎 | Reptile |
| 🐴 | Horse |

### Food (24 flags)
| Emoji | Flag Name |
|-------|-----------|
| 🌱 | Vegan |
| 🥦 | Vegetarian |
| 🍝 | Italian |
| 🥡 | Chinese |
| 🍛 | Indian |
| 🥖 | French |
| 🥘 | Spanish |
| 🌮 | Mexican |
| 🍣 | Japanese |
| 🍢 | Turkish |
| 🍲 | Thai |
| 🥙 | Greek |
| 🍔 | American |
| 🍜 | Vietnamese |
| 🍚 | Korean |
| 🌭 | German |
| 🍇 | Mediterranean |
| 🍟 | Fast Food |
| 🥡 | Street Food |
| 🥗 | Healthy Food |
| 🍰 | Desserts |
| 🥐 | Pastries |
| 🍖 | BBQ |
| 🍿 | Snacks |

### Sports (27 flags)
| Emoji | Flag Name |
|-------|-----------|
| ⚽ | Soccer |
| 🤸 | Gymnastics |
| 🎾 | Tennis |
| 🥾 | Hiking |
| 🧗 | Climbing |
| ⛷ | Skiing |
| 🏃 | Athletics |
| 🤾 | Handball |
| 🏇 | Horse Riding |
| ⛳ | Golf |
| 🏊 | Swimming |
| 🏐 | Volleyball |
| 🏀 | Basketball |
| 🏒 | Ice Hockey |
| 🏓 | Table Tennis |
| 🏸 | Badminton |
| 🧘 | Yoga |
| 🤿 | Diving |
| 🏄 | Surfing |
| ⛵ | Sailing |
| 🚣 | Rowing |
| 🥊 | Boxing |
| 🚴 | Cycling |
| 🏃‍♂️ | Jogging |
| 🤸‍♀️ | Pilates |
| 🏋️ | Gym |
| 🥋 | Martial Arts |

### Travels (10 flags)
| Emoji | Flag Name |
|-------|-----------|
| 🏖️ | Beach |
| 🏙️ | City Trips |
| 🥾 | Hiking Vacation |
| 🚢 | Cruises |
| 🚴 | Bike Tours |
| 🧘‍♀️ | Wellness |
| 🏋️‍♂️ | Active and Sports Vacation |
| 🏕️ | Camping |
| 🕌 | Cultural Trips |
| 🏂 | Winter Sports |

### Favorite Destinations (27 flags)
| Emoji | Flag Name |
|-------|-----------|
| 🇪🇺 | Europe |
| 🌏 | Asia |
| 🌍 | Africa |
| 🌎 | North America |
| 🌎 | South America |
| 🇦🇺 | Australia |
| ❄️ | Antarctica |
| 🇪🇸 | Spain |
| 🇮🇹 | Italy |
| 🇹🇷 | Turkey |
| 🇦🇹 | Austria |
| 🇬🇷 | Greece |
| 🇫🇷 | France |
| 🇭🇷 | Croatia |
| 🇩🇪 | Germany |
| 🇹🇭 | Thailand |
| 🇺🇸 | USA |
| 🇵🇹 | Portugal |
| 🇨🇭 | Switzerland |
| 🇳🇱 | Netherlands |
| 🇪🇬 | Egypt |
| 🌴 | Canary Islands |
| 🏝️ | Mallorca |
| 🌺 | Bali |
| 🇳🇴 | Norway |
| 🇨🇦 | Canada |
| 🇬🇧 | United Kingdom |

### Music (23 flags)
| Emoji | Flag Name |
|-------|-----------|
| 🎤 | Pop |
| 🎸 | Rock |
| 🧢 | Hip-Hop |
| 🎙️ | Rap |
| 🎛️ | Techno |
| 🍻 | Schlager |
| 🎻 | Classical |
| 🎷 | Jazz |
| 🤘 | Heavy Metal |
| 👓 | Indie |
| 🪕 | Folk |
| 🏞️ | Folk Music |
| 🎵 | Blues |
| 🇯🇲 | Reggae |
| 💖 | Soul |
| 🤠 | Country |
| 💿 | R&B |
| 🔊 | Electronic |
| 🏠🎶 | House |
| 💃 | Dance |
| 🕺 | Latin |
| 🧷 | Punk |
| 🚀 | Alternative |

### Literature (20 flags)
| Emoji | Flag Name |
|-------|-----------|
| 🔍 | Crime |
| 📚 | Novels |
| ❤️ | Romance Novels |
| 🏰 | Historical Novels |
| 🐉 | Fantasy |
| 🚀 | Science Fiction |
| 📘 | Non-Fiction |
| 👤 | Biographies |
| 💋 | Erotica |
| 👧👦 | Children's and Young Adult |
| 😄 | Humor |
| 📖 | Classics |
| 👻 | Horror |
| 📙 | Guidebooks |
| 🍂 | Poetry |
| 🌍 | Adventure |
| 💭 | Philosophy |
| 💣 | Thriller |
| 🧠 | Psychology |
| 🔬 | Science |

### At Home (19 flags)
| Emoji | Flag Name |
|-------|-----------|
| 🍳 | Cooking |
| 🍰 | Baking |
| 📖 | Reading |
| 🎬 | Movies |
| 📺 | Series |
| 💻 | Online Courses |
| 🏋️‍♂️ | Fitness Exercises |
| 🌱 | Gardening |
| 🧵 | Handicrafts |
| 🎨 | Drawing |
| 🎵 | Music |
| 🧩 | Puzzles |
| 🎲 | Board Games |
| 🧘 | Meditation |
| 🔨 | DIY Projects |
| 📓 | Journaling |
| 🎧 | Podcasts |
| 🔊 | Audiobooks |
| 🎮 | Video Games |

### Creativity (16 flags)
| Emoji | Flag Name |
|-------|-----------|
| 📷 | Photography |
| 🎨 | Design |
| 🧶 | Crafting |
| 🖌️ | Art |
| 💄 | Make-up |
| ✍️ | Writing |
| 🎤 | Singing |
| 💃 | Dancing |
| 🎥 | Video Production |
| 📱 | Social Media |
| 🎶 | Making Music |
| 🎭 | Acting |
| 🖼️ | Painting |
| 🧵 | Crocheting |
| 🧶 | Knitting |
| 🪡 | Sewing |

### Going Out (11 flags)
| Emoji | Flag Name |
|-------|-----------|
| 🍹 | Bars |
| ☕ | Cafes |
| 🎉 | Clubbing |
| 💃 | Drag Shows |
| 🎪 | Festivals |
| 🎤 | Karaoke |
| 🎵 | Concerts |
| 🌈 | LGBTQ+ Nightlife |
| 🖼️ | Museums & Galleries |
| 😆 | Stand-Up Comedy |
| 🎭 | Theater |

### Self Care (7 flags)
| Emoji | Flag Name |
|-------|-----------|
| 😴 | Good Sleep |
| 💬 | Deep Conversations |
| 🧘 | Mindfulness |
| 👥 | Counseling |
| 🍏 | Nutrition |
| 📵 | Going Offline |
| ❤️‍🔥 | Sex Positivity |

### Politics (7 flags)
| Emoji | Flag Name |
|-------|-----------|
| - | CDU |
| - | SPD |
| - | Die Grünen |
| - | FDP |
| - | AfD |
| - | The Left |
| - | CSU |

### Religion (10 flags)
| Emoji | Flag Name |
|-------|-----------|
| ✝️ | Roman Catholic |
| ✝️ | Protestant |
| ☦️ | Orthodox Christianity |
| ☪️ | Islam |
| ✡️ | Judaism |
| ☸️ | Buddhism |
| 🕉️ | Hinduism |
| ⚛️ | Atheism |
| ❓ | Agnosticism |
| 🕊️ | Spirituality |

---

**Total: 16 categories with 217 flags**
