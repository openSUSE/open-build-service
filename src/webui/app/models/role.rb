class Role

  class << self
    def local_roles
      Array[ "maintainer", "bugowner", "reviewer", "downloader" , "reader"]
    end
    def global_roles
      Array[ "Admin", "User"]
    end

  end

end
