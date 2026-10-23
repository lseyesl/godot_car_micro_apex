# Project guide

- Read [README.md](README.md) and [Android build/release instructions](docs/android-build.md) before building or publishing.
- APK/Release attachments must be uploaded by a **GitHub Actions runner**. Cloud Codex may push authorized changes, dispatch workflows and inspect status; it must not upload attachments directly to `uploads.github.com`.
- To publish an already successful Android build, use `.github/workflows/publish-android-artifact.yml` with its source run/artifact IDs, approved APK SHA-256, build SHA and existing draft Release ID. See the documented example and recovery procedure.
- The publish job alone needs `actions: read` and `contents: write`, using its built-in `GITHUB_TOKEN`. Do not add credentials or change repository/organization security settings.
- Check original build success, APK digest, pinned debug certificate, package/version and tag target. A publish workflow's own commit is **not** the APK's build commit.
- After a publishing failure inspect the existing draft and attachment states; reuse the original artifact/draft, do not rebuild, overwrite old releases/tags or repeatedly retry cloud uploads.
- These instructions describe the engineering workflow. They do not create additional approval rules; follow the user's authorized scope for push/build/release.

- Model styles default to `original`; read [model style instructions](docs/model-styles.md). Do not overwrite original GLBs. Builds must seal an explicit style and exclude unused resources; Android must never depend on host/device environment variables for style selection.
