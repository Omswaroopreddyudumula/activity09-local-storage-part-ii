# Activity 09 Local Storage Part II

Student: **Om Swaroop Reddy Udumula**. Pathway: **Undergraduate**. This is the user's Activity 08 Fall Festival Roster project extended in place with a folder/card catalogue. No Part I table or installed data was discarded.

## Requirements and authoritative source

Read and reconciled the [official Activity 09 instructions and rubric](https://codd.cs.gsu.edu/~lhenry23/mad/ica/act09/v2/index.html) before implementation, using the [lecture companion](https://codd.cs.gsu.edu/~lhenry23/mad/ica/act09/v2/notes/activity09-lecture.html) as supporting notes. The official page was fetched successfully from the course site on October 8, 2026; the general web reader could not access it, so its HTML was read directly. The official page currently lists **October 9, 2026 at 11:59 PM**, whereas the supplied lecture and user request specify **October 8 at 11:59 PM**. Preparation follows the user's earlier cutoff; verify the exact iCollege folder/time zone before submission.

The official instructions sharpen the lecture's summary: T1 has upgrade and separate fresh-target subtests; T2 uses two Echo titles in Moon plus Beacon in Lantern; T5 tests card deletion before folder cascade; T6 tests blank title, blank folder name and duplicate Lantern separately. Folder rename is optional in the rubric but is implemented. The official lifecycle guidance states that sqflite already wraps onCreate/onUpgrade in a transaction: this project awaits each callback operation and does not nest another transaction.

## Run and build

Verified with Flutter **3.47.2 stable**, Dart **3.13.2**, macOS 26.6.2, Android SDK/Android Studio Java, Android 17/API 37 arm64. Existing target: **Pixel_8 / emulator-5554**. Separate fresh/release target: **Activity09Fresh / emulator-5556**, created from the installed Android system image. Use Android, not Flutter web, for this sqflite project.

```sh
git clone https://github.com/Omswaroopreddyudumula/activity09-local-storage-part-ii.git
cd activity09-local-storage-part-ii
flutter pub get
flutter devices
flutter run -d <android-device-id>
flutter analyze 2>&1 | tee evidence/analysis_output.txt
flutter build apk --release
```

Start a device/emulator through Android Studio Device Manager. Flutter configures machine-local Android paths on first run; local.properties is deliberately excluded. Android/iOS source configuration and lockfile are included. iOS has not been executed. The preserved dependency constraints are sqflite ^2.4.1, path_provider ^2.1.5 and path ^1.9.0; pubspec.lock resolves the tested versions. Gradle uses `org.gradle.vfs.watch=false`, retained from Activity 08 to avoid a macOS file-watcher stall. The wrapper scripts/JAR are included explicitly for reproducibility.

Release output: `build/app/outputs/flutter-apk/app-release.apk`. Copy it to **Activity09_Udumula_OmSwaroopReddy.apk**. The submitted release uses the template's local debug signing key; it is a release-mode coursework APK, not a Play Store publishing configuration. Its exact SHA-256 is recorded in `evidence/release_sha256.txt`. Do not uninstall an existing Activity 08 app to solve a signing conflict: use a separate disposable emulator instead. The verified project uses the same package `edu.student.fall_festival_roster` and database filename throughout.

## Schema and preservation

Original file: documents directory **MyDatabase.db**, schema version **1**, table **my_table**, columns **_id INTEGER PRIMARY KEY, name TEXT NOT NULL, age INTEGER NOT NULL**. A source copy and a stopped-app database backup were made before implementation. The private database backup remains outside this repository; only fictional test rows are represented in evidence.

Pre-upgrade real rows, count **3**:

| ID | Name | Age |
|---|---|---|
| 2 | River | 35 |
| 3 | Acorn | 0 |
| 4 | Oak | 130 |

`lib/database_helper.dart` keeps the original path and Part I CRUD. `onConfigure` enables `PRAGMA foreign_keys = ON`. Fresh `onCreate` creates the unchanged Part I schema plus both catalogue tables and index. `onUpgrade` gates only the catalogue creation behind `oldVersion < 2`; failures propagate to the visible initialization error. No seeding, database rename, table drop, uninstall or clearing occurred. `evidence/schema_comparison.json` records identical fresh/upgraded table and index definitions.

New schema:

- `folders`: generated `id` primary key, nonempty `name` with case-sensitive UNIQUE constraint, ISO-8601 `created_at`.
- `cards`: generated `id`, trimmed nonempty title, suit constrained to Hearts/Diamonds/Clubs/Spades, notes default `''`, nullable `image_ref`, required `folder_id REFERENCES folders(id) ON DELETE CASCADE`.
- `idx_cards_folder_id` indexes the foreign key. Queries filter by bound folder ID and order titles case-insensitively with ID as a stable tie-breaker.

The app's actual diagnostic connection returned `user_version=2`, `foreign_keys=1`, a `cards.folder_id → folders.id` CASCADE relationship and the expected index. Read-only snapshots from the actual Android database corroborate the rows; external SQLite readers do not establish the app connection's foreign-key setting, so connection logs are included separately.

Cascade fits this catalogue because a folder owns its cards. For records with independent retention value, restrict deletion, require reassignment, or archive the parent instead. Deletion confirmation names the item and ID; folder confirmation warns that children are deleted. All writes target stable IDs using bound parameters. Duplicate folder names are rejected, never handled with REPLACE, which could cascade away children.

## Models and UI

`lib/models.dart` contains typed Folder and CardRecord mappings. CardRecord avoids a collision with Flutter's Card widget. The helper supplies folder create/update/read/count/delete and card full CRUD; widgets contain no SQL. LEFT JOIN counts keep empty folders visible with zero cards. The folder screen opens only the selected folder's ID; a shared Add/Edit form validates title, suit and selected folder. SQLite enforces the relationship even if a folder disappears after the form opens.

The existing guest screen is available from the people icon. Separate async read/write handling supplies loading, empty, error and affected-row feedback. Busy flags disable repeat submissions; mounted checks guard state updates after awaits. Cancel does not write. Failed writes retain input; a later refresh error tells the user to retry Refresh instead of repeating a completed Save. Busy guards do not provide cross-editor optimistic concurrency or network synchronization.

Images use a nullable reference, with null as the tested default. The UI displays the appropriate suit symbol when the reference is null, malformed, unsupported, loading, or cannot load. Optional assets and HTTPS references have error fallback; no assets are bundled and no network image was required by tests. Managed app-private image files/gallery copying and BLOB storage are not implemented. A URL is a reference, not offline bytes; production remote images also require an Android network permission and lifecycle/network policy. Suit fallback remains usable regardless.

## Actual required test results

Run date: October 8, 2026, America/New_York. Tests were operated by Codex through the actual Android UI, with real insert/affected-row feedback, screenshots, app connection logs and read-only database snapshots. IDs below are observed return values, not assumed constants. No automated Flutter test suite is required by the assignment. The UI driver occasionally required retries after emulator startup, device-selection or missing UI-root errors; completed runs and row comparisons determine the results, and no reset/reseeding was used to recover.

| Test | Input/action | Expected | Actual observed result | Result/evidence |
|---|---|---|---|---|
| T1a upgrade | Install updated debug APK with `adb -s emulator-5554 install -r`; launch same Part I package/database | v1→v2, all original IDs/values unchanged; tables/index and FK enabled | v1 original count 3 becomes v2 count 3: (2,River,35),(3,Acorn,0),(4,Oak,130). New folders/cards initially empty. App connection FK=1, CASCADE/index present | PASS: T1_before.png, T1_original_rows.json, T1_upgrade.json, upgrade_connection_log.txt |
| T1b fresh | Install v2 on new Activity09Fresh/emulator-5556; create and open Fresh check | Complete fresh schema, empty folder opens normally | Guests/folders/cards initially empty; v2 and FK=1. Created Fresh check returned folder ID 1; count 0; “No cards in this folder.” Fresh schema equals upgraded schema | PASS: T1_fresh_empty.json, T1_fresh_folder.json/png, fresh_connection_log.txt, schema_comparison.json |
| T2 parent-child | Create Moon and Lantern; add Echo twice to Moon, Beacon to Lantern | Distinct IDs, Moon=2, Lantern=1, correct filtering | Folder inserts returned Moon=1, Lantern=2; card inserts returned Echo Hearts=1, Echo Spades=2, Beacon Clubs=3. Both Echo image refs NULL; Beacon NULL. Moon query only cards 1/2; Lantern only 3 | PASS: T2_cards.png, T2_counts.png, T2_lantern.png, T2_complete.json |
| T3 edit identity | Edit card 2 title/notes; edit card 1 then Cancel | Save affects 1; other rows unchanged; Cancel no write | Card 2 → Echo revised / Changed by ID, feedback 1 row affected; card 1 remains Echo/empty notes. Save/cancel snapshots identical; counts remain 2/1. Initial driver selection appended old title; corrected text-entry driver and repeated exact required edit/cancel successfully | PASS: T3_saved_exact.json, T3_canceled_exact.json, T3_identity.png; earlier intermediate snapshots retained |
| T4 cold restart | Record all rows; Android App info → Force stop → OK; start same MainActivity | Same IDs, values/counts and no duplicates | Old PID 29407 absent after stop; new PID 1935. All row snapshots identical: guests=3, folders=2, cards=3; Moon=2, Lantern=1 | PASS: T4_before.json/png, T4_after.json/png, restart.txt |
| T5 card delete then cascade | Cancel card 1 deletion, confirm card 1 deletion; Cancel Moon deletion, confirm Moon deletion | Cancels preserve rows; card delete affects 1 then Moon count=1; folder delete affects 1 parent and removes child; Lantern remains | First Cancel unchanged. Card delete 1 row, leaves cards 2/3. Folder Cancel unchanged. Delete Moon parent ID 1 returns 1 and removes card 2; no child references 1. Lantern ID 2 / Beacon ID 3 count 1 intact. Guests remain 3 | PASS: T5_card_cancel.json, T5_card_delete.json/png, T5_folder_cancel.json, T5_cascade.json/png |
| T6 validation and fallback | Open Beacon NULL image; separately Add whitespace title, blank folder name, duplicate Lantern | Visible fallback/errors; no writes | Clubs placeholder with Beacon ID 3. “Enter a nonempty title” and “Enter a nonempty folder name”; UNIQUE rejects Lantern. All three snapshots exactly equal baseline: one folder, one card, original three guests. After improving the duplicate-name message, the final build was retested with the same unchanged rows; see T6_duplicate_folder_final.json/png and final_validate_retry.txt | PASS: T6_fallback.png, T6_invalid_title.json/png, T6_invalid_folder.json/png, T6_duplicate_folder.json/png |

### Exact pre-restart rows

Before T4: folders `(1,Moon,2026-10-08T23:23:16.879081)` and `(2,Lantern,2026-10-08T23:23:26.877610)`; cards `(1,Echo,Hearts,'',NULL,1)`, `(2,Echo revised,Spades,Changed by ID,NULL,1)`, `(3,Beacon,Clubs,'',NULL,2)`. All same values after restart. There was no live debugger attached during this built-and-installed debug APK test. The system App info Force stop was confirmed, the PID vanished, and the same installation was launched without reinstall, data clearing, hot reload or hot restart. T4_after.png shows folder counts; full rows are in paired JSON snapshots.

### Release verification

The exact renamed final release APK is installed on the separate Activity09Fresh target. The final release smoke transcript and screenshots record folder/card creation, card edit returning 1, suit fallback, cold restart with changed process ID, confirmed card deletion and folder deletion. See `evidence/release_ui_final.txt`, `release_restart_final.txt`, `release_smoke_log_final.txt`, `release_final_*.png`, `release_build.txt` and `release_sha256.txt` for the actual returned IDs/counts and final binary identity. Exact final release APK installed on Activity09Fresh emulator-5556. Created folder ID 3, card ID 2; title Final card then Final revised, notes Final binary verified, Hearts fallback. Before restart PID 11337; absent after am force-stop; after launch PID 12299. Same folder/card IDs and count 1 visible after restart. Card delete 1 row, folder delete 1 row, fresh empty folder rename 1 row. The final APK manifest has debuggable=false. An earlier release smoke run is also retained in `release_ui.txt` and `release_*` evidence, explicitly separate from the final run. The original Pixel_8 Part I installation is preserved.

### Analyzer and remaining limits

Final `flutter analyze` reports **No issues found** in `evidence/analysis_output.txt`. Android release build succeeded; the build log retains Java native-access warnings. No failing required test is hidden. Android/iOS source is provided, but iOS was not run. Missing network image/file scenarios, forced read failures, zero-row writes and cross-editor races were not fault-injected; the implemented handling is source-reviewed, and proposed extra tests in the DOCX are labeled unrun. Local storage has no encryption, cloud sync, production signing or backup service. The UI diagnostic logs contain fictional test records only.

## Rubric mapping

| Criterion | Evidence |
|---|---|
| Schema and data preservation 25 | database_helper.dart lifecycle; T1a/T1b rows, connection logs and schema comparison; T5 cascade |
| Models repository and CRUD 25 | models.dart typed mappings; helper bound queries; catalogue.dart forms/busy/error/cancel; T2/T3/T5/T6 |
| Image handling and usability 10 | nullable model and `_image` loader/fallback; T6_fallback.png; empty folder/fresh screen; named confirmation |
| Testing and evidence 20 | T1–T6 matrix, required screenshot names, analyzer output, exact installed release smoke evidence |
| Critical thinking and AI Lab 15 | separate Udumula_OmSwaroopReddy_CriticalThinking.docx, prompts 1–3 plus U1/U4, evidence/prediction/challenge/design/test and disclosure |
| README and delivery 5 | commands, source/platform/lockfile, public verified repository URL, named APK/DOCX; iCollege uploads/receipt remain user action |

## Credits and AI disclosure

Starter: user's completed Activity 08 project and its supplied [database helper](https://codd.cs.gsu.edu/~lhenry23/mad/ica/act08/database_helper.txt), with original schema/helper preserved in docs/part1_database_helper.dart.txt. Activity 09 SQL, lifecycle and tests follow the official assignment. References: [sqflite documentation](https://pub.dev/packages/sqflite), [Flutter SQLite cookbook](https://docs.flutter.dev/cookbook/persistence/sqlite), [SQLite foreign keys](https://www.sqlite.org/foreignkeys.html). No downloaded artwork is included; suit symbols use system text rendering and icons use Flutter Material Icons.

OpenAI Codex (based on GPT 6), October 8, 2026, generated/edited the extension, operated real Android UI tests, collected evidence, built and installed the actual release APK, and drafted the README/reflection. This is AI-operated work; it does not represent the student personally carrying out every test. Review and understand the code, adapt the reflection into your own words, and follow course AI attribution rules. No screenshots, IDs, observed test passes, links or benchmark numbers were invented. The reflection identifies selected U1/U4 questions and distinguishes observed evidence from hypothetical/unrun follow-ups.

## Three required submission files

1. `github_link.txt`: verified URL of this public repository. It contains source, Android/iOS configuration, lockfile, README and evidence; build caches, machine paths, keys and database files are excluded.
2. `Activity09_Udumula_OmSwaroopReddy.apk`: exact installed/smoke-tested release binary, uploaded separately.
3. `Udumula_OmSwaroopReddy_CriticalThinking.docx`: individual undergraduate reflection with supplied name/student ID, prompts 1–3, exactly U1/U4, evidence references and AI disclosure.

A source ZIP is also provided for convenience; it does not replace the three uploads. No iCollege upload or receipt is claimed. Upload the three files into **In-Class Activity 09 — Local Storage Part II**, confirm the repository is accessible, reopen/download each uploaded file, and save the submission receipt under the course's actual cutoff/time zone.
