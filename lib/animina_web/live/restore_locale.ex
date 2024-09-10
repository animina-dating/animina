defmodule AniminaWeb.RestoreLocale do
  def on_mount(:default, %{"language" => language}, _session, socket) do

    IO.inspect("I Mounted")
    IO.inspect language
    IO.inspect Gettext.put_locale(Animina.Gettext, "de")
    {:cont, socket}
  end

  # catch-all case
  def on_mount(:default, _params, _session, socket), do: {:cont, socket}
end
