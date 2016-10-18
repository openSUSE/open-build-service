require 'api_exception'

class Review < ApplicationRecord
  class NotFoundError < APIException
    setup 'review_not_found', 404, 'Review not found'
  end

  belongs_to :bs_request
  validates_inclusion_of :state, :in => VALID_REVIEW_STATES

  validates :by_user, length: { maximum: 250 }
  validates :by_group, length: { maximum: 250 }
  validates :by_project, length: { maximum: 250 }
  validates :by_package, length: { maximum: 250 }
  validates :reviewer, length: { maximum: 250 }
  validates :reason, length: { maximum: 65534 }

  validate :check_initial, :on => [:create]

  before_validation(on: :create) do
    if read_attribute(:state).nil?
      self.state = :new
    end
  end

  def state
    read_attribute(:state).to_sym
  end

  def check_initial
    # Validates the existence of references.
    # NOTE: they can disappear later and the review should be still
    #       usable to some degree (can be showed at least)
    #       But it must not be possible to create one with broken references
    unless self.by_user || self.by_group || self.by_project
      errors.add(:unknown, 'no reviewer defined')
    end

    if self.by_user && !User.find_by_login(self.by_user)
      errors.add(:by_user, "#{self.by_user} not found")
    end

    if self.by_group && !Group.find_by_title(self.by_group)
      errors.add(:by_group, "#{self.by_group} not found")
    end

    if self.by_project && !Project.find_by_name(self.by_project)
      # must be a local project or we can't ask
      errors.add(:by_project, "#{self.by_project} not found")
    end

    if self.by_package && !self.by_project
      errors.add(:unknown, 'by_package defined, but missing by_project')
    end
    if self.by_package && !Package.find_by_project_and_name(self.by_project, self.by_package)
      # must be a local package. maybe we should rewrite in case the
      # package comes via local project link...
      errors.add(:by_package, "#{self.by_project}/#{self.by_package} not found")
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
    attributes = { state: self.state.to_s }
    # old requests didn't have who and when
    attributes[:when] = self.created_at.strftime('%Y-%m-%dT%H:%M:%S') if self.reviewer
    attributes[:who] = self.reviewer if self.reviewer
    attributes[:by_group] = self.by_group if self.by_group
    attributes[:by_user] = self.by_user if self.by_user
    attributes[:by_package] = self.by_package if self.by_package
    attributes[:by_project] = self.by_project if self.by_project

    attributes
  end

  def render_xml(builder)
    builder.review(_get_attributes) do
      builder.comment! self.reason if self.reason
      History.find_by_review(self).each do |history|
        history.render_xml(builder)
      end
    end
  end

  def webui_infos
    ret = _get_attributes
    # XML has this perl format, don't use that here
    ret[:when] = self.created_at
    ret
  end

  def reviewers_for_obj(obj)
    return [] unless obj
    relationships = obj.relationships
    roles = relationships.where(role: Role.rolecache['maintainer'])
    User.where(id: roles.users.pluck(:user_id)) + Group.where(id: roles.groups.pluck(:group_id))
  end

  def users_and_groups_for_review
    if self.by_user
       return [User.find_by_login!(self.by_user)]
    end
    if self.by_group
      return [Group.find_by_title!(self.by_group)]
    end
    obj = nil
    if self.by_package
      obj = Package.find_by_project_and_name(self.by_project, self.by_package)
      return [] unless obj
      reviewers_for_obj(obj) + reviewers_for_obj(obj.project)
    else
      reviewers_for_obj(Project.find_by_name(self.by_project))
    end
  end

  def map_objects_to_ids(objs)
    objs.map { |obj| { "#{obj.class.to_s.downcase}_id" => obj.id } }.uniq
  end

  def create_notification(params = {})
    params = params.merge(_get_attributes)
    params[:comment] = self.reason
    params[:reviewers] = map_objects_to_ids(users_and_groups_for_review)

    # send email later
    Event::ReviewWanted.create params
  end
end
