# Tavolino-Tischreservation

Eine Rails-Applikation, mit der Gäste ohne Benutzerkonto online einen Tisch
reservieren können, und mit der Mitarbeiter und Admins einer Restaurant-Kette
mit mehreren Standorten die Reservationen verwalten.

Details zur Problemstellung, den Anforderungen und den Architekturentscheiden
(Überschneidungsprüfung, Optimistic Locking) stehen im Projektantrag unter
[`docs/sandro_bucher_dokumentation_v2.md`](docs/sandro_bucher_dokumentation_v2.md).
Der Nachweis der Tests steht unter [`docs/testing.md`](docs/testing.md).

## Setup

Voraussetzung: Ruby gemäss `.ruby-version` (aktuell 4.0.6).

```
bundle install
bin/rails db:setup   # legt die Datenbank an, führt Migrationen aus und lädt db/seeds.rb
bin/rails server
```

Die Applikation läuft danach unter `http://localhost:3000`.

Nach dem ersten Setup, oder wenn du die Datenbank zurücksetzen willst:

```
bin/rails db:reset
```

## Demo-Logins

`db/seeds.rb` legt beim Ausführen von `db:setup`/`db:seed` folgende Konten an:

| Rolle | E-Mail | Passwort |
|---|---|---|
| Admin | `admin@tavolino.test` | `admin-passwort-1234` |
| Mitarbeiter (Standort Zürich) | `staff@tavolino.test` | `staff-passwort-1234` |

Diese Zugangsdaten sind nur für die Entwicklungsumgebung gedacht.

## Rollen

| Rolle | Kann |
|---|---|
| **Gast** (kein Konto) | Tische suchen und reservieren, eigene Reservation mit Reservationscode + E-Mail abrufen und stornieren (bis 2 Stunden vor dem Termin) |
| **Mitarbeiter** | Reservationen der eigenen Standorte einsehen, bearbeiten, stornieren und manuell erfassen; Aktivitäten der eigenen Standorte einsehen |
| **Admin** | Alles, was Mitarbeiter können, für alle Standorte; zusätzlich Tische verwalten (anlegen, Kapazität ändern, deaktivieren) und Benutzerkonten verwalten (Rolle, Standortzuweisung) |

Ein neu registriertes Konto hat die Rolle Mitarbeiter, ist aber noch keinem
Standort zugewiesen und sieht deshalb keine Reservationen, bis ein Admin es
einem Standort zuordnet (unter „Benutzer“ im Admin-Bereich).

## Tests ausführen

```
bin/rails test
```

Der vollständige Nachweis, welche Anforderungen wie geprüft wurden, steht in
[`docs/testing.md`](docs/testing.md).

## Technische Hinweise

- **Datenbank:** SQLite (`storage/`). In der Entwicklungsumgebung reicht das;
  für einen produktiven Mehrbenutzerbetrieb mit hoher Last würde sich
  PostgreSQL eher eignen (siehe Hinweis zu `lock!` in `docs/testing.md`).
- **E-Mail:** In der Entwicklungsumgebung werden keine echten Mails
  verschickt (`delivery_method = :test`). Bestätigungsmails erscheinen im
  Log (`log/development.log`) und als Vorschau unter
  `http://localhost:3000/rails/mailers`.
- **Zeitzone:** Europe/Zurich (Bern).
- **Aktivitätsprotokoll:** Änderungen an Reservationen werden mit
  [PaperTrail](https://github.com/paper-trail-gem/paper_trail) protokolliert
  und sind für Mitarbeiter/Admins unter „Aktivitäten“ einsehbar. Der
  Reservationscode wird bewusst nicht protokolliert.