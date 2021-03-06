#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_snapchat.podspec' to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_snapchat'
  s.version          = '1.0.0'
  s.summary          = 'A snapchat flutter plugin'
  s.description      = <<-DESC
A snapchat flutter plugin
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '10.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  s.dependency 'SnapSDK'
  # s.dependency 'SnapSDK', '1.11.0'
end
