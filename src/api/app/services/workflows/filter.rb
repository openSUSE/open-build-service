module Workflows
  class Filter
    def initialize(filters:)
      filters ||= {}
      @repository_filters = filters[:repositories]
      @architecture_filters = filters[:architectures]
    end

    def match?(event)
      match_repository?(event.payload['repository']) && match_architecture?(event.payload['arch'])
    end

    private

    def match_repository?(event_repository)
      return true if @repository_filters.blank?

      return true if @repository_filters[:only]&.include?(event_repository)

      return true if @repository_filters[:ignore]&.exclude?(event_repository)

      false
    end

    def match_architecture?(event_architecture)
      return true if @architecture_filters.blank?

      return true if @architecture_filters[:only]&.include?(event_architecture)

      return true if @architecture_filters[:ignore]&.exclude?(event_architecture)

      false
    end
  end
end
