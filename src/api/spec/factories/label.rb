FactoryBot.define do
  factory :label do
    labelable { association :project }
    label_template
  end
end
