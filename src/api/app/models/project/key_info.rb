# frozen_string_literal: true
class Project
  class KeyInfo
    include ActiveModel::Model

    attr_accessor :origin,
                  :pubkey,
                  :algorithm,
                  :ssl_certificate,
                  :keyid,
                  :keysize,
                  :expires,
                  :fingerprint

    CACHE_EXPIRY_TIME = 5.minutes

    def self.find_by_project(project)
      response = key_info_for_project(project)

      parsed_response = Xmlhash.parse(response)

      return if parsed_response['pubkey'].blank?

      key_info_params = {
        origin:      parsed_response['project'],
        pubkey:      parsed_response['pubkey']['_content'],
        algorithm:   parsed_response['pubkey']['algo'],
        keyid:       parsed_response['pubkey']['keyid'],
        keysize:     parsed_response['pubkey']['keysize'],
        expires:     parsed_response['pubkey']['expires'],
        fingerprint: parsed_response['pubkey']['fingerprint']
      }

      if parsed_response['sslcert'].present?
        key_info_params[:ssl_certificate] = parsed_response['sslcert']
      end

      key_info_params.delete(:origin) if key_info_params[:origin] == project.name

      new(key_info_params)
    end

    def self.key_info_for_project(project)
      Rails.cache.fetch("key_info_project_#{project.cache_key}", expires_in: CACHE_EXPIRY_TIME) do
        Backend::Api::Sources::Project.key_info(project.name)
      end
    end
  end
end
