//
//  ViewController.swift
//  OnlineScorerSDKDemo
//
//  Created by Johnny on 27/03/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    var recordURL: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("testAudio.aac", isDirectory: false)
    }
    
    lazy var recordButton: UIButton = UIButton(type: .system)
    lazy var volumeLabel: UILabel = UILabel()
    lazy var referenceTextField: UITextField = UITextField()
    
    let defaultReadAloadText = "I will study English very hard."
    var scorer: EZOnlineScorerRecorder?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        view.addSubview(recordButton)
        recordButton.addTarget(self, action: #selector(record), for: .touchUpInside)
        recordButton.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(NSLayoutConstraint(item: recordButton, attribute: .centerX, relatedBy: .equal,
                                              toItem: view, attribute: .centerX, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: recordButton, attribute: .centerY, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 1, constant: 0))
        
        view.addSubview(volumeLabel)
        volumeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(NSLayoutConstraint(item: volumeLabel, attribute: .centerX, relatedBy: .equal,
                                              toItem: view, attribute: .centerX, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: volumeLabel, attribute: .centerY, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 1, constant: +40))
        
        view.addSubview(referenceTextField)
        referenceTextField.borderStyle = .line
        referenceTextField.placeholder = "Enter read text here"
        referenceTextField.text = defaultReadAloadText
        referenceTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(NSLayoutConstraint(item: referenceTextField, attribute: .centerX, relatedBy: .equal,
                                              toItem: view, attribute: .centerX, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: referenceTextField, attribute: .centerY, relatedBy: .equal,
                                              toItem: view, attribute: .centerY, multiplier: 1, constant: -40))
        
        
        updateUI()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func setupScorer() -> EZOnlineScorerRecorder {
        //setup scorer
        if referenceTextField.text?.characters.count == 0
        {
           referenceTextField.text = defaultReadAloadText
        }
        
        let payload = EZReadAloudPayload(referenceText: referenceTextField.text!)
        let scorer = EZOnlineScorerRecorder(payload: payload)!
        scorer.delegate = self
        self.scorer = scorer
        return scorer
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
            let alert = UIAlertController(title: "打分报告", message: "\(report)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好的", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            self.scorer = nil
        }
    }
    
    func onlineScorer(_ reader: EZOnlineScorerRecorder, didVolumnChange volumn: Float) {
        volumeLabel.text = String(format: "音量：%.3f", volumn)
    }
}
