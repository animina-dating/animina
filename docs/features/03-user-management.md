# 1. User Management & Authentication

**Status:** Not Started

---

## 1.1 Registration
- **Simple registration form** collecting required and optional fields
- Required fields: email, password, username (downcased unique, 2-15 chars, alphanumeric with dots/hyphens), first_name, last_name, birthday (legal age validation), gender, height (80-225cm), zip code, country (preselected as Germany), mobile phone, legal terms acceptance, preferred partner gender, minimum/maximum partner age offset (stored as years relative to user's age; auto-adjusts over time; calculated min must be >= 18), minimum/maximum partner height, geographic search radius (in km)
- Optional fields: occupation, language preference
- Email confirmation via 6-digit PIN within 30 minutes (before account deletion)

## 1.2 Authentication
- Email/password login (can sign in with username OR email)
- Persistent session tokens
- Password reset via email link

## 1.3 User States (Visibility Control)
| State | Description |
|-------|-------------|
| `normal` | Active, fully visible |
| `validated` | Admin-verified account |
| `under_investigation` | Flagged for review, hidden from public |
| `banned` | Permanently restricted |
| `hibernate` | Temporary self-deactivation |
| `archived` | User-deleted account |

State transitions are controlled with specific rules (e.g., only admins can ban/unban).

## 1.4 Roles & Permissions
- **User role**: Default for all users
- **Admin role**: Platform management, can view all profiles, manage reports, control waitlist

## 1.5 Waitlist System
- All new registrations are placed on the waitlist by default
- Waitlisted users see a "too successful" page
- Admins manually grant access to waitlisted users
- Email notifications for both admins and users
