class ReservationPolicy < ApplicationPolicy
  # Die Übersicht dürfen alle Angemeldeten öffnen. Was sie darin sehen,
  # bestimmt der Scope (Mitarbeiter ohne Standort sehen nichts).
  def index?
    user.present?
  end

  def show?
    manages_location?
  end

  # edit? läuft über update? (siehe ApplicationPolicy)
  def update?
    manages_location?
  end

  # Stornieren durch Mitarbeiter/Admins (ohne 2-Stunden-Frist der Gäste)
  def cancel?
    manages_location?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?
      return scope.all if user.admin?

      scope.joins(:dining_table).where(dining_tables: { location_id: user.location_ids })
    end
  end

  private

  # Admins dürfen alle Standorte, Mitarbeiter nur die ihnen zugewiesenen
  def manages_location?
    return false if user.blank?

    user.admin? || user.location_ids.include?(record.dining_table.location_id)
  end
end