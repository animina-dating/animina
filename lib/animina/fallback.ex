defmodule Animina.Fallback do
  defexception message:
                 "This profile either doesn't exist or you don't have enough points to access it.  You need 20 points to access a profile page.",
               plug_status: 404
end
