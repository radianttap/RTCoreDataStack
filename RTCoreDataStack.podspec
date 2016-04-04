Pod::Spec.new do |s|
  s.name         = 'RTCoreDataStack'
  s.version      = '1.0'
  s.summary      = 'A CoreData library with lots of options to initialize the data model and option to use it as singleton, or not. Especially useful and usable for heavy background processing, since - by default - it uses setup with two PSCs, one for reading in the main thread and one for writing in background thread.'
  s.homepage     = 'https://github.com/radianttap/RTCoreDataStack'
  s.license      = 'MIT'
  s.author       = { 'Aleksandar Vacić' => 'radianttap.com' }
  s.source       = { :git => "https://github.com/radianttap/RTCoreDataStack.git", :tag => "#{s.version}" }
  s.platform     = :ios, '8.0'
  s.source_files = 'RTCoreDataStack/*.{h,m}'
  s.frameworks   = 'CoreData'
  s.requires_arc = true
end
