# Öffentlich: Standort ansehen und freie Tische suchen (kein Login nötig)
class LocationsController < ApplicationController
  def show
    @location = Location.find(params[:id])
    @search = ReservationSearch.new(location: @location, attributes: search_params)
    return unless params[:search].present?

    if @search.valid?
      @tables = @search.tables.to_a
      @alternatives = alternatives if @tables.empty?
    end
  end

  private

  def search_params
    params.fetch(:search, {}).permit(:date, :time, :party_size)
  end

  def alternatives
    ReservationSearch.alternatives_for(location: @location,
                                       starts_at: @search.starts_at,
                                       party_size: @search.party_size)
  end
end