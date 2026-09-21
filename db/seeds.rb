# Idempotent: kann beliebig oft mit `bin/rails db:seed` ausgeführt werden.

# --- Standorte (Namen/Adressen sind Platzhalter, bei Bedarf anpassen) ---------
locations = {
  "Tavolino Zürich" => "Bahnhofstrasse 1, 8001 Zürich",
  "Tavolino Luzern" => "Pilatusstrasse 5, 6003 Luzern"
}.map do |name, address|
  Location.find_or_create_by!(name: name) { |location| location.address = address }
end

# --- Tische: je Standort 6 Tische mit unterschiedlicher Kapazität -------------
locations.each do |location|
  [ 2, 2, 4, 4, 6, 8 ].each_with_index do |capacity, index|
    location.dining_tables.find_or_create_by!(number: index + 1) do |table|
      table.capacity = capacity
    end
  end
end

# --- Demo-Konten (nur Entwicklung) --------------------------------------------
# Der erste Admin wird laut Projektantrag bei der Einrichtung direkt gesetzt.
if Rails.env.development?
  admin = User.find_or_create_by!(email_address: "admin@tavolino.test") do |user|
    user.name = "Admin Demo"
    user.password = "admin-passwort-1234"
    user.role = :admin
  end

  staff = User.find_or_create_by!(email_address: "staff@tavolino.test") do |user|
    user.name = "Mitarbeiter Demo"
    user.password = "staff-passwort-1234"
    user.role = :staff
  end
  staff.locations << locations.first unless staff.locations.include?(locations.first)

  puts "Demo-Login Admin:       #{admin.email_address} / admin-passwort-1234"
  puts "Demo-Login Mitarbeiter: #{staff.email_address} / staff-passwort-1234 (Standort: #{locations.first.name})"
end