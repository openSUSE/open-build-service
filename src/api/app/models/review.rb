require 'api_error'

class Review < ApplicationRecord
  include ActiveModel::Validations

  class NotFoundError < APIError
    setup 'review_not_found', 404, 'Review not found'
  end

  VALID_REVIEW_STATES = %i[new declined accepted superseded obsoleted].freeze

  belongs_to :bs_request, touch: true, optional: true
  has_many :history_elements, -> { order(:created_at) }, class_name: 'HistoryElement::Review', foreign_key: :op_object_id
  has_many :history_elements_assigned, class_name: 'HistoryElement::ReviewAssigned', foreign_key: :op_object_id
  has_many :notifications, as: :notifiable, dependent: :delete_all

  validates :state, inclusion: { in: VALID_REVIEW_STATES }

  validates :by_user, length: { maximum: 250 }
  validates :by_group, length: { maximum: 250 }
  validates :by_project, length: { maximum: 250 }
  validates :by_package, length: { maximum: 250 }
  validates :reviewer, length: { maximum: 250 }
  validates :reason, length: { maximum: 65_534 }

  validates :user, presence: true, if: :by_user?
  validates :group, presence: true, if: :by_group?
  validates :project, presence: true, if: :by_project?, on: :create
  validates :package, presence: true, if: :by_package?, on: :create
  validates :by_project, presence: true, if: :by_package?, on: :create

  validate :review_assignment

  # Validate the review is not assigned to a review which is already assigned to this review
  validate :validate_non_symmetric_assignment
  validate :validate_not_self_assigned
  validates_with AllowedUserValidator

  belongs_to :user, optional: true
  belongs_to :group, optional: true
  belongs_to :project, optional: true
  belongs_to :package, optional: true

  belongs_to :review_assigned_from, class_name: 'Review', foreign_key: :review_id, optional: true
  has_one :review_assigned_to, class_name: 'Review'

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

  scope :opened, -> { where(state: :new) }
  scope :accepted, -> { where(state: :accepted) }
  scope :declined, -> { where(state: :declined) }
  scope :for_staging_projects, lambda { |project|
                                 includes(:project).where(projects: { staging_workflow: Staging::Workflow.find_by(project:) })
                                                   .where.not(projects: { staging_workflow_id: nil })
                               }
  scope :for_non_staging_projects, ->(project) { where.not(id: for_staging_projects(project)) }

  scope :staging, ->(project) { for_staging_projects(project).or(where(group: Staging::Workflow.find_by(project:).managers_group)) }

  before_validation(on: :create) do
    self.state = :new if self[:state].nil?
  end

  before_validation :set_reviewable_association
  after_commit :update_cache
  after_commit { PopulateToSphinxJob.perform_later(id: bs_request.id, model_name: :bs_request) }

  delegate :number, to: :bs_request

  def review_assignment
    errors.add(:unknown, 'no reviewer defined') unless by_user || by_group || by_project
    errors.add(:base, 'it is not allowed to have more than one reviewer entity: by_user, by_group, by_project') if invalid_reviewers?
  end

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

  def declined?
    state == :declined
  end

  def accepted?
    state == :accepted
  end

  def new?
    state == :new
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

  def self.new_from_xml_hash(hash)
    r = Review.new

    r.state = :new
    hash.delete('state')

    r.by_user = hash.delete('by_user')
    r.by_group = hash.delete('by_group')
    r.by_project = hash.delete('by_project')
    r.by_package = hash.delete('by_package')

    r.reviewer = r.creator = hash.delete('who')
    r.reason = hash.delete('comment')
    begin
      r.changed_state_at = Time.zone.parse(hash.delete('when'))
    rescue TypeError
      # no valid time -> ignore
    end

    raise ArgumentError, "too much information #{hash.inspect}" if hash.present?

    r
  end

  def _get_attributes
    attributes = { state: state.to_s }
    # old requests didn't have who and when
    attributes[:when] = changed_state_at&.strftime('%Y-%m-%dT%H:%M:%S')
    attributes[:who] = reviewer if reviewer
    attributes[:by_group] = by_group if by_group
    attributes[:by_user] = by_user if by_user
    attributes[:by_package] = by_package if by_package
    attributes[:by_project] = by_project if by_project

    attributes
  end

  def render_xml(builder)
    builder.review(_get_attributes) do
      builder.comment!(reason) if reason
      history_elements.each do |history|
        history.render_xml(builder)
      end
    end
  end

  def reviewers_for_obj(obj)
    return [] unless obj

    relationships = obj.relationships
    roles = relationships.where(role: Role.hashed['maintainer'])
    User.where(id: roles.users.select(:user_id)) + Group.where(id: roles.groups.select(:group_id))
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

  def reviewable_by?(opts)
    return by_user == opts[:by_user] if by_user
    return by_group == opts[:by_group] if by_group

    reviewable_by = by_project == opts[:by_project]
    if by_package
      reviewable_by && by_package == opts[:by_package]
    else
      reviewable_by
    end
  end

  def change_state(new_state, comment)
    return false if state == new_state && reviewer == User.session!.login && reason == comment

    self.reason = comment
    self.state = new_state
    self.reviewer = User.session!.login
    self.changed_state_at = Time.now.utc
    save!
    Event::ReviewChanged.create(bs_request.event_parameters)

    arguments = { review: self, comment: comment, user: User.session! }
    case new_state
    when :accepted
      HistoryElement::ReviewAccepted.create(arguments)
    when :declined
      HistoryElement::ReviewDeclined.create(arguments)
    else
      HistoryElement::ReviewReopened.create(arguments)
    end
    true
  end

  def matches_user?(user)
    return false unless user
    return user.login == by_user if by_user
    return user.in_group?(by_group) if by_group

    matches_maintainers?(user)
  end

  def event_parameters(params = {})
    params = params.merge(_get_attributes)
    params[:id] = bs_request.id
    params[:comment] = reason
    params[:reviewers] = map_objects_to_ids(users_and_groups_for_review)
    params[:when] = changed_state_at&.strftime('%Y-%m-%dT%H:%M:%S')
    params
  end

  def create_event(params = {})
    params = event_parameters(params)

    Event::ReviewWanted.create(params)
  end

  def reviewed_by
    return User.find_by(login: by_user) if by_user
    return Group.find_by(title: by_group) if by_group
    return Package.find_by_project_and_name(by_project, by_package) if by_package

    Project.find_by(name: by_project) if by_project
  end

  # Make sure this is always set, also for old records
  def changed_state_at
    self[:changed_state_at] || self[:updated_at]
  end

  def for_user?
    by_user?
  end

  def for_group?
    by_group?
  end

  def for_project?
    by_project? && !by_package?
  end

  def for_package?
    by_project? && by_package?
  end

  def staging_project?
    for_project? && !project&.staging_workflow_id.nil?
  end

  def check_reviewer!
    selected_errors = errors.select { |error| error.attribute.in?(%i[user group project package]) }
    raise ::NotFoundError, selected_errors.map { |error| "#{error.attribute.capitalize} not found" }.to_sentence if selected_errors.any?
  end

  private

  def matches_maintainers?(user)
    return false unless by_project

    if by_package
      user.local_permission?('change_package', Package.find_by_project_and_name(by_project, by_package))
    else
      user.local_permission?('change_project', Project.find_by_name(by_project))
    end
  end

  # The authoritative storage are the by_ attributes as even when a record (project, package ...) got deleted
  # the review should still be usable, however, the entity association is nullified
  def set_reviewable_association
    self.package = Package.find_by_project_and_name(by_project, by_package)
    self.project = Project.find_by_name(by_project)
    self.user = User.find_by(login: by_user)
    self.group = Group.find_by(title: by_group)
  end

  # A review can be by one and only one of following options: by_user, by_group or by_project
  def invalid_reviewers?
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
#  id               :integer          not null, primary key
#  by_group         :string(255)      indexed, indexed => [state]
#  by_package       :string(255)      indexed => [by_project]
#  by_project       :string(255)      indexed => [by_package], indexed, indexed => [state]
#  by_user          :string(255)      indexed, indexed => [state]
#  changed_state_at :datetime
#  creator          :string(255)      indexed
#  reason           :text(65535)
#  reviewer         :string(255)      indexed
#  state            :string(255)      indexed => [by_group], indexed => [by_project], indexed => [by_user]
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  bs_request_id    :integer          indexed
#  group_id         :integer          indexed
#  package_id       :integer          indexed
#  project_id       :integer          indexed
#  review_id        :integer          indexed
#  user_id          :integer          indexed
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
#  index_reviews_on_state_and_by_group         (state,by_group)
#  index_reviews_on_state_and_by_project       (state,by_project)
#  index_reviews_on_state_and_by_user          (state,by_user)
#  index_reviews_on_user_id                    (user_id)
#
# Foreign Keys
#
#  fk_rails_...    (review_id => reviews.id)
#  reviews_ibfk_1  (bs_request_id => bs_requests.id)
#
