module NotificationFilterable
  extend ActiveSupport::Concern

  included do
    scope :for_project_name, ->(project_name) { joins(:projects).where(projects: { name: project_name }) }
    scope :for_package_name, lambda { |package_name|
      # This allows to match the package directly via the notification
      joins(<<~SQL.squish)
        LEFT JOIN packages notified_packages ON notified_packages.id = notifications.notifiable_id AND notifications.notifiable_type = 'Package'
      SQL
        # This allows us to match the package via the comment
        .joins(<<~SQL.squish)
          LEFT JOIN comments ON comments.id = notifications.notifiable_id AND notifications.notifiable_type = 'Comment'
          LEFT JOIN packages commented_packages ON commented_packages.id = comments.commentable_id AND comments.commentable_type = 'Package'
      SQL
        # This allows us to match the package via the source or the target package of the notified request
        .joins(<<~SQL.squish)
          LEFT JOIN bs_requests ON bs_requests.id = notifications.notifiable_id AND notifications.notifiable_type = 'BsRequest'
          LEFT JOIN bs_request_actions ON bs_request_actions.bs_request_id = bs_requests.id
      SQL
        # This allows us to match the package via the reported package
        .joins(<<~SQL.squish)
          LEFT JOIN reports ON reports.id = notifications.notifiable_id AND notifications.notifiable_type = 'Report'
          LEFT JOIN packages reported_packages ON reported_packages.id = reports.reportable_id AND reports.reportable_type = 'Package'
        SQL
        .where('notified_packages.name = :name OR ' \
               'commented_packages.name = :name OR ' \
               'reported_packages.name = :name OR ' \
               'bs_request_actions.source_package = :name OR ' \
               'bs_request_actions.target_package = :name',
               name: package_name)
        .distinct
    }
    scope :for_group_title, ->(group_title) { joins(:groups).where(groups: { title: group_title }) }
    scope :for_request_state, ->(request_state) { joins(:bs_request).where(bs_request: { state: request_state }) }
  end
end
