# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'playwright'

module Sunpass
  class Client
    LOGIN_URL_DEFAULT = 'https://www.sunpass.com/vector/account/home/accountLogin.do'
    TRANSACTIONS_URL_DEFAULT = 'https://www.sunpass.com/vector/account/transactions/webtransactionSearch.do'
    TRANSPONDERS_URL_DEFAULT = 'https://www.sunpass.com/vector/account/transponders/tagsandvehiclesList.do'

    # These selectors are intentionally grouped so they are easy to adapt when SunPass changes markup.
    USERNAME_SELECTORS = [
      '#tt_username1'
    ].freeze

    PASSWORD_SELECTORS = [
      '#tt_loginPassword1'
    ].freeze

    LOGIN_BUTTON_SELECTORS = [
      'button:has-text("Log In")',
      'button:has-text("Login")',
      'input[value*="Login"]',
      'input[type="submit"]',
      'button[type="submit"]'
    ].freeze

    TRANSACTION_ROW_SELECTORS = [
      '#transactionItem > tbody > tr',
      '#transactionItem tbody tr',
      '#transactionTable tbody tr',
      'tr.footable-row',
      'tr[class*="footable"]',
      'tr[id*="transaction"]',
      'table tbody tr'
    ].freeze

    TRANSPONDER_ROW_SELECTORS = [
      '#resultTransponderid > tbody > tr',
      '#resultTransponderid tbody tr',
      '#transponderItem tbody tr',
      '#transponderTable tbody tr',
      '#vehicleTransponderTable tbody tr',
      'tr[id*="transponder"]',
      'tr[class*="transponder"]',
      '.transponder-item',
      '.transponder-card',
      'table tbody tr'
    ].freeze

    def initialize(
      username:,
      password:,
      headless: true,
      login_url: LOGIN_URL_DEFAULT,
      transactions_url: TRANSACTIONS_URL_DEFAULT,
      transponders_url: TRANSPONDERS_URL_DEFAULT,
      playwright_cli_executable_path: ENV.fetch('PLAYWRIGHT_CLI_EXECUTABLE_PATH', 'npx playwright'),
      transaction_parser: TransactionParser.new,
      transponder_parser: TransponderParser.new,
      logger: nil
    )
      @username = username
      @password = password
      @headless = headless
      @login_url = login_url
      @transactions_url = transactions_url
      @transponders_url = transponders_url
      @playwright_cli_executable_path = playwright_cli_executable_path
      @transaction_parser = transaction_parser
      @transponder_parser = transponder_parser
      @logger = logger
    end

    def fetch_transactions(lookback_days: 30, from_date: nil, to_date: nil)
      raw_rows = fetch_transaction_rows(
        lookback_days: lookback_days,
        from_date: from_date,
        to_date: to_date
      )
      @transaction_parser.parse_rows(raw_rows)
    end

    def fetch_transaction_rows(lookback_days: 30, from_date: nil, to_date: nil)
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

        rows = find_transaction_row_texts(
          page,
          artifact_path: 'tmp/last_transactions_page.html'
        )
        log("Found #{rows.size} transaction row(s)")
        rows
      ensure
        log('Closing browser')
        browser&.close
      end
    end

    def fetch_transponders(transponders_url: @transponders_url)
      records = fetch_transponder_records(transponders_url: transponders_url)
      unless records.empty?
        transponders = @transponder_parser.parse_records(records)
        return transponders unless transponders.empty?
      end

      raw_rows = fetch_transponder_rows(transponders_url: transponders_url)
      @transponder_parser.parse_rows(raw_rows)
    end

    def fetch_transponder_rows(transponders_url: @transponders_url)
      log("Launching browser (headless=#{@headless})")
      Playwright.create(playwright_cli_executable_path: @playwright_cli_executable_path) do |playwright|
        browser = playwright.chromium.launch(headless: @headless)
        context = browser.new_context
        page = context.new_page

        login(page)
        open_transponders(page, transponders_url: transponders_url)

        rows = find_transponder_row_texts(
          page,
          artifact_path: 'tmp/last_transponders_page.html'
        )
        log("Found #{rows.size} transponder row(s)")
        rows
      ensure
        log('Closing browser')
        browser&.close
      end
    end

    def fetch_transponder_records(transponders_url: @transponders_url)
      log("Launching browser (headless=#{@headless})")
      Playwright.create(playwright_cli_executable_path: @playwright_cli_executable_path) do |playwright|
        browser = playwright.chromium.launch(headless: @headless)
        context = browser.new_context
        page = context.new_page

        login(page)
        open_transponders(page, transponders_url: transponders_url)

        records = extract_transponder_records(page)
        log("Found #{records.size} structured transponder row(s)")
        records
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

    def open_transponders(page, transponders_url:)
      log("Opening transponders page: #{transponders_url}")
      page.goto(transponders_url)
      page.wait_for_load_state(state: 'networkidle')
      page.wait_for_timeout(2000)
    end

    def extract_transponder_records(page)
      frames = page.frames
      log("Inspecting #{frames.size} frame(s) for structured transponder rows")

      frames.each_with_index do |frame, index|
        frame_name = frame.name.to_s.strip
        frame_url = frame.url.to_s.strip
        log("Frame #{index}: name=#{frame_name.empty? ? '(blank)' : frame_name} url=#{frame_url}")

        records = extract_transponder_records_from_frame(frame)
        next if records.empty?

        log("Frame #{index} structured selector \"#resultTransponderid > tbody > tr\": #{records.size}")
        return records
      end

      dump_debug_artifacts(page, 'tmp/last_transponders_page.html')
      []
    end

    def find_transaction_row_texts(page, artifact_path:)
      best_rows = []
      best_score = nil
      frames = page.frames
      log("Inspecting #{frames.size} frame(s) for transaction rows")

      frames.each_with_index do |frame, index|
        frame_name = frame.name.to_s.strip
        frame_url = frame.url.to_s.strip
        log("Frame #{index}: name=#{frame_name.empty? ? '(blank)' : frame_name} url=#{frame_url}")

        TRANSACTION_ROW_SELECTORS.each do |selector|
          rows = extract_rows_from_frame(frame, selector)
          next if rows.empty?

          filtered_rows = filter_transaction_candidate_rows(rows)
          score = transaction_row_score(rows, filtered_rows, selector)
          log("Frame #{index} selector #{selector.inspect}: total=#{rows.size} filtered=#{filtered_rows.size} score=#{score}")

          next unless better_transaction_row_score?(score, best_score)

          best_rows = filtered_rows.empty? ? rows : filtered_rows
          best_score = score
        end
      end

      dump_debug_artifacts(page, artifact_path) if best_rows.empty?
      best_rows
    end

    def find_row_texts(page, selectors:, artifact_path:, label:)
      best_rows = []
      frames = page.frames
      log("Inspecting #{frames.size} frame(s) for #{label} rows")

      frames.each_with_index do |frame, index|
        frame_name = frame.name.to_s.strip
        frame_url = frame.url.to_s.strip
        log("Frame #{index}: name=#{frame_name.empty? ? '(blank)' : frame_name} url=#{frame_url}")

        selectors.each do |selector|
          rows = extract_rows_from_frame(frame, selector)
          next if rows.empty?

          log("Frame #{index} selector #{selector.inspect}: non-empty #{rows.size}")
          best_rows = rows if rows.size > best_rows.size
        end
      end

      dump_debug_artifacts(page, artifact_path) if best_rows.empty?
      best_rows
    end

    def find_transponder_row_texts(page, artifact_path:)
      best_rows = []
      best_score = nil
      frames = page.frames
      log("Inspecting #{frames.size} frame(s) for transponder rows")

      frames.each_with_index do |frame, index|
        frame_name = frame.name.to_s.strip
        frame_url = frame.url.to_s.strip
        log("Frame #{index}: name=#{frame_name.empty? ? '(blank)' : frame_name} url=#{frame_url}")

        TRANSPONDER_ROW_SELECTORS.each do |selector|
          rows = extract_rows_from_frame(frame, selector)
          next if rows.empty?

          filtered_rows = filter_transponder_candidate_rows(rows)
          score = transponder_row_score(rows, filtered_rows, selector)
          log("Frame #{index} selector #{selector.inspect}: total=#{rows.size} filtered=#{filtered_rows.size} score=#{score}")

          next unless better_transaction_row_score?(score, best_score)

          best_rows = filtered_rows.empty? ? rows : filtered_rows
          best_score = score
        end
      end

      dump_debug_artifacts(page, artifact_path) if best_rows.empty?
      best_rows
    end

    def filter_transaction_candidate_rows(rows)
      rows.select { |row| transaction_candidate_row?(row) }
    end

    def transaction_candidate_row?(row_text)
      normalized = row_text.to_s.gsub(/\s+/, ' ').strip
      return false if normalized.empty?
      return false unless normalized.match?(TransactionParser::DATE_REGEX)
      return false unless normalized.match?(TransactionParser::AMOUNT_REGEX)
      return false if normalized.match?(/\bview receipt\b/i) && !normalized.match?(/\b(?:am|pm)\b/i)

      true
    end

    def transaction_row_score(all_rows, filtered_rows, selector)
      matches = filtered_rows.size
      total = all_rows.size
      ratio = total.zero? ? 0 : (matches.to_f / total)
      specificity_bonus = selector.include?('#transactionItem') ? 10 : 0
      ratio_bonus = (ratio * 100).round

      [
        matches.positive? ? 1 : 0,
        specificity_bonus + ratio_bonus,
        matches,
        -total
      ]
    end

    def filter_transponder_candidate_rows(rows)
      rows.select { |row| transponder_candidate_row?(row) }
    end

    def transponder_candidate_row?(row_text)
      normalized = row_text.to_s.gsub(/\s+/, ' ').strip
      return false if normalized.empty?
      return false if normalized.match?(/\b(?:tag\s*#|serial\s*#|status|plate|vehicle)\b/i) &&
                      !normalized.match?(/\b(active|inactive|lost|stolen|damaged|closed|pending)\b/i)
      return false if normalized.casecmp('no records found').zero?

      normalized.match?(Sunpass::TransponderParser::ROW_HINT_REGEX)
    end

    def transponder_row_score(all_rows, filtered_rows, selector)
      matches = filtered_rows.size
      total = all_rows.size
      ratio = total.zero? ? 0 : (matches.to_f / total)
      specificity_bonus = selector.include?('#resultTransponderid') ? 10 : 0
      ratio_bonus = (ratio * 100).round

      [
        matches.positive? ? 1 : 0,
        specificity_bonus + ratio_bonus,
        matches,
        -total
      ]
    end

    def better_transaction_row_score?(score, best_score)
      best_score.nil? || (score <=> best_score) == 1
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
      locator.evaluate('el => el.blur()')
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

    def extract_transponder_records_from_frame(frame)
      values = frame.eval_on_selector_all(
        '#resultTransponderid > tbody > tr',
        <<~JS
          els => els.map(row => {
            const cells = Array.from(row.querySelectorAll('td')).map(cell =>
              (cell.innerText || cell.textContent || '').replace(/\\s+/g, ' ').trim()
            )

            if (cells.length < 5) return null

            return {
              serial_number: cells[0],
              transponder_type: cells[1],
              status: cells[2],
              plate_number: cells[3],
              friendly_name: cells[4]
            }
          }).filter(Boolean)
        JS
      )
      values.is_a?(Array) ? values : []
    rescue StandardError
      []
    end

    def dump_debug_artifacts(page, path)
      FileUtils.mkdir_p('tmp')
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
