class Service < ActiveXML::Base

  class << self
    def make_stub( opt )
      "<services/>"
    end

    def updateServiceList
       # cache service list
       @serviceList = []
       @serviceParameterList = {}

       doc = Service.find_cached :all
       doc.each_service do |s|
         serviceName = s.value("name")
         next if s.value("hidden") == "true"
         hash = {}
         hash[:name]        = serviceName
         hash[:summary]     = s.find_first("summary").text
         hash[:description] = s.find_first("description").text
         @serviceList.push( hash )

         @serviceParameterList[serviceName] = {}
         s.each("parameter") do |p|
           hash = {}
           hash[:description] = p.find_first("description").text
           hash[:required] = true if p.has_element?("required")

           allowedvalues = []
           p.each("allowedvalue") do |a|
             allowedvalues.push(a.text)
           end
           hash[:allowedvalues] = allowedvalues

           @serviceParameterList[serviceName][p.value("name")] = hash
         end
       end
    end

    def findAvailableParameterValues(serviceName, parameter)
      if @serviceList.nil?
         # FIXME: do some more clever cacheing
         updateServiceList
      end

      if @serviceParameterList[serviceName] and @serviceParameterList[serviceName][parameter] \
         and @serviceParameterList[serviceName][parameter][:allowedvalues]
        return @serviceParameterList[serviceName][parameter][:allowedvalues]
      end
      return nil
    end

    def findAvailableParameters(serviceName)
      if @serviceList.nil?
         # FIXME: do some more clever cacheing
         updateServiceList
      end

      return {} unless @serviceParameterList[serviceName]
      @serviceParameterList[serviceName]
    end

    def available
      if @serviceList.nil?
         # FIXME: do some more clever cacheing
         updateServiceList
      end

      @serviceList
    end

    def findService(name)
      # would be nicer if we store it as hash, but it makes us impossible to order it
      if @serviceList.nil?
         # FIXME: do some more clever cacheing
         updateServiceList
      end
   
      @serviceList.each do |s|
        return s if s[:name] == name
      end

      return nil
    end

    def summary(name)
      return nil unless s = findService(name)
      return "" unless s[:summary]
      s[:summary]
    end

    def description(name)
      return nil unless s = findService(name)
      return "" unless s[:description]
      s[:description]
    end

    def parameterDescription(serviceName, name)
      return nil unless findService(serviceName)
      return nil unless @serviceParameterList[serviceName]
      return nil unless @serviceParameterList[serviceName][name]
      return ""  unless @serviceParameterList[serviceName][name][:description]
      @serviceParameterList[serviceName][name][:description]
    end
  end

  def addDownloadURL( url )
     begin
       uri = URI.parse( url )
     rescue
       return false
     end

     p = []
     p << { :name => "host", :value => uri.host }
     p << { :name => "protocol", :value => uri.scheme }
     p << { :name => "path", :value => uri.path }
     unless ( uri.scheme == "http" and uri.port == 80 ) or ( uri.scheme == "https" and uri.port == 443 ) or ( uri.scheme == "ftp" and uri.port == 21 )
        # be nice and skip it for simpler _service file
        p << { :name => "port", :value => uri.port }
     end

     if uri.path =~ /.src.rpm$/ or uri.path =~ /.spm$/
        # download and extract source package
        addService( "download_src_package", -1, p )
     else
        # just download
        addService( "download_url", -1, p )
     end
     return true
  end

  def removeService( serviceid )
     each("/services/service") do |service|
        serviceid=serviceid-1
	if serviceid == 0
	  delete_element service
	  return true
	end
     end
     return false
  end

  # parameters need to be given as an array with hash pairs :name and :value
  def addService( name, position=-1, parameters=[] )
     element = add_element 'service', 'name' => name
     if position >= 0 
        service_elements = each("/services/service")
        if service_elements.count >= position
          element.move_before(service_elements[position-1])
	end
     end
     parameters.each{ |p|
       param = element.add_element('param', :name => p[:name])
       param.text = p[:value]
     }
     return true
  end

  def getParameters(serviceid)
     ret = []
     each("/services/service[#{serviceid}]/param") do |p|
       ret << { :name => p.value(:name), :value => p.text }
     end

     return ret
  end

  def setParameters( serviceid, parameters=[] )
     service = find_first("/services/service[#{serviceid}]")
     return false if not service

     # remove all existing parameters
     each("/services/service[#{serviceid}]/param") do |p|
       delete_element p
     end

     parameters.each{ |p|
        param = service.add_element('param', :name => p[:name])
        param.text = p[:value]
     }
     return true
  end

  def moveService( from, to )
    return if from == to
    service_elements = each("/services/service")
    return false if service_elements.count < from or service_elements.count < to or service_elements.count <= 0
    logger.debug "moveService #{from}->#{to}"
    if from > to
      service_elements[from].move_before(service_elements[to])
    else
      service_elements[from].move_after(service_elements[to])
    end
  end

  def error
    opt = Hash.new
    opt[:project]  = self.init_options[:project]
    opt[:package]  = self.init_options[:package]
    opt[:expand]   = self.init_options[:expand]
    opt[:rev]      = self.init_options[:revision]
    begin
      fc = FrontendCompat.new
      answer = fc.get_source opt
      doc = ActiveXML::Base.new(answer)
      doc.each("/directory/serviceinfo/error") do |e|
         return e.text
      end
    rescue
      return nil
    end
  end

  def execute()
    opt = Hash.new
    opt[:project] = self.init_options[:project]
    opt[:package] = self.init_options[:package]
    opt[:expand]   = self.init_options[:expand]
    opt[:cmd] = "runservice"
    logger.debug "execute services"
    fc = FrontendCompat.new
    fc.do_post nil, opt
  end

  def save
    if !has_element?("/services/service")
        begin
	   delete
        rescue ActiveXML::Transport::NotFoundError
           # to be ignored, if it's gone, it's gone
        end
    else
	super(:comment => "Modified via webui")
        fc = FrontendCompat.new
        fc.do_post nil, self.init_options.merge(:cmd => "runservice")
    end
    true
  end

end
