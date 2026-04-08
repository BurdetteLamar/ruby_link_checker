# frozen_string_literal: true

require 'test_helper'

class TestRubyLinkChecker < Minitest::Test

  def test_version
    refute_nil ::RubyLinkChecker::VERSION
  end

  # This is the default source for the link checker;  it should exist.
  def test_master_exists
    master_url = File.join(RubyLinkChecker::BASE_URL, 'master', '')
    uri = URI.parse(master_url)
    response =  Net::HTTP.get_response(uri)
    assert_equal('200', response.code)
  end

  def test_option_help
    options = %w[ --help ]
    arguments = []
    stdout_s, stderr_s, status = do_command(options, arguments)
    usage_text = 'Usage: bin/ruby_link_checker [options]'
    assert_match(usage_text, stdout_s)
    assert_empty(stderr_s)
    assert_equal(0, status.exitstatus)
  end

  def do_command(options, arguments)
    executable = 'bin/ruby_link_checker'
    command = "ruby #{executable} #{options.join(' ')} #{arguments.join(' ')}"
    require 'open3'
    Open3.capture3(command)
  end
end


