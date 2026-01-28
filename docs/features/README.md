# ANIMINA Feature Specifications

A comprehensive feature specification for the ANIMINA dating platform. This document is split into logical sections for incremental development.

## Overview

ANIMINA is a dating platform with:
- **Simple registration** with waitlist and post-registration profile completion
- **Three-color personality trait system** for compatibility matching
- **Story-based profiles** with headlines and photos
- **Geographic matching** within configurable radius
- **Comprehensive moderation** with reports and user state management
- **Visibility controls** including incognito mode
- **Real-time notifications** for all interactions
- **Rate-limited messaging** with communication gating options

The platform emphasizes profile completeness and thoughtful matching through the personality flag system.

## Feature Sections

| # | Section | Status | Phase |
|---|---------|--------|-------|
| 01 | [Geographic Features](01-geographic.md) | Done | Foundation |
| 02 | [Security Features](02-security.md) | Not Started | Foundation |
| 03 | [User Management & Authentication](03-user-management.md) | Not Started | Waitlist MVP |
| 04 | [Registration & Profile Completion Flow](04-registration-flow.md) | Not Started | Waitlist MVP |
| 05 | [Admin Features](05-admin-features.md) | Not Started | Waitlist MVP |
| 06 | [Notifications](06-notifications.md) | Not Started | Waitlist MVP |
| 07 | [User Profile](07-user-profile.md) | Not Started | Profile Building |
| 08 | [Profile Content (Stories & Photos)](08-stories-photos.md) | Not Started | Profile Building |
| 09 | [Personality Traits System (Flags)](09-traits-flags.md) | Not Started | Profile Building |
| 10 | [Matching & Discovery](10-matching-discovery.md) | Not Started | Core Dating |
| 11 | [User Interactions](11-user-interactions.md) | Not Started | Core Dating |
| 12 | [Reporting & Moderation](12-moderation.md) | Not Started | Safety & Polish |
| 13 | [Account Management](13-account-management.md) | Not Started | Safety & Polish |

## Appendices

| Appendix | Description |
|----------|-------------|
| [Appendix A: Headlines](appendix-a-headlines.md) | All 46 story headline prompts |
| [Appendix B: Flags](appendix-b-flags.md) | All 217 personality flags by category |

## Implementation Phases

### Phase 1 - Foundation & Waitlist MVP (01-06)
Essential for launching with a waitlist:
1. **Geographic Features** - Foundation for location-based matching (DONE)
2. **Security Features** - Validation rules needed for registration forms
3. **User Management & Authentication** - Core user system with waitlist mechanism
4. **Registration Flow** - The actual user journey through waitlist
5. **Admin Features** - Managing the waitlist and user states
6. **Notifications** - Email for PIN confirmation and waitlist alerts

### Phase 2 - Profile Building (07-09)
After users are let off the waitlist:
7. **User Profile** - Basic profile data completion
8. **Stories & Photos** - Profile content (photos required for completion)
9. **Personality Traits** - Three-color flag system

### Phase 3 - Core Dating Features (10-11)
Complete profile required:
10. **Matching & Discovery** - Finding compatible partners
11. **User Interactions** - Likes, messages, bookmarks

### Phase 4 - Safety & Polish (12-13)
Post-launch refinement:
12. **Reporting & Moderation** - Full moderation system
13. **Account Management** - User self-service (hibernate, delete)
