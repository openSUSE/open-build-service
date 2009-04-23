class Packstatus < ActiveXML::Base
  default_find_parameter :project

  def status_for( package, repo, arch )
    psl = packstatuslist("@repository='#{repo}' and @arch='#{arch}'")
    return nil if psl.nil?
    return psl.packstatus("@name='#{package}'").status
  end

end
