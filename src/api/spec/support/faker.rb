RSpec.configure do |config|
  config.before do
    # avoid names already used as attrib namespace as tests rely on them
    # being unique (issue #7204)
    Faker::Lorem.unique.exclude(:word, [], AttribNamespace.pluck(:name))
  end
end
