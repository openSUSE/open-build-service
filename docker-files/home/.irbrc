# frozen_string_literal: true

require 'irb/completion'
require 'irb/ext/save-history'

ARGV.push('--readline', '--prompt-mode', 'simple')

# 500 entries in the list
IRB.conf[:SAVE_HISTORY] = 500

# Store results in home directory with specified file name
IRB.conf[:HISTORY_FILE] = "#{Dir.home}/.irb_history"
