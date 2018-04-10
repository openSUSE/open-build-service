# frozen_string_literal: true

require_dependency 'feature_switch/obs_repository'
require_dependency 'feature_switch/feature'
Feature.set_repository(Feature::Repository::ObsRepository.new("#{Rails.root}/config/feature.yml", Rails.env))
