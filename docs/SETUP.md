# One-time setup for TestFlight releases

Four secrets in the GitHub repo let CI sign and upload builds. You only do this once. **Never paste any of these values into chat or commit them to the repo** — they go directly into GitHub's encrypted secrets.

## 1. Create an App Store Connect API key

1. Go to [App Store Connect](https://appstoreconnect.apple.com) → **Users and Access** → **Integrations** tab → **App Store Connect API** → **Team Keys**.
2. Click **+** (Generate API Key).
3. Name: `breathe-ci`. Access: **App Manager**.
4. After it's created, note the **Key ID** (e.g. `A1B2C3D4E5`) and the **Issuer ID** (shown at the top of the page, a UUID).
5. Click **Download API Key** — you get a `.p8` file. You can only download it once; keep it somewhere safe.

## 2. Find your Team ID

Go to [developer.apple.com/account](https://developer.apple.com/account) → **Membership details** → **Team ID** (10 characters, e.g. `AB12CD34EF`).

## 3. Add the four secrets to GitHub

Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**, four times:

| Secret name | Value |
|---|---|
| `APPLE_TEAM_ID` | Your 10-character Team ID |
| `APPSTORE_KEY_ID` | The API Key ID from step 1 |
| `APPSTORE_ISSUER_ID` | The Issuer ID from step 1 |
| `APPSTORE_P8` | The **entire text contents** of the `.p8` file (open it in Notepad, copy everything including the BEGIN/END lines) |

## 4. Create the app record in App Store Connect

1. First run the **Release to TestFlight** workflow once (repo → **Actions** → *Release to TestFlight* → **Run workflow**). The archive step auto-registers the bundle IDs (`com.jyelen.breathe` and `com.jyelen.breathe.watchkitapp`) with your developer account. If the *upload* step then fails with "no suitable application record found", that's expected on the very first run — continue below.
2. In App Store Connect → **Apps** → **+** → **New App**:
   - Platform: **iOS**
   - Bundle ID: `com.jyelen.breathe`
   - Name: must be unique on the App Store — "Breathe" is taken, so use something like *Breathe Guardian* or *Breathe by Jason* (TestFlight-only, so the name barely matters)
   - SKU: `breathe-001`
3. Re-run the **Release to TestFlight** workflow. The upload should now succeed.

## 5. Install on your devices

1. Install **TestFlight** from the App Store on your iPhone.
2. In App Store Connect → your app → **TestFlight** tab, the build appears after processing (~10–30 min). Answer the export-compliance question if prompted (the app uses no custom encryption).
3. Add yourself as an internal tester: **TestFlight** → **Internal Testing** → create a group → add your Apple ID.
4. Open TestFlight on the iPhone → install Breathe. The Watch app installs automatically (or via the Watch app → Available Apps).
5. On first launch (iPhone), tap **Connect Apple Health** and grant all permissions. On the Watch, tap **Start Work Mode** and grant the sensor permissions when prompted.
