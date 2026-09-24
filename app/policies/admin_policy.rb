# Kopflose Policy für den ganzen Admin-Bereich: authorize :admin, :access?
class AdminPolicy < ApplicationPolicy
  def access?
    user&.admin?
  end
end