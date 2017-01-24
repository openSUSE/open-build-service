require 'api_exception'

class Review < ApplicationRecord
  class NotFoundError < APIException
    setup 'review_not_found', 404, 'Review not found'
  end

  belongs_to :bs_request, touch: true
  has_many :history_elements, -> { order(:created_at) }, class_name: 'HistoryElement::Review', foreign_key: :op_object_id
  validates :state, inclusion: { in: VALID_REVIEW_STATES }

  validates :by_user, length: { maximum: 250 }
  validates :by_group, length: { maximum: 250 }
  validates :by_project, length: { maximum: 250 }
  validates :by_package, length: { maximum: 250 }
  validates :reviewer, length: { maximum: 250 }
  validates :reason, length: { maximum: 65534 }

  validate :check_initial, on: [:create]
  validate :validate_non_symmetric_assignment # Validate the review is not assigned to a review which is already assigned to this review
  validate :validate_not_self_assigned

  belongs_to :review_assigned_from, class_name: 'Review', foreign_key: :review_id
  has_one :review_assigned_to, class_name: 'Review', foreign_key: :review_id

  HISTORY_ELEMENTS_ASSIGNED_SUB_QUERY = <<-SQL
    SELECT COUNT(history_elements.id) FROM history_elements
    WHERE history_elements.op_object_id = reviews.id
    AND history_elements.type = 'HistoryElement::ReviewAssigned'
  SQL

  scope :assigned, -> { where("(#{HISTORY_ELEMENTS_ASSIGNED_SUB_QUERY}) > 0") }
  scope :unassigned, -> { where("(#{HISTORY_ELEMENTS_ASSIGNED_SUB_QUERY}) = 0") }

  before_validation(on: :create) do
    if read_attribute(:state).nil?
      self.state = :new
    end
  end

  def validate_non_symmetric_assignment
    if review_assigned_from && review_assigned_from == review_assigned_to
      errors.add(:review_id, "recursive assignment")
    end
  end

  def validate_not_self_assigned
    if persisted? && id == review_id
      errors.add(:review_id, "recursive assignment")
    end
  end

  def state
    read_attribute(:state).to_sym
  end

  def accepted_at
    if review_assigned_to && review_assigned_to.state == :accepted
      review_assigned_to.updated_at
    elsif state == :accepted && !review_assigned_to
      updated_at
    end
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

    if by_user && !User.find_by_login(by_user)
      errors.add(:by_user, "#{by_user} not found")
    end

    if by_group && !Group.find_by_title(by_group)
      errors.add(:by_group, "#{by_group} not found")
    end

    if by_project && !Project.find_by_name(by_project)
      # must be a local project or we can't ask
      errors.add(:by_project, "#{by_project} not found")
    end

    if by_package && !by_project
      errors.add(:unknown, 'by_package defined, but missing by_project')
    end
    if by_package && !Package.find_by_project_and_name(by_project, by_package)
      # must be a local package. maybe we should rewrite in case the
      # package comes via local project link...
      errors.add(:by_package, "#{by_project}/#{by_package} not found")
    end
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

    raise ArgumentError, "too much information #{hash.inspect}" unless hash.blank?
    r
  end

  def _get_attributes
    attributes = { state: state.to_s }
    # old requests didn't have who and when
    attributes[:when] = created_at.strftime('%Y-%m-%dT%H:%M:%S') if reviewer
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
    roles = relationships.where(role: Role.rolecache['maintainer'])
    User.where(id: roles.users.pluck(:user_id)) + Group.where(id: roles.groups.pluck(:group_id))
  end

  def users_and_groups_for_review
    if by_user
      return [User.find_by_login!(by_user)]
    end
    if by_group
      return [Group.find_by_title!(by_group)]
    end
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
end
