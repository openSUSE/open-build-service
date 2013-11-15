require 'test_helper'

class WebuiPackageTest < ActiveSupport::TestCase
  test 'is_binary_file?' do
    file_paths = [
      '/tmp/some/file',
      '/srv/www/another_file_',
      '/var/lib/cache/file with spaces'
    ]

    filename = ''

    # binary files
    generate_suffixes(%w{exe bin bz bz2 gem gif jpg jpeg ttf zip gz png}).each do |suffix|
      file_paths.each do |file_path|
        filename = file_path + '.' + suffix
        assert PackageHelper::is_binary_file?(filename), "File #{filename} should be treated as binary"
      end
    end

    # these aren't binary
    generate_suffixes(%w{diff txt csv pm c rb h}).each do |suffix|
      file_paths.each do |file_path|
        filename = file_path + '.' + suffix
        assert !PackageHelper::is_binary_file?(filename), "File #{filename} should not be treated as binary"
      end
    end
  end

  private

  # gets list of strings and tries to generate another longer list
  # with some letters up/down-cased, based on the original list
  def generate_suffixes(suffixes_in)
    suffixes_out = suffixes_in.dup
    # some lower-cased suffixes
    suffixes_out.collect!{|i| i.downcase}
    # the same ones capitalized
    suffixes_out.concat(suffixes_in.collect{|i| i.capitalize})
    # the same ones upper-cased
    suffixes_out.concat(suffixes_in.collect{|i| i.upcase})
    # the same ones swap-cased
    suffixes_out.concat(suffixes_in.collect{|i| i.capitalize.swapcase})
  end
end
