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
end
