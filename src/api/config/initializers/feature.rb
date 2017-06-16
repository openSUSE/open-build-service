require_dependency 'feature_switch/obs_repository'
Feature.set_repository(Feature::Repository::ObsRepository.new("#{Rails.root}/config/feature.yml", Rails.env))
