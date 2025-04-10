class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true # belongs to a Project, Package, BsRequest or BsRequestActionSubmit
  belongs_to :user, inverse_of: :comments
  belongs_to :moderator, class_name: 'User', optional: true

  # Preloads for polymorphic commentable:
  belongs_to :project, foreign_key: 'commentable_id', optional: true

  validates :body, presence: true
  # FIXME: this probably should be MEDIUMTEXT(16MB) instead of text (64KB)
  validates :body, length: { maximum: 65_535 }
  validates :body, format: { with: /\A[^\u0000]*\Z/,
                             message: 'must not contain null characters' }
  validates :source_rev, length: { maximum: 32 }
  validates :target_rev, length: { maximum: 32 }

  validate :validate_parent_id

  validates_with CommentLockingValidator

  after_create :create_event
  after_destroy :delete_parent_if_unused
  after_commit(if: proc { commentable_type == 'BsRequest' }) { PopulateToSphinxJob.perform_later(id: commentable.id, model_name: :bs_request) }

  has_many :children, dependent: :destroy, class_name: 'Comment', foreign_key: 'parent_id'
  has_many :notifications, as: :notifiable, dependent: :delete_all
  has_many :reports, as: :reportable, dependent: :nullify

  extend ActsAsTree::TreeWalker
  acts_as_tree order: 'created_at'

  has_paper_trail

  scope :on_actions_for_request, ->(bs_request) { where(commentable: BsRequestAction.where(bs_request: bs_request)) }
  scope :without_parent, -> { where(parent_id: nil) }
  scope :newest_first, -> { order(created_at: :desc) }

  def to_s
    body
  end

  def blank_or_destroy
    if children.exists?
      self.paper_trail_event = 'delete'
      self.body = 'This comment has been deleted'
      self.user = User.find_nobody!
      save!
    else
      destroy
    end
  end

  def event_parameters
    commentable.event_parameters.merge!({ id: id,
                                          commenter: user.login,
                                          comment_body: body,
                                          commenters: involved_users,
                                          when: updated_at.strftime('%Y-%m-%dT%H:%M:%S') })
  end

  def unused_parent?
    parent && parent.user.nobody? && parent.children.empty?
  end

  def moderated?
    !!(moderated_at && moderator)
  end

  def moderate(state)
    self.paper_trail_event = state ? 'moderate' : 'release'
    self.moderated_at = state ? Time.zone.now : nil
    self.moderator = state ? User.session : nil
    save!
  end

  def body
    return "*This content was considered problematic and has been moderated at #{moderated_at} by @#{moderator}*" if moderated?
    return '*You have blocked this user. To see this comment, unblock the user in the user profile.*' if blocked?

    super
  end

  def revisions?
    return false if diff_file_index.nil?
    return false if source_rev.nil? || target_rev.nil?

    true
  end

  def outdated?
    return false unless revisions?
    return true unless commentable.target_srcmd5 == target_rev && commentable.source_srcmd5 == source_rev

    false
  end

  private

  def create_event
    case commentable_type
    when 'Package'
      Event::CommentForPackage.create(event_parameters)
    when 'Project'
      Event::CommentForProject.create(event_parameters)
    when 'BsRequest'
      Event::CommentForRequest.create(event_parameters)
    when 'BsRequestAction'
      Event::CommentForRequest.create(event_parameters.merge({ id: id, diff_file_index: diff_file_index, diff_line_number: diff_line_number }))
    end
  end

  def delete_parent_if_unused
    parent.destroy if unused_parent?
  end

  # build an array of users, commenting or being mentioned on the commentable of this comment
  def involved_users
    users = Set.new
    users_mentioned = Set.new
    Comment.where(commentable: commentable).includes(:user).find_each do |comment|
      # take the one making the comment
      users << comment.user.login
      # check if users are mentioned (regexp borrowed from user model - with whitespace removed)
      comment.body.scan(/@([\w\^\-.#*+&'"]*)/).each do |user_login|
        users_mentioned << user_login.first
      end
    end
    users += User.where(login: users_mentioned).pluck(:login)
    users.to_a
  end

  def validate_parent_id
    return unless parent_id
    return if commentable.comments.where(id: parent_id).present?

    errors.add(:parent, 'belongs to different object')
  end

  def blocked?
    return false unless (session = User.session)
    return true if session.blocked_users.exists?(user_id)

    false
  end
end

# == Schema Information
#
# Table name: comments
#
#  id               :integer          not null, primary key
#  body             :text(65535)
#  commentable_type :string(255)      indexed => [commentable_id]
#  diff_file_index  :integer
#  diff_line_number :integer
#  moderated_at     :datetime
#  source_rev       :string(255)
#  target_rev       :string(255)
#  created_at       :datetime
#  updated_at       :datetime
#  commentable_id   :integer          indexed => [commentable_type]
#  moderator_id     :integer          indexed
#  parent_id        :integer          indexed
#  user_id          :integer          not null, indexed
#
# Indexes
#
#  index_comments_on_commentable_type_and_commentable_id  (commentable_type,commentable_id)
#  moderated_comments_fk                                  (moderator_id)
#  parent_id                                              (parent_id)
#  user_id                                                (user_id)
#
# Foreign Keys
#
#  comments_ibfk_1        (user_id => users.id)
#  comments_ibfk_4        (parent_id => comments.id)
#  moderated_comments_fk  (moderator_id => users.id)
#
