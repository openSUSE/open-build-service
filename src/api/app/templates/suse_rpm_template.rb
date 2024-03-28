class SuseRpmTemplate < ApplicationTemplate
  SUBTEMPLATES = { empty: 'Empty', make: 'Make', meson: 'Meson' }.freeze

  def self.title
    'SUSE style RPM'
  end

  def self.subtemplates
    SUBTEMPLATES
  end

  def initialize(subtemplate:, package:, user:)
    super

    ['spec', 'changes'].each do |file_type|
      @files << uploaded_file("#{package.name}.#{file_type}", render(file_type))
    end
  end
end
