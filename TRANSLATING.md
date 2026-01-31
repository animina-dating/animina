# Translating ANIMINA

ANIMINA supports 9 languages. UI strings and validation errors use [Phoenix Gettext](https://hexdocs.pm/gettext/Gettext.html) (`.po` files). Email translations use per-language EEx template files.

## Supported Languages

| Code | Language | Status |
|------|----------|--------|
| de | Deutsch | Complete (default) |
| en | English | Complete (msgid = English, empty msgstr falls through) |
| tr | Türkçe | Complete |
| ru | Русский | Complete |
| ar | العربية | Complete |
| pl | Polski | Complete |
| fr | Français | Complete |
| es | Español | Complete |
| uk | Українська | Complete |

## File Structure

### Gettext (UI & Errors)

```
priv/gettext/
├── default.pot          # Template: UI strings
├── errors.pot           # Template: Validation errors
├── de/LC_MESSAGES/
│   ├── default.po       # German UI translations
│   └── errors.po        # German error translations
├── en/LC_MESSAGES/
│   ├── default.po
│   └── errors.po
└── (tr, ru, ar, pl, fr, es, uk)/
    └── ...
```

**Two gettext domains:**
- `default` — UI strings (buttons, labels, headings, page content)
- `errors` — Validation error messages

### Email Templates

Email translations use whole-file EEx templates (one file per language per email type):

```
priv/email_templates/
├── de/
│   ├── confirmation_pin.text.eex
│   ├── password_reset.text.eex
│   ├── update_email.text.eex
│   ├── duplicate_registration.text.eex
│   └── daily_report.text.eex
├── en/
│   └── ... (same 5 files)
└── (tr, ru, ar, pl, fr, es, uk)/
    └── ... (same 5 files each)
```

Each template has the subject on line 1, a `---` separator, then the body. Variables use EEx syntax (`<%= @var %>`).

## How to Translate

### Gettext (UI & Errors)

#### 1. Fork and clone the repository

```bash
git clone git@github.com:YOUR_USERNAME/animina.git
cd animina
```

#### 2. Edit the `.po` files for your language

Open the file for your language and domain, e.g. `priv/gettext/fr/LC_MESSAGES/default.po`.

Each entry looks like:

```po
#: lib/animina_web/live/user_live/login.ex:12
msgid "Log in"
msgstr ""
```

Fill in the `msgstr` with your translation:

```po
msgid "Log in"
msgstr "Se connecter"
```

#### 3. Rules

- **Never change `msgid`** — these are the English source strings
- **Preserve `%{variable}` placeholders exactly** — e.g. `%{email}`, `%{count}`, `%{cities}`
- **Preserve `%{count}`** — it is automatically populated by Gettext for plural forms
- **Keep the same line structure** — one `msgstr` per entry
- You can use any text editor, [Poedit](https://poedit.net/), or edit directly on GitHub

### Email Templates

#### 1. Edit the template files for your language

Open the template in `priv/email_templates/<your-locale>/`, e.g. `priv/email_templates/fr/confirmation_pin.text.eex`.

#### 2. Template format

```
Subject line here
---

==============================

Body text here with <%= @variable %> placeholders.

==============================
```

#### 3. Rules

- **Keep the subject on line 1** and the `---` separator on line 2
- **Preserve `<%= @variable %>` placeholders** — e.g. `<%= @email %>`, `<%= @pin %>`, `<%= @url %>`, `<%= @count %>`
- You have full creative freedom over the body text — no need to match the structure of other languages
- For plural forms, use EEx conditionals: `<%= if @count == 1, do: "singular", else: "plural" %>`

### 4. Submit a Pull Request

Push your branch and open a PR. The CI will verify compilation.

## Plural Forms (Gettext)

Different languages have different plural rules. The `.po` file header declares the rule:

| Language | nplurals | Rule |
|----------|----------|------|
| German (de) | 2 | `n != 1` |
| English (en) | 2 | `n != 1` |
| Turkish (tr) | 2 | `n != 1` |
| French (fr) | 2 | `n > 1` (0 is singular) |
| Spanish (es) | 2 | `n != 1` |
| **Russian (ru)** | **3** | complex: 1 form, 2-4 form, 5+ form |
| **Polish (pl)** | **3** | complex: 1 form, 2-4 form, 5+ form |
| **Ukrainian (uk)** | **3** | complex: same as Russian |
| **Arabic (ar)** | **6** | complex: 0, 1, 2, 3-10, 11-99, 100+ |

### Plural entry example (2 forms — German, English, etc.)

```po
msgid "Wrong code. %{count} attempt remaining."
msgid_plural "Wrong code. %{count} attempts remaining."
msgstr[0] "Falscher Code. Noch %{count} Versuch übrig."
msgstr[1] "Falscher Code. Noch %{count} Versuche übrig."
```

### Plural entry example (3 forms — Russian)

```po
msgid "Wrong code. %{count} attempt remaining."
msgid_plural "Wrong code. %{count} attempts remaining."
msgstr[0] "Неверный код. Осталась %{count} попытка."
msgstr[1] "Неверный код. Осталось %{count} попытки."
msgstr[2] "Неверный код. Осталось %{count} попыток."
```

For Russian, Polish, and Ukrainian, you must provide 3 `msgstr` entries. For Arabic, you need 6.

## Testing Locally

```bash
mix deps.get
mix compile
mix phx.server
```

Then switch languages using the footer dropdown or visit with your browser language set to the target locale.

## Regenerating PO Files

After adding new `gettext()` calls in code:

```bash
mix gettext.extract --merge
```

This updates the `.pot` templates and merges new entries into all `.po` files.
