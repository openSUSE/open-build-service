require 'webmock/rspec'

# Allow webdriver update urls
# from https://github.com/titusfortner/webdrivers/wiki/Using-with-VCR-or-WebMock
allowed_urls = Webdrivers::Common.subclasses.map(&:base_url)
allowed_urls << /github\.com\/mozilla\/geckodriver/
# github.com/mozilla/geckodriver might redirect here
allowed_urls += ['github-releases.githubusercontent.com']

WebMock.disable_net_connect!(allow_localhost: true, allow: allowed_urls)
