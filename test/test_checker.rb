# frozen_string_literal: true

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

end
