# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'playwright'

module Sunpass
  class Client
    LOGIN_URL_DEFAULT = 'https://www.sunpass.com/vector/account/home/accountLogin.do'
    TRANSACTIONS_URL_DEFAULT = 'https://www.sunpass.com/vector/account/transactions/webtransactionSearch.do'

    # These selectors are intentionally grouped so they are easy to adapt when SunPass changes markup.
    USERNAME_SELECTORS = [
      '#tt_username',
      'input[name="tt_username"]',
      'input[name="username"]',
      'input[name="userName"]',
      'input[name="login"]',
      'input[name="loginName"]',
      'input[name*="login"]',
      'input[id*="user"]',
      'input[id*="login"]',
      'input[placeholder*="Login"]',
      'input[aria-label*="Login"]'
    ].freeze

    PASSWORD_SELECTORS = [
      '#tt_loginPassword',
      'input[name="tt_loginPassword"]',
      'input[type="password"]',
      'input[name="password"]',
      'input[id*="pass"]'
    ].freeze

    LOGIN_BUTTON_SELECTORS = [
      'button:has-text("Log In")',
      'button:has-text("Login")',
      'input[value*="Login"]',
      'input[type="submit"]',
      'button[type="submit"]'
    ].freeze

    TRANSACTION_ROW_SELECTORS = [
      '#transactionItem > tbody > tr.footable-row-detail',
      '#transactionItem > tbody > tr',
      '#transactionItem tbody tr',
      'tr.footable-row-detail',
      'tr.footable-row',
      'tr[class*="footable"]',
      'table tbody tr',
      '#transactionTable tbody tr',
      'tr[id*="transaction"]'
    ].freeze

    def initialize(
      username:,
      password:,
      headless: true,
      login_url: LOGIN_URL_DEFAULT,
      transactions_url: TRANSACTIONS_URL_DEFAULT,
      playwright_cli_executable_path: ENV.fetch('PLAYWRIGHT_CLI_EXECUTABLE_PATH', 'npx playwright'),
      logger: nil
    )
      @username = username
      @password = password
      @headless = headless
      @login_url = login_url
      @transactions_url = transactions_url
      @playwright_cli_executable_path = playwright_cli_executable_path
      @logger = logger
    end

    def fetch_transactions(lookback_days: 30, from_date: nil, to_date: nil)
      log("Launching browser (headless=#{@headless})")
      Playwright.create(playwright_cli_executable_path: @playwright_cli_executable_path) do |playwright|
        browser = playwright.chromium.launch(headless: @headless)
        context = browser.new_context
        page = context.new_page

        login(page)
        open_transactions(
          page,
          lookback_days: lookback_days,
          from_date: from_date,
          to_date: to_date
        )

        rows = find_transaction_row_texts(page)
        log("Found #{rows.size} transaction row(s)")
        rows
      ensure
        log('Closing browser')
        browser&.close
      end
    end

    private

    def login(page)
      log("Opening login page: #{@login_url}")
      page.goto(@login_url)
      page.wait_for_timeout(1500)

      log('Filling username')
      fill_first_match(page, USERNAME_SELECTORS, @username)
      log('Filling password')
      fill_first_match(page, PASSWORD_SELECTORS, @password)
      log('Submitting login form')
      click_first_match(page, LOGIN_BUTTON_SELECTORS)

      # Let post-login redirects settle.
      page.wait_for_load_state(state: 'networkidle')
      page.wait_for_timeout(2000)
      log('Login flow completed')
    end

    def open_transactions(page, lookback_days:, from_date: nil, to_date: nil)
      log("Opening transactions page: #{@transactions_url}")
      page.goto(@transactions_url)
      page.wait_for_load_state(state: 'networkidle')

      # Best-effort filter fields. Safe if they do not exist.
      computed_from_date = from_date || (Date.today - lookback_days).strftime('%m/%d/%Y')
      computed_to_date = to_date || Date.today.strftime('%m/%d/%Y')
      log("Applying date filter #{computed_from_date} to #{computed_to_date} (best effort)")

      from_filled = try_fill(page, '#startDateAll1', computed_from_date) ||
                    try_fill(page, 'input[name*="from"]', computed_from_date)
      to_filled = try_fill(page, '#endDateAll1', computed_to_date) ||
                  try_fill(page, 'input[name*="to"]', computed_to_date)
      log("Date fields filled: from=#{from_filled} to=#{to_filled}")

      search_clicked = try_click(page, 'button[name="btnView"]') ||
                       try_click(page, 'button[value="1"]') ||
                       try_click(page, 'button:has-text("VIEW")') ||
                       try_click(page, 'button:has-text("View")') ||
                       try_click(page, 'input[name="btnView"]') ||
                       try_click(page, 'button:has-text("Search")') ||
                       try_click(page, 'input[value*="Search"]') ||
                       try_click(page, '#searchButton') ||
                       try_click(page, '#search')
      if search_clicked
        log('Clicked Search; waiting for results')
        page.wait_for_load_state(state: 'networkidle')
        page.wait_for_timeout(2000)
      else
        log('Search button not found/clicked; continuing with current page state')
      end
    end

    def find_transaction_row_texts(page)
      best_rows = []
      frames = page.frames
      log("Inspecting #{frames.size} frame(s) for transaction rows")

      frames.each_with_index do |frame, index|
        frame_name = frame.name.to_s.strip
        frame_url = frame.url.to_s.strip
        log("Frame #{index}: name=#{frame_name.empty? ? '(blank)' : frame_name} url=#{frame_url}")

        TRANSACTION_ROW_SELECTORS.each do |selector|
          rows = extract_rows_from_frame(frame, selector)
          next if rows.empty?

          log("Frame #{index} selector #{selector.inspect}: non-empty #{rows.size}")
          best_rows = rows if rows.size > best_rows.size
        end
      end

      dump_debug_artifacts(page) if best_rows.empty?
      best_rows
    end

    def fill_first_match(page, selectors, value)
      selectors.each do |selector|
        locator = page.locator(selector)
        count = locator.count
        next unless count.positive?

        count.times do |i|
          next unless try_fill_locator(locator.nth(i), value)

          return true
        end
      end
      raise "Could not find fillable input for any selector: #{selectors.inspect}"
    end

    def click_first_match(page, selectors)
      selectors.each do |selector|
        begin
          locator = page.locator(selector)
          count = locator.count
          next unless count.positive?

          count.times do |i|
            next unless try_click_locator(locator.nth(i))

            return true
          end
        rescue StandardError => e
          # A successful submit can navigate immediately and invalidate the old context.
          if navigation_context_destroyed?(e)
            log('Navigation started during submit click')
            return true
          end
        end
      end
      raise "Could not find clickable element for any selector: #{selectors.inspect}"
    end

    def try_fill(page, selector, value)
      locator = page.locator(selector).first
      try_fill_locator(locator, value)
    rescue StandardError
      false
    end

    def try_click(page, selector)
      locator = page.locator(selector).first
      try_click_locator(locator)
    rescue StandardError
      false
    end

    def try_fill_locator(locator, value)
      locator.fill(value, timeout: 2_000)
      true
    rescue StandardError
      false
    end

    def try_click_locator(locator)
      locator.click(timeout: 2_000)
      true
    rescue StandardError => e
      return true if navigation_context_destroyed?(e)

      false
    end

    def navigation_context_destroyed?(error)
      return false unless defined?(Playwright::Error) && error.is_a?(Playwright::Error)

      error.message.include?('Execution context was destroyed')
    end

    def extract_rows_from_frame(frame, selector)
      values = frame.eval_on_selector_all(
        selector,
        'els => els.map(e => (e.innerText || e.textContent || "").replace(/\\s+/g, " ").trim()).filter(Boolean)'
      )
      values.is_a?(Array) ? values.map(&:to_s).reject(&:empty?) : []
    rescue StandardError
      []
    end

    def dump_debug_artifacts(page)
      FileUtils.mkdir_p('tmp')
      path = 'tmp/last_transactions_page.html'
      File.write(path, page.content)
      log("No rows found. Saved page HTML to #{path}")
    rescue StandardError => e
      log("Failed to save debug HTML: #{e.class}")
    end

    def log(message)
      return unless @logger

      @logger.call(message)
    end
  end
end
