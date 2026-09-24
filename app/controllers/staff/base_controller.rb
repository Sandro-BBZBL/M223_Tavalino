# Basis für alle Bereiche, die Mitarbeiter und Admins nutzen
class Staff::BaseController < ApplicationController
  before_action :authenticate_user!
  after_action :verify_authorized
end