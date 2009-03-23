require 'natcmp' unless ''.respond_to? :natcmp

if Rails.version.natcmp("2.2.0") < 0
  class Array
    undef_method :count if method_defined? :count
  end
end
