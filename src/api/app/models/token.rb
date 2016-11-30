class Token < ApplicationRecord
  belongs_to :user, foreign_key: 'user_id', inverse_of: :tokens
  belongs_to :package, inverse_of: :tokens

  validates :user_id, presence: true
  after_create :update_token

  def self.find_by_string(token)
    token = Token.where(string: token.to_s).includes(:package, :user).first
    return nil unless token && token.user_id

    # package found and user has write access
    token
  end

  def update_token
    # base64 with a length that is a multiple of 3 avoids trailing "=" chars
    self.string = SecureRandom.base64(30) # 30 bytes leads to 40 chars string
    save!
  end
end
