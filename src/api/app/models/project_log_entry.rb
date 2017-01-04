# Class to track recent activity in order to provide rss feeds.
# Log entries are created from events and deleted after a time threshold
# @see ProjectLogRotate
class ProjectLogEntry < ApplicationRecord
  belongs_to :project
  belongs_to :bs_request

  validates :event_type, :datetime, :project_id, presence: true

  USERNAME_KEYS = %w(sender user who author commenter)
  EXCLUDED_KEYS = USERNAME_KEYS + %w(project package requestid)

  # Creates a new LogEntry record from the information contained in an Event
  def self.create_from(event)
    project_id = Project.unscoped.where(name: event.payload["project"]).pluck(:id).first
    # Map request number to internal id
    bs_request_id = BsRequest.find_by_number(event.payload["requestid"]).try(:id)
    entry = new(project_id: project_id,
                package_name: event.payload["package"],
                bs_request_id: bs_request_id,
                datetime: event.created_at,
                event_type: event.class.model_name.to_s.split("::").last.underscore)
    entry.user_name = username_from(event.payload)
    entry.additional_info = event.payload.except(*EXCLUDED_KEYS)
    entry.save
    entry
  end

  # Delete old entries
  def self.clean_older_than(date)
    where('datetime < ?', date).delete_all
  end

  # Human readable message, based in the event class
  def message
    Event.const_get(event_type.camelize).description
  end

  def package
    @package ||= package_name.blank? ? nil : Package.get_by_project_and_name(project.name, package_name)
  rescue APIException, ActiveRecord::RecordNotFound
    @package ||= nil
  end

  def user
    @user ||= user_name.blank? ? nil : User.find_by_login(user_name)
  end

  # Same mechanism that ApplicationRecord.serialize with extra robustness
  def additional_info=(obj)
    write_attribute(:additional_info, YAML.dump(obj))
  rescue
    write_attribute(:additional_info, nil)
  end

  # Almost equivalent to the ApplicationRecord.serialize mechanism
  def additional_info
    a = read_attribute(:additional_info)
    a ? YAML.load(a) : {}
  end

  # Extract the username from the payload of an event, since different names are
  # used for storing it in different situations
  def self.username_from(payload)
    USERNAME_KEYS.each do |key|
      username = payload[key]
      return username unless username.blank? || username == "unknown"
    end
    return
  end
end
