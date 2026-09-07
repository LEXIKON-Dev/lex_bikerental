# FiveM Fahrradverleih

## Installation

1. Den Ordner `lex_bikerental` nach `resources/` kopieren.
2. OneSync aktivieren. Als einzige zusätzliche Ressource wird ESX Legacy (`es_extended`) benötigt.
3. Danach in `server.cfg` eintragen:

```cfg
ensure es_extended
ensure figma_bikerental
```

4. In `config.lua` den Standort und den freien Fahrrad-Ausgabepunkt anpassen.
   Der enthaltene Standort ist ein Beispiel am Flughafen LSIA und muss vor Ort geprüft werden.

```lua
coords = vector3(-1034.60, -2733.60, 20.17), -- Hier E drücken
spawn = vector4(-1030.80, -2731.00, 20.17, 240.0), -- x, y, z, Heading
```

## Bedienung

- Im grünen Marker zu Fuß **E** drücken: Menü öffnen. Die native GTA-Hilfemeldung erscheint nur innerhalb des sichtbaren Kreises und verschwindet beim Verlassen. Dafür ist kein zusätzliches HelpNotify-Script nötig.
- **RENT**: Geld abbuchen und das gewählte Fahrrad ausgeben.
- **ESC**: Menü schließen und Mausfokus freigeben. Es gibt keinen Schließen-Button.
- Mit dem Mietfahrrad zum Marker zurückkehren und **G** drücken: Rückgabe.
- Ein aktives Fahrrad pro Spieler. Rückgabe erstattet den Mietpreis nicht.
- Mietfahrräder werden beim Disconnect oder Ressourcenstopp entfernt.

`Config.MarkerRadius = 0.5` legt sowohl den sichtbaren Radius als auch den
Bereich für HelpNotify und E/G fest. Die Höhenprüfung verhindert eine Interaktion
von einem anderen Stockwerk (`Config.MarkerZTolerance`).

## Preise und Framework

Die Preise stehen ausschließlich in `Config.Bikes` und werden beim Öffnen ins UI übernommen:
BMX $10, SCORCHER $20, Tribike $25, Cruiser $5. Der Betrag wird einmal pro Ausleihe fällig.

ESX wird für die Zahlung und Spielmeldungen über `ESX.ShowNotification` verwendet.
Die vorhandene ESX-Notify-Integration wird genutzt. Falls sie fehlt oder einen Fehler
meldet, erscheint stattdessen eine native GTA-Meldung. `esx_notify` ist deshalb
keine feste Abhängigkeit dieser Ressource. Neuere ESX-Versionen benötigen es jedoch,
um ihre ESX-Notify-Oberfläche statt des GTA-Fallbacks anzuzeigen.
Die Marker-Hilfe bleibt die native GTA-Hilfemeldung.
Es gibt keine zusätzliche feste Notify-, HelpNotify-, Target- oder UI-Abhängigkeit.
OneSync ist eine eingebaute FiveM-Funktion für die serverseitige Fahrzeugausgabe.
Die eigenen Abhängigkeiten deiner vorhandenen ESX-Installation bleiben erforderlich.
Alle Bilder und Schriftarten liegen lokal bei; kein CDN, npm oder Build ist nötig.
`Config.PaymentAccount = 'cash'` nutzt Bargeld; `'bank'` nutzt das Bankkonto.
Ohne unterstütztes Framework wird die Ausleihe mit einer Fehlermeldung abgelehnt.
Bei anderen Economy- oder Inventory-Systemen muss `account()` in `server.lua` angepasst werden.

Standort, erlaubtes Modell, Preis, Geldbestand, Routing Bucket, belegter Ausgabepunkt
und bestehende Ausleihe werden auf dem Server geprüft. Client-Preise werden nicht angenommen.
Erst nach erfolgreicher Fahrzeugerstellung wird abgebucht.

## UI

Die Menüposition folgt Figma-Node `17:64`: Die erste Fahrradkarte beginnt bei
x = 51, y = 166 auf einer 1918 × 1077 großen Referenzansicht.
Auf anderen Auflösungen werden
Position und Größe proportional angepasst; das Seitenverhältnis bleibt erhalten.
Der Ingame-Screenshot aus Figma wird weder mitgeliefert noch im Spiel angezeigt.
Alle vier Fahrräder sind gleichzeitig sichtbar und skalieren mit der Bildschirmgröße. Der äußere Rahmen samt Kopf- und Fußzeile wurde entfernt.
Scrollen ist deaktiviert; der Schließen-Button wurde entfernt.
Beim Öffnen fliegt das Menü in 520 ms von links herein. Eine leichte
Ausfluganimation bewegt es beim Schließen in 300 ms wieder nach links aus dem Bild.
Eine
perspektivische Neigung gibt ihm Tiefe; es wird nicht in der Bildebene gedreht.
Die Neigung lässt sich in `html/styles.css` über `--menu-angle` anpassen.
Bei aktivierter Systemeinstellung für reduzierte Bewegung entfällt die Einfluganimation.
Die Fahrradkarten behalten das Figma-Design. Das Menü ist zunächst unsichtbar,
der Hintergrund transparent. Der zusätzliche interne 30%-Versatz der alten
`#shop`-Karten ist nicht übernommen, da er das Figma-Layout im Menü abschneiden würde.

Zum Anschauen ohne FiveM `html/index.html?preview=1` über einen lokalen Webserver öffnen.
Die Browser-Vorschau löst keine Ausleihe aus.

## Validierung und Ingame-Abnahme

Lua-Syntax, serverseitige Abläufe mit simulierten FiveM-/Framework-Aufrufen und
die Browser-Oberfläche werden lokal geprüft. Ein echter FiveM-Server ist hier nicht vorhanden.
Vor dem Live-Einsatz in FiveM E/ESC, alle vier Modelle, Bargeld/Bank,
zu wenig Guthaben, blockierten Spawn, Rückgabe und Disconnect prüfen.
Andere Fahrzeugschlüssel-, Garage- oder Anti-Cheat-Ressourcen können zusätzliche Integration erfordern.

Technische Referenzen:
- https://docs.fivem.net/docs/scripting-manual/nui-development/nui-callbacks/
- https://docs.fivem.net/docs/scripting-manual/nui-development/full-screen-nui/
- https://docs.fivem.net/docs/developers/server-security/
- https://docs.fivem.net/docs/scripting-reference/onesync/
