//
//  ViewController.swift
//  OnlineScorerExample
//
//  Created by Johnny on 14/04/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

import UIKit
import AVFoundation
import EZOnlineScorer

class ViewController: UIViewController {
    
    var recordURL: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("testAudio.aac", isDirectory: false)
    }
    
    lazy var recordButton: UIButton = UIButton(type: .system)
    lazy var playButton: UIButton = UIButton(type: .system)
    lazy var speexButton: UIButton = UIButton(type: .system)
    lazy var volumeLabel: UILabel = UILabel()
    lazy var referenceTextField: UITextField = UITextField()
    lazy var configureButton: UIButton = UIButton(type: .system)
    lazy var reportTextView: UITextView = UITextView()
    
    let defaultReadAloadText = "I will study English very hard."
    var scorer: EZOnlineScorerRecorder?
    var player: AVPlayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //setup configureButton
        view.addSubview(configureButton)
        configureButton.translatesAutoresizingMaskIntoConstraints = false
        configureButton.setTitle("configure", for: .normal)
        configureButton.addTarget(self, action: #selector(configureAppID), for: .touchUpInside)
        view.addConstraint(NSLayoutConstraint(item: configureButton, attribute: .centerX, relatedBy: .equal,
                                              toItem: view, attribute: .centerX, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: configureButton, attribute: .centerY, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 1, constant: 0))

    }
    
    func setupRecordUI()
    {
        configureButton.removeFromSuperview()
        
        view.addSubview(referenceTextField)
        referenceTextField.borderStyle = .line
        referenceTextField.placeholder = "Enter read text here"
        referenceTextField.text = defaultReadAloadText
        referenceTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(NSLayoutConstraint(item: referenceTextField, attribute: .centerX, relatedBy: .equal,
                                              toItem: view, attribute: .centerX, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: referenceTextField, attribute: .centerY, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 1, constant: -40))

        view.addSubview(recordButton)
        recordButton.addTarget(self, action: #selector(record), for: .touchUpInside)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(NSLayoutConstraint(item: recordButton, attribute: .trailing, relatedBy: .equal,
                                              toItem: view, attribute: .centerX, multiplier: 1, constant: -10))
        view.addConstraint(NSLayoutConstraint(item: recordButton, attribute: .centerY, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 1, constant: 0))

        view.addSubview(playButton)
        playButton.setTitle("播放", for: .normal)
        playButton.addTarget(self, action: #selector(play), for: .touchUpInside)
        playButton.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(NSLayoutConstraint(item: playButton, attribute: .leading, relatedBy: .equal,
                                              toItem: view, attribute: .centerX, multiplier: 1, constant: +10))
        view.addConstraint(NSLayoutConstraint(item: playButton, attribute: .centerY, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 1, constant: 0))
        
        view.addSubview(speexButton)
        speexButton.setTitle("speex off", for: .normal)
        speexButton.setTitle("speex on", for: .selected)
        speexButton.isSelected = true
        speexButton.addTarget(self, action: #selector(setSpeex), for: .touchUpInside)
        speexButton.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(NSLayoutConstraint(item: speexButton, attribute: .centerX, relatedBy: .equal,
                                              toItem: view, attribute: .centerX, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: speexButton, attribute: .centerY, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 1, constant: +40))

        view.addSubview(volumeLabel)
        volumeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(NSLayoutConstraint(item: volumeLabel, attribute: .centerX, relatedBy: .equal,
                                              toItem: view, attribute: .centerX, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: volumeLabel, attribute: .centerY, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 1, constant: +80))
        
        view.addSubview(reportTextView)
        reportTextView.isEditable = false
        reportTextView.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(NSLayoutConstraint(item: reportTextView, attribute: .leading, relatedBy: .equal,
                                              toItem: view, attribute: .leading, multiplier: 1, constant: 10))
        view.addConstraint(NSLayoutConstraint(item: reportTextView, attribute: .trailing, relatedBy: .equal,
                                              toItem: view, attribute: .trailing, multiplier: 1, constant: 10))
        view.addConstraint(NSLayoutConstraint(item: reportTextView, attribute: .bottom, relatedBy: .equal,
                                              toItem: view, attribute: .bottom, multiplier: 1, constant: 10))
        view.addConstraint(NSLayoutConstraint(item: reportTextView, attribute: .top, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 1, constant: 100))
        
        updateUI()
    }
    
    func updateUI() {
        if let scorer = scorer {
            if scorer.isRecording {
                recordButton.isEnabled = true
                recordButton.setTitle("结束录音", for: .normal)
            } else if scorer.isProcessing {
                recordButton.isEnabled = false
                recordButton.setTitle("正在接收打分结果", for: .normal)
            } else {
                recordButton.isEnabled = true
                recordButton.setTitle("开始录音", for: .normal)
            }
        } else {
            recordButton.isEnabled = true
            recordButton.setTitle("开始录音", for: .normal)
        }
        
        reportTextView.text = ""
    }
    
    private func setupScorer() -> EZOnlineScorerRecorder {
        //setup scorer
        if referenceTextField.text?.characters.count == 0
        {
            referenceTextField.text = defaultReadAloadText
        }
        
        let payload = EZReadAloudPayload(referenceText: referenceTextField.text!)
        let scorer = EZOnlineScorerRecorder(payload: payload, useSpeex: speexButton.isSelected)!
        scorer.delegate = self
        self.scorer = scorer
        return scorer
    }
    
    //MARK: Action
    
    @objc private func configureAppID() {
        let alert = UIAlertController(title: "configure AppID and Secret", message: nil, preferredStyle: .alert)
        alert.addTextField { (appIDField) in
            appIDField.placeholder = "appID"
            appIDField.text = "test"//default appID
        }
        alert.addTextField { (secretField) in
            secretField.placeholder = "secret"
            secretField.text = "test"//default secret
        }
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { [weak alert, weak self] (_) in
            guard let textFields = alert?.textFields, textFields.count == 2 else { return }
            
            let appID = textFields[0].text!
            let secret = textFields[1].text!
            EZOnlineScorerRecorder.configureAppID(appID, secret: secret)
            
            self?.configureSocketURL()
        }))
        
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func configureSocketURL() {
        let alert = UIAlertController(title: "configure SocketURL", message: "leave field empty to use default socketURL", preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { [weak alert, weak self] (_) in
            if let socketURLString = alert?.textFields?.first?.text,
                let socketURL = URL(string: socketURLString) {
                EZOnlineScorerRecorder.setSocketURL(socketURL)
            }
            
            self?.setupRecordUI()
        }))

        present(alert, animated: true, completion: nil)
    }
    
    @objc private func setSpeex() {
        speexButton.isSelected = !speexButton.isSelected
    }
    
    @objc private func play()
    {
        if scorer?.isRecording == true { return }
        
        if player?.rate != 0 {
            player?.pause()
        }
        
        player = AVPlayer(url: recordURL)
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            player?.play()
        } catch {
            let alert = UIAlertController(title: "播放失败", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好的", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @objc private func record() {
        let scorer = self.scorer ?? setupScorer()
        
        if scorer.isProcessing {
            if scorer.isRecording {
                scorer.stopRecording()
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self, weak scorer] (success) in
                DispatchQueue.main.async {
                    guard let `self` = self else { return }
                    
                    if success {
                        do {
                            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord)
                            try AVAudioSession.sharedInstance().setActive(true)
                            scorer?.record(to: self.recordURL)
                        } catch {
                            let alert = UIAlertController(title: "未能开启录音", message: error.localizedDescription, preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "好的", style: .default, handler: nil))
                            self.present(alert, animated: true, completion: nil)
                        }
                    } else {
                        let alert = UIAlertController(title: "未能开启录音", message: "请开启录音权限，否则不能录音", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "好的", style: .default, handler: nil))
                        self.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
}

extension ViewController: EZOnlineScorerRecorderDelegate {
    func onlineScorerDidBeginReading(_ reader: EZOnlineScorerRecorder) {
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }
    
    func onlineScorerDidStop(_ reader: EZOnlineScorerRecorder) {
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }
    
    func onlineScorer(_ reader: EZOnlineScorerRecorder, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            self.updateUI()
            self.volumeLabel.text = ""
            self.reportTextView.text = "\(error)"
            let alert = UIAlertController(title: "打分错误", message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好的", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            self.scorer = nil
        }
    }
    
    func onlineScorer(_ audioSocket: EZOnlineScorerRecorder, didGenerateReport report: [AnyHashable : Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            self.updateUI()
            self.volumeLabel.text = ""
            let reportData = try! JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted])
            let reportString = String(data: reportData, encoding: .utf8)
            self.reportTextView.text = reportString
            self.scorer = nil
        }
    }
    
    func onlineScorer(_ reader: EZOnlineScorerRecorder, didVolumnChange volumn: Float) {
        volumeLabel.text = String(format: "音量：%.3f", volumn)
    }
}
