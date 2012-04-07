module ProductHelper

  # updates packages automatically generated in the backend after submitting a product file
  def update_product_autopackages( project )

    backend_pkgs = Collection.find :id, :what => 'package', :match => "@project='#{project}' and starts-with(@name,'_product:')"
    b_pkg_index = backend_pkgs.each_package.inject(Hash.new) {|hash,elem| hash[elem.name] = elem; hash}
    frontend_pkgs = DbProject.find_by_name(project).db_packages.where("`db_packages`.name LIKE '_product:%'").all
    f_pkg_index = frontend_pkgs.inject(Hash.new) {|hash,elem| hash[elem.name] = elem; hash}

    all_pkgs = [b_pkg_index.keys, f_pkg_index.keys].flatten.uniq

    wt_state = ActiveXML::Config.global_write_through
    begin
      ActiveXML::Config.global_write_through = false
      all_pkgs.each do |pkg|
        if b_pkg_index.has_key?(pkg) and not f_pkg_index.has_key?(pkg)
          # new autopackage, import in database
          Package.new(b_pkg_index[pkg].dump_xml, :project => project).save
        elsif f_pkg_index.has_key?(pkg) and not b_pkg_index.has_key?(pkg)
          # autopackage was removed, remove from database
          f_pkg_index[pkg].destroy
        end
      end
    ensure
      ActiveXML::Config.global_write_through = wt_state
    end
  end

end
