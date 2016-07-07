class DistributionIcon < ApplicationRecord
  validates_presence_of :url
  # TODO: Allow file-upload later on, probably thru CarrierWave gem

  has_and_belongs_to_many :distributions
end
