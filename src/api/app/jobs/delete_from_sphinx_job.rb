class DeleteFromSphinxJob < ApplicationJob
  queue_as :quick

  def perform(id, klass)
    delete_from_sphinx(id: id, klass: klass)
  end

  private

  def delete_from_sphinx(id:, klass:)
    indices(klass: klass).each do |index|
      ThinkingSphinx::Deletion.perform(index, id)
    end
  end

  def indices(klass:)
    ThinkingSphinx::Configuration.instance.index_set_class.new(
      classes: [klass]
    ).to_a
  end
end
