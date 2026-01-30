# Email Privacy Protection

## Problem

When registering with an email already in use, the system previously showed
"has already been taken". This reveals that the email's owner has a dating
account — a serious privacy leak for a dating platform.

## Solution

When a duplicate email is the only registration error, the system pretends
registration succeeded. The user sees the same PIN confirmation page as a
real registration. A **warning email** is sent to the existing account holder
instead of a confirmation PIN. The attacker sees identical UX and cannot
determine whether the email was already registered.

## How It Works

### Phantom Flow

1. User submits registration with an already-taken email
2. System detects the email uniqueness error is the only error
3. A warning email is sent to the existing account holder
4. A **phantom token** is generated: `{:phantom, uuid, email}` signed with
   `Phoenix.Token`
5. User is redirected to `/users/confirm/:token` with the same flash message

### Phantom PIN Confirmation

- The PIN confirmation page detects the phantom token via pattern matching
- It renders identical UI (same fields, same remaining attempts/time display)
- Every PIN attempt returns "wrong PIN" (no real PIN exists)
- After 3 failed attempts, redirects to registration with the same "account
  deleted" message as the real flow

### Mixed Errors

If the email uniqueness error appears alongside other validation errors
(e.g., password too short), the email uniqueness error is silently stripped
from the changeset. The remaining errors are shown normally. Once the user
fixes those errors and resubmits, they hit the phantom flow.

### Warning Email

The existing account holder receives a German-language email informing them
that someone tried to register with their email address, suggesting they
change their password.

## Key Design Decisions

- **No DB record for phantom**: The phantom flow creates no user record. The
  existing user's record is untouched. The only side effect is the warning email.
- **Timing**: Both flows involve email delivery I/O, so response times are
  comparable. No artificial delay is needed.
- **Token shape**: `{:phantom, uuid, email}` tuple vs plain UUID string —
  `Phoenix.Token` serializes arbitrary Erlang terms, so pattern matching in
  `case` distinguishes the flows. URLs look equally opaque.

## Files

| File | Role |
|------|------|
| `lib/animina/accounts/user_notifier.ex` | `deliver_duplicate_registration_warning/1` |
| `lib/animina/accounts.ex` | `email_uniqueness_error?/1`, `only_email_uniqueness_error?/1` |
| `lib/animina_web/live/user_live/registration.ex` | Phantom flow trigger in save handler |
| `lib/animina_web/live/user_live/pin_confirmation.ex` | Phantom token mount + verify_pin |
| `test/animina_web/live/user_live/registration_test.exs` | Privacy protection tests |
