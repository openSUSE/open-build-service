# frozen_string_literal: true
module Event
  PROJECT_CLASSES = ['Event::CommentForProject',
                     'Event::CreateProject',
                     'Event::DeleteProject',
                     'Event::UndeleteProject',
                     'Event::UpdateProjectConfig',
                     'Event::UpdateProject'].freeze
  PACKAGE_CLASSES = ['Event::BranchCommand',
                     'Event::Build',
                     'Event::CommentForPackage',
                     'Event::Commit',
                     'Event::CreatePackage',
                     'Event::DeletePackage',
                     'Event::ServiceFail',
                     'Event::ServiceSuccess',
                     'Event::UndeletePackage',
                     'Event::UpdatePackage',
                     'Event::Upload',
                     'Event::VersionChange'].freeze
end
