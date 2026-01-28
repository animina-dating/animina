# 10. Reporting & Moderation

**Status:** Not Started

---

## 10.1 User Reports
- Users can report other users with description (max 1,024 characters)
- Report captures accused user's state at time of report

**Report States:**
| State | Description |
|-------|-------------|
| `pending` | Awaiting admin review |
| `under_review` | Admin is reviewing |
| `accepted` | Report validated, user banned |
| `denied` | Report dismissed, user normalized |

## 10.2 Report Actions
- Creating report automatically puts accused user "under investigation"
- Accepting report bans the accused user
- Denying report returns user to previous valid state
- Admins can add internal memo (max 1,024 characters)

## 10.3 Admin Notifications
- Email sent to admin when new report submitted
- Admin panel for reviewing pending reports
