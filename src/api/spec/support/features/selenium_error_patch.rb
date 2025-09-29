# Monkey patch for a specific intermittent Selenium error.
#
# Intermittently, Selenium/Chromedriver raises `Selenium::WebDriver::Error::UnknownError`
# with the message "Node with given id does not belong to the document".

# Capybara's automatic waiting/retrying mechanism doesn't catch it,
# leading to failure.
#
# We intercept the initialization of `UnknownError`. If the message matches this specific
# case, we raise a `StaleElementReferenceError` instead. This uses Capybara's
# retry logic which makes doesn't fail the test
#
# This can be removed once the following issue is resolved:
# https://github.com/teamcapybara/capybara/issues/2800
#
# taken from the following issue:
# https://github.com/teamcapybara/capybara/issues/2800#issuecomment-3049956982

module Selenium
  module WebDriver
    module Error
      class UnknownError
        alias old_initialize initialize
        def initialize(msg = nil)
          raise StaleElementReferenceError, msg if msg&.include?('Node with given id does not belong to the document')

          old_initialize(msg)
        end
      end
    end
  end
end
