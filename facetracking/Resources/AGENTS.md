# Resource guidance

- `Localizable.xcstrings` owns stable user-facing keys and the section-9 English baseline. SwiftUI views consume keys from typed presentation mappings; algorithms and reducers contain no localized copy.
- Keep required permission, action, camera/error, positioning, lighting, and return-guide keys manually managed so dynamic key mapping does not make Xcode mark them stale or remove them.
- Add translations under the existing stable keys. Do not change baseline meaning into identity, liveness, medical, certified-quality, or completion claims.
- Assets are decorative application resources only. Never add participant images, face crops, landmarks, captured frames, or test evidence to this directory.
- `AGENTS.md` is excluded from synchronized-group target membership and the application bundle.
