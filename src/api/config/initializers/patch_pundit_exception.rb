# This monkey patch allows custom messages for a Pundit error.
#
# This is an exact copy of Pundit #master.
# Refs:
#  - commit: https://github.com/varvet/pundit/commit/973b63b396c2a98099caf5eefd1c6841416eddfa
#  - file: https://github.com/varvet/pundit/blob/504b86a09de57490bf3855b810088a2916cc3d44/lib/pundit.rb#L24-L41
#
# TODO: Remove this after a new Pundit release.
module Pundit
  class NotAuthorizedError < Error
    attr_reader :query, :record, :policy, :reason

    def initialize(options = {})
      if options.is_a?(String)
        message = options
      else
        @query  = options[:query]
        @record = options[:record]
        @policy = options[:policy]
        @reason = options[:reason]

        message = options.fetch(:message) { "not allowed to #{query} this #{record.class}" }
      end

      super(message)
    end
  end
end
