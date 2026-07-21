# Distribution

Quip ships via **direct distribution**: a Developer ID-signed, notarized `.dmg`,
with **Sparkle** handling in-app updates. It is **not** sandboxed and is **not**
on the Mac App Store. This mirrors Chorus's setup, and reuses the same Apple
Developer account and Sparkle signing key.

Hardened Runtime stays **on** (required for notarization). The App Sandbox is
intentionally **off** — see `Quip/Quip.entitlements`.

---

## Configured values

| Key | Where | Value |
|---|---|---|
| `SUPublicEDKey` | `Quip/Info.plist` | `6/h2Pfjbo39vHie8JIt/kY7h0wQvmQxj9Ea0W3gnH0w=` — the shared EdDSA key whose private half is in the login Keychain |
| `teamID` | `release/ExportOptions.plist` | `3CY4DX3K45` |
| `SUFeedURL` | `Quip/Info.plist` | `https://quip.nicojan.com/appcast.xml` |

### Hosting (GitHub)

The `nicojan/Quip` repo is **public**. Updates are hosted from it:

- **Appcast** — `docs/appcast.xml`, served by **GitHub Pages** (source: `main`
  branch, `/docs` folder). The custom domain `quip.nicojan.com` (see
  `docs/CNAME`) serves it at `https://quip.nicojan.com/appcast.xml`, which is the
  `SUFeedURL`. Builds up to and including **1.1.10** used
  `https://nicojan.github.io/Quip/appcast.xml`; that still works, but only
  because Pages redirects it to the custom domain.
- **DMGs** — attached as **GitHub Release assets** (one release per version, tag
  `vX.Y.Z`). The appcast's `<enclosure>` URLs point at the release download URLs.

> **Gotcha — HTTPS enforcement.** Once the `quip.nicojan.com` custom domain was
> set, `https://nicojan.github.io/Quip/appcast.xml` began **301-redirecting** to
> the custom domain. With Pages' **Enforce HTTPS off**, that redirect went to
> **`http://`**, and Sparkle refuses an https→http downgrade — so every installed
> app's update check failed with "An error occurred in retrieving update
> information." Fix: keep **Enforce HTTPS on** for the Pages site
> (`gh api -X PUT repos/nicojan/Quip/pages -F https_enforced=true`; needs the cert
> `approved` first). From 1.1.11 on, `SUFeedURL` points straight at the custom
> domain, so new builds don't ride that redirect at all.

### Signing key note

The EdDSA **private** key already lives in the login Keychain (shared with
Chorus and WatchMeType). Only the public key is in `Info.plist`. Keep that
private key backed up — if it's lost you cannot ship signed updates to existing
users.

---

## One-time setup

1. **Sparkle** is already declared in `project.yml` and wired in
   `Quip/App/QuipApp.swift` (`SPUStandardUpdaterController`) and
   `Quip/Support/UpdaterView.swift` (the "Check for Updates…" button in
   Settings). Nothing to add.
2. **Signing** — set the Team on the Quip target and sign the Release build with
   **Developer ID Application**. The same Team ID is in
   `release/ExportOptions.plist`.
3. **Notary credentials** (once): `xcrun notarytool store-credentials`. Quip
   reuses the shared `chorus-notary` profile (same Apple account as Chorus), so
   this is already set up.

---

## Cutting a release

Run from the repo root. Replace `X.Y.Z`. Regenerate the project first if
`project.yml` changed (`xcodegen generate`).

1. **Bump the version** in `project.yml` (both must increase;
   `CURRENT_PROJECT_VERSION` is what Sparkle compares):
   - `MARKETING_VERSION` → `X.Y.Z` (`CFBundleShortVersionString`)
   - `CURRENT_PROJECT_VERSION` → next integer (`CFBundleVersion`)

   Then `xcodegen generate`.

2. **Archive:**
   ```sh
   xcodebuild -project Quip.xcodeproj -scheme Quip \
     -configuration Release -archivePath build/Quip.xcarchive archive
   ```

3. **Export with Developer ID:**
   ```sh
   xcodebuild -exportArchive -archivePath build/Quip.xcarchive \
     -exportOptionsPlist release/ExportOptions.plist -exportPath build/export
   ```

4. **Package a DMG.** `create-dmg` puts the output name first:
   ```sh
   rm -rf build/dmg-src && mkdir -p build/dmg-src
   cp -R build/export/Quip.app build/dmg-src/Quip.app
   create-dmg --volname "Quip" --window-size 600 320 --icon-size 100 \
     --icon "Quip.app" 160 155 --app-drop-link 440 155 \
     build/Quip-X.Y.Z.dmg build/dmg-src
   ```
   `create-dmg` lays out the window with AppleScript, so it needs a logged-in GUI
   session — but it also adds the drag-to-**Applications** link, so prefer it.
   The `hdiutil create -volname "Quip" -srcfolder build/dmg-src -ov -format UDZO
   build/Quip-X.Y.Z.dmg` fallback works headlessly but produces a DMG **without**
   the Applications drop link (just the app), so only use it when there's no GUI
   session. Then sign the DMG:
   ```sh
   codesign --force --sign "Developer ID Application: … (3CY4DX3K45)" build/Quip-X.Y.Z.dmg
   ```

5. **Notarize and staple:**
   ```sh
   xcrun notarytool submit build/Quip-X.Y.Z.dmg --keychain-profile "chorus-notary" --wait
   xcrun stapler staple build/Quip-X.Y.Z.dmg
   ```

6. **Publish the DMG as a GitHub Release:**
   ```sh
   gh release create vX.Y.Z build/Quip-X.Y.Z.dmg \
     --repo nicojan/Quip --title "Quip X.Y.Z" --notes "Release notes…"
   ```

7. **Sign the stapled DMG and add an appcast item.** Stapling changes the bytes,
   so sign after step 6:
   ```sh
   …/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update build/Quip-X.Y.Z.dmg
   ```
   Add a new `<item>` at the top of `docs/appcast.xml`: set `sparkle:version` to
   the build number, `sparkle:shortVersionString` to `X.Y.Z`, point the enclosure
   at `https://github.com/nicojan/Quip/releases/download/vX.Y.Z/Quip-X.Y.Z.dmg`,
   and paste in the `length` and `edSignature`. Put release notes in a CDATA
   `<description>`. Then check it:
   ```sh
   xmllint --noout docs/appcast.xml
   ```

8. **Commit the appcast** so GitHub Pages republishes it at `SUFeedURL`:
   ```sh
   git add docs/appcast.xml && git commit -m "release: Quip X.Y.Z appcast" && git push
   ```
   Installed apps pick up the update on their next scheduled check (daily), or
   via **Check for Updates…** in Settings.
