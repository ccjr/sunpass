# frozen_string_literal: true

require_relative 'test_helper'

class TransponderParserTest < Minitest::Test
  def setup
    @parser = Sunpass::TransponderParser.new
  end

  def test_parses_structured_records_into_domain_objects
    transponder = @parser.parse_records([
      {
        serial_number: '167709831010',
        transponder_type: 'SunPass Mini Transponder',
        status: 'ACTIVE',
        plate_number: '',
        friendly_name: ''
      }
    ]).first

    assert_instance_of Sunpass::Transponder, transponder
    assert_equal '167709831010', transponder.serial_number
    assert_equal 'SunPass Mini Transponder', transponder.transponder_type
    assert_equal 'Active', transponder.status
    assert_nil transponder.plate_number
    assert_nil transponder.friendly_name
  end

  def test_parses_structured_records_with_string_keys
    transponder = @parser.parse_records([
      {
        'serial_number' => '167709831010',
        'transponder_type' => 'SunPass Mini Transponder',
        'status' => 'ACTIVE',
        'plate_number' => '',
        'friendly_name' => ''
      }
    ]).first

    assert_instance_of Sunpass::Transponder, transponder
    assert_equal '167709831010', transponder.serial_number
    assert_equal 'SunPass Mini Transponder', transponder.transponder_type
    assert_equal 'Active', transponder.status
  end

  def test_ignores_header_like_structured_records
    transponders = @parser.parse_records([
      {
        serial_number: 'Transponder Number',
        transponder_type: 'Transponder Type',
        status: 'Transponder Status',
        plate_number: 'Associated Plate',
        friendly_name: 'Friendly Name'
      }
    ])

    assert_empty transponders
  end

  def test_parses_text_rows_as_fallback
    transponder = @parser.parse_rows([
      'Transponder 167709831010 Type SunPass Mini Transponder Status Active Plate ABC123 Friendly Name Commuter'
    ]).first

    assert_equal '167709831010', transponder.serial_number
    assert_equal 'ABC123', transponder.plate_number
    assert_equal 'Active', transponder.status
  end
end
