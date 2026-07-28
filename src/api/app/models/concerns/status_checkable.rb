module StatusCheckable
  extend ActiveSupport::Concern

  included do
    serialize :required_checks, type: Array
    has_many :status_reports, as: :checkable, class_name: 'Status::Report', dependent: :destroy
  end
end
