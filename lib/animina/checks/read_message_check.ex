defmodule Animina.Checks.ReadMessageCheck do
  @moduledoc """
  Policy for The Read By Sender and Receiver Action
  """
  use Ash.Policy.SimpleCheck

  def describe(_opts) do
    "Ensures an actor can only read messages that they are the sender or receiver of"
  end

  def match?(actor, params, _opts) do
    if actor.id == params.query.arguments.sender_id or
         actor.id == params.query.arguments.receiver_id do
      true
    else
      false
    end
  end
end
