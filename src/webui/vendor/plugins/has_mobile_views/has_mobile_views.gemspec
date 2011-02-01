spec = Gem::Specification.new do |s|
  s.name              = "has_mobile_views"
  s.version           = "0.0.2"
  s.authors           = ["André Duffeck"]
  s.email             = ["aduffeck@suse.de"]
  s.homepage          = "http://github.com/aduffeck/has_mobile_views"
  s.summary           = "A Rails plugin which allows for rendering special templates for mobile devices."
  s.description       = <<-EOM
    This Rails plugin allows for rendering special templates for mobile devices, using the existing views and partials as a fallback.
  EOM

  s.has_rdoc         = false
  s.test_files       = Dir.glob "test/**/*_test.rb"
  s.files            = Dir["lib/**/*.rb", "lib/**/*.rake", "*.md", "LICENSE",
    "Rakefile", "rails/init.rb", "generators/**/*.*", "test/**/*.*"]
end
