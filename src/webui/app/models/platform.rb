class Platform < ActiveXML::Base

  def to_s
    name.to_s
  end

  def set_project p
    logger.debug( "SET PROJECT #{p}" )
    data.attributes["project"] = p
  end

end
