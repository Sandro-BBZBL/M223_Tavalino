class DiningTablePolicy < ApplicationPolicy
  # Welche Tische darf ein Benutzer auswählen bzw. verwalten?
  # Admins alle, Mitarbeiter nur Tische ihrer Standorte.
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?
      return scope.all if user.admin?

      scope.where(location_id: user.location_ids)
    end
  end
end