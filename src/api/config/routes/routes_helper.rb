module RoutesContrains
  CONS = {
    arch: %r{[^\/]*},
    binary: %r{[^\/]*},
    filename: %r{[^\/]*},
    id: %r{\d*},
    login: %r{[^\/]*},
    package: %r{[^\/]*},
    package_name: %r{[^\/]*},
    project: %r{[^\/]*},
    project_name: %r{[^\/]*},
    maintained_project: %r{[^\/]*},
    repository: %r{[^\/]*},
    repository_name: %r{[^\/]*},
    service: %r{\w[^\/]*},
    title: %r{[^\/]*},
    user: %r{[^\/]*},
    repository_publish_build_id: %r{[^\/]*}
  }.freeze
end

class WebuiMatcher
  class InvalidRequestFormat < APIError
  end

  def self.matches?(request)
    request.format.to_sym != :xml
  rescue ArgumentError => e
    raise InvalidRequestFormat, e.to_s
  end
end

# here we take everything that is XML, JSON or osc ;)
class APIMatcher
  def self.matches?(request)
    format = request.format.to_sym || :xml
    format == :xml || format == :json || public_or_about_path?(request)
  end

  def self.public_or_about_path?(request)
    request.fullpath.start_with?('/public', '/about')
  end
end
