FactoryBot.define do
  factory :patchinfo, class: 'Patchinfo' do
    # Patchinfo is an ActiveModel::Model. Override FactoryBot `create` method
    skip_create
  end
end
