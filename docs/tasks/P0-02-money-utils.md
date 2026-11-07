# P0-02 Money utilities (`@pos/core`)
Goal: integer minor units + currency code; exponent per currency (JPY 0, USD 2, KWD 3).
Do: `Money` type, `toMinor`, `fromMinor`, `formatMoney(money, locale)`, `add/sub`, `multiply` with rounding, `convert(money, rate)`.
Rules: never floats in storage; reject non-integer minor values; cross-currency add throws.
Done when: tests cover 3 currencies and locales `en` and `fil`.
