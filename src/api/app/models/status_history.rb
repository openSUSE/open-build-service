class StatusHistory < ActiveRecord::Base
  attr_accessible :time, :key, :value
end
