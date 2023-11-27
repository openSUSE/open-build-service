module Backend::Xml
  class Patchinfo::Releasetarget
    include HappyMapper

    attribute :project, String
    attribute :repository, String
  end
end
