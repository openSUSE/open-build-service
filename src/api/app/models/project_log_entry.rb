# Class to track recent activity in order to provide rss feeds.
# Log entries are created from events and deleted after a time threshold
# @see ProjectLogRotate
class ProjectLogEntry < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :bs_request, optional: true

  validates :event_type, :datetime, :project_id, presence: true

  USERNAME_KEYS = %w[sender user who author commenter].freeze
  EXCLUDED_KEYS = (USERNAME_KEYS + %w[project package requestid]).freeze

  # Creates a new LogEntry record from the payload, timestamp, and model name of
  # an Event
  def self.create_from(payload, created_at, event_model_name)
    project_id = Project.unscoped.where(name: payload['project']).pick(:id)
    # Map request number to internal id
    bs_request_id = BsRequest.find_by_number(payload['requestid']).try(:id)
    entry = new(project_id: project_id,
                package_name: payload['package'],
                bs_request_id: bs_request_id,
                datetime: Time.parse(created_at),
                event_type: event_model_name.demodulize.underscore)
    entry.user_name = username_from(payload)
    entry.additional_info = payload.except(*EXCLUDED_KEYS)
    entry.save
    entry
  end

  def self.cleanup
    where(event_type: %i[build_fail build_success]).where(datetime: ...Time.zone.yesterday).delete_all
  end

  # Human readable message, based in the event class
  def message
    Event.const_get(event_type.camelize).description
  end

  def package
    @package ||= package_name.blank? ? nil : Package.get_by_project_and_name(project.name, package_name)
  rescue APIError, ActiveRecord::RecordNotFound
    @package ||= nil
  end

  def user
    @user ||= user_name.blank? ? nil : User.find_by_login(user_name)
  end

  # Same mechanism that ApplicationRecord.serialize with extra robustness
  # FIXME: We shouldn't slice the input here, this should either fit or never
  # reach us through Event...
  def additional_info=(obj)
    self[:additional_info] = YAML.dump(obj)[0..65_534]
  rescue StandardError
    self[:additional_info] = nil
  end

  # Almost equivalent to the ApplicationRecord.serialize mechanism
  def additional_info
    a = self[:additional_info]
    a ? YAML.safe_load(a) : {}
  end

  # Extract the username from the payload of an event, since different names are
  # used for storing it in different situations
  def self.username_from(payload)
    USERNAME_KEYS.each do |key|
      username = payload[key]
      # FIXME: Why is commenter `id`` when everything else is `login`?
      username = User.find_by(id: payload[key]).try(:login) if key == 'commenter'
      return username unless username.blank? || username == 'unknown'
    end
    nil
  end
end

# == Schema Information
#
# Table name: project_log_entries
#
#  id              :integer          not null, primary key
#  additional_info :text(65535)
#  datetime        :datetime         indexed
#  event_type      :string(255)      indexed, indexed => [project_id]
#  package_name    :string(255)      indexed
#  user_name       :string(255)      indexed
#  bs_request_id   :integer          indexed
#  project_id      :integer          indexed => [event_type], indexed
#
# Indexes
#
#  index_project_log_entries_on_bs_request_id              (bs_request_id)
#  index_project_log_entries_on_datetime                   (datetime)
#  index_project_log_entries_on_event_type                 (event_type)
#  index_project_log_entries_on_package_name               (package_name)
#  index_project_log_entries_on_project_id_and_event_type  (project_id,event_type)
#  index_project_log_entries_on_user_name                  (user_name)
#  project_id                                              (project_id)
#
# Foreign Keys
#
#  project_log_entries_ibfk_1  (project_id => projects.id)
#
