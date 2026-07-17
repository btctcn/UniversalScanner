# UniversalScanner

A small iOS app (Objective-C, UIKit) that scans barcodes/QR codes and reads a decimal number
(e.g. a price tag) off a live camera feed using on-device text recognition — no third-party
scanning library, everything is built on `AVFoundation` + `Vision`.

## What it does

Two tabs (`USCTabBarController`):

- **Scanner** (`USCScannerController`) — a segmented control switches between two modes:
  - **QR/Barcode** — `AVCaptureMetadataOutput` decodes UPC-E, EAN-8/13, Code 39/93/128,
    PDF417, QR, Aztec, Interleaved 2 of 5, ITF-14 and Data Matrix. A yellow quad is drawn
    around the detected code once its center falls inside the on-screen cutout; the shutter
    button only becomes active while a code is centered.
  - **Number** — `VNRecognizeTextRequest` (Vision) runs on live `AVCaptureVideoDataOutput`
    frames, restricted to a region of interest, and extracts the first decimal number
    (regex `[0-9]+\.[0-9]+`) found in the frame — meant for reading a price off a tag.
  - Tapping the shutter freezes the session and hands the current value (`currentQrOrBarCode`
    or `currentTextualCode`) to the data service; tapping the result banner resumes scanning.
- **History** (`USCHistoryController`) — an in-memory, session-only list of everything captured
  from the Scanner tab. It implements the `USCDataService` protocol
  (`- (void)addEntry:(NSString *)entry;`) that `USCScannerController` is handed at init time —
  the scanner has no idea what happens to a captured value beyond that one method.

Camera preview is a custom `AVCaptureVideoPreviewLayer`-backed view (`USCPreviewView`) with an
overlaid `CAShapeLayer` for the cutout mask and detection outline; `USCCaptureButton` draws its
own shutter-button rings in `-drawRect:` instead of using image assets.

Portrait-only; device orientation is still tracked manually to keep the Vision region-of-interest
and the QR/barcode drawing transform correct when the device is rotated in-hand.

## Requirements

- Xcode with iOS 13.0+ SDK (`IPHONEOS_DEPLOYMENT_TARGET = 13.0`)
- A physical iOS device — `AVCaptureSession`/`Vision` need a camera, the Simulator can't run this
  (it builds fine on the Simulator, it just has no camera to scan with)
- No third-party dependencies — no CocoaPods/Carthage/SPM, only Apple frameworks (`AVKit`,
  `Vision`, `CoreVideo`)

## Project layout

```
UniversalScanner/
├── AppDelegate.{h,m}            — sets up the tab bar tint and root view controller
├── USCTabBarController.{h,m}    — owns the two tabs, portrait-only
├── USCScannerController.{h,m}   — camera capture, QR/barcode + text-recognition modes
├── USCPreviewView.{h,m}         — AVCaptureVideoPreviewLayer-backed camera preview
├── USCCaptureButton.{h,m}       — self-drawn shutter button
├── USCDataService.h             — protocol the scanner reports captures through
├── USCHistoryController.{h,m}   — table view of captured values (implements USCDataService)
├── USCHistoryTableViewCell.*    — table cell (nib-based)
└── UIColor+Additions.{h,m}      — UIColor(Additions) category (fromHex:), used for the tab bar tint
```

## License

[MIT](LICENSE)
