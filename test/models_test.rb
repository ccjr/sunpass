# frozen_string_literal: true

require_relative 'test_helper'

class ModelsTest < Minitest::Test
  def test_transaction_build_generates_external_id
    transaction = Sunpass::Transaction.build(
      occurred_on: Date.new(2026, 4, 18),
      amount: 5.34,
      description: 'desc',
      raw_text: 'desc'
    )

    assert transaction.external_id
    refute_empty transaction.external_id
  end

  def test_transponder_build_uses_new_fields
    transponder = Sunpass::Transponder.build(
      serial_number: '167709831010',
      transponder_type: 'SunPass Mini Transponder',
      plate_number: nil,
      friendly_name: nil,
      status: 'Active',
      raw_text: 'raw'
    )

    assert_equal '167709831010', transponder.serial_number
    assert_equal 'SunPass Mini Transponder', transponder.transponder_type
    assert_equal 'Active', transponder.status
  end
end
