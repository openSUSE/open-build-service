class IssueTracker < ActiveRecord::Base
  has_many :acronyms, :class_name => 'IssueTrackerAcronym', :dependent => :destroy

  validates_associated :acronyms # Validate also associated models
  validates_presence_of :name, :url
  validates_uniqueness_of :name
end
