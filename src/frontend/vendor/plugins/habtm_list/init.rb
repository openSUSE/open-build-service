require 'habtm_list'

ActiveRecord::Base.class_eval do
  include RailsExtensions::HabtmList
end