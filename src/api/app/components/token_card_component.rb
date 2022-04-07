class TokenCardComponent < ApplicationComponent
  with_collection_parameter :token

  def initialize(token:)
    super

    @token = token
  end

  def operation
    "Operation: #{@token.token_name.capitalize}"
  end

  def token_package_link
    link_to("#{truncate(@token.package.project.name, length: 32)}/#{truncate(@token.package.name, length: 32)}",
            package_show_path(project: @token.package.project, package: @token.package))
  end
end
