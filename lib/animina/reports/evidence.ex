defmodule Animina.Reports.Evidence do
  @moduledoc """
  Captures evidence snapshots at the time of a report.
  """

  alias Animina.Messaging
  alias Animina.Moodboard
  alias Animina.Reports.ReportEvidence
  alias Animina.Repo
  alias Animina.TimeMachine

  @doc """
  Captures a snapshot of the reported user's data at the time of the report.

  Includes conversation messages (if chat context), moodboard items, and profile data.
  """
  def capture_snapshot(report, reported_user, attrs \\ %{}) do
    conversation_snapshot =
      capture_conversation(attrs[:context_type], attrs[:context_reference_id], report.reporter_id)

    moodboard_snapshot = capture_moodboard(reported_user.id)
    profile_snapshot = capture_profile(reported_user)

    %ReportEvidence{}
    |> ReportEvidence.changeset(%{
      report_id: report.id,
      conversation_snapshot: conversation_snapshot,
      moodboard_snapshot: moodboard_snapshot,
      profile_snapshot: profile_snapshot,
      snapshot_at: TimeMachine.utc_now(:second)
    })
    |> Repo.insert()
  end

  defp capture_conversation("chat", conversation_id, reporter_id)
       when is_binary(conversation_id) do
    messages = Messaging.list_messages(conversation_id, reporter_id, limit: 200)

    %{
      "conversation_id" => conversation_id,
      "messages" =>
        Enum.map(messages, fn msg ->
          %{
            "id" => msg.id,
            "sender_id" => msg.sender_id,
            "content" => msg.content,
            "inserted_at" => DateTime.to_iso8601(msg.inserted_at),
            "edited_at" => if(msg.edited_at, do: DateTime.to_iso8601(msg.edited_at))
          }
        end)
    }
  end

  defp capture_conversation(_, _, _), do: nil

  defp capture_moodboard(user_id) do
    items = Moodboard.list_moodboard(user_id)

    %{
      "items" =>
        Enum.map(items, fn item ->
          base = %{
            "id" => item.id,
            "item_type" => item.item_type,
            "position" => item.position
          }

          case item.moodboard_story do
            %{content: content} -> Map.put(base, "story_content", content)
            _ -> base
          end
        end)
    }
  end

  defp capture_profile(user) do
    %{
      "id" => user.id,
      "display_name" => user.display_name,
      "first_name" => user.first_name,
      "last_name" => user.last_name,
      "gender" => user.gender,
      "occupation" => user.occupation,
      "state" => user.state
    }
  end
end
