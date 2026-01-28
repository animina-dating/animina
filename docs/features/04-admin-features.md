# 4. Admin Features

**Status:** Not Started

---

## 4.1 Additional User States
| State | Description |
|-------|-------------|
| `validated` | Admin-verified account |
| `under_investigation` | Flagged for review, hidden from public |
| `banned` | Permanently restricted |

## 4.2 Roles & Permissions
- **User role**: Default for all users
- **Admin role**: Platform management, can view all profiles, manage reports, grant waitlist access

## 4.3 Access Control
- Route protection based on authentication state
- Role-based access (user vs admin)
- State-based visibility rules
- Automatic logout for banned/archived users

## 4.4 Waitlist Management
- Admin interface to view waitlisted users
- Manually grant access to waitlisted users
- Email notifications for both admins (new signups) and users (access granted)

## 4.5 User Management
- View all profiles regardless of privacy/state
- Change user states (ban, unban, investigate, normalize)
- Promote/demote admin role

## 4.6 Report Management
- Review pending reports
- Accept or deny reports
- Add internal memos
- View report history

