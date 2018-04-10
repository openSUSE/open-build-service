# frozen_string_literal: true

class Token < ApplicationRecord
  belongs_to :user, foreign_key: 'user_id', inverse_of: :service_tokens
  belongs_to :package, inverse_of: :tokens

  has_secure_token :string

  validates :user_id, presence: true
end

# == Schema Information
#
# Table name: tokens
#
#  id         :integer          not null, primary key
#  string     :string(255)      indexed
#  user_id    :integer          not null, indexed
#  package_id :integer          indexed
#  type       :string(255)
#
# Indexes
#
#  index_tokens_on_string  (string) UNIQUE
#  package_id              (package_id)
#  user_id                 (user_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (user_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
