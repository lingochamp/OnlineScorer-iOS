### OnlineScorer-iOS

---

OnlineScorer for iOS. 

## Installation

OnlineScorer require development target iOS 8.0 or later.

OnlineScorer is available as dynamic framework or static library. There are two ways to use
 OnlineScorer in your project:
- using CocoaPods
- manually installation

We highly recommend using CocoaPods to intergrate OnlineScorer into your project.

### Installation with CocoaPods

[CocoaPods](http://cocoapods.org/) is a dependency manager for Objective-C, which automates 
and simplifies the process of using 3rd-party libraries in your projects. See the 
[Get Started](http://cocoapods.org/#get_started) section for more details.

#### Podfile
```
platform :ios, '8.0'
use_frameworks!

pod 'EZOnlineScorer'
```

### Manually Installation

You can download latest libraries at [OnlineScorer-iOS](https://github.com/lingochamp/OnlineScorer-iOS)

After clone or download OnlineScorer into you project source directory, dragging 
`EZOnlineScorer.xcodeproj` into your project/workspace, then do as following.

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

OnlineScorer 动态链接库和静态库两种版本，支持CocoaPods和手动安装两种集成方式。我们强烈推荐使用 CocoaPods 集成。

### 使用 CocoaPods 集成

[CocoaPods](http://cocoapods.org/) 是 Objective-C 和 Swift 的包管理工具。关于如何使用 CocoaPods, 请参阅 [Get Started](http://cocoapods.org/#get_started).

#### Podfile
```
platform :ios, '8.0'
use_frameworks!

pod 'EZOnlineScorer'
```

### 手动集成

你可以在 [OnlineScorer-iOS](https://github.com/lingochamp/OnlineScorer-iOS) 下载到最新版本的 OnlineScorer.

当你下载或克隆 OnlineScorer 到你项目目录后，将`EZOnlineScorer.xcodeproj` 文件拖进你的 project/workspace 中，然后按下面的说明进行配置。

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

# 服务端返回错误列表

0 - 成功
-1 - 参数有误
-8 - 音频过长（目前限制120秒）
-20 - 认证失败
-30 - 请求过于频繁
-31 - 余额不足
-40 - 并发不足，需要重试（WeChat only）
-41 - 排队超时（WeChat excluded）
-97 - 接收音频数据超时（超过15秒没有数据包）
-99 - 计算资源不可用
-100 - 其他错误（例如从微信服务器下载音频不成功）


## 打分报告格式

EZReadAloudPayload 类型返回 json 示例

```
{
    "fluency": 99,
    "integrity": 100,
    "locale": "en",
    "overall": 100,
    "pronunciation": 100,
    "version": "2.1.0",
    "words": [
        {
            "scores": {
                "pronunciation": 100
            },
            "word": "i"
        },
        {
            "scores": {
                "pronunciation": 100
            },
            "word": "will"
        },
        {
            "scores": {
                "pronunciation": 100
            },
            "word": "study"
        },
        {
            "scores": {
                "pronunciation": 100
            },
            "word": "english"
        },
        {
            "scores": {
                "pronunciation": 100
            },
            "word": "very"
        },
        {
            "scores": {
                "pronunciation": 100
            },
            "word": "hard"
        }
    ]
}
```
