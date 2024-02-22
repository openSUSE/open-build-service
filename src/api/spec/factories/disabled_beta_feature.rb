FactoryBot.define do
  factory :disabled_beta_feature do
    name { 'something' } # It needs to be enabled: Flipper[name].enable
    user

    before(:create) do |dbf|
      dbf.feature = Flipper::Adapters::ActiveRecord::Feature.create(key: dbf.name) if dbf.feature.nil?
    end
  end
end
