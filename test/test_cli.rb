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
  # The tests verify only that the options are passed correctly,
  # not that the checker uses them well or wisely;
  # that's a job for other tests.

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

  def test_option_verbosity
    Command.new(
      self,
      options: %w[ --no-op ],
      exp_stdout: 'verbosity: minimal'
    ).execute
    %w[quiet minimal debug].each do |setting|
      Command.new(
        self,
        options: [ '--no-op', "--verbosity=#{setting}"],
        exp_stdout: "verbosity: #{setting}"
      ).execute
    end
    Command.new(
      self,
      options: %w[ --no-op --verbosity=FOO ],
      exp_status: 1,
      exp_stderr: 'FOO',
    ).execute
  end

  def test_option_legal
    Command.new(
      self,
      options: %w[ --no-op ],
      exp_stdout: 'legal: false'
    ).execute
    Command.new(
      self,
      options: %w[ --no-op --legal ],
      exp_stdout: 'legal: true'
    ).execute
  end

  def test_option_news
    Command.new(
      self,
      options: %w[ --no-op ],
      exp_stdout: 'news: false'
    ).execute
    Command.new(
      self,
      options: %w[ --no-op --news ],
      exp_stdout: 'news: true'
    ).execute
  end

  def test_option_github_lines
    Command.new(
      self,
      options: %w[ --no-op ],
      exp_stdout: 'github_lines: false'
    ).execute
    Command.new(
      self,
      options: %w[ --no-op --github-lines ],
      exp_stdout: 'github_lines: true'
    ).execute
  end

end
