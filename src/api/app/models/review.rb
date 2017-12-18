require 'api_exception'

class Review < ApplicationRecord
  class NotFoundError < APIException
    setup 'review_not_found', 404, 'Review not found'
  end

  VALID_REVIEW_STATES = [:new, :declined, :accepted, :superseded, :obsoleted].freeze

  belongs_to :bs_request, touch: true
  has_many :history_elements, -> { order(:created_at) }, class_name: 'HistoryElement::Review', foreign_key: :op_object_id
  has_many :history_elements_assigned, class_name: 'HistoryElement::ReviewAssigned', foreign_key: :op_object_id
  validates :state, inclusion: { in: VALID_REVIEW_STATES }

  validates :by_user, length: { maximum: 250 }
  validates :by_group, length: { maximum: 250 }
  validates :by_project, length: { maximum: 250 }
  validates :by_package, length: { maximum: 250 }
  validates :reviewer, length: { maximum: 250 }
  validates :reason, length: { maximum: 65534 }

  validate :check_initial, on: [:create]
  # Validate the review is not assigned to a review which is already assigned to this review
  validate :validate_non_symmetric_assignment
  validate :validate_not_self_assigned

  belongs_to :user
  belongs_to :group
  belongs_to :project
  belongs_to :package

  belongs_to :review_assigned_from, class_name: 'Review', foreign_key: :review_id
  has_one :review_assigned_to, class_name: 'Review', foreign_key: :review_id

  scope :assigned, lambda {
    left_outer_joins(:history_elements_assigned).having('COUNT(history_elements.id) > 0').group('reviews.id')
  }

  scope :unassigned, lambda {
    left_outer_joins(:history_elements_assigned).having('COUNT(history_elements.id) = 0').group('reviews.id')
  }

  scope :bs_request_ids_of_involved_projects, ->(project_ids) { where(project_id: project_ids, state: :new).select(:bs_request_id) }
  scope :bs_request_ids_of_involved_packages, ->(package_ids) { where(package_id: package_ids, state: :new).select(:bs_request_id) }
  scope :bs_request_ids_of_involved_groups, ->(group_ids) { where(group_id: group_ids, state: :new).select(:bs_request_id) }
  scope :bs_request_ids_of_involved_users, ->(user_ids) { where(user_id: user_ids).select(:bs_request_id) }

  before_validation(on: :create) do
    self.state = :new if self[:state].nil?
  end

  before_validation :set_reviewable_association
  after_commit :update_cache

  def validate_non_symmetric_assignment
    return unless review_assigned_from && review_assigned_from == review_assigned_to

    errors.add(
      :review_id,
      'assigned to review which is already assigned to this review'
    )
  end

  def validate_not_self_assigned
    return unless persisted? && id == review_id
    errors.add(:review_id, 'recursive assignment')
  end

  def state
    self[:state].to_sym
  end

  def accepted_at
    if review_assigned_to && review_assigned_to.state == :accepted
      review_assigned_to.accepted_history_element.created_at
    elsif state == :accepted && !review_assigned_to
      accepted_history_element.created_at
    end
  end

  def declined_at
    if review_assigned_to && review_assigned_to.state == :declined
      review_assigned_to.declined_history_element.created_at
    elsif state == :declined && !review_assigned_to
      declined_history_element.created_at
    end
  end

  def accepted_history_element
    history_elements.find_by(type: 'HistoryElement::ReviewAccepted')
  end

  def declined_history_element
    history_elements.find_by(type: 'HistoryElement::ReviewDeclined')
  end

  def assigned_reviewer
    self[:reviewer] || by_user || by_group || by_project || by_package
  end

  def check_initial
    # Validates the existence of references.
    # NOTE: they can disappear later and the review should be still
    #       usable to some degree (can be showed at least)
    #       But it must not be possible to create one with broken references
    unless by_user || by_group || by_project
      errors.add(:unknown, 'no reviewer defined')
    end

    if validate_reviewer_fields
      errors.add(:base, 'it is not allowed to have more than one reviewer entity: by_user, by_group, by_project, by_package')
    end

    errors.add(:by_user, "#{by_user} not found") if by_user && !user

    errors.add(:by_group, "#{by_group} not found") if by_group && !group

    if by_project && !project
      # must be a local project or we can't ask
      errors.add(:by_project, "#{by_project} not found")
    end

    if by_package && !by_project
      errors.add(:unknown, 'by_package defined, but missing by_project')
    end
    return unless by_package && !package

    # must be a local package. maybe we should rewrite in case the
    # package comes via local project link...
    errors.add(:by_package, "#{by_project}/#{by_package} not found")
  end

  def self.new_from_xml_hash(hash)
    r = Review.new

    r.state = hash.delete('state') { raise ArgumentError, 'no state' }
    r.state = r.state.to_sym

    r.by_user = hash.delete('by_user')
    r.by_group = hash.delete('by_group')
    r.by_project = hash.delete('by_project')
    r.by_package = hash.delete('by_package')

    r.reviewer = r.creator = hash.delete('who')
    r.reason = hash.delete('comment')
    begin
      r.created_at = Time.zone.parse(hash.delete('when'))
    rescue TypeError
      # no valid time -> ignore
    end

    raise ArgumentError, "too much information #{hash.inspect}" if hash.present?
    r
  end

  def _get_attributes
    attributes = { state: state.to_s }
    # old requests didn't have who and when
    attributes[:when] = created_at.strftime('%Y-%m-%dT%H:%M:%S')
    attributes[:who] = reviewer if reviewer
    attributes[:by_group] = by_group if by_group
    attributes[:by_user] = by_user if by_user
    attributes[:by_package] = by_package if by_package
    attributes[:by_project] = by_project if by_project

    attributes
  end

  def render_xml(builder)
    builder.review(_get_attributes) do
      builder.comment! reason if reason
      history_elements.each do |history|
        history.render_xml(builder)
      end
    end
  end

  def webui_infos
    ret = _get_attributes
    # XML has this perl format, don't use that here
    ret[:when] = created_at
    ret
  end

  def reviewers_for_obj(obj)
    return [] unless obj
    relationships = obj.relationships
    roles = relationships.where(role: Role.hashed['maintainer'])
    User.where(id: roles.users.pluck(:user_id)) + Group.where(id: roles.groups.pluck(:group_id))
  end

  def users_and_groups_for_review
    return [User.find_by_login!(by_user)] if by_user
    return [Group.find_by_title!(by_group)] if by_group
    if by_package
      obj = Package.find_by_project_and_name(by_project, by_package)
      return [] unless obj
      reviewers_for_obj(obj) + reviewers_for_obj(obj.project)
    else
      reviewers_for_obj(Project.find_by_name(by_project))
    end
  end

  def map_objects_to_ids(objs)
    objs.map { |obj| { "#{obj.class.to_s.downcase}_id" => obj.id } }.uniq
  end

  def create_notification(params = {})
    params = params.merge(_get_attributes)
    params[:comment] = reason
    params[:reviewers] = map_objects_to_ids(users_and_groups_for_review)

    # send email later
    Event::ReviewWanted.create params
  end

  def reviewable_by?(opts)
    by_user && by_user == opts[:by_user] ||
      by_group && by_group == opts[:by_group] ||
      by_project && by_project == opts[:by_project] ||
      by_package && by_package == opts[:by_package]
  end

  private

  # The authoritative storage are the by_ attributes as even when a record (project, package ...) got deleted
  # the review should still be usable, however, the entity association is nullified
  def set_reviewable_association
    self.package = Package.find_by_project_and_name(by_project, by_package)
    self.project = Project.find_by_name(by_project)
    self.user = User.find_by(login: by_user)
    self.group = Group.find_by(title: by_group)
  end

  def validate_reviewer_fields
    (by_user && (by_group || by_project || by_package)) || (by_group && (by_project || by_package))
  end

  def update_cache
    # rubocop:disable Rails/SkipsModelValidations
    # Skipping Model validations in this case is fine as we only want to touch
    # the associated user models to invalidate the cache keys
    if user_id
      user_ids = [user_id]
    elsif group_id
      group.touch
      user_ids = GroupsUser.where(group_id: group_id).pluck(:user_id)
    elsif package_id
      Group.joins(:relationships).where(relationships: { package_id: package_id }).update_all(updated_at: Time.now)
      user_ids = Relationship.joins(:groups_users).where(package_id: package_id).groups.pluck('groups_users.user_id')
      user_ids += Relationship.where(package_id: package_id).users.pluck(:user_id)
    elsif project_id
      Group.joins(:relationships).where(relationships: { project_id: project_id }).update_all(updated_at: Time.now)
      user_ids = Relationship.joins(:groups_users).where(project_id: project_id).groups.pluck('groups_users.user_id')
      user_ids += Relationship.where(project_id: project_id).users.pluck(:user_id)
    end
    User.where(id: user_ids).update_all(updated_at: Time.now)
    # rubocop:enable Rails/SkipsModelValidations
  end
end

# == Schema Information
#
# Table name: reviews
#
#  id            :integer          not null, primary key
#  bs_request_id :integer          indexed
#  creator       :string(255)      indexed
#  reviewer      :string(255)      indexed
#  reason        :text(65535)
#  state         :string(255)      indexed => [by_project], indexed => [by_user]
#  by_user       :string(255)      indexed, indexed => [state]
#  by_group      :string(255)      indexed
#  by_project    :string(255)      indexed => [by_package], indexed, indexed => [state]
#  by_package    :string(255)      indexed => [by_project]
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  review_id     :integer          indexed
#  user_id       :integer          indexed
#  group_id      :integer          indexed
#  project_id    :integer          indexed
#  package_id    :integer          indexed
#
# Indexes
#
#  bs_request_id                               (bs_request_id)
#  index_reviews_on_by_group                   (by_group)
#  index_reviews_on_by_package_and_by_project  (by_package,by_project)
#  index_reviews_on_by_project                 (by_project)
#  index_reviews_on_by_user                    (by_user)
#  index_reviews_on_creator                    (creator)
#  index_reviews_on_group_id                   (group_id)
#  index_reviews_on_package_id                 (package_id)
#  index_reviews_on_project_id                 (project_id)
#  index_reviews_on_review_id                  (review_id)
#  index_reviews_on_reviewer                   (reviewer)
#  index_reviews_on_state_and_by_project       (state,by_project)
#  index_reviews_on_state_and_by_user          (state,by_user)
#  index_reviews_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...    (review_id => reviews.id)
#  reviews_ibfk_1  (bs_request_id => bs_requests.id)
#
