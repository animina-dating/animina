defmodule AniminaWeb.Helpers.WaitlistData do
  @moduledoc """
  Shared data-loading logic for waitlist-related views.

  Used by both `MyHub` (inline waitlist content) and `Waitlist` (standalone page).
  """

  alias Animina.Accounts
  alias Animina.Accounts.ProfileCompleteness
  alias Animina.FeatureFlags
  alias Animina.Moodboard
  alias Animina.Photos
  alias Animina.Traits

  @doc """
  Loads all waitlist-related assigns for the given user.

  Returns a keyword list suitable for `Phoenix.Component.assign/2`.
  """
  def load_waitlist_assigns(user) do
    referral_count = Accounts.count_confirmed_referrals(user)
    referral_threshold = FeatureFlags.referral_threshold()
    has_passkeys = Accounts.list_user_passkeys(user) != []
    blocked_contacts_count = Accounts.count_contact_blacklist_entries(user)
    profile_completeness = ProfileCompleteness.compute(user)

    avatar_photo = Photos.get_user_avatar(user.id)
    flag_count = Traits.count_user_flags(user)
    moodboard_count = Moodboard.count_items(user.id)

    [
      referral_code: user.referral_code,
      referral_count: referral_count,
      referral_threshold: referral_threshold,
      end_waitlist_at: user.end_waitlist_at,
      has_passkeys: has_passkeys,
      has_blocked_contacts: blocked_contacts_count > 0,
      blocked_contacts_count: blocked_contacts_count,
      avatar_photo: avatar_photo,
      flag_count: flag_count,
      moodboard_count: moodboard_count,
      profile_completeness: profile_completeness
    ]
  end
end
