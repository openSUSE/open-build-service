module Event
  module CommentEvent
    def self.included(base)
      base.class_eval do
        payload_keys :commenters, :commenter, :comment_body, :comment_title
        receiver_roles :commenter
        shortenable_key :comment_body
      end
    end

    def expanded_payload
      p = payload.dup
      p['commenter'] = User.find_by(login: p['commenter'])
      p
    end

    def originator
      User.find_by(login: payload['commenter'])
    end

    def commenters
      return User.none unless payload['commenters']
      User.where(login: payload['commenters'])
    end

    def custom_headers
      h = super
      h['X-OBS-Request-Commenter'] = originator.login
      h
    end
  end
end
