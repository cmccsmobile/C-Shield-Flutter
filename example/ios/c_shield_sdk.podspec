#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
#
Pod::Spec.new do |s|
  s.name             = 'c_shield_sdk'
  s.version          = '0.0.1'
  s.summary          = 'CShield Flutter SDK plugin for iOS'
  s.description      = 'Flutter plugin wrapping CShieldSDK XCFramework (RASP, SSL pinning, AIP)'
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'CMCCS' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # CShieldSDK không được bundle trong plugin — host app cung cấp via Libs/Debug|Release/.
  # Khai báo framework để CocoaPods thêm -framework CShieldSDK vào OTHER_LDFLAGS.
  # FRAMEWORK_SEARCH_PATHS (variant-specific) phải được set trong Podfile của host app.
  s.frameworks = 'CShieldSDK'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.0'
end
