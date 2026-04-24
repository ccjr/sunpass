# frozen_string_literal: true

require 'date'

module Sunpass
  class TransactionParser
    # Expected row text example (varies by account/site):
    # "01/12/2026 Turnpike Mainline Plaza -$2.15 Posted"
    DATE_REGEX = /\b\d{1,2}\/\d{1,2}\/\d{2,4}\b/
    AMOUNT_REGEX = /(?:-\$\d+[\d,]*\.\d{2}|\$\d+[\d,]*\.\d{2}|\(\$\d+[\d,]*\.\d{2}\))/

    def parse_rows(raw_rows)
      raw_rows.map { |text| parse_row(text) }.compact
    end

    private

    def parse_row(text)
      normalized = text.gsub(/\s+/, ' ').strip
      return nil if normalized.empty?

      date = extract_date(normalized)
      amount = extract_amount(normalized)
      return nil unless transaction_row?(normalized, date, amount)

      Sunpass::Transaction.build(
        occurred_on: date,
        amount: amount,
        description: normalized,
        raw_text: text
      )
    rescue StandardError
      nil
    end

    def extract_date(text)
      match = text.match(DATE_REGEX)
      return nil unless match

      Date.strptime(match[0], '%m/%d/%Y')
    rescue ArgumentError
      Date.strptime(match[0], '%m/%d/%y')
    end

    def extract_amount(text)
      match = text.match(AMOUNT_REGEX)
      return nil unless match

      raw_amount = match[0]
      negative = raw_amount.start_with?('(') || raw_amount.start_with?('-')
      amount = raw_amount.delete('$,()-').to_f

      negative ? -amount : amount
    end

    def transaction_row?(text, date, amount)
      return false if date.nil? || amount.nil?
      return false if detail_only_row?(text)

      true
    end

    def detail_only_row?(text)
      text.match?(/\b(?:transponder purchase|sales tax|replenishment)\b/i) &&
        !text.match?(/\b\d{1,2}:\d{2}:\d{2}\s*(?:AM|PM)\b/i)
    end
  end
end
