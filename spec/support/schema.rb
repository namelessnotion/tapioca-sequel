# frozen_string_literal: true

# An in-memory database for the fixture models. Sequel reads each model's
# schema from it when the model is defined, exactly as it would from Postgres.
DB = Sequel.sqlite

# One column of every type the compiler maps, nullable and not.
DB.create_table(:entities) do
  primary_key :id
  String :name, null: false
  String :nickname
  column :holder_uuid, :uuid, null: false
  TrueClass :active
  BigDecimal :balance
  Float :score
  Date :born_on
  DateTime :created_at, null: false
  File :avatar
  column :metadata, :json
end

DB.create_table(:profiles) do
  primary_key :id
  foreign_key :entity_id, :entities
  String :bio
end

DB.create_table(:accounts) do
  primary_key :id
  foreign_key :entity_id, :entities
  String :currency, null: false
end

DB.create_table(:tags) do
  primary_key :id
  String :label, null: false
end

DB.create_table(:accounts_tags) do
  foreign_key :account_id, :accounts
  foreign_key :tag_id, :tags
end
