Config = {}

-- ESX für Zahlung und Meldungen; GTA-Fallback bei fehlendem ESX-Notify.
Config.PaymentAccount = 'cash' -- 'cash' oder 'bank'
Config.MarkerRadius = 0.5 -- Sichtbarer Radius und Bereich für E/G sowie HelpNotify.
Config.MarkerZTolerance = 1.0 -- Höhenabweichung zur Interaktionskoordinate.
Config.DrawDistance = 20.0
Config.ServerDistance = 3.0
Config.SpawnClearRadius = 2.0
Config.RequestCooldown = 2 -- Sekunden

-- Beispielstandort am Flughafen LSIA. Koordinaten und Heading anpassen!
-- coords: E-Interaktion; spawn: Fahrradposition, w ist die Blickrichtung.
Config.Locations = {
    {
        label = 'Fahrradverleih',
        coords = vector3(-1034.60, -2733.60, 20.17),
        spawn = vector4(-1030.80, -2731.00, 20.17, 240.0),
        blip = true
    }
}

-- Einmaliger Preis pro Ausleihe; keine zeitabhängige Abbuchung.
Config.Bikes = {
    { id = 'bmx', name = 'BMX', model = 'bmx', price = 10 },
    { id = 'scorcher', name = 'SCORCHER', model = 'scorcher', price = 20 },
    { id = 'tribike', name = 'Tribike', model = 'tribike', price = 25 },
    { id = 'cruiser', name = 'Cruiser', model = 'cruiser', price = 5 }
}
