# frozen_string_literal: true

require_relative 'test_helper'

class PlaywrightCompatTest < Minitest::Test
  def test_debugger_channel_owner_is_defined
    assert Playwright::ChannelOwners.const_defined?(:Debugger, false)
  end
end
