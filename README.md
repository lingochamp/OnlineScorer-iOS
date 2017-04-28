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

---

# 安装

使用 OnlineScorer 需要 deployment target 为 iOS8.0 以上。

OnlineScorer 当前仅支持把项目的 `EZOnlineScorer.xcodeproj` 文件拖进你的 project/workspace 中以动态链接库的形式集成。
CocoaPods 和 Carthage 支持，以及静态库支持在计划中，但不做任何保证。

把项目的 `EZOnlineScorer.xcodeproj` 文件拖进你的 project/workspace 后，

1. 在项目的 target settings 中的 "General" tab，点击 "Embedded Binaries" 下方加号，添加 "EZOnlineScorer.framework"。
2. 继续在"General" tab，点击 "Linked Frameworks and Libraries" 下方加号，添加 "libicucore.tbd"。

在 ObjC 中引用 OnlineScorer, 需要 `#import <EZOnlineScorer/EZOnlineScorer.h>`
如果你的项目使用 swift 编写，你可以添加 `#import <EZOnlineScorer/EZOnlineScorer.h>` 到你的 swift 
bridging header, 也可以在 swift 文件中使用 `import EZOnlineScorer`.

## 使用方法

EZOnlineScorer 的主类是 EZOnlineScorerRecorder。在录音前需要配置好 AppID 和 secret。如果需要也可以配置 socketURL。

```
EZOnlineScorerRecorder.configureAppID("test", secret: "test")
//set socket URL only when needed
EZOnlineScorerRecorder.setSocketURL(URL(string: "ws://test.test:1080/test")!)
```

在线打分需要先创建一个 scorer payload 对象（目前只支持 EZReadAloudPayload），再使用这个 scorer payload 创建 EZOnlineScorerRecorder。

```
let payload = EZReadAloudPayload(referenceText: "I will study Endlish very hard!")
let scorer = EZOnlineScorerRecorder(payload: payload)!
```

需要注意 EZOnlineScorerRecorder 不负责管理 AVAduioSession。你需要自行申请录音权限并设置正确的 AVAudioSession category 并在录音前激活 
AVAudioSession，否则录音会直接失败。

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

当结束录音时调用 stopRecording()，EZOnlineScorerRecorder 需要一些时间和服务器交换数据，可以通过 isProcessing & isRecording 属性来确定当前状态。
当打分、录音状态变化或者报告生成后，EZOnlineScorerRecorder 会通知它的 delegate。
