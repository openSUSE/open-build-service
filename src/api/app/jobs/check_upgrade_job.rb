class CheckUpgradeJob < ApplicationJob
  
  def perform(project_name, package_name)
    Rails.logger.debug "Running check upgrade job ...."

    #Inizialize
    urlsrc = nil
    regexurl = nil
    regexver = nil
    currentver = nil
    separator = "."
    debug = "false"

    #Get all services
    document = Backend::Api::Sources::Package.service(project_name, package_name)
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

          #Fixme
          #Calls the script and generates the file ....

        end  
      end
    end

    Rails.logger.info "Check upgrade job finished!"
  end

end