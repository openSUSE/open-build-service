class Workflow
  module Step
    class BranchPackageStep
      include ActiveModel::Model
      # TODO: Placeholder to be able to test the Workflow model. The code for this class will be added in another PR.
      def initialize(step_instructions:, scm_extractor_payload:); end

      def allowed_event_and_action?
        true
      end
    end
  end
end
