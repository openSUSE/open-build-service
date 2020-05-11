FactoryBot.define do
  factory :attrib_value do
    attrib
    # this is necessary! otherwise the default value will not be recognized.
    after(:create, &:reload)
  end
end
