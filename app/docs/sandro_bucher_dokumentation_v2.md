# Projektantrag: Tavolino-Tischreservation

**Modul:** 24-223-E Multi-User-Applikationen objektorientiert realisieren
**Datum:** 18.09.2026 (überarbeitet am 21.09.2026 nach Feedback)
**Autor:** Sandro Bucher
**Schulklasse:** 24 E

---

## 1. Problemstellung

Eine kleine Restaurant-Kette mit zwei Standorten und einer gemeinsamen Geschäftsleitung nimmt Tischreservationen aktuell ausschliesslich telefonisch entgegen. Die Mitarbeiter tragen die Reservationen anschliessend händisch in ein Reservationsbuch ein.

Dieses Vorgehen bringt für beide Seiten Nachteile:

- **Für das Restaurant:** Telefonate binden während der Stosszeiten Personal, das eigentlich für den Service benötigt wird. Übertragungsfehler beim händischen Eintragen (z. B. Zahlendreher bei Uhrzeit oder Personenzahl) können zu Doppelbelegungen oder falsch reservierten Tischgrössen führen. Zudem ist der Überblick über beide Standorte schwierig, da jedes Reservationsbuch separat geführt wird.
- **Für die Gäste:** Reservationen sind nur während der Öffnungszeiten des Restaurants (telefonisch) möglich. Es gibt keine sofortige, verlässliche Bestätigung, und bei zwei Gästen, die zur gleichen Zeit anrufen, entscheidet reiner Zufall bzw. das Geschick des Mitarbeiters am Telefon.

Aus **Kundensicht** (privater Kontext) ist die Problemstellung mir persönlich regelmässig begegnet: Es ist unpraktisch, ausserhalb der Geschäftszeiten keine Reservation vornehmen zu können, und es kam bereits vor, dass eine telefonisch zugesagte Reservation im Restaurant nicht auffindbar war, weil sie falsch übertragen wurde.

Eine digitale Multiuser-Applikation würde es Gästen ermöglichen, jederzeit online einen Tisch zu reservieren, während das Restaurant-Personal die Übersicht über beide Standorte zentral und fehlerfrei behält.

---

## 2. Projekt

### Domäne
Gastronomie / Tischreservation für eine Restaurant-Kette mit mehreren Standorten.

### Name der Applikation
**Tavolino-Tischreservation**

### Vision
Tavolino-Tischreservation ermöglicht Gästen, jederzeit online und ohne Benutzerkonto einen passenden Tisch an einem der Standorte zu reservieren – schnell, verlässlich und ohne Telefonanruf. Dem Restaurant-Personal verschafft die Applikation eine zentrale, fehlerfreie Übersicht über alle Reservationen an beiden Standorten und reduziert den Aufwand für die telefonische Reservationsannahme.

### Projektplanung: 1. MVP-Iteration
Die wichtigste domänenspezifische funktionale Anforderung der 1. Iteration ist:

> **Ein Gast kann für einen bestimmten Standort, ein Datum, eine Uhrzeit und eine Personenzahl einen passenden freien Tisch reservieren.**

Dafür benötigte Multiuser-Aspekte:
- Gleichzeitiger Zugriff mehrerer Gäste auf denselben Tischbestand (standort- und zeitbezogen)
- Überschneidungsfreie Vergabe: Prüfung auf Überschneidungen und Speichern der Reservation in **einer Transaktion**, damit nicht zwei Gäste denselben Tisch für sich überschneidende Zeiten erhalten
- Eindeutige, konsistente Bestätigung bzw. Ablehnung bei konkurrierenden Reservationsversuchen auf den letzten passenden freien Tisch
- **Optimistic Locking** bei gleichzeitiger Bearbeitung derselben Reservation durch mehrere Mitarbeiter (Locking-Anwendungsfall, siehe Abschnitt «Locking und Transaktionen»)
- Rollenbasierte Sicht: Mitarbeiter und Admin (mit Benutzerkonto) sehen und verwalten die Reservationen. Gäste benötigen kein Konto und verwalten ihre eigene Reservation über Reservationscode und E-Mail-Adresse.

---

## 3. Anforderungsanalyse

### Funktionale Anforderungen (priorisiert)

1. Als Gast (ohne Benutzerkonto) kann ich für einen Standort, ein Datum, eine Uhrzeit und eine Personenzahl einen freien, passend grossen Tisch reservieren.
2. Als Gast erhalte ich nach erfolgreicher Reservation eine sofortige, eindeutige Bestätigung mit allen Reservationsdetails und einem Reservationscode.
3. Als Mitarbeiter kann ich alle Reservationen meiner Standorte in einer Übersicht (z. B. nach Datum/Zeit) einsehen.
4. Als Gast kann ich meine Reservation mit Reservationscode und E-Mail-Adresse bis zu einer definierten Frist vor dem Termin stornieren.
5. Als Mitarbeiter kann ich eine Reservation manuell erfassen oder anpassen (z. B. bei telefonischen Ausnahmefällen). Ändert gleichzeitig eine andere Person dieselbe Reservation, wird der Konflikt erkannt und nichts still überschrieben.
6. Als Admin kann ich Tische (inkl. Kapazität) für beide Standorte verwalten (anlegen, bearbeiten, deaktivieren).
7. Als Gast werde ich bei einem nicht mehr verfügbaren Zeitslot mit einer verständlichen Meldung und einem Alternativvorschlag informiert.
8. Als Admin kann ich Mitarbeiter-Konten verwalten und Standorten zuordnen.

### Qualitätsattribute (nicht-funktional, priorisiert und überprüfbar)

1. **Datenkonsistenz:** Reservieren zwei Gäste gleichzeitig den letzten verfügbaren, passenden Tisch für denselben oder einen sich überschneidenden Zeitraum, wird genau eine Reservation bestätigt; die zweite Anfrage erhält innerhalb von 2 Sekunden eine Fehlermeldung mit Alternativvorschlag. Es entstehen nie zwei sich überschneidende, nicht stornierte Reservationen am selben Tisch.
2. **Performance:** Die Suche nach verfügbaren Tischen zeigt bei 500 erfassten Reservationen pro Standort und zehn gleichzeitigen Suchanfragen die Ergebnisse innerhalb von 2 Sekunden an.
3. **Konflikterkennung:** Speichert eine Person eine Reservation auf Basis eines veralteten Stands (weil eine andere Person sie inzwischen geändert hat), wird die Änderung abgelehnt, und die Person sieht eine verständliche Meldung mit dem aktuellen Stand. Es gehen keine Änderungen unbemerkt verloren.
4. **Nachvollziehbarkeit:** Jede Reservation, Stornierung und Änderung wird mit Zeitstempel und Akteur (Gast, Mitarbeiter oder Admin) protokolliert und ist für Mitarbeiter und Admin im Verlauf einsehbar.
5. **Sicherheit der Konten:** Passwörter der Mitarbeiter und Admins sind mindestens 12 Zeichen lang und werden ausschliesslich als Hash gespeichert. Die Anmeldung erlaubt keine Rückschlüsse darauf, ob eine E-Mail-Adresse existiert (keine Timing-basierte Enumeration). Reservationscodes sind nicht erratbar.

### Benutzerrollen

| Rolle | Berechtigungen |
|---|---|
| **Gast** (kein Konto) | Tische suchen und reservieren; die eigene Reservation mit Reservationscode und E-Mail-Adresse abrufen und stornieren |
| **Mitarbeiter** (Konto) | Reservationen der eigenen Standorte einsehen, manuell erfassen/anpassen/stornieren; eigenes Profil verwalten |
| **Admin** (Konto) | Alle Rechte des Mitarbeiters für beide Standorte, zusätzlich Verwaltung der Tische (Anlegen, Kapazität, Deaktivieren) und der Mitarbeiter-Konten (inkl. Standortzuweisung), Einsicht standortübergreifend |

**Konten für Mitarbeiter und Admin**

- Nur Mitarbeiter und Admins besitzen ein Benutzerkonto und melden sich mit E-Mail-Adresse und Passwort an. Gäste registrieren sich nie.
- Ein neu registriertes Konto hat die Rolle Mitarbeiter, ist aber keinem Standort zugeordnet und sieht deshalb keine Reservationen, bis ein Admin es einem Standort zuweist.
- Die Rolle Admin kann nur ein Admin vergeben. Der erste Admin wird bei der Einrichtung direkt in der Datenbank gesetzt.
- Mitarbeiter und Admins können ihr Profil (Name, Passwort) ändern. Eine neue E-Mail-Adresse wird erst nach Klick auf einen Bestätigungslink übernommen.

### Zusätzliche fachliche Regeln

- Die Tischgrösse (Kapazität) muss der angegebenen Personenzahl entsprechen bzw. diese abdecken.
- Eine Reservation hat eine Standarddauer (z. B. 2 Stunden); danach gilt der Tisch wieder als frei.
- Reservationen sind nur für Datum/Zeit in der Zukunft möglich.
- Stornierungen sind bis 2 Stunden vor dem reservierten Termin kostenlos möglich. Stornierte Reservationen blockieren den Tisch nicht mehr.
- Ein Tisch darf nicht doppelt belegt werden: Zwei nicht stornierte Reservationen am selben Tisch dürfen sich zeitlich nicht überschneiden (siehe nächster Abschnitt).
- Deaktivierte Tische können nicht neu reserviert werden.

### Locking und Transaktionen

#### Doppelbuchungen verhindern (Transaktion mit Überschneidungsprüfung)

Zwei Reservationen am selben Tisch überschneiden sich, wenn gilt:

> **Beginn A < Ende B  UND  Ende A > Beginn B**

Ein Unique-Index auf Tisch und Startzeit reicht dafür nicht aus, weil er nur exakt gleiche Startzeiten erkennt. Eine Reservation von 18:00 bis 20:00 Uhr und eine von 19:00 bis 21:00 Uhr am selben Tisch würden ihn beide passieren, obwohl sie sich überschneiden.

Beim Abschliessen einer Reservation läuft deshalb alles in **einer kurzen Datenbank-Transaktion**:

1. Der gewählte Tisch wird für die Dauer der Transaktion gesperrt (pessimistisch, nur Millisekunden). Parallele Buchungen auf denselben Tisch laufen dadurch nacheinander.
2. Es wird geprüft, ob eine nicht stornierte Reservation am Tisch die Überschneidungsbedingung erfüllt.
3. Ist der Zeitraum frei, wird die Reservation gespeichert und bestätigt. Sonst wird die Transaktion abgebrochen und der Gast erhält eine Fehlermeldung mit Alternativvorschlag (nächstliegende freie Zeit am selben Standort oder anderer Standort).

Es wird bewusst **keine Sperre über eine Benutzereingabe hinweg** gehalten. Der Gast wählt Tisch und Zeit, gibt seine Kontaktdaten ein und bucht. Ist der Zeitraum in der Zwischenzeit vergeben worden, erfährt er es beim Buchen.

#### Locking-Anwendungsfall: Optimistic Locking bei gleichzeitiger Bearbeitung

**Szenario:** Zwei Mitarbeiter (oder Mitarbeiter und Admin) öffnen dieselbe Reservation. Der eine ändert die Uhrzeit, der andere die Personenzahl. Ohne Schutz würde derjenige, der zuletzt speichert, die Änderung des anderen unbemerkt überschreiben («Last write wins»). Auch eine Stornierung durch einen Gast, während ein Mitarbeiter die Reservation bearbeitet, ist ein solcher Konflikt.

**Lösung:** Jede Reservation trägt eine Versionsnummer (`lock_version`). Beim Öffnen des Bearbeitungsformulars wird die aktuelle Version mitgeführt. Beim Speichern wird die Änderung nur übernommen, wenn die Version in der Datenbank noch dieselbe ist (`UPDATE ... WHERE lock_version = <erwartete Version>`), und die Version wird dabei erhöht.

- Stimmt die Version, wird die Änderung gespeichert.
- Stimmt sie nicht (jemand anderes war schneller), betrifft das Update keine Zeile. Die Änderung wird abgelehnt, und der Benutzer sieht die Meldung «Diese Reservation wurde inzwischen geändert» zusammen mit dem aktuellen Stand. Er kann danach bewusst erneut bearbeiten.

**Begründung:** Gleichzeitige Änderungen derselben Reservation sind selten. Optimistic Locking hält deshalb keine Sperre und braucht keinen Timer. Es passt zum zustandslosen Ablauf im Web, bei dem zwischen Öffnen und Speichern beliebig viel Zeit vergehen kann, und verhindert trotzdem sicher, dass Änderungen verloren gehen.

### ERM (Entity-Relationship-Model)

```mermaid
erDiagram
    STANDORT {
        int id PK
        string name UK
        string adresse
    }

    TISCH {
        int id PK
        int nummer
        int kapazitaet
        boolean aktiv
        int standort_id FK
    }

    BENUTZER {
        int id PK
        string name
        string email UK
        string passwort_digest
        string rolle "Mitarbeiter oder Admin"
        string unbestaetigte_email
        string bestaetigungs_token
        datetime bestaetigung_gesendet_am
    }

    BENUTZER_STANDORT {
        int benutzer_id FK
        int standort_id FK
    }

    RESERVATION {
        int id PK
        datetime beginn
        datetime ende
        int dauer_minuten
        int personenzahl
        string status "bestaetigt oder storniert"
        string gast_name
        string gast_email
        string gast_telefon
        string bestaetigungscode UK
        int lock_version
        datetime erstellt_am
        datetime geaendert_am
        int tisch_id FK
        int erfasst_von_benutzer_id FK "optional, nur bei manueller Erfassung"
    }

    STANDORT ||--|{ TISCH : "hat"
    TISCH ||--o{ RESERVATION : "wird reserviert in"
    BENUTZER |o--o{ RESERVATION : "erfasst manuell"
    BENUTZER ||--o{ BENUTZER_STANDORT : "zugeordnet"
    STANDORT ||--o{ BENUTZER_STANDORT : "zugewiesen"
```

**Wichtige Änderungen gegenüber dem ersten Entwurf**

- **Gäste sind keine Benutzer.** Sie haben kein Konto. Ihre Kontaktdaten (`gast_name`, `gast_email`, `gast_telefon`) und ein nicht erratbarer `bestaetigungscode` liegen direkt an der Reservation. Über Code und E-Mail-Adresse findet der Gast seine Reservation wieder.
- **`BENUTZER`** enthält nur Mitarbeiter und Admins (Rolle `Mitarbeiter` oder `Admin`). Statt `kontaktdaten` gibt es `email` und `passwort_digest` (Hash). Die drei `unbestaetigte_email`-/Token-Felder dienen der Bestätigung einer geänderten E-Mail-Adresse.
- **`RESERVATION`** hat `beginn` und `ende` statt `datum` und `uhrzeit`, damit die Überschneidungsprüfung mit zwei Zeitpunkten einfach und korrekt ist. `lock_version` ermöglicht das Optimistic Locking. Der Status kennt nur `bestaetigt` und `storniert`. Die Felder `erstellt_am` und `geaendert_am` ersetzen den bisherigen `zeitstempel`.
- **`TISCH`** hat das Feld `aktiv`, damit der Admin Tische deaktivieren kann.
- **`erfasst_von_benutzer_id`** ist nur gesetzt, wenn ein Mitarbeiter die Reservation manuell erfasst hat.

**Umsetzung in Rails (Namen im Code)**

| Fachbegriff | Rails-Modell / Attribut |
|---|---|
| Standort | `Location` |
| Tisch | `DiningTable` |
| Benutzer | `User` |
| Benutzer-Standort | `UserLocation` |
| Reservation | `Reservation` |
| beginn / ende | `starts_at` / `ends_at` |
| gast_name / gast_email / gast_telefon | `guest_name` / `guest_email` / `guest_phone` |
| bestaetigungscode | `confirmation_code` |
| erfasst_von_benutzer_id | `user_id` (optional) |

### Breadboards aller User-Flows der 1. Iteration

**1. Gast reserviert einen Tisch**
```mermaid
flowchart TD
    A["[Standortwahl]"] -->|Standort wählen| B["[Suchmaske]"]
    B -->|Datum, Uhrzeit & Personenzahl| C["[Ergebnisliste Tische]"]
    C -->|Freien Tisch wählen| D["[Reservierungsformular]"]
    D -->|Kontaktdaten eingeben & Buchen| E["[Bestätigungsseite mit Reservationscode]"]
    D -.->|Zeitraum inzwischen vergeben| F["[Fehlermeldung mit Alternativvorschlag]"]
    F -->|Alternative wählen| C
```

**2. Gast storniert eine Reservation**
```mermaid
flowchart TD
    A["[Reservation abrufen]"] -->|Code & E-Mail eingeben| B["[Detailansicht]"]
    A -.->|Angaben passen nicht| E["[Fehler: keine Reservation gefunden]"]
    B -->|Stornieren klicken| C{"Frist prüfen"}
    C -->|> 2h Restzeit| D["[Stornierungsbestätigung]"]
    C -.->|< 2h Restzeit| F["[Fehler: Frist abgelaufen]"]
```

**3. Mitarbeiter verwaltet Reservationen**
```mermaid
flowchart TD
    A["[Mitarbeiter-Dashboard]"] -->|Filter nach Standort/Datum| B["[Reservationsübersicht]"]
    B -->|Reservation auswählen| C["[Detail / Bearbeiten]"]
    C -->|Ändern / Stornieren / Manuell erfassen| B
    C -.->|Konflikt: inzwischen von anderem geändert| D["[Hinweis mit aktuellem Stand]"]
    D -->|Erneut bearbeiten| C
```

**4. Admin verwaltet Tische**
```mermaid
flowchart TD
    A["[Admin-Dashboard]"] -->|Standort wählen| B["[Tischverwaltung]"]
    B -->|Tisch anlegen / bearbeiten| C["[Tisch-Formular]"]
    C -->|Speichern / Kapazität ändern| B
```

Abzubildende User-Flows:

1. **Gast reserviert einen Tisch:** Standort wählen → Datum/Uhrzeit/Personenzahl eingeben → passenden freien Tisch auswählen → Kontaktdaten eingeben → Reservation abschliessen → Bestätigung mit Reservationscode erhalten. Ist der Zeitraum inzwischen vergeben, erscheint eine Fehlermeldung mit Alternativvorschlag.
2. **Gast storniert eine Reservation:** Code und E-Mail-Adresse eingeben → Reservation ansehen → Stornierung bestätigen (nur falls Frist eingehalten)
3. **Mitarbeiter verwaltet Reservationen:** Übersicht Standort öffnen → Reservation auswählen → manuell anpassen/stornieren. Bei gleichzeitiger Änderung durch eine andere Person erscheint ein Konflikt-Hinweis mit dem aktuellen Stand.
4. **Admin verwaltet Tische:** Standort wählen → Tisch anlegen/bearbeiten (Nummer, Kapazität) → Speichern

### Fat-Marker-Sketches (Screens) der 1. Iteration


Abzubildende Screens:

1. Startseite / Standortwahl (öffentlich, ohne Anmeldung)
2. Suchmaske (Datum, Uhrzeit, Personenzahl)
3. Ergebnisliste verfügbarer Tische
4. Reservationsformular (Kontaktdaten des Gastes) inkl. Fehlermeldung mit Alternativvorschlag, falls der Zeitraum inzwischen vergeben ist
5. Bestätigungsseite mit Reservationscode
6. «Reservation abrufen» (Code und E-Mail-Adresse) mit Detailansicht und Stornierung (Gast)
7. Mitarbeiter-Dashboard: Reservationsübersicht Standort, inkl. Bearbeitungsansicht mit Konflikt-Hinweis
8. Admin-Ansicht: Tischverwaltung (inkl. Kapazität) je Standort

---

## 4. Änderungen nach dem Feedback (21.09.2026)

| Feedback | Anpassung |
|---|---|
| Eine DB-Sperre über fünf Minuten ist ungeeignet, anderen Anwendungsfall wählen. | Die 5-Minuten-Sperre ist entfernt. Locking-Anwendungsfall ist neu **Optimistic Locking** bei gleichzeitiger Bearbeitung einer Reservation durch mehrere Mitarbeiter. Der Gast-Ablauf hält keine Sperre mehr. |
| Überschneidungen berücksichtigen, ein Unique-Index auf Tisch und Startzeit reicht nicht. | Doppelbuchungen werden durch eine **Überschneidungsprüfung** (Beginn A < Ende B und Ende A > Beginn B) innerhalb einer kurzen Transaktion verhindert. Stornierte Reservationen zählen nicht. |
| Umfang: OK. | Der Umfang bleibt gleich. Gäste reservieren ohne Konto, und die Konten der Mitarbeiter und Admins folgen den Kursvorgaben (Authentifizierung, Profil, Benutzerverwaltung). |
