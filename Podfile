platform :ios, '16.0'
use_frameworks!

target 'SosMienTrung' do
  pod 'BridgefySDK'
  pod 'FirebaseCore'
  pod 'FirebaseAuth'
  pod 'FirebaseAnalytics'
  pod 'RecaptchaEnterprise'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      config.build_settings['CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER'] = 'NO'
    end
  end
end
