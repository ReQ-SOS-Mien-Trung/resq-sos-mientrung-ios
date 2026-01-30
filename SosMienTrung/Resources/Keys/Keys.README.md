How to add your OpenWeather API key

1. Copy `Keys.plist.example` to `Keys.plist` in the `SosMienTrung` folder.
2. Replace the `YOUR_OPENWEATHER_API_KEY` value with your real OpenWeather API key.
3. In Xcode, add `Keys.plist` to the project and ensure it's included in the app target's "Copy Bundle Resources" so `Bundle.main.url(forResource: "Keys", withExtension: "plist")` can find it at runtime.
4. Do NOT commit `Keys.plist` to git. The repository's `.gitignore` already contains `SosMienTrung/Keys.plist`.

Optional (recommended):

- Store secrets in the Keychain or use environment variables / CI secrets and inject them at build time for better security.
- If the key was ever committed earlier, rotate the key and scrub it from git history.
