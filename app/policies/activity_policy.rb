# Aktivitäten-Feed (PaperTrail-Versionen von Reservationen).
# Kopflose Policy: authorize :activity, :index?
class ActivityPolicy < ApplicationPolicy
  def index?
    user.present?
  end

  # Wer welche Einträge sieht, hängt an den Reservationen: Der Scope baut auf
  # ReservationPolicy::Scope auf, damit die Standortlogik nur an einer Stelle steht.
  class Scope < ApplicationPolicy::Scope
    def resolve
      visible_reservation_ids = ReservationPolicy::Scope.new(user, Reservation).resolve.select(:id)

      scope.where(item_type: "Reservation", item_id: visible_reservation_ids)
    end
  end
end