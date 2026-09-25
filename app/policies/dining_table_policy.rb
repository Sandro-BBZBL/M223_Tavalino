class DiningTablePolicy < ApplicationPolicy
  # Tische verwalten (anlegen, bearbeiten, deaktivieren) dürfen nur Admins.
  # new? läuft über create?, edit? über update? (siehe ApplicationPolicy)
  def index?
    admin?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  # Welche Tische darf ein Benutzer auswählen (z. B. beim Erfassen)?
  # Admins alle, Mitarbeiter nur Tische ihrer Standorte.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?
      return scope.all if user.admin?

      scope.where(location_id: user.location_ids)
    end
  end

  private

  def admin?
    user.present? && user.admin?
  end
end