# frozen_string_literal: true

require 'test_helper'

class TestRubyLinkChecker < Minitest::Test

  # The tests for the first two options do not call the checker.

  def test_option_version
    Command.new(
      self,
      options: %w[ --version ],
      exp_stdout: /\d+\.\d+\.\d+/
    ).execute
  end

  def test_option_help
    Command.new(
      self,
      options: %w[ --help ],
      exp_stdout: 'Usage: bin/ruby_link_checker [options]',
      ).execute
  end

  # The tests for the options below use option --no-op
  # to cause the checker and its reporter to print options.

  def test_option_no_op
    Command.new(
      self,
      options: %w[ --no-op ],
      exp_stdout: 'no_op: true'
    ).execute
  end

  def test_option_source
    Command.new(
      self,
      options: %w[ --no-op ],
      exp_stdout: 'source: master'
    ).execute
    Command.new(
      self,
      options: %w[ --no-op --source=FOO ],
      exp_stdout: 'source: FOO'
    ).execute
  end

end
