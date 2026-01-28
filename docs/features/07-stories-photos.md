# 7. Profile Content (Stories & Photos)

**Status:** Not Started

---

## 7.1 Headlines System
46 predefined story prompts organized as:
- **Personal narratives**: "The story behind my smile", "A challenge I've overcome", etc.
- **Temporal**: Monday through Sunday
- **Seasonal**: Spring, Summer, Fall, Winter
- **Special**: "About me" (mandatory for profile completion)
- **Lifestyle/Interests**: "My favorite recipe", "A hobby I've picked up", etc.

Headlines can be activated/deactivated by admins.

See [Appendix A: Headlines](appendix-a-headlines.md) for the complete list of 46 headlines.

## 7.2 Stories
- Text content associated with a headline (max 1,024 characters)
- Position ordering within profile
- Can have associated photos
- One "About me" story required per user
- Minimum number of stories required for registration completion

## 7.3 Posts (Blog-Style)
- Title + content (max 8,192 characters)
- Auto-generated URL slug
- Date-based filtering/querying
- Separate from profile stories (more blog-like)

## 7.4 Photos
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
