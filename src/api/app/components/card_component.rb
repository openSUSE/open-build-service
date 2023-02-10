# The card component is shaping the card style only, it does not set anything about the width
# of the card itself because it depends on the occurrence where it is used for.
# I.e: look at the src/api/app/views/webui/repositories/_repository_entry.html.haml
class CardComponent < ApplicationComponent
  renders_one :header
  renders_one :delete_button
  renders_many :actions

  def initialize(extra_classes_for_body: [])
    super

    @extra_classes_for_body = extra_classes_for_body
  end
end
