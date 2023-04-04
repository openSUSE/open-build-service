module RoutesHelper
  module RoutesConstraints
    CONS = {
      arch: %r{[^/]*},
      binary: %r{[^/]*},
      filename: %r{[^/]*},
      id: /\d*/,
      login: %r{[^/]*},
      package: %r{[^/]*},
      package_name: %r{[^/]*},
      project: %r{[^/]*},
      project_name: %r{[^/]*},
      maintained_project: %r{[^/]*},
      repository: %r{[^/]*},
      repository_name: %r{[^/]*},
      service: %r{\w[^/]*},
      title: %r{[^/]*},
      user: %r{[^/]*},
      user_login: %r{[^/]*},
      repository_publish_build_id: %r{[^/]*},
      workflow_project: %r{[^/]*},
      staging_project_name: %r{[^/]*},
      staging_project_copy_name: %r{[^/]*},
      request_action_id: /\d*/,
      line: /diff_\d+_n\d+/
    }.freeze
  end
end
