# frozen_string_literal: true

require 'test_helper'

class TestRubyLinkChecker < Minitest::Test

  def test_option_version
    command = Command.new(
      self,
      options: %w[ --version ],
      exp_stdout: /\d+\.\d+\.\d+/
      )
    command.execute
  end

  def test_option_help
    command = Command.new(
      self,
      options: %w[ --help ],
      exp_stdout: 'Usage: bin/ruby_link_checker [options]',
      )
    command.execute
  end

end
