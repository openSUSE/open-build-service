# This model implements the locking mechanism to allow or disallow commenting
# on Projects, Packages, Requests and Request actions etc.
class CommentLock < ApplicationRecord
  # belongs to a Project, Package, BsRequest or BsRequestActionSubmit
  belongs_to :commentable, polymorphic: true

  # The user that locked the comments. It can be a proper Moderator, a package
  # or project Maintainer or a Request's target maintainer
  belongs_to :moderator, class_name: 'User'

  # Prevent locking comments twice
  validates :commentable_id, uniqueness: { scope: :commentable_type }
end

# == Schema Information
#
# Table name: comment_locks
#
#  id               :bigint           not null, primary key
#  commentable_type :string(255)      not null, indexed => [commentable_id]
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  commentable_id   :integer          not null, indexed => [commentable_type]
#  moderator_id     :integer          not null, indexed
#
# Indexes
#
#  fk_rails_238113656b                                         (moderator_id)
#  index_comment_locks_on_commentable_type_and_commentable_id  (commentable_type,commentable_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (moderator_id => users.id)
#
