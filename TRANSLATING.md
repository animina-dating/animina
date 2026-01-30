# Translating ANIMINA

ANIMINA supports 8 languages using [Phoenix Gettext](https://hexdocs.pm/gettext/Gettext.html). Translations live in `.po` files under `priv/gettext/`.

## Supported Languages

| Code | Language | Status |
|------|----------|--------|
| de | Deutsch | Complete (default) |
| en | English | Complete (msgid = English, empty msgstr falls through) |
| tr | Türkçe | Needs translation |
| ru | Русский | Needs translation |
| ar | العربية | Needs translation |
| pl | Polski | Needs translation |
| fr | Français | Needs translation |
| es | Español | Needs translation |

## File Structure

```
priv/gettext/
├── default.pot          # Template: UI strings
├── emails.pot           # Template: Email strings
├── errors.pot           # Template: Validation errors
├── de/LC_MESSAGES/
│   ├── default.po       # German UI translations
│   ├── emails.po        # German email translations
│   └── errors.po        # German error translations
├── en/LC_MESSAGES/
│   ├── default.po
│   ├── emails.po
│   └── errors.po
├── tr/LC_MESSAGES/
│   └── ...
└── (ar, ru, pl, fr, es)/
    └── ...
```

**Three domains:**
- `default` — UI strings (buttons, labels, headings, page content)
- `emails` — Email subject lines and body text
- `errors` — Validation error messages

## How to Translate

### 1. Fork and clone the repository

```bash
git clone git@github.com:YOUR_USERNAME/animina.git
cd animina
```

### 2. Edit the `.po` files for your language

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

### 3. Rules

- **Never change `msgid`** — these are the English source strings
- **Preserve `%{variable}` placeholders exactly** — e.g. `%{email}`, `%{count}`, `%{cities}`
- **Preserve `%{count}`** — it is automatically populated by Gettext for plural forms
- **Keep the same line structure** — one `msgstr` per entry
- You can use any text editor, [Poedit](https://poedit.net/), or edit directly on GitHub

### 4. Submit a Pull Request

Push your branch and open a PR. The CI will verify compilation.

## Plural Forms

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

For Russian and Polish, you must provide 3 `msgstr` entries. For Arabic, you need 6.

### Updating the Plural-Forms header

If your language needs a different plural rule, update the header in each `.po` file. For example, for Russian:

```po
"Plural-Forms: nplurals=3; plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ? 1 : 2);\n"
```

For Arabic:

```po
"Plural-Forms: nplurals=6; plural=(n==0 ? 0 : n==1 ? 1 : n==2 ? 2 : n%100>=3 && n%100<=10 ? 3 : n%100>=11 ? 4 : 5);\n"
```

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
