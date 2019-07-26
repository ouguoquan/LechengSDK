
Pod::Spec.new do |spec|
  spec.name         = "LechengSDK"
  spec.version      = "0.0.1"
  spec.summary      = "LechengSDK."
  spec.description  = '自用的 LechengSDK.'

  spec.homepage     = "https://github.com/ouguoquan/LechengSDK"

  spec.license      = "MIT"
  spec.author             = { "ouguoquan" => "842599919@qq.com" }
  spec.platform     = :ios

  spec.ios.deployment_target = "9.0"

  spec.source       = { :git => "https://github.com/ouguoquan/LechengSDK.git", :tag => "#{spec.version}" }

  spec.source_files  = "Depend/**/*.{h,m}", "Depend/**/**/*.{h,m}"

  # spec.resource  = "icon.png"
   spec.resources = "Depend/*.pem"

  # spec.preserve_paths = "FilesToSave", "MoreFilesToSave"


   spec.frameworks  = "CoreAudio", "MediaPlayer", "AudioToolbox", "VideoToolbox", "OpenGLES", "MediaAccessibility", "CoreVideo", "AVFoundation", "CoreMedia"

   spec.library   = "z" #省略lib 前缀
   spec.vendored_libraries = 'Depend/*.a'

   spec.requires_arc = true

  # spec.xcconfig = { "HEADER_SEARCH_PATHS" => "$(SDKROOT)/usr/include/libxml2" }

end
