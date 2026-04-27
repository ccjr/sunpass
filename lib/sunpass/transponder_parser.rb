# frozen_string_literal: true

module Sunpass
  class TransponderParser
    ROW_HINT_REGEX = /\b(active|inactive|lost|stolen|damaged|closed|pending|plate|vehicle|transponder|tag)\b/i
    STATUS_REGEX = /\b(active|inactive|lost|stolen|damaged|closed|pending)\b/i
    SERIAL_LABEL_REGEX = /(?:transponder|serial)(?:\s+number)?\s*[:#]?\s*([A-Z0-9-]{6,})/i
    TAG_LABEL_REGEX = /tag\s*#?\s*[:#]?\s*([A-Z0-9-]{6,})/i
    PLATE_REGEX = /(?:plate|license(?:\s+plate)?)\s*[:#]?\s*([A-Z0-9-]{2,})/i
    FRIENDLY_NAME_REGEX = /(?:friendly\s+name|name)\s*[:#]?\s*(.+?)(?=\s+(?:plate|license|status|transponder|serial|type)\b|$)/i
    TYPE_REGEX = /(?:type|transponder\s+type)\s*[:#]?\s*(.+?)(?=\s+(?:plate|license|status|friendly\s+name|name|transponder|serial)\b|$)/i
    SERIAL_TOKEN_REGEX = /\b[A-Z0-9]{6,}\b/

    def parse_rows(raw_rows)
      raw_rows.map { |text| parse_row(text) }.compact
    end

    def parse_records(raw_records)
      raw_records.map { |record| parse_record(record) }.compact
    end

    private

    def parse_row(text)
      normalized = text.gsub(/\s+/, ' ').strip
      return nil if normalized.empty?

      serial_number = extract_serial_number(normalized)
      transponder_type = extract_transponder_type(normalized)
      plate_number = extract_plate_number(normalized)
      friendly_name = extract_friendly_name(normalized)
      status = extract_status(normalized)
      return nil unless transponder_row?(normalized, serial_number, transponder_type, plate_number, friendly_name, status)

      Sunpass::Transponder.build(
        serial_number: serial_number,
        transponder_type: transponder_type,
        plate_number: plate_number,
        friendly_name: friendly_name,
        status: status,
        raw_text: text
      )
    rescue StandardError
      nil
    end

    def parse_record(record)
      serial_number = clean_value(record_value(record, :serial_number))
      transponder_type = clean_value(record_value(record, :transponder_type))
      plate_number = clean_value(record_value(record, :plate_number))
      friendly_name = clean_value(record_value(record, :friendly_name))
      status = clean_value(record_value(record, :status))&.capitalize
      raw_text = [
        serial_number,
        transponder_type,
        status,
        plate_number,
        friendly_name
      ].compact.join(' | ')
      return nil unless transponder_row?(raw_text, serial_number, transponder_type, plate_number, friendly_name, status)

      Sunpass::Transponder.build(
        serial_number: serial_number,
        transponder_type: transponder_type,
        plate_number: plate_number,
        friendly_name: friendly_name,
        status: status,
        raw_text: raw_text
      )
    rescue StandardError
      nil
    end

    def extract_serial_number(text)
      labeled = text.match(SERIAL_LABEL_REGEX)
      return labeled[1] if labeled

      tagged = text.match(TAG_LABEL_REGEX)
      return tagged[1] if tagged

      tokens = text.scan(SERIAL_TOKEN_REGEX)
      tokens.max_by(&:length)
    end

    def extract_plate_number(text)
      match = text.match(PLATE_REGEX)
      match && match[1]
    end

    def extract_friendly_name(text)
      match = text.match(FRIENDLY_NAME_REGEX)
      return match[1].strip if match

      nil
    end

    def extract_transponder_type(text)
      match = text.match(TYPE_REGEX)
      return match[1].strip if match

      nil
    end

    def extract_status(text)
      match = text.match(STATUS_REGEX)
      match && match[1].capitalize
    end

    def transponder_row?(text, serial_number, transponder_type, plate_number, friendly_name, status)
      return false unless text.match?(ROW_HINT_REGEX)
      return false if header_row?(text)
      return false if header_value?(serial_number)
      return false if header_value?(transponder_type)
      return false if header_value?(plate_number)
      return false if header_value?(friendly_name)
      return false if [serial_number, transponder_type, plate_number, friendly_name, status].all?(&:nil?)

      true
    end

    def header_row?(text)
      text.match?(/\b(?:tag\s*#|transponder|serial|vehicle|plate|status)\b/i) &&
        !text.match?(STATUS_REGEX) &&
        text.split.size <= 8
    end

    def clean_value(value)
      normalized = value.to_s.gsub(/\s+/, ' ').strip
      normalized.empty? ? nil : normalized
    end

    def record_value(record, key)
      record[key] || record[key.to_s]
    end

    def header_value?(value)
      value.to_s.match?(/\A(?:transponder number|transponder type|transponder status|associated plate|friendly name)\z/i)
    end
  end
end
