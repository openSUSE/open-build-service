require 'api_exception'

class Review < ActiveRecord::Base

  class NotFoundError < APIException
    setup 'review_not_found', 404, 'Review not found'
  end

  belongs_to :bs_request
  validates_inclusion_of :state, :in => VALID_REQUEST_STATES

  before_validation(on: :create) do
    if read_attribute(:state).nil?
      self.state = :new
    end
  end

  def state
    read_attribute(:state).to_sym
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

  def users_for_review
    if self.by_user
       return [User.find_by_login!(self.by_user).id]
    end
    if self.by_group
      return Group.find_by_title!(self.by_group).email_users.pluck('users.id')
    end
    obj = nil
    if self.by_package
      obj = Package.find_by_project_and_name(self.by_project, self.by_package)
    else
      obj = Project.find_by_name(self.by_project)
    end
    return [] unless obj
    User.where(id: obj.relationships.users.where(role: Role.rolecache['maintainer']).pluck(:user_id))
  end

  def create_notification(params = {})
    params = params.merge(_get_attributes)
    params[:comment] = self.reason
    params[:reviewers] = users_for_review

    # send email later
    Event::ReviewWanted.create params
  end
end
