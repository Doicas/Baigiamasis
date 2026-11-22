# Šviesos – namų šviesų valdymas balsu (iPhone)

SwiftUI programėlė iPhone 16 Pro Max (ir kitiems iPhone su iOS 18+), kuria namų šviestuvus galima valdyti **balsu lietuviškai**.

## Ką moka

- 🎙️ **Balso komandos** – paspaudžiate mikrofoną, pasakote komandą, programėlė pati supranta, kada nutilote, ir ją įvykdo.
- 💡 **Tikri šviestuvai per HomeKit** – bet kokios lemputės, pridėtos Apple programėlėje „Namai“ (Home): Philips Hue, IKEA Dirigera, Nanoleaf, Aqara, Matter įrenginiai ir kt.
- 🧪 **Demonstracinis režimas** – 6 netikri šviestuvai, kad galėtumėte išbandyti be jokių įrenginių (simuliatoriuje įjungiamas automatiškai).
- 🎚️ Rankinis valdymas: jungikliai, ryškumo slankikliai, „Įjungti / išjungti visas“.
- ⌨️ Komandas galima ir įvesti klaviatūra.
- 🗣️ Atsakymas balsu (jei įrenginyje yra lietuviškas balsas) ir vibracija.
- 🔘 **Siri, Shortcuts ir veiksmo mygtukas (Action Button)**.

## Komandų pavyzdžiai

| Pasakykite | Kas nutiks |
|---|---|
| „Įjunk šviesą svetainėje“ | įjungiamos visos svetainės šviesos |
| „Išjunk visas šviesas“ | išjungiama viskas |
| „Uždek naktinę lempą“ | įjungiamas šviestuvas pavadinimu „Naktinė lempa“ |
| „Užgesink šviesą vonioje“ | išjungiama vonia |
| „Pritemdyk miegamąjį iki 20 procentų“ | ryškumas 20 % |
| „Pašviesink virtuvėje“ / „Pritemdyk šviesą“ | ryškumas +25 % / −25 % |
| „Nustatyk raudoną spalvą svetainėje“ | spalva (raudona, oranžinė, geltona, žalia, žydra, mėlyna, violetinė, rožinė, balta, šilta, šalta) |
| „Turn off all lights“ | veikia ir angliškai |

Kambarių ir šviestuvų pavadinimai imami iš programėlės „Namai“, linksniai atpažįstami automatiškai („svetainė“ → „svetainėje“, „miegamasis“ → „miegamajame“). Jei pasakote nežinomą kambarį (pvz., „garaže“), programėlė nieko neįjungia ir praneša, ko nerado.

## Kaip įsidiegti į savo iPhone

Reikia **Mac kompiuterio su Xcode 16** (ar naujesniu) ir Apple ID.

1. Atidarykite `Sviesos/Sviesos.xcodeproj` Xcode programoje.
2. Kairėje pasirinkite projektą **Sviesos** → taikinį **Sviesos** → skirtuką **Signing & Capabilities**.
3. **Team** – pasirinkite savo Apple ID (nemokamos paskyros pakanka). Jei Xcode skundžiasi, pakeiskite **Bundle Identifier** į unikalų, pvz., `lt.jusuvardas.sviesos`.
4. Patikrinkite, kad sąraše yra **HomeKit** galimybė (ji jau įjungta per `Sviesos.entitlements`).
5. Prijunkite iPhone laidu, viršuje pasirinkite jį kaip paskirties įrenginį ir spauskite ▶︎ (Run).
6. iPhone: **Nustatymai → Bendrieji → VPN ir įrenginio valdymas** → patvirtinkite savo kūrėjo sertifikatą. Taip pat įjunkite **Nustatymai → Privatumas ir saugumas → Kūrėjo režimas (Developer Mode)**.
7. Pirmą kartą paleidus programėlė paprašys leidimų: **Namų duomenys (HomeKit)**, **Mikrofonas**, **Kalbos atpažinimas** – leiskite visus.

> Su nemokama Apple ID paskyra programėlė iPhone veikia 7 dienas, po to ją reikia vėl paleisti iš Xcode.

## Šviestuvų paruošimas

1. Atidarykite Apple programėlę **„Namai“ (Home)** ir pridėkite savo išmaniąsias lemputes.
2. Priskirkite jas kambariams ir duokite aiškius pavadinimus (pvz., „Toršeras“, „Naktinė lempa“) – būtent šiuos žodžius galėsite sakyti.
3. Šviesos programėlėje: ⚙️ **Nustatymai → Šaltinis → HomeKit**.

## Siri ir veiksmo mygtukas (Action Button)

- **Veiksmo mygtukas**: *Nustatymai → Veiksmo mygtukas → Spartusis veiksmas (Shortcut) → Šviesos → „Klausytis“*. Nuspaudus mygtuką programėlė atsidaro ir iš karto klausosi komandos.
- **Siri** (lietuviškai Siri nekalba, todėl frazės angliškos): „*Listen with Šviesos*“, „*Turn off lights with Šviesos*“, „*Turn on lights with Šviesos*“.
- **Shortcuts** programėlėje yra veiksmas „Vykdyti šviesų komandą“ – galite susikurti savo automatizacijas (pvz., „kai išeinu iš namų → išjunk visas šviesas“).

## Kalbos atpažinimas

Atpažinimą atlieka Apple `Speech` sistema. Jei jūsų iOS versija nepalaiko lietuvių kalbos atpažinimo, nustatymuose galite pasirinkti anglų kalbą (komandos „turn on the kitchen lights“ ir pan. taip pat suprantamos) arba komandas įvesti klaviatūra.

## Projekto struktūra

```
Sviesos/
├── Sviesos.xcodeproj
├── Sviesos.entitlements          HomeKit leidimas
└── Sviesos/
    ├── SviesosApp.swift          programėlės pradžia
    ├── Models/Light.swift        šviestuvo modelis
    ├── Services/
    │   ├── CommandParser.swift   lietuviškų komandų supratimas
    │   ├── TextNormalizer.swift  diakritika, linksniai
    │   ├── SpeechRecognizer.swift kalbos atpažinimas (mikrofonas)
    │   ├── VoiceAssistant.swift  balsas → komanda → atsakymas
    │   ├── LightStore.swift      šviestuvų būsena ir valdymas
    │   ├── LightBackend.swift    sąsaja + demonstraciniai šviestuvai
    │   └── HomeKitLightBackend.swift tikri HomeKit šviestuvai
    ├── Views/                    SwiftUI ekranai
    └── Intents/LightIntents.swift Siri / Shortcuts / Action Button
```
