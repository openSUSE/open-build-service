module PublicHelper
  def download_url(path)
     url = Configuration.download_url
     (path && url) ? File.join(url, path) : ""
  end

  def ymp_url(path)
     url = Configuration.ymp_url
     (path && url) ? File.join(url, path) : ""
  end
end
