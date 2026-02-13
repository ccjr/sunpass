# frozen_string_literal: true

require 'sequel'

module Sunpass
  class Store
    def initialize(db_path: 'db/sunpass.sqlite3')
      @db = Sequel.sqlite(db_path)
      ensure_schema!
    end

    def upsert_transactions(transactions)
      table = @db[:transactions]
      inserted = 0

      transactions.each do |tx|
        next if table.where(external_id: tx[:external_id]).count.positive?

        table.insert(
          external_id: tx[:external_id],
          occurred_on: tx[:occurred_on],
          amount: tx[:amount],
          description: tx[:description],
          raw_text: tx[:raw_text],
          created_at: Time.now,
          updated_at: Time.now
        )
        inserted += 1
      end

      inserted
    end

    private

    def ensure_schema!
      return if @db.table_exists?(:transactions)

      @db.create_table :transactions do
        primary_key :id
        String :external_id, null: false, unique: true
        Date :occurred_on
        Float :amount
        String :description, text: true
        String :raw_text, text: true
        DateTime :created_at, null: false
        DateTime :updated_at, null: false
      end
    end
  end
end
