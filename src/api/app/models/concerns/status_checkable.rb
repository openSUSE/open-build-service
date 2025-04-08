module StatusCheckable
  extend ActiveSupport::Concern

  included do
    if RailsVersion.is_7_1?
      serialize :required_checks, type: Array
    else
      serialize :required_checks, Array
    end
    has_many :status_reports, as: :checkable, class_name: 'Status::Report', dependent: :destroy
  end
end
