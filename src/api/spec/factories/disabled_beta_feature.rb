FactoryBot.define do
  factory :disabled_beta_feature do
    name { 'something' } # It needs to be enabled: Flipper[name].enable
    user
  end
end
