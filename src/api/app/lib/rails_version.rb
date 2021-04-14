# Check which Rails version is used by the application
#
# This allows code to be migrated to a newer version of Rails while keeping the old code around
# until the migration to the newer Rails version is done.
#
# Use this module in combination with the gem next_rails and its Gemfile.next/Gemfile.next.lock.
#
# Methods of this module must match whatever Rails version is defined in Gemfile.next.lock.
# Matching on major and minor versions should be enough for most migrations.
module RailsVersion
  def self.is_6_1?
    Rails::VERSION::MAJOR == 6 && Rails::VERSION::MINOR == 1
  end
end
