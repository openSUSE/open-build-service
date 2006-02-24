module PlatformHelper

  def project_from_path path
    path =~ /(.*)\/(.*)/
    return $1
  end
  
  def name_from_path path
    path =~ /(.*)\/(.*)/
    return $2
  end
  
end
