# frozen_string_literal: true

class PackageMetaFile < PackageFile
  def initialize(attributes = {})
    super
    @name = '_meta'
  end

  # You dont want to change name of _meta
  private :name=
end
