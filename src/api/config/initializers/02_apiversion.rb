# define our current api version
api_version = '2.10.50'

# the packages define the api_version in environment.rb file already
if CONFIG['version'].blank?
  CONFIG['version'] = if defined? API_DATE
                        "#{api_version}.git#{API_DATE}"
                      else
                        api_version
                      end
end
