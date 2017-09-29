//
//  ViewController.swift
//  OnlineScorerExample
//
//  Created by Johnny on 14/04/2017.
//  Copyright © 2017 LLS. All rights reserved.
//

import UIKit
import AVFoundation

// comment next line if NO `use_frameworks!` mark in Podfile
import EZOnlineScorer

class ViewController: UIViewController {
    
    lazy var tableView: UITableView = UITableView(frame: .zero, style: .grouped)
    
    var recordURL: URL {
        return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true).appendingPathComponent("testAudio.aac", isDirectory: false)
    }
    
    lazy var configureButton: UIButton = UIButton(type: .system)
    
    enum ScorerType: String {
        case asr, readAload
    }
    
    var scorerType: ScorerType = .readAload {
        didSet {
            if oldValue != scorerType {
                tableView.reloadRows(at: [IndexPath(row: 0, section: 0)], with: .none)
                switch scorerType {
                case .asr:
                    readAloadText = ""
                case .readAload:
                    readAloadText = defaultReadAloadText
                }
            }
        }
    }
    var readAloadText = defaultReadAloadText {
        didSet {
            tableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none)
        }
    }
    var reportDescription = "" {
        didSet {
            tableView.reloadRows(at: [IndexPath(row: 0, section: 2)], with: .none)
        }
    }
    let cellReuseIdentifier = "UITableViewCell"
    var useSpeex = true
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
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraint(NSLayoutConstraint(item: tableView, attribute: .leading, relatedBy: .equal,
                                              toItem: view, attribute: .leading, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: tableView, attribute: .trailing, relatedBy: .equal,
                                              toItem: view, attribute: .trailing, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: tableView, attribute: .top, relatedBy: .equal,
                                              toItem: view, attribute: .top, multiplier: 1, constant: 0))
        view.addConstraint(NSLayoutConstraint(item: tableView, attribute: .bottom, relatedBy: .equal,
                                              toItem: view, attribute: .bottom, multiplier: 1, constant: 0))
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    @discardableResult func setupScorer() -> EZOnlineScorerRecorder {
        //setup scorer
        let payload: EZOnlineScorerRecorderPayload
        switch scorerType {
        case .readAload:
            if readAloadText.isEmpty {
                readAloadText = defaultReadAloadText
            }
            payload = EZReadAloudPayload(referenceText: readAloadText)
        case .asr:
            payload = EZASRPayload()
        }
        
        reportDescription = ""
        let scorer = EZOnlineScorerRecorder(payload: payload, useSpeex: useSpeex)!
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
            
            EZOnlineScorerRecorder.setDebugMode(true)
            self?.setupRecordUI()
        }))

        present(alert, animated: true, completion: nil)
    }
    
    func play()
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
    
    func record() {
        if scorer?.isRecording ?? false {
            scorer?.stopScoring()
        }
        setupScorer()
        
        if AVAudioSession.sharedInstance().recordPermission() == .granted {
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
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] (success) in
                DispatchQueue.main.async {
                    guard let `self` = self else { return }
                    
                    if !success {
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
    func onlineScorerDidBeginRecording(_ scorer: EZOnlineScorerRecorder) {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: .none)
        }
    }
    
    func onlineScorerDidFinishRecording(_ scorer: EZOnlineScorerRecorder) {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadRows(at: [IndexPath(row: 2, section: 0), IndexPath(row: 3, section: 0)], with: .none)
        }
    }
    
    func onlineScorer(_ scorer: EZOnlineScorerRecorder, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            self.tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: .none)
            self.reportDescription = "\(error)"
        }
    }
    
    func onlineScorer(_ scorer: EZOnlineScorerRecorder, didGenerateReport report: [AnyHashable : Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let `self` = self else { return }
            
            self.tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: .none)
            let reportData = try! JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted])
            let reportString = String(data: reportData, encoding: .utf8)
            self.reportDescription = reportString ?? ""
        }
    }
    
    func onlineScorer(_ scorer: EZOnlineScorerRecorder, didVolumnChange volumn: Float) {
        if let cell = tableView.cellForRow(at: IndexPath(row: 2, section: 0)) {
            cell.detailTextLabel?.text = String(format: "%.3f", volumn)
        }
    }
}

extension ViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 4
        case 1:
            return 7
        case 2:
            return 1
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier) ?? UITableViewCell(style: .value1, reuseIdentifier: cellReuseIdentifier)
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.numberOfLines = 0
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
          cell.accessoryType = .disclosureIndicator
          cell.textLabel?.text = "Type"
          cell.detailTextLabel?.text = scorerType.rawValue
        case (0, 1):
            cell.accessoryType = .none
            cell.textLabel?.text = readAloadText
            cell.detailTextLabel?.text = ""
        case (0, 2):
            cell.accessoryType = .none
            cell.textLabel?.text = "volumn"
            cell.detailTextLabel?.text = ""
        case (0, 3):
            cell.accessoryType = .none
            cell.textLabel?.text = "state"
            cell.detailTextLabel?.text = {
                if let scorer = scorer {
                    if scorer.isRecording {
                        return "recording"
                    } else if scorer.isProcessing {
                        return "receiving result"
                    } else {
                        return "finished"
                    }
                } else {
                    return "ready to record"
                }
            }()
        case (1, 0):
            cell.accessoryType = useSpeex ? .checkmark : .none
            cell.textLabel?.text = "use speex"
            cell.detailTextLabel?.text = ""
        case (1, 1):
            cell.accessoryType = .none
            cell.textLabel?.text = "record"
            cell.detailTextLabel?.text = ""
        case (1, 2):
            cell.accessoryType = .none
            cell.textLabel?.text = "stop record"
            cell.detailTextLabel?.text = ""
        case (1, 3):
            cell.accessoryType = .none
            cell.textLabel?.text = "stop scoring"
            cell.detailTextLabel?.text = ""
        case (1, 4):
            cell.accessoryType = .none
            cell.textLabel?.text = "retry"
            cell.detailTextLabel?.text = ""
        case (1, 5):
            cell.accessoryType = .none
            cell.textLabel?.text = "play"
            cell.detailTextLabel?.text = ""
        case (1, 6):
            cell.accessoryType = .none
            cell.textLabel?.text = "export debug log"
            cell.detailTextLabel?.text = ""
        case (2, 0):
            cell.accessoryType = .none
            cell.textLabel?.text = reportDescription
            cell.detailTextLabel?.text = ""
        default:
            break
        }
        return cell
    }
}

extension ViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 2 || (indexPath.section == 0 && indexPath.row == 1) {
            return UITableViewAutomaticDimension
        }
        return 44
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch (indexPath.section, indexPath.row) {
        case (0, 0):
            let alert = UIAlertController(title: "set scorer type", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "ASR", style: .default, handler: { [weak self] (_) in
                self?.scorerType = .asr
            }))
            alert.addAction(UIAlertAction(title: "ReadAload", style: .default, handler: { [weak self] (_) in
                self?.scorerType = .readAload
            }))
            present(alert, animated: true, completion: nil)
        case (0, 1):
            let alert = UIAlertController(title: "set spoken text", message: nil, preferredStyle: .alert)
            alert.addTextField(configurationHandler: nil)
            alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { [weak alert, weak self] (_) in
                guard let textFields = alert?.textFields, textFields.count == 1 else { return }
                
                self?.readAloadText = textFields[0].text!
            }))
            
            present(alert, animated: true, completion: nil)
        case (1, 0):
            useSpeex = !useSpeex
            if let cell = tableView.cellForRow(at: indexPath) {
                cell.accessoryType = useSpeex ? .checkmark : .none
            }
        case (1, 1):
            record()
        case (1, 2):
            scorer?.stopRecording()
        case (1, 3):
            scorer?.stopScoring()
        case (1, 4):
            scorer?.retry()
            self.tableView.reloadRows(at: [IndexPath(row: 2, section: 0)], with: .none)
        case (1, 5):
            play()
        case (1, 6):
            EZOnlineScorerRecorder.exportDebugLog { _, logURL in
                if logURL != nil {
                    DispatchQueue.main.async {
                        let activityViewController = UIActivityViewController(activityItems: [logURL!], applicationActivities: nil)
                        self.present(activityViewController, animated: true, completion: nil)
                    }
                    
                }
            }
        default:
            break
        }
    }
}
