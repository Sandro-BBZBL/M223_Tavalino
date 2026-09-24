class PagesController < ApplicationController
  def index
    @locations = Location.order(:name)
  end
end