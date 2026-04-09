# frozen_string_literal: true

require 'open3'
require 'test_helper'

class TestRubyLinkChecker < Minitest::Test

  def test_version
    refute_nil RubyLinkChecker::VERSION
  end

  # The default source for the link checker should exist.
  def test_master_exists
    master_url = File.join(RubyLinkChecker::BASE_URL, 'master', '')
    uri = URI.parse(master_url)
    response =  Net::HTTP.get_response(uri)
    assert_equal('200', response.code)
  end

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

  # Class to execute a command.
  class Command

    attr_accessor :test,                                  # TestRubyLinkChecker object
                  :options, :arguments,                   # CLI options and arguments.
                  :exp_stdout, :exp_stderr, :exp_status,  # Expected output values.
                  :act_stdout, :act_stderr, :act_status   # Actual output values.

    # Returns a new Command object.
    def initialize(
      test,
      options: [],
      arguments: [],
      exp_stdout: '',
      exp_stderr: '',
      exp_status: 0)
      self.test = test
      self.options = options
      self.arguments = arguments
      self.exp_stdout = exp_stdout
      self.exp_stderr = exp_stderr
      self.exp_status = exp_status
    end

    EXECUTABLE_PATH = 'bin/ruby_link_checker'

    # Executes the command, after which actual values are available.
    def execute
      command = "ruby #{EXECUTABLE_PATH} #{options.join(' ')} #{arguments.join(' ')}"
      self.act_stdout, self.act_stderr, status = Open3.capture3(command)
      test.assert_match(exp_stdout, act_stdout, 'stdout')
      test.assert_match(exp_stderr, act_stderr, 'stderr')
      self.act_status = status.exitstatus
      test.assert_equal(exp_status, act_status, 'status')
    end
  end

end
