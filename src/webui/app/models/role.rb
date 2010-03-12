class Role

  class << self
    def local_roles
      Array[ "maintainer", "bugowner", "reviewer", "downloader" ]
    end
  end

end
