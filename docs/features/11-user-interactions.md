# 6. User Interactions

**Status:** Not Started

---

## 6.1 Reactions
Three reaction types:
| Type | Effect |
|------|--------|
| **Like** | Express romantic interest, auto-creates bookmark |
| **Block** | Prevent user from seeing you or contacting you |
| **Hide** | Temporarily hide user from your search results |

- One reaction type per sender-receiver pair
- Reactions can be reversed (unlike, unblock, unhide)
- Removing a like deletes associated bookmark

## 6.2 Bookmarks
Two bookmark reasons:
- **Liked**: Auto-created when liking a profile
- **Visited**: Created when viewing a profile

Features:
- Last visit timestamp tracking
- Sort by: most frequently visited, longest total duration, most recent
- Used for "who visited my profile" features

## 6.3 Visit Tracking
- Records every profile visit with duration (milliseconds)
- Aggregates total visits and total time per profile
- Enables engagement analytics

## 6.4 Messaging
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
