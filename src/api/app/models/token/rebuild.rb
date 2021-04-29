class Token::Rebuild < Token
  def self.token_name
    'rebuild'
  end

  def call(options)
    # FIXME: Use the Package#rebuild? instead of calling the Backend directly
    Backend::Api::Sources::Package.rebuild(project_from_association_or_params.name,
                                           package_from_association_or_params.name,
                                           options.slice(:repository, :arch))

    # TODO: This will be done beforehand... so we can use that
    # payload = SCMExtractor.new(options[:request]).call
    #
    # Pseudo code for SCMExtractor
    # - is it GitHub or GitLab
    # - retrieve the webhook payload
    # - return the fields we need
    #
    # payload would contain the following:
    #  GitHub:
    #  {
    #  scm: :github,
    #  repository_owner: 'openSUSE',
    #  repository_name: 'open-build-service',
    #  commit_sha: okgofdkgok4305045ofkodkgodfkg
    #  }
    #  GitLab:
    #  {
    #  scm: :gitlab,
    #  project_id: 123
    #  commit_sha: ogfkgofdkgoo095043939
    #  }
    #
    # Just a test for GitHub
    # payload = {
    #   scm: :github,
    #   repository_owner: 'vpereira',
    #   repository_name: 'test-repo',
    #   commit_sha: '1793ce9f361c9eb19c0874b209a43fc1faae41e9'
    # }
    #
    # Just a test for GitLab
    # payload = {
    #   scm: :gitlab,
    #   project_id: 26270676,
    #   commit_sha: '78139bf5d91ca3df43eebe8d3381544fd8e2d061'
    # }

    # TODO: Everything below is going to be in Token::Workflow once we have that model
    ['Event::BuildFail', 'Event::BuildSuccess'].each do |event|
      EventSubscription.create!(eventtype: event,
                                receiver_role: 'watcher', # TODO: check if this makes sense
                                user: user,
                                channel: 'scm',
                                enabled: true,
                                token: self,
                                payload: payload)
    end

    SCMStatusReporter.new(payload, scm_token).call
  end

  def package_find_options
    { use_source: false, follow_project_links: true, follow_multibuild: true }
  end
end

# == Schema Information
#
# Table name: tokens
#
#  id         :integer          not null, primary key
#  scm_token  :string(255)      indexed
#  string     :string(255)      indexed
#  type       :string(255)
#  package_id :integer          indexed
#  user_id    :integer          not null, indexed
#
# Indexes
#
#  index_tokens_on_scm_token  (scm_token)
#  index_tokens_on_string     (string) UNIQUE
#  package_id                 (package_id)
#  user_id                    (user_id)
#
# Foreign Keys
#
#  tokens_ibfk_1  (user_id => users.id)
#  tokens_ibfk_2  (package_id => packages.id)
#
