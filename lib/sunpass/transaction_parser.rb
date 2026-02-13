# frozen_string_literal: true

require 'date'
require 'digest'

module Sunpass
  class TransactionParser
    # Expected row text example (varies by account/site):
    # "01/12/2026 Turnpike Mainline Plaza -$2.15 Posted"
    DATE_REGEX = /\b\d{1,2}\/\d{1,2}\/\d{2,4}\b/
    AMOUNT_REGEX = /-?\$\d+[\d,]*\.\d{2}/

    def parse_rows(raw_rows)
      raw_rows.map { |text| parse_row(text) }.compact
    end

    private

    def parse_row(text)
      normalized = text.gsub(/\s+/, ' ').strip
      return nil if normalized.empty?

      date = extract_date(normalized)
      amount = extract_amount(normalized)

      record = {
        external_id: build_external_id(normalized),
        occurred_on: date,
        amount: amount,
        description: normalized,
        raw_text: text
      }

      record
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

      match[0].delete('$,').to_f
    end

    def build_external_id(normalized)
      Digest::SHA256.hexdigest(normalized)
    end
  end
end
