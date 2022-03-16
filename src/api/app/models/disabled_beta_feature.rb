class DisabledBetaFeature < ApplicationRecord
  validates :name, presence: true
  validates :user_id, uniqueness: { scope: :name }

  belongs_to :user
  # rubocop:disable Rails/InverseOf
  # This is an internal model from the flipper-active_record gem, so we cannot set inverse_of
  belongs_to :feature, foreign_key: :name, class_name: 'Flipper::Adapters::ActiveRecord::Feature', primary_key: :key
  # rubocop:enable Rails/InverseOf
end

# == Schema Information
#
# Table name: disabled_beta_features
#
#  id         :integer          not null, primary key
#  name       :string(255)      not null, indexed => [user_id]
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          indexed => [name]
#
# Indexes
#
#  index_disabled_beta_features_on_user_id_and_name  (user_id,name) UNIQUE
#
