module PublicHelper
  def download_url(path)
     path ? File.join(Configuration.download_url, path) : ""
  end

  def ymp_url(path)
     path ? File.join(Configuration.ymp_url, path) : ""
  end
end
