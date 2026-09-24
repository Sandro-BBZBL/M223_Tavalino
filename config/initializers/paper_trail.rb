# Aktivitätsprotokoll: Änderungen werden als JSON gespeichert.
# (Die Standard-Serialisierung YAML macht mit Zeitwerten unter neuem Ruby/Psych Probleme.)
PaperTrail.serializer = PaperTrail::Serializers::JSON