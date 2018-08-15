require_dependency 'feature_switch/feature'
Feature.set_repository(Feature::Repository::YamlRepository.new("#{Rails.root}/config/feature.yml", Rails.env))
