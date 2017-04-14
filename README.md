### OnlineScorer-iOS

---

OnlineScorer for iOS. 

## Installation

OnlineScorer require development target iOS 8.0 or later.

OnlineScorer currently only available by dragging `EZOnlineScorer.xcodeproj` into your project/workspace, 
as Dynamic Framework. CocoaPods and Carthage support will be latter on as well as static library support (no guarantee).

After adding xcodeproj file into your project, do as following.

1. Go to "General" tab in target settings. In "Embedded Binaries" section, click plus button and add "EZOnlineScorer.framework".

2. Still in "General" tab, In "Linked Frameworks and Libraries" section, click plus button and add "libicucore.tbd"

To import OnlineScorer to ObjC, add `#import <EZOnlineScorer/EZOnlineScorer.h>`
if your project witten in swift, you can either add `#import <EZOnlineScorer/EZOnlineScorer.h>` into your swift 
bridging header, or just use `import EZOnlineScorer` wherever you need.

## Usage

The main class of EZOnlineScorer is EZOnlineScorerRecorder. Before start recording, configure AppID and secret. 
You can also set socketURL if needed.

```
EZOnlineScorerRecorder.configureAppID("test", secret: "test")
//set socket URL only when needed
EZOnlineScorerRecorder.setSocketURL(URL(string: "ws://test.test:1080/test")!)
```

To perform a online scoring, first create a scorer payload object (only EZReadAloudPayload is supported currently) and 
create a EZOnlineScorerRecorder using this payload.

```
let payload = EZReadAloudPayload(referenceText: "I will study Endlish very hard!")
let scorer = EZOnlineScorerRecorder(payload: payload)!
```

Note that EZOnlineScorerRecorder do not manage AVAduioSession. You need request record permission, and set AVAudioSession 
to currect category (Record or PlayAndRecord) and activate AVAudioSession before recording.

```
guard AVAudioSession.sharedInstance().recordPermission() == .granted else {
    //request record permission
    return
}
do {
    try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord)
    try AVAudioSession.sharedInstance().setActive(true)

    //begin record
    scorer.record(to: recordURL)
    //or record to a temp file
    scorer.record()
} catch {
    //failed to configure AVAudioSession 
    let alert = UIAlertController(title: "未能开启录音", message: error.localizedDescription, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "好的", style: .default, handler: nil))
    present(alert, animated: true, completion: nil)
}
```

Call stopRecording() when finish recording. EZOnlineScorerRecorder need time to process, and you can check it's status by isProcessing & isRecording property. EZOnlineScorerRecorder will call it's delegate when scoring status changed or a report have generated.

