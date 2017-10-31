FactoryGirl.define do
  factory :kiwi_preference_type, class: Kiwi::PreferenceType do
    image_type 'docker'
    containerconfig_name 'my_container'
    containerconfig_tag 'latest'
  end
end
