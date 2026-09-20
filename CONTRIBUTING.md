# Contributing to Najikify

Thanks for your interest in improving Najikify. This guide covers how to set up the project, the conventions used, and how to get a change merged.

## Ways to Contribute

- Report bugs and request features via [Issues](https://github.com/ankitkhatrik6/najikify/issues)
- Improve documentation
- Fix bugs or implement features via pull requests
- Test on hardware you have available (different Linux distros, Android versions)

## Getting Started

### 1. Fork and clone

```bash
git clone https://github.com/<your-username>/najikify.git
cd najikify
```

### 2. Install prerequisites

- **Flutter** 3.47+ (stable), Linux desktop enabled:
  ```bash
  flutter config --enable-linux-desktop
  ```
- **Linux toolchain**:
  ```bash
  sudo bash packaging/linux/install_deps.sh
  ```
- **Android**: Android SDK (platform 35+), build-tools, JDK 17+

Confirm everything is healthy:

```bash
flutter doctor
```

### 3. Fetch dependencies and verify

```bash
flutter pub get
flutter analyze
flutter test
```

All three should pass before you start changing code.

## Development Workflow

1. Create a branch with a descriptive name:
   ```bash
   git checkout -b feat/file-resume
   git checkout -b fix/discovery-timeout
   ```
2. Make your change in small, focused commits.
3. Add or update tests where behaviour changes.
4. Run the checks:
   ```bash
   flutter analyze && flutter test
   ```
5. Push and open a pull request against `main`.

CI (`ci.yml`) runs analysis and the test suite automatically on every pull request.

## Project Conventions

| Area | Convention |
|------|------------|
| Business logic | `lib/services/` — one service per concern, extends `ChangeNotifier` when it holds observable state |
| UI | `lib/features/<feature>/` — screens grouped by feature |
| Reusable widgets | `lib/widgets/` |
| Data models | `lib/models/` — plain Dart classes with `toJson`/`fromJson` or `toMap`/`fromMap` |
| Utilities | `lib/core/utils/` — pure static helpers |
| Constants | `lib/core/constants/` — ports, timeouts and app-wide values; no magic numbers elsewhere |
| Errors | `lib/core/errors/` — throw typed exceptions from the `NajikifyException` hierarchy |

Additional guidelines:

- Prefer `const` constructors and immutable models.
- Keep files focused; split a file once it grows past a single clear responsibility.
- Do not add magic numbers for ports or timeouts — put them in `lib/core/constants/`.
- Document any new network behaviour in the README's **How It Works** section.
- Match the existing formatting; run `dart format .` before committing.

## Testing Guidelines

- Tests live in `test/` and use `flutter_test`.
- Unit-test models, utilities and protocol serialization.
- Widget-test reusable UI components with a `MaterialApp`/`Scaffold` wrapper.
- Keep tests deterministic — avoid real network calls and wall-clock dependencies.

```bash
flutter test                       # everything
flutter test test/transfer_state_test.dart   # a single file
```

## Reporting Bugs

Please include:

- Platform and version (e.g. Ubuntu 25.10, Android 14)
- Najikify version (from `pubspec.yaml` or the release you installed)
- Steps to reproduce
- Expected vs actual behaviour
- Relevant logs — run the app from a terminal (`najikify`) to capture output

## Security Issues

Do **not** open a public issue for vulnerabilities. Use a
[private security advisory](https://github.com/ankitkhatrik6/najikify/security/advisories/new)
instead. See the **Security** section of the README for the project's threat model.

## License

By contributing, you agree that your contributions are licensed under the
[MIT License](LICENSE).