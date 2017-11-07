FactoryGirl.define do
  factory :kiwi_preference, class: Kiwi::Preference do
    type_image 'docker'
    type_containerconfig_name 'my_container'
    type_containerconfig_tag 'latest'
  end
end
