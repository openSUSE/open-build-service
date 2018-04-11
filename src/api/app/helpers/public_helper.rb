# frozen_string_literal: true

module PublicHelper
  def ymp_url(path)
    url = ::Configuration.ymp_url
    path && url ? File.join(url, path) : ''
  end
end
