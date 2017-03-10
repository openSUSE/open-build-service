class Token < ApplicationRecord
  belongs_to :user, foreign_key: 'user_id', inverse_of: :tokens
  belongs_to :package, inverse_of: :tokens

  validates :user_id, presence: true
  after_create :update_token

  def self.find_by_string(token)
    token = Token.where(string: token.to_s).includes(:package, :user).first
    return unless token && token.user_id

    # package found and user has write access
    token
  end

  def update_token
    # base64 with a length that is a multiple of 3 avoids trailing "=" chars
    self.string = SecureRandom.base64(30) # 30 bytes leads to 40 chars string
    save!
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id         :integer          not null, primary key
#  string     :string(255)
#  user_id    :integer          not null
#  package_id :integer
#
# Indexes
#
#  index_tokens_on_string  (string) UNIQUE
#  package_id              (package_id)
#  user_id                 (user_id)
#
