defmodule Animina.Accounts.EmailTemplates do
  @moduledoc """
  Renders per-language whole-email templates from EEx files in priv/email_templates/.

  Each template file contains the subject on line 1, a `---` separator, then the body.
  """

  @supported_locales ~w(de en tr ru ar pl fr es uk)

  @company_signature """
  Wintermeyer Consulting - Johannes-Müller-Str. 10 - 56068 Koblenz - Germany
  https://wintermeyer-consulting.de
  """

  defp templates_dir do
    Application.app_dir(:animina, "priv/email_templates")
  end

  @doc """
  Renders an email template for the given locale and type.

  Returns `{subject, body}`.

  Falls back to `"de"` if the locale is not supported.

  ## Parameters

    * `locale` - Language code (e.g. "de", "en", "tr")
    * `type` - Email type atom (e.g. :confirmation_pin, :password_reset)
    * `assigns` - Keyword list of template variables

  """
  def render(locale, type, assigns) when is_atom(type) and is_list(assigns) do
    locale = if locale in @supported_locales, do: locale, else: "de"
    path = Path.join([templates_dir(), locale, "#{type}.text.eex"])
    rendered = EEx.eval_file(path, assigns: Map.new(assigns))
    [subject, body] = String.split(rendered, "\n---\n", parts: 2)
    {String.trim(subject), body <> footer(locale)}
  end

  defp footer(locale) do
    dir = templates_dir()
    closing = EEx.eval_file(Path.join([dir, locale, "_closing.text.eex"]))
    intro = EEx.eval_file(Path.join([dir, locale, "_footer.text.eex"]))
    "\n#{closing}\n-- \n#{intro}\n#{@company_signature}"
  end
end
