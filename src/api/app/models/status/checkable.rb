module Status::Checkable
  extend ActiveSupport::Concern

  included do
    serialize :required_checks, Array
    has_many :status_reports, as: :checkable, class_name: 'Status::Report', dependent: :destroy
  end

  def current_status_report
    status_reports.find_or_initialize_by(uuid: build_id)
  end
end
