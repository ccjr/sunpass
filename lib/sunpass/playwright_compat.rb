# frozen_string_literal: true

require 'playwright'

module Sunpass
  module PlaywrightCompat
    module_function

    def install!
      return unless defined?(Playwright::ChannelOwners)
      return if Playwright::ChannelOwners.const_defined?(:Debugger, false)

      Playwright.define_channel_owner('Debugger')
    end
  end
end

Sunpass::PlaywrightCompat.install!
