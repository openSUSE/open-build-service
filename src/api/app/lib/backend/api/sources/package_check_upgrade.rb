module Backend
  module Api
    module Sources
      # Class that connect to endpoints related to source packages
      module PackageCheckUpgrade
        extend Backend::ConnectionHelper

        # Runs the command checkupgrade
        # @return [String]
        def self.check_upgrade(urlsrc, regexurl, regexver, currentver, separator, debug, user_login)
          http_post(['/source/checkupgrade'], 
                      params: { cmd: :checkupgrade, urlsrc: urlsrc, regexurl: regexurl,
                                regexver: regexver, currentver: currentver,
                                separator: separator, debug: debug, user: user_login  
                              })
        end

      end
    end
  end
end
