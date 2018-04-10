# frozen_string_literal: true
require 'bs_request_action/differ/for_source'

# this overwrites the sourcediff function for submit requests and maintenance
class BsRequestAction
  module Differ
    def sourcediff(options = {})
      source_package_names = SourcePackageFinder.new(bs_request_action: self).all
      ForSource.new(
        bs_request_action: self,
        source_package_names: source_package_names,
        options: options
      ).perform
    end
  end
end
