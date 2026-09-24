# Aktivitäten-Feed: die neusten Änderungen an Reservationen (Mitarbeiter: eigene Standorte, Admin: alle)
class Staff::ActivitiesController < Staff::BaseController
  LIMIT = 100

  after_action :verify_policy_scoped

  def index
    authorize :activity, :index?

    versions = policy_scope(PaperTrail::Version, policy_scope_class: ActivityPolicy::Scope)
               .reorder(created_at: :desc, id: :desc)
               .limit(LIMIT)

    @limit = LIMIT
    @entries = ActivityFeed.new(versions).entries
  end
end