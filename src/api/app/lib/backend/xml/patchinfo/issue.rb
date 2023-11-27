module Backend::Xml
  class Patchinfo::Issue
    include HappyMapper

    attribute :tracker, String
    attribute :id, String
    attribute :documented, String

    content :summary, String
  end
end
