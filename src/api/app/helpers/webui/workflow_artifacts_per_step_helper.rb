module Webui
  module WorkflowArtifactsPerStepHelper
    def paths_sentence(repository)
      repository[:paths].map { |path| "#{path[:target_project]}/#{path[:target_repository]}" }.to_sentence
    end
  end
end
