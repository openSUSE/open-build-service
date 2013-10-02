$:.push File.expand_path("../lib", __FILE__)

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "webui"
  s.version     = "1.0"
  s.authors     = ["Stephan Kulow et al :)"]
  s.email       = ["opensuse-buildservice@opensuse.org"]
  s.homepage    = "http://opensuse-build-service.org"
  s.summary     = "The current webui"
  s.description = "TODO: Description of WebuI."

  s.files = Dir["{app,config,db,lib}/**/*", "Rakefile"]

  s.add_dependency "rails", "~> 4.0.0"
end
