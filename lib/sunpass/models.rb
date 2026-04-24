# frozen_string_literal: true

require 'digest'

module Sunpass
  Transaction = Data.define(
    :external_id,
    :occurred_on,
    :amount,
    :description,
    :raw_text
  ) do
    def self.build(occurred_on:, amount:, description:, raw_text:)
      new(
        external_id: Digest::SHA256.hexdigest(description),
        occurred_on: occurred_on,
        amount: amount,
        description: description,
        raw_text: raw_text
      )
    end
  end

  Transponder = Data.define(
    :external_id,
    :serial_number,
    :transponder_type,
    :plate_number,
    :friendly_name,
    :status,
    :raw_text
  ) do
    def self.build(serial_number:, transponder_type:, plate_number:, friendly_name:, status:, raw_text:)
      normalized = [serial_number, transponder_type, plate_number, friendly_name, status, raw_text].compact.join('|')

      new(
        external_id: Digest::SHA256.hexdigest(normalized),
        serial_number: serial_number,
        transponder_type: transponder_type,
        plate_number: plate_number,
        friendly_name: friendly_name,
        status: status,
        raw_text: raw_text
      )
    end
  end
end
