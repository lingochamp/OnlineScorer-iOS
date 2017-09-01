Pod::Spec.new do |s|

  s.name         = "EZOnlineScorer"
  s.version      = "0.0.4"
  s.summary      = "OnlineScorer for iOS."
  s.description  = <<-DESC
    An online spoken English scorer. Contact liulishuo for business license.
                   DESC
  s.homepage     = "https://www.liulishuo.com"
  s.license      = "Proprietary software"
  s.author             = { "Johnny" => "johnny.huang@liulishuo.com" }
  s.platform     = :ios, "8.0"
  s.source       = { :git => "https://github.com/lingochamp/OnlineScorer-iOS.git", :tag => "#{s.version}" }
  s.source_files  = "EZOnlineScorer/EZOnlineScorer/**/*.{h,m,c}"
  s.public_header_files = "EZOnlineScorer/EZOnlineScorer/EZOnlineScorer.h", 
    "EZOnlineScorer/EZOnlineScorer/Payload/*.h",
    "EZOnlineScorer/EZOnlineScorer/OnlineScorerRecorder/EZOnlineScorerRecorder.h"
  s.vendored_library = "EZOnlineScorer/EZOnlineScorer/Speex/libspeex.a"
  s.library   = "icucore"
  s.requires_arc = true

end
