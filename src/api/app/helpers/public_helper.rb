module PublicHelper
  def download_url(path)
     path ? File.join(DOWNLOAD_URL, path) : ""
  end

  def ymp_url(path)
     path ? File.join(YMP_URL, path) : ""
  end
end
