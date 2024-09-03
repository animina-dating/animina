defmodule Animina.Accounts do
  @moduledoc """
  This is the Accounts module.
  """

  use Ash.Domain

  resources do
    resource Animina.Accounts.BadPassword
    resource Animina.Accounts.BasicUser
    resource Animina.Accounts.Credit
    resource Animina.Accounts.User
    resource Animina.Accounts.Token
    resource Animina.Accounts.Photo
    resource Animina.Accounts.Reaction
    resource Animina.Accounts.Message
    resource Animina.Accounts.Role
    resource Animina.Accounts.OptimizedPhoto
    resource Animina.Accounts.Report
    resource Animina.Accounts.PotentialPartner
    resource Animina.Accounts.VisitLogEntry
    resource Animina.Accounts.Bookmark
    resource Animina.Accounts.UserRole
    resource Animina.Traits.UserFlags
    resource Animina.Traits.Flag
    resource Animina.Traits.FlagTranslation
    resource Animina.Traits.Category
    resource Animina.Traits.CategoryTranslation
    resource Animina.Accounts.PhotoFlags
  end

  authorization do
    authorize :when_requested
  end
end
