Gem::Specification.new do |s|
  s.name        = 'co-kamishibai'
  s.version     = '0.9.4'
  s.date        = '2013-11-10'
  s.summary     = "co-kamishibai"
  s.description = "Mini standalone Manga/Comic/CBZ Mini Web Server"
  s.authors     = ["Mac Ma"]
  s.homepage    = 'https://github.com/comomac/co-kamishibai'
  s.license     = 'bsd-2-clause'

  s.required_rubygems_version = '>= 2.0.3'
  s.rubyforge_project = 'co-kamishibai'

  s.add_dependency 'haml',      '>= 4.0.3'
  s.add_dependency 'ffi',       '>= 1.9.0'
  s.add_dependency 'gd2-ffij',  '>= 0.1.1'
  s.add_dependency 'json',      '>= 1.7.7'
  s.add_dependency 'rubyzip',   '>= 1.0.0'
  s.add_dependency 'sinatra',   '>= 1.4.4'
  s.add_dependency 'thin',      '>= 1.6.0'
  
  s.executable = 'co-kamishibai'
  s.require_path = 'lib'
  s.files = Dir.glob('**/*')
  s.files.reject! { |fn| fn.include?( '.gem' ) }
  s.files.reject! { |fn| fn.include?( '.git' ) }
  s.files.reject! { |fn| fn.include?( '.sublime-' ) }
  s.files.reject! { |fn| fn.include?( '._' ) }
  s.files.reject! { |fn| fn.include?( '.DS_Store' ) }
end