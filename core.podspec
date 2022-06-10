Pod::Spec.new do |s|
  s.name             = "core"
  s.version          = "1.21.0"
  s.summary          = "A lightweight, one line setup, iOS/OSX network debugging library!"
  s.description      = "A lightweight, one line setup, network debugging library"
  s.homepage         = "https://github.com/johndow/core"
  s.screenshots      = "https://raw.githubusercontent.com/johndow/core/master/assets/overview1_5_3.gif"
  s.license          = 'MIT'
  s.author           = "John Dow"
  s.source           = { :git => "https://github.com/johndow/core.git", :tag => "#{s.version}" }
  s.swift_versions = '5.0'
  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'
  s.requires_arc = true
  s.source_files = "core/Core/*.{swift}"
  s.ios.source_files = "core/iOS/*.swift"
  s.osx.source_files = "core/OSX/*.{swift,xib}"
end
