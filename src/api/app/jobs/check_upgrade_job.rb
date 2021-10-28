class CheckUpgradeJob < ApplicationJob
  
  def perform(project_id, package_id=nil)
    Rails.logger.debug "Running check upgrade job ...."

    if package_id.present?    
      packages = Package.all.where(id: package_id, project_id: project_id)
    else
      packages = Package.all.where(project_id: project_id)
    end

    packages.each do |package|

      #Initializing the script input parameters
      urlsrc = nil
      regexurl = nil
      regexver = nil
      currentver = nil
      separator = "."
      debug = "false"

      #Get all services
      document = Backend::Api::Sources::Package.service(package.project.name, package.name)
      if document.present?
        Xmlhash.parse(document).elements('service').each do |service|
          if service['name'] == 'check_upgrade'
            #Preparing parameters...
            service['param'].each do |param|
                case param['name']
                  when 'urlsrc'
                    urlsrc = param['_content']                
                  when 'regexurl'
                    regexurl = param['_content']                
                  when 'regexver'
                    regexver = param['_content']                
                  when 'currentver'
                    currentver = param['_content']                
                  when 'separator'
                    separator = param['_content']                
                  when 'debug'
                    debug = param['_content']                
                end
            end

            #Execute the script
            params = "--urlsrc='" + urlsrc + "' \
                      --regexurl='" + regexurl + "' \
                      --regexver='" + regexver + "' \
                      --currentver='" + currentver + "' \
                      --separator='" + separator + "' \
                      --debug='" + debug + "'"
            
            #FIXME
            result = `/usr/lib/obs/service/check_upgrade #{params}`

            #Generate the files according result value


          end  
        end
      end
    end

    Rails.logger.info "Check upgrade job finished!"
  end

end