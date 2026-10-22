# App Store product-page screenshots

Three black/silver feature panels per device family, in English and Simplified Chinese:

1. Screenshot → review → Apple Reminders and optional Calendar events; less retyping.
2. Mac, iPhone and iPad; on-device recognition works without a network connection; English/Chinese.
3. Actual deadlines in Apple Reminders, optional Calendar blocks, and conditional iCloud account-provider synchronization.

Genuine app captures use the built-in fictional sample. No private reminder lists, calendars or course schedule screenshots are published. The user-supplied screenshots are references only. Marketing copy never promises perfect OCR, automatic saving without review, or offline cross-device syncing.

Layout source: `Scripts/render-store-media.cjs` (Node + sharp). Input captures remain in ignored `Artifacts/StoreMedia/raw/`. The renderer crops only the Mac OS title bar/capture indicator, preserves app UI proportions and contents, and places real screens inside code-drawn presentation frames. It does not fabricate app UI. Final PNGs have no alpha channel.

Output sizes: Mac 2880×1800; iPhone large 1320×2868 and medium 1206×2622; iPad 13-inch portrait 2064×2752. Upload the sizes requested by the live App Store Connect media manager; smaller device families may inherit scaled images.

On October 20, 2026, three panels per locale were uploaded for Mac, iPhone Dynamic Island medium and iPad 13-inch: 18 uploaded images in total. The large iPhone set is retained as an optional export, not uploaded into the medium-size slot. All 24 generated PNGs passed dimension/format/no-alpha checks. Apple finished processing the uploaded screenshots, and both platform submissions reached Waiting for Review.

On October 22, App Store Connect showed iOS Ready for Distribution and macOS Rejected under guideline 5.2.5 for Apple wording in the subtitle. The subtitle was corrected separately in both languages. As a precaution, only the third Mac panel was revised to a neutral headline: "Your tasks. Your day." / "你的任务，日程更清晰。" The replacement was uploaded as `03-tasks-and-calendar.png`, leaving three panels per locale. Its tracked file remains `macOS/03-apple-and-icloud.png`. The other panels, including released iPhone/iPad assets, are unchanged. Original Mac panels are retained in ignored `Artifacts/StoreMedia/Pre-5.2.5-2026-10-22/` and Apple's Asset Library.

Rebuild with `node Scripts/render-store-media.cjs`, using a Node environment where sharp is available. Optional arguments `mac iphone ipad` select the sets to render. Contact-sheet previews and the capture-to-output manifest are written into ignored `Artifacts/StoreMedia/`.

References: [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [show your app in use](https://developer.apple.com/help/app-review/guideline-reference/2-3-3-screenshots), [iCloud Reminders setup](https://support.apple.com/guide/icloud/set-up-reminders-mmbf52194b5a/icloud).
