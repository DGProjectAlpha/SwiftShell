# Native weather, hourly outlook and air quality

Date: 2026-11-05

WeatherModule shows a monochrome condition icon and temperature. WeatherPanel
shares the existing frosted surface and theme, with current/feels-like temperature,
humidity, wind, precipitation, a horizontally scrolling hourly outlook, rain
probability/amount charts, seven daily rows that expand into hourly detail,
sunrise/sunset/UV and modelled air quality. AQI and pollutant values explicitly
show unavailability when the provider has no data. Zero temperatures and zero
rain are values, not missing data. Location names render as plain text.

WeatherPage configures an explicitly chosen city/state/country/postal code/address,
Celsius/Fahrenheit and a 15–120 minute refresh interval. The WeatherService model
is shared across panels and displays. It starts no process/network request with
disabled defaults. The typed snapshot property is `WeatherService.forecast`;
`data` is intentionally avoided because it is a QML default property. Location,
query and provider payloads travel through stdin/stdout to the helper and are not
logged or included in process arguments. Changing units/location or disabling
weather invalidates an in-flight response so it cannot restore obsolete state.

The helper uses bounded HTTPS JSON requests to Open-Meteo forecast, air-quality
and city-geocoding endpoints. Forecasts retain a private on-device cache and
show their original update age when offline. API failure can reuse the saved
forecast without presenting it as fresh. Metric/imperial caches are independent;
weather remains usable when the air-quality endpoint fails. Provider credentials,
API keys and packages are unnecessary for the personal-use integrations.

Address lookup falls back to Nominatim only after an explicit Search action;
there is no autocomplete or periodic geocoding. Requests identify SwiftShell,
are locally rate-limited under a file lock, cache results for 24 hours and show
OpenStreetMap attribution. The deployment can change the HTTPS address-search
endpoint with `SWIFTSHELL_ADDRESS_SEARCH_URL` if the public operator requests it.
Queries cannot choose an endpoint or introduce shell commands.

Approximate location is a separate explicit button. Its explanation names the
IP-location provider and states that no GPS or background location lookup is
used. Only that action calls ipwho.is; the returned IP itself is discarded.
The selected approximate city persists and can be updated by the same button.
Fresh installs never guess a location or look up the user's IP automatically.
Weather/AQI attribution links to Open-Meteo; geographic searches also identify
GeoNames/OpenStreetMap as appropriate.

Verified on Quickshell 0.3.2, Qt 6.12 and Hyprland 0.57:

- `python3 tests/test_weatherctl.py`: 10 tests passed. Coverage includes location
  validation, seven-day/hourly normalization, null AQI, cache/network suppression,
  offline age preservation, imperial provider parameters, optional AQI failure,
  city/address caching and rate limiting, explicit approximate lookup without
  retaining the IP, bounded responses and sanitized errors.
- `node tests/weather.test.js`: zero/null handling, units, location validation,
  condition glyphs, precipitation scales, AQI labels and age formatting passed.
- `tst_weather.qml`: eight checks passed for rich/zero-valued conditions, daily
  expansion/collapse, chart mode controls, Settings action, literal location text,
  unavailable AQI, Settings inputs and disabled/no-automatic-location behavior.
- A real public Berlin city-geocoding + forecast/AQI request returned seven days,
  24 upcoming hours and air quality; cache readback passed in a temporary cache.
  No real address or user location was requested. `tests/live/weather.py --live
  --offscreen --api` provides an explicit repeatable public-city smoke check.
- `tests/live/weather.py --live --offscreen`: actual native Process/stdin transport,
  explicit synthetic location choice, atomic units save/readback, full process
  restart, offline age and disabling during an in-flight response passed. It
  caught a shared settings-writer key-order loop, repaired separately by the root
  agent before this test passed. Disabled defaults produced zero helper requests.
- `tests/live/weather.py --live`: the same isolated fixture passed with a real
  HDMI-A-1 panel, daily expansion and dark/light layout. Screenshots use only a
  named owned QML item with an opaque checkerboard inside the same window. No
  compositor/app/browser pixels are captured. Current-dark and expanded-light
  snapshots were visually inspected. Native blur attachment is exercised, but
  item captures do not measure compositor blur strength. No desktop pointer or
  keyboard input, monitor-mode change or production restart was required.

Limitations: IP-location and real street-address handling were tested with fixed
synthetic responses, not by querying the owner's IP/address. Location accuracy,
AQI availability and forecasts depend on provider coverage; air quality is a model
estimate rather than a local physical sensor. The initial native layout fixture
uses the explicitly authorized HDMI output; production monitors are discovered by
the existing per-display bar host. No Noctalia, user Lua, autostart or system service
was changed. Owner acceptance should select a location, inspect the hourly/day
expansions, change units, restart SwiftShell and confirm the chosen location/units.

Recovery: disable weather to stop requests, or choose a different location. Revert
this feature commit for source rollback. Its private cache is isolated under
`$XDG_CACHE_HOME/swiftshell/weather`; removing that owned directory clears saved
forecasts/geocoding. Location/units use the existing versioned atomic preferences,
with no separate settings migration.

Primary contracts:

- https://open-meteo.com/en/docs
- https://open-meteo.com/en/docs/air-quality-api
- https://open-meteo.com/en/docs/geocoding-api
- https://nominatim.org/release-docs/latest/api/Search/
- https://operations.osmfoundation.org/policies/nominatim/
- https://ipwhois.io/documentation
