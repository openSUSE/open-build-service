class BsRequestAction
  module Differ
    class QueryBuilderForAccepted
      include ActiveModel::Model
      attr_accessor :bs_request_action_accept_info

      def build
        query = {}
        query[:rev] = bs_request_action_accept_info.xsrcmd5 || bs_request_action_accept_info.srcmd5
        query[:orev] = bs_request_action_accept_info.oxsrcmd5 || bs_request_action_accept_info.osrcmd5 || '0'
        query[:oproject] = bs_request_action_accept_info.oproject if bs_request_action_accept_info.oproject
        query[:opackage] = bs_request_action_accept_info.opackage if bs_request_action_accept_info.opackage
        query
      end
    end
  end
end
