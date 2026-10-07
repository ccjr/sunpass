# frozen_string_literal: true

require_relative 'test_helper'

class ClientTest < Minitest::Test
  class ParserDouble
    attr_reader :parse_records_calls, :parse_rows_calls

    def initialize(parse_records_result: nil, parse_rows_result: nil)
      @parse_records_result = parse_records_result
      @parse_rows_result = parse_rows_result
      @parse_records_calls = []
      @parse_rows_calls = []
    end

    def parse_records(records)
      @parse_records_calls << records
      @parse_records_result
    end

    def parse_rows(rows)
      @parse_rows_calls << rows
      @parse_rows_result
    end
  end

  def setup
    @client = Sunpass::Client.new(
      username: 'user',
      password: 'pass',
      logger: ->(*) {}
    )
  end

  def test_filters_transaction_candidates_to_summary_rows
    rows = [
      '04/18/2026 04/18/2026 05:45:45 AM PAYMENT & ADJUSTMENTS $5.34 $24.50 View Receipt',
      'TRANSPONDER PURCHASE - MINI ($4.99)',
      'SALES TAX ($0.30)'
    ]

    filtered = @client.send(:filter_transaction_candidate_rows, rows)

    assert_equal 1, filtered.length
    assert_match(/PAYMENT & ADJUSTMENTS/, filtered.first)
  end

  def test_extracts_structured_transponder_records_from_frame
    frame = Object.new
    def frame.eval_on_selector_all(selector, _script)
      raise 'unexpected selector' unless selector == '#resultTransponderid > tbody > tr'

      [
        {
          'serial_number' => '167709831010',
          'transponder_type' => 'SunPass Mini Transponder',
          'status' => 'ACTIVE',
          'plate_number' => '',
          'friendly_name' => ''
        }
      ]
    end

    records = @client.send(:extract_transponder_records_from_frame, frame)

    assert_equal 1, records.length
    assert_equal '167709831010', records.first['serial_number']
  end

  def test_fetch_transponders_prefers_structured_records
    parser = ParserDouble.new(parse_records_result: [:structured])

    client = Sunpass::Client.new(
      username: 'user',
      password: 'pass',
      transponder_parser: parser,
      logger: ->(*) {}
    )

    client.define_singleton_method(:fetch_transponder_records) { |transponders_url: nil| [{ serial_number: '167709831010' }] }
    client.define_singleton_method(:fetch_transponder_rows) { |transponders_url: nil| flunk('raw row fallback should not be used') }

    assert_equal [:structured], client.fetch_transponders
    assert_equal [[{ serial_number: '167709831010' }]], parser.parse_records_calls
    assert_empty parser.parse_rows_calls
  end

  def test_fetch_transponders_falls_back_to_raw_rows_when_structured_rows_are_empty
    parser = ParserDouble.new(parse_rows_result: [:fallback])

    client = Sunpass::Client.new(
      username: 'user',
      password: 'pass',
      transponder_parser: parser,
      logger: ->(*) {}
    )

    client.define_singleton_method(:fetch_transponder_records) { |transponders_url: nil| [] }
    client.define_singleton_method(:fetch_transponder_rows) { |transponders_url: nil| ['row text'] }

    assert_equal [:fallback], client.fetch_transponders
    assert_equal [['row text']], parser.parse_rows_calls
    assert_empty parser.parse_records_calls
  end

  def test_fetch_transponders_falls_back_to_raw_rows_when_structured_parse_is_empty
    parser = ParserDouble.new(parse_records_result: [], parse_rows_result: [:fallback])

    client = Sunpass::Client.new(
      username: 'user',
      password: 'pass',
      transponder_parser: parser,
      logger: ->(*) {}
    )

    records = [{ 'serial_number' => 'Transponder Number' }]
    client.define_singleton_method(:fetch_transponder_records) { |transponders_url: nil| records }
    client.define_singleton_method(:fetch_transponder_rows) { |transponders_url: nil| ['Transponder 167709831010 Status Active'] }

    assert_equal [:fallback], client.fetch_transponders
    assert_equal [records], parser.parse_records_calls
    assert_equal [['Transponder 167709831010 Status Active']], parser.parse_rows_calls
  end

  def test_login_forces_the_known_submit_button_when_it_is_not_clickable
    forced_clicks = 0
    button = Object.new
    button.define_singleton_method(:click) do |force:, timeout:|
      forced_clicks += 1 if force && timeout == 2_000
    end
    locator = Object.new
    locator.define_singleton_method(:first) { button }
    page = Object.new
    page.define_singleton_method(:goto) { |_url| }
    page.define_singleton_method(:wait_for_timeout) { |_milliseconds| }
    page.define_singleton_method(:wait_for_load_state) { |state:| raise unless state == 'networkidle' }
    page.define_singleton_method(:locator) do |selector|
      raise "unexpected selector: #{selector}" unless selector == 'button[name="btnLogin"]'

      locator
    end

    @client.define_singleton_method(:fill_first_match) { |_page, _selectors, _value| }
    @client.define_singleton_method(:click_first_match) do |_page, selectors|
      raise "Could not find clickable element for any selector: #{selectors.inspect}"
    end

    @client.send(:login, page)

    assert_equal 1, forced_clicks
  end
end
