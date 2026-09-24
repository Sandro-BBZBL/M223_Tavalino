# Übersetzt PaperTrail-Versionen von Reservationen in lesbare Feed-Einträge
# (Wer, Was, Änderungen). Alle nötigen Daten werden gesammelt geladen (kein N+1).
class ActivityFeed
  Entry = Struct.new(:id, :time, :actor, :action, :reservation_id, :reservation, :changes, keyword_init: true)

  # Nur Felder mit Label werden angezeigt. Technische Felder (id, ends_at, user_id ...) bleiben aussen vor.
  FIELD_LABELS = {
    "starts_at" => "Zeitpunkt",
    "duration_minutes" => "Dauer (Minuten)",
    "dining_table_id" => "Tisch",
    "party_size" => "Personenzahl",
    "guest_name" => "Name",
    "guest_email" => "E-Mail",
    "guest_phone" => "Telefon",
    "status" => "Status"
  }.freeze

  STATUS_LABELS = { "confirmed" => "bestätigt", "cancelled" => "storniert" }.freeze

  def initialize(versions)
    @versions = versions.to_a
  end

  def entries
    @entries ||= @versions.map { |version| build_entry(version) }
  end

  private

  def build_entry(version)
    changeset = changesets[version.id]

    Entry.new(
      id: version.id,
      time: version.created_at.in_time_zone,
      actor: actor_for(version),
      action: action_for(version, changeset),
      reservation_id: version.item_id,
      reservation: reservations[version.item_id],
      changes: change_lines(version, changeset)
    )
  end

  # Ohne Akteur = Gast (Gäste haben kein Konto)
  def actor_for(version)
    return "Gast" if version.whodunnit.blank?

    users[version.whodunnit.to_s]&.name || "Unbekannter Benutzer"
  end

  def action_for(version, changeset)
    case version.event
    when "create"
      version.whodunnit.present? ? "erfasst" : "gebucht"
    when "update"
      changeset["status"]&.last == "cancelled" ? "storniert" : "geändert"
    else
      version.event
    end
  end

  # Neu angelegt: "Label: Wert". Geändert: "Label: alt → neu".
  def change_lines(version, changeset)
    FIELD_LABELS.filter_map do |field, label|
      next unless changeset.key?(field)

      from, to = changeset[field]
      if version.event == "create"
        "#{label}: #{format_value(field, to)}" if to.present?
      else
        "#{label}: #{format_value(field, from)} → #{format_value(field, to)}"
      end
    end
  end

  def format_value(field, value)
    return "–" if value.blank?

    case field
    when "starts_at" then format_time(value)
    when "dining_table_id" then table_label(value)
    when "status" then STATUS_LABELS.fetch(value.to_s, value.to_s)
    else value.to_s
    end
  end

  def format_time(value)
    time = value.is_a?(String) ? Time.zone.parse(value) : value
    time ? time.in_time_zone.strftime("%d.%m.%Y, %H:%M") : value.to_s
  end

  def table_label(id)
    table = tables[id.to_i]
    table ? "#{table.location.name}, Tisch #{table.number}" : "Tisch ##{id}"
  end

  # --- gesammelt geladene Daten ---------------------------------------------------

  def changesets
    @changesets ||= @versions.to_h { |version| [ version.id, version.changeset || {} ] }
  end

  def users
    @users ||= User.where(id: @versions.filter_map { |version| version.whodunnit.presence })
                   .index_by { |user| user.id.to_s }
  end

  def reservations
    @reservations ||= Reservation.where(id: @versions.map(&:item_id).uniq).index_by(&:id)
  end

  def tables
    @tables ||= begin
      ids = changesets.values.flat_map { |changeset| Array(changeset["dining_table_id"]) }.compact.uniq
      DiningTable.where(id: ids).includes(:location).index_by(&:id)
    end
  end
end