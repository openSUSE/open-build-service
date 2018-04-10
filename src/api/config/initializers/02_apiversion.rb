# frozen_string_literal: true
# define our current api version
api_version = '2.8.50'

# the packages define the api_version in environment.rb file already
if CONFIG['version'].blank?
  if defined? API_DATE
    CONFIG['version'] = api_version + '.git' + API_DATE
  else
    CONFIG['version'] = api_version
  end
end
