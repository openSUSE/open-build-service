class Staging::ProjectCategory < ApplicationRecord
  def self.table_name_prefix
    'staging_'
  end

  belongs_to :staging_workflow, class_name: 'Staging::Workflow'

  validates :staging_workflow, :title, :name_pattern, presence: true
  validates :title, length: { maximum: 30 }
  validate :valid_regexp

  def nick(project)
    match = compiled.match(project.to_s)
    return unless match
    match[:nick]
  end

  private

  def compiled
    @compiled || Regexp.new(name_pattern)
  end

  def valid_regexp
    begin
      regexp = Regexp.new(name_pattern.to_s)
      return if regexp.inspect =~ /\(\?<nick>.*\)/
    rescue RegexpError, TypeError
    end
    errors.add(:name_pattern, 'needs to be a regexp with capture group for "nick"')
  end
end
