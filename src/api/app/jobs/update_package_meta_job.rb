class UpdatePackageMetaJob

  def scan_links
    names = Package.distinct(:name).order(:name).pluck(:name)
    while !names.empty? do
      slice = names.slice!(0, 30)
      path = "/search/package/id?match=("
      path += slice.map { |name| "linkinfo/@package='#{CGI.escape(name)}'" }.join("+or+")
      path += ")"
      answer = Xmlhash.parse(Suse::Backend.get(path).body)
      answer.elements('package') do |p|
        pkg = Package.find_by_project_and_name(p['project'], p['name'])
        # if there is a linkinfo for a package not in database, there can not be a linked_package either
        next unless pkg
        pkg.update_backendinfo
      end

    end
  end

  def perform
    # first we scan the links so that commits happening
    # while the delayed job runs can update our work
    scan_links

    Package.order(:name).each do |pkg|
      next unless Package.exists?(pkg)
      begin
        pkg.update_backendinfo
      rescue ActiveXML::Transport::Error
      end
    end
  end

end

