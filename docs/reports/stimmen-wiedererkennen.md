# Prüfbericht Stimmen wiedererkennen

## `STIM-01`

Durchlauf 1 und 2 vom 27.11.2026, geprüft gegen `docs/specs/stimmen-wiedererkennen.md`, Prüfer Anforderungen und Rechte (Durchlauf 1), Rechte und Datenablage (Durchlauf 2, nur das Geänderte). Ergebnisse unverändert von den Prüfern. Geprüft wurde mit den Prüfläufen der App und Wegwerfdateien, nie mit den echten Daten. Klicks in der Oberfläche waren in dieser Umgebung nicht möglich.

**Bestanden.** AK01, AK03, AK05, AK11, AK15, AK16, RF01, RF02, RF03, RF04, RF06. Nach Durchlauf 2 zusätzlich AK08 («Vergessen») und der Schutz der Ablage aus AK12.

## Nicht bestanden

| Spec-ID | Schritte zum Nachstellen | Erwartet | Tatsächlich | Schweregrad |
|---|---|---|---|---|
| AK08 (N1) | Meeting A auswerten, Person 1 als «Anna» mit Haken benennen, Meeting B auswerten, «Anna» vergessen, Datei entschlüsseln | Kein Abdruck dieser Person mehr gespeichert | Stimme weg, ihre Abdrücke standen weiter am Meeting | Wichtig, in Durchlauf 2 behoben |
| AK12 (N2a) | Während eines Speichervorgangs die Datei laufend abfragen | Nie ohne Rechte 600 oder ohne Backup-Ausnahme | Kurz 644 ohne Ausnahme, dann 600 ohne Ausnahme | Wichtig, in Durchlauf 2 behoben |
| AK12 (N2b) | Datei mit einem fremden Programm entschlüsseln | Schutz auf der Datenebene trennt Benutzerkonten | Der Schlüssel entsteht aus der Hardware-Kennung und ist für jedes Konto dieses Macs derselbe. Es hält nur der Ordner (`~/Library` mit 700) und die Datei mit 600 | Wichtig, offen |

Durchlauf 2 zu N1: Stimme und alle ihre Abdrücke weg, auch bei 25 Meetings und nach einer mit «Ja» beantworteten Frage; die Abdrücke anderer Personen bleiben. Zu N2a: 0 Dateien mit Inhalt ohne Rechte 600 oder ohne Backup-Ausnahme über 1610 Speichervorgänge. Nach dem Speichern bleibt keine vorübergehende Datei zurück, ein Rest nach einem Absturz wird beim nächsten Start entfernt.

**Nicht prüfbar.**
- AK04, AK09, AK13, AK17, RF05 ganz: Kein Prüflauf kann den Haken entfernen, den Schalter umlegen, ein Meeting löschen oder ein altes Meeting benennen. «Diktat-Daten löschen» hätte die echten Daten gelöscht. Die Logik dahinter ist durch die automatischen Tests abgedeckt, nicht durch einen Lauf in der App.
- AK02, AK06, AK07, AK14, RF07 teilweise: Der geprüfte Teil ist in Ordnung. Offen sind die Wirkung von «Ja» und «Nein» per Klick, ob die Zusammenfassung beim Umbenennen mitzieht, Zeitablauf und Update, der Abbruch einer Auswertung.
- Rückfragetexte und Knöpfe im Fenster, der Schalter «aus» in der App.
- Zugriff durch ein anderes Benutzerkonto (kein zweites Konto), ein echtes Backup (hätte den echten Mac gesichert), der Wortlaut der Anfrage an das Sprachmodell (läuft im Prozess).

**Tests.** `xcodegen generate && xcodebuild … test`. Durchlauf 1: 296 gelaufen, 0 fehlgeschlagen. Durchlauf 2: 297 gelaufen, 0 fehlgeschlagen. Build erfolgreich. 23 Tests gehören zu STIM-01.

**Rechte.**
- Eigenes Benutzerkonto: Erlaubtes geht ja (nach Durchlauf 2).
- Anderes Benutzerkonto auf demselben Mac: nicht prüfbar. Indirekt belegt durch Rechte 600 ohne Zugriffsliste. Siehe N2b.
- Backup des Macs: Verbotenes verweigert ja (nach Durchlauf 2). Belegt ist die Markierung an der Datei, kein echtes Backup.
- Sprachmodell oder Modell-Anbieter: Verbotenes verweigert ja, mittelbar belegt (Transkript und Zusammenfassung enthalten Namen, keine Zahlenreihe).
- Empfänger von kopiertem oder geteiltem Text: Verbotenes verweigert ja.
- Logs: sauber, weder Namen noch Transkript noch Abdrücke.

**Auffälligkeiten.**
- Falscher Name ohne Nachfrage: Eine Computerstimme (Reed) wurde als eine andere, bekannte (Eddy) mit «erkannt» eingetragen, Ähnlichkeit 0.92 bei einer Grenze von 0.75. Nur mit Computerstimmen derselben Familie gesehen. Die Grenzen sind nicht an echten Meetings eingestellt.
- Nach «Vergessen» bleibt ein Abdruck am Meeting, wenn die Person dort nur dem Namen nach Anna ist: benannt ohne Haken, oder Frage mit «Ja» beantwortet bei ausgeschaltetem Schalter.
- Eine beiseitegelegte unlesbare Datei behält die Rechte ihrer Ursprungsdatei. Von der App geschrieben sind das 600 mit Backup-Ausnahme.
- Eine Ablage, die mit dem alten, im Code stehenden Schlüssel versiegelt ist, nimmt die App an. Braucht Schreibzugriff im eigenen Konto.
- «Neu in Diktat»: Der Eintrag «Meetings: zwei Quellen» wurde entfernt, das verlangt die Spec nicht. Die Seite heisst «Neu in Diktat 0.1.17», bis die Version der App angehoben ist.
- Der Prüflauf `-DiktatMeetingCheck` legt die Tondatei vorübergehend im echten Ordner der Meetings ab und räumt am Ende auf (schon vor diesem Feature so).
- Keine gelöschten oder abgeschwächten Tests, keine Änderung an Lockfiles, CI, Build-Skripten oder Regeldateien.

**Für die Projektleitung.** Der Freigabe im Weg stehen drei Dinge. Erstens ein Durchlauf von Hand in der App für das, was sich nicht klicken liess (Haken entfernen, Schalter, Meeting löschen, «Ja» und «Nein», Rückfragen). Zweitens Probeläufe mit echten Meetings, um die Grenze für «sicher» einzustellen. Drittens der Entscheid zum Schlüssel der Ablage (N2b): Heute trennen nur die Rechte von Ordner und Datei die Benutzerkonten, nicht die Verschlüsselung.
