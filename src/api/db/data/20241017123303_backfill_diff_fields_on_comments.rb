# frozen_string_literal: true

class BackfillDiffFieldsOnComments < ActiveRecord::Migration[7.0]
  def up
    return unless User.columns.any? { |c| c.name == 'diff_ref' }

    Comment.where.not(diff_ref: [nil, '']).where(diff_file_index: nil).in_batches do |batch|
      batch.find_each do |comment|
        diff_file_index, diff_line_number = comment.diff_ref.match(/diff_([0-9]+)_n([0-9]+)/).captures

        comment.update!(diff_file_index:, diff_line_number:)
      end
    end
  end

  def down
    return unless User.columns.any? { |c| c.name == 'diff_ref' }

    Comment.where.not(diff_file_index: nil).in_batches do |batch|
      batch.find_each do |comment|
        comment.update!(diff_file_index: nil, diff_line_number: nil)
      end
    end
  end
end
