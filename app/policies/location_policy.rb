class LocationPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none if user.blank?
      return scope.all if user.admin?

      scope.where(id: user.location_ids)
    end
  end
end