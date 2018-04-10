# frozen_string_literal: true
class BsRequest
  module DataTable
    class ParamsParserWithStateAndType < ParamsParser
      def parsed_params
        super.merge(types: types, states: states)
      end

      private

      def types
        [@requested_params[:type]] if @requested_params[:type].present? && @requested_params[:type] != 'all'
      end

      def states
        if @requested_params[:state] == 'new or review'
          ['new', 'review']
        elsif @requested_params[:state].present?
          [@requested_params[:state]]
        end
      end
    end
  end
end
