# This class represents saved replies you can use when writing a comment
class CommentSnippet < ApplicationRecord
  belongs_to :user, inverse_of: :comment_snippets

  validates :title, :body, :user, presence: true
  validates :title, length: { maximum: 255 }
  validates :body, length: { maximum: 16.megabytes - 1 }
  validates :body, format: { with: /\A[^\u0000]*\Z/,
                             message: 'must not contain null characters' }
end

# == Schema Information
#
# Table name: comment_snippets
#
#  id         :integer          not null, primary key
#  body       :text(16777215)   not null
#  title      :string(255)      not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer          not null, indexed
#
# Indexes
#
#  index_comment_snippets_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
