PROPSURE 1.2.0 - ALL PARTS (1 to 6) IN ONE PACKAGE
NOTHING HERE WAS COMPILED. Run flutter analyze and fix what it reports.

WHAT TO COPY
  lib/                  replace your lib/ folder
  web/                  replace your web/ folder (index.html, manifest.json, robots.txt)
  functions/            copy over your functions/ (new: accountcheck.js, areas.js, share.js;
                        changed: index.js, media.js). founder_promo.js: keep YOUR copy if you have one.
  firebase.json         replace (adds /l/** and /sitemap.xml rewrites; admin target unchanged)
  pubspec.yaml          yours + one line: flutter_web_plugins (sdk: flutter). Version left at 1.1.1+12.
  config/               firestore.rules, firestore.indexes.json (23 indexes), storage.rules
  CHANGES.md, DEPLOY.md

DEPLOY ORDER
  1. firebase deploy --only firestore:indexes      (wait until every index says Enabled)
  2. firebase deploy --only firestore:rules
  3. cd functions && npm install && cd ..
     firebase deploy --only functions
     (new: listBanks, checkAccountName, submitAreaReport, updateStillLabels, shareListing, sitemap)
  4. flutter pub get && flutter analyze
  5. flutter build web --release        (add --dart-define=MAPS_WEB=true only if you add a web Maps key)
  6. firebase deploy --only hosting:app

WEB DEPLOY NOTE
  Hosting rewrites call functions shareListing and sitemap, so deploy functions BEFORE hosting.

TEST LIST
  Phone + browser: Home greeting by time of day; city chip opens picker; Abuja shows homes.
  Search/filters; open a listing; chapter chips and "What the video shows" (after an agent names rooms).
  Agent: add listing with photos + video; "Name the rooms in your video".
  Listing > "Before you pay" > check an account (needs live Paystack key).
  Listing > area card > report an area (needs sign-in; not from an agent with a listing there).
  Web only: resize window (phone / tablet / desktop layouts); upload photos; pay a boost (returns to /payment/callback);
  open https://propsure.africa/l/<listingId> in WhatsApp preview; /sitemap.xml loads.
  Sign in, sign out, open /workspace while signed out (should go to sign in).
