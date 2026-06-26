module Event
  PROJECT_CLASSES = ['Event::CommentForProject',
                     'Event::UpdateProjectConfig',
                     'Event::UpdateProject'].freeze
  PACKAGE_CLASSES = ['Event::BranchCommand',
                     'Event::BuildSuccess',
                     'Event::BuildFail',
                     'Event::CommentForPackage',
                     'Event::Commit',
                     'Event::CreatePackage',
                     'Event::DeletePackage',
                     'Event::ServiceFail',
                     'Event::ServiceSuccess',
                     'Event::UndeletePackage',
                     'Event::UpdatePackage',
                     'Event::VersionChange'].freeze
end
