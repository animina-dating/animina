# ANIMINA Feature Specifications

A comprehensive feature specification for the ANIMINA dating platform. This document is split into logical sections for incremental development.

## Overview

ANIMINA is a dating platform with:
- **Simple registration** with waitlist and post-registration profile completion
- **Three-color personality trait system** for compatibility matching
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
| 02 | [User Management & Authentication](02-user-management.md) | Not Started | Waitlist MVP |
| 03 | [Registration & Profile Completion Flow](03-registration-flow.md) | Not Started | Waitlist MVP |
| 04 | [Admin Features](04-admin-features.md) | Not Started | Waitlist MVP |
| 05 | [Notifications](05-notifications.md) | Not Started | Waitlist MVP |
| 06 | [User Profile](06-user-profile.md) | Not Started | Profile Building |
| 07 | [Personality Traits System (Flags)](07-traits-flags.md) | Not Started | Profile Building |
| 08 | [Matching & Discovery](08-matching-discovery.md) | Not Started | Core Dating |
| 09 | [User Interactions](09-user-interactions.md) | Not Started | Core Dating |
| 10 | [Reporting & Moderation](10-moderation.md) | Not Started | Safety & Polish |
| 11 | [Account Management](11-account-management.md) | Not Started | Safety & Polish |

## Appendices

| Appendix | Description |
|----------|-------------|
| [Appendix B: Flags](appendix-b-flags.md) | All 217 personality flags by category |

## Implementation Phases

### Phase 1 - Foundation & Waitlist MVP (01-05)
Essential for launching with a waitlist:
1. **Geographic Features** - Foundation for location-based matching (DONE)
2. **User Management & Authentication** - Core user system with waitlist mechanism
3. **Registration Flow** - The actual user journey through waitlist
4. **Admin Features** - Managing the waitlist and user states
5. **Notifications** - Email for PIN confirmation and waitlist alerts

### Phase 2 - Profile Building (06-07)
After users are let off the waitlist:
6. **User Profile** - Basic profile data completion
7. **Personality Traits** - Three-color flag system

### Phase 3 - Core Dating Features (08-09)
Complete profile required:
8. **Matching & Discovery** - Finding compatible partners
9. **User Interactions** - Likes, messages, bookmarks

### Phase 4 - Safety & Polish (10-11)
Post-launch refinement:
10. **Reporting & Moderation** - Full moderation system
11. **Account Management** - User self-service (hibernate, delete)
