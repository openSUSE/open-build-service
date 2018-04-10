# frozen_string_literal: true
class PackageServiceErrorFile < PackageFile
  def initialize(attributes = {})
    super
    @name = '_serviceerror'
  end

  # You dont want to change name of _serviceerror
  private :name=
end
