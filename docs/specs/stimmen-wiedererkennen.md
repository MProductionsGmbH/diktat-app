# Stimmen wiedererkennen (`STIM-01`)

Stand: von der Projektleitung am 27.11.2026 freigegeben. Prüfbericht: `docs/reports/stimmen-wiedererkennen.md`.

**Wer und warum.** Wer regelmässig mit denselben Personen Meetings aufzeichnet, benennt heute in jedem Meeting «Person 1», «Person 2» von Hand neu. Diktat soll sich die Stimme einer benannten Person merken und sie in späteren Meetings selbst mit Namen versehen.

**Rollen.** Diktat hat einen Nutzer pro Mac-Benutzerkonto, keine Rollen. Die Funktion ist für alle da, die Meetings aufzeichnen, und standardmässig eingeschaltet. Andere Benutzerkonten, andere Geräte und Sprachmodelle bekommen keine Stimmabdrücke.

## Kriterien

| ID | Ausgangslage | Handlung | Erwartetes Ergebnis |
|---|---|---|---|
| STIM-01-AK01 | Neu installiert oder aktualisiert | Einstellungen > Meetings > «Sprecher-Erkennung» öffnen | Schalter «Stimmen wiedererkennen» ist an. Darunter steht: «Diktat merkt sich die Stimme von Personen, die du benennst, und erkennt sie in späteren Meetings wieder. Die Stimmabdrücke bleiben verschlüsselt auf diesem Mac, bis du sie löschst. Bitte frag die Personen vorher.» |
| STIM-01-AK02 | Schalter aus | Ein Meeting aufzeichnen und auswerten | Es wird kein neuer Stimmabdruck gespeichert und niemand erkannt. Vorhandene Stimmabdrücke bleiben unverändert. |
| STIM-01-AK03 | Schalter an, Meeting ausgewertet, «Person 2» unbekannt | «Person 2» in «Anna» umbenennen, Haken «Stimme für künftige Meetings merken» ist gesetzt | «Anna» steht unter Einstellungen > Meetings > «Bekannte Stimmen». |
| STIM-01-AK04 | Wie AK03 | Den Haken vor dem Sichern entfernen | Der Name gilt nur in diesem Meeting. Unter «Bekannte Stimmen» kommt nichts dazu. |
| STIM-01-AK05 | «Anna» ist bekannt | Ein neues Meeting mit Anna auswerten, die Übereinstimmung ist sicher | Im Transkript, in der Zusammenfassung und beim Kopieren steht «Anna» statt «Person N». Neben dem Namen steht das Kennzeichen «erkannt». |
| STIM-01-AK06 | «Anna» ist bekannt | Ein neues Meeting auswerten, die Übereinstimmung ist unsicher | Die Person bleibt «Person N». Diktat fragt «Ist das Anna?» mit «Ja» und «Nein». «Ja» setzt den Namen, «Nein» lässt «Person N» und fragt in diesem Meeting nicht mehr. |
| STIM-01-AK07 | Diktat hat eine Person als «Anna» erkannt, es ist aber Bea | Die Person in «Bea» umbenennen | Im Meeting steht überall «Bea». Annas gemerkte Stimme enthält nichts aus diesem Meeting. |
| STIM-01-AK08 | Mindestens eine bekannte Stimme, Schalter an oder aus | «Bekannte Stimmen» öffnen | Pro Person: Name, Anzahl Meetings, zuletzt gehört. Umbenennen und «Vergessen» sind möglich. «Vergessen» fragt «Die Stimme von „Anna“ vergessen?» mit dem Zusatz «Die Namen in bisherigen Meetings bleiben.» Danach wird Anna in neuen Meetings nicht mehr erkannt. |
| STIM-01-AK09 | Schalter an, Stimmabdrücke vorhanden | Schalter ausschalten, später wieder einschalten | Ausschalten löscht nichts und fragt nicht nach. Nach dem Einschalten werden die bekannten Stimmen wieder erkannt. |
| STIM-01-AK10 | entfallen | entfallen | entfallen (Ablauf nach 30 Tagen, von der Projektleitung gestrichen) |
| STIM-01-AK11 | Online-Meeting, der Nutzer ist «Ich» | Auswerten | «Ich» bleibt «Ich», wird mit keiner bekannten Stimme verglichen und nicht gelernt. |
| STIM-01-AK12 | Verbotsfall: Stimmabdrücke vorhanden | Meeting kopieren, teilen, zusammenfassen (auch mit Modell-Anbieter), Mac sichern, als anderes Benutzerkonto anmelden | Kein Stimmabdruck steckt im kopierten oder geteilten Text, in der Anfrage an ein Sprachmodell oder im Backup. Ein anderes Benutzerkonto kann ihn nicht lesen. |
| STIM-01-AK13 | Stimmabdrücke vorhanden | «Diktat-Daten löschen» ausführen | Alle Stimmabdrücke sind entfernt. |
| STIM-01-AK14 | Stimmabdrücke vorhanden, keine Handlung des Nutzers | Zeit vergeht, Diktat wird beendet, gestartet, aktualisiert | Kein Stimmabdruck wird von selbst gelöscht, weder der einer bekannten Stimme noch der einer unbenannten Person. |
| STIM-01-AK15 | Stimmabdrücke vorhanden, Schalter an oder aus | Unter «Bekannte Stimmen» «Alle Stimmabdrücke löschen» wählen | Rückfrage «Alle Stimmabdrücke löschen?» mit «Diktat vergisst alle bekannten Stimmen und die Stimmabdrücke aus bisherigen Meetings. Die Namen in den Meetings bleiben.» Nach «Löschen» ist kein Stimmabdruck mehr gespeichert. Der Schalter bleibt, wie er ist. |
| STIM-01-AK16 | Aktualisiert auf die Version mit dieser Funktion | Diktat öffnen | «Neu in Diktat» nennt die Funktion, sagt, dass sie eingeschaltet ist, und wo sie sich ausschalten lässt (Einstellungen > Meetings). |
| STIM-01-AK17 | Meeting mit unbenannten Personen | Das Meeting löschen | Die Stimmabdrücke der unbenannten Personen dieses Meetings sind mit gelöscht. Bekannte Stimmen bleiben. |

## Randfälle

| ID | Situation | Erwartetes Verhalten |
|---|---|---|
| STIM-01-RF01 | Zwei bekannte Stimmen passen ähnlich gut auf eine Person | Keine automatische Zuordnung. Diktat fragt nach der besser passenden. |
| STIM-01-RF02 | Eine bekannte Stimme passt auf zwei Personen desselben Meetings | Nur die besser passende bekommt den Namen, die andere bleibt «Person N». |
| STIM-01-RF03 | Eine Person spricht insgesamt weniger als 10 Sekunden | Sie wird weder erkannt noch gelernt. Der Haken wird nicht angeboten. |
| STIM-01-RF04 | Eine Person wird «Anna» genannt, «Anna» ist schon bekannt | Die Stimme kommt zur bestehenden Anna dazu. Es entsteht keine zweite Anna. |
| STIM-01-RF05 | Meeting von vor dem Update, oder aufgezeichnet bei ausgeschaltetem Schalter | Benennen wie bisher, ohne Haken. Es wird nichts nachträglich gelernt. |
| STIM-01-RF06 | Gespeicherte Stimmabdrücke sind nicht lesbar | Die Auswertung läuft durch, alle bleiben «Person N», nichts blockiert. |
| STIM-01-RF07 | Auswertung schlägt fehl oder wird abgebrochen | Es wird nichts gelernt und nichts gespeichert. |

## Daten und Rechte

**Daten.** Neu sind zwei Dinge. «Bekannte Stimme»: Name, Stimmabdruck, Anzahl Meetings, zuletzt gehört. «Stimmabdruck am Meeting»: einer pro Person eines neuen Meetings, auch für unbenannte, damit späteres Benennen etwas lernen kann. Beide bleiben, bis der Nutzer sie von Hand löscht: einzeln mit «Vergessen», alle mit «Alle Stimmabdrücke löschen», mit dem Meeting oder mit «Diktat-Daten löschen». Ein Stimmabdruck ist eine Zahlenreihe, keine Tonaufnahme. Die Aufnahme wird wie bisher nach der Auswertung gelöscht.

**Rechte.** Nur das eigene Benutzerkonto auf diesem Mac. Durchgesetzt auf der Datenebene: Ablage im eigenen Bereich von Diktat, verschlüsselt mit dem gerätegebundenen Schlüssel wie die Meetings, vom Backup ausgenommen, kein Abgleich mit anderen Geräten.

**Abhängigkeiten und Dienste.** Keine neuen. Die vorhandene Bibliothek für die Sprecher-Erkennung (FluidAudio 0.17.4, Apache 2.0, Stand vom 24.09.2026) liefert den Stimmabdruck pro Person im selben Durchgang. Keine externen Dienste, keine Kosten.

**Nur die Projektleitung.** Rechtliche Prüfung vor einem Verkauf: Stimmabdrücke sind biometrische Daten (nDSG, DSGVO). Mit «standardmässig an» und ohne Ablauf speichert jeder Nutzer von Diktat Stimmabdrücke Dritter, ohne es gewählt zu haben. Das gehört ausdrücklich in diese Prüfung. Dazu Probeläufe mit echten Meetings und Einwilligung der Beteiligten, um festzulegen, ab wann eine Übereinstimmung «sicher» ist.

**Nicht dabei.** Erkennen schon während der laufenden Aufnahme. Audiodateien. Nachträgliches Lernen aus alten Meetings. Export, Import oder Abgleich von Stimmen. iOS. Lernen der eigenen Stimme aus dem Mikrofon eines Online-Meetings.

**Entscheide der Projektleitung (27.11.2026).**
- Standard ist «an».
- Stimmabdrücke bleiben, bis der Nutzer sie von Hand löscht. Nichts läuft von selbst ab.
- Ausschalten löscht nichts.

**Annahmen und offene Fragen.**
- Wer ein Meeting löscht, löscht damit die Stimmabdrücke seiner unbenannten Personen (Annahme, AK17). Sie liessen sich sonst nie mehr einer Person zuordnen.
- Weil die Funktion an ist, weist «Neu in Diktat» einmal darauf hin (Annahme, AK16).
- Die eigene Stimme lernt Diktat wie jede andere, wenn sich der Nutzer in einem Meeting «Im Raum» einmal selbst benennt (Annahme).
- Die Grenzen für «sicher» und «unsicher» legt die Spec nicht als Zahl fest. Sie werden an echten Aufnahmen bestimmt, mit dem Ziel: lieber nachfragen als ein falscher Name.
- Der Datenschutztext wird ergänzt.

**Referenzen.** Ankündigung MacWhisper 16 vom 27.11.2026 (Wiedererkennen über mehrere Transkripte) als Vorbild für den Ablauf.
