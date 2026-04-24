# frozen_string_literal: true

require_relative 'test_helper'

class TransactionParserTest < Minitest::Test
  def setup
    @parser = Sunpass::TransactionParser.new
  end

  def test_parses_transaction_rows_into_domain_objects
    transaction = @parser.parse_rows([
      '04/18/2026 04/18/2026 05:45:45 AM PAYMENT & ADJUSTMENTS $5.34 $24.50 View Receipt'
    ]).first

    assert_instance_of Sunpass::Transaction, transaction
    assert_equal Date.new(2026, 4, 18), transaction.occurred_on
    assert_equal 5.34, transaction.amount
  end

  def test_parses_parenthesized_amounts_as_negative
    transaction = @parser.parse_rows([
      '04/18/2026 Toll Adjustment ($4.99)'
    ]).first

    assert_equal(-4.99, transaction.amount)
  end

  def test_rejects_detail_only_rows
    transactions = @parser.parse_rows([
      'TRANSPONDER PURCHASE - MINI ($4.99)',
      'SALES TAX ($0.30)',
      'MASTERCARD (MC) REPLENISHMENT $4.99'
    ])

    assert_empty transactions
  end

  def test_rejects_rows_without_date_or_amount
    transactions = @parser.parse_rows([
      'No transactions found',
      '04/18/2026 Missing amount'
    ])

    assert_empty transactions
  end
end
