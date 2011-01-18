class Role

  class << self
    def local_roles
      Array[ "maintainer", "bugowner", "reviewer", "downloader" , "reader"]
    end
  end

end
