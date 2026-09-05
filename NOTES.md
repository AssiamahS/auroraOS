# NOTES

- ASC API subscription pricing 409s ("ENTITY_ERROR.RELATIONSHIP.INVALID") until you
  POST /v1/subscriptionAvailabilities for the sub FIRST (all 175 territories), then
  POST /v1/subscriptionPrices with only subscription+pricePoint relationships.
  Lifetime IAP pricing works standalone via inAppPurchasePriceSchedules with the
  ${placeholder} included-object pattern.
- PATH live data: official free endpoint is panynj.gov/bin/portauthority/ridepath.json
  (razza.dev API is dead). Station codes NWK/HAR/JSQ/GRV/EXP/WTC/HOB/NEW/CHR/09S/14S/23S/33S.
- MTA GTFS-RT: keyless. Chained flatMap/filter on the decoded feed made SourceKit
  time out type-checking — keep the arrival extraction as plain for-loops.
- First TestFlight archive failed until all three bundle ids (app/watch/widgets)
  existed in ASC; register them via API before the first signed build.
- App Store watch screenshots: the CI watch sim now captures 422x514 (Ultra 3), which
  ASC does not accept. Resample to 410x502 (Ultra) or 416x496 (46mm) before upload.
- The pre-push auto-version hook bumps MARKETING_VERSION inside the commit being pushed,
  so the shipped version is one higher than the commit message says. Read the version
  back with `git show origin/main:project.yml` after pushing, never trust the message.
- App Privacy: zero third-party SDKs, and location never leaves the device (only two
  keyless GETs to MTA/PANYNJ). Disclose Location / App Functionality / not linked /
  not tracking anyway — see SUBMISSION.md for the reasoning.
