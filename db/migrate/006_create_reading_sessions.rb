class CreateReadingSessions < ActiveRecord::Migration[7.0]
  def change
    create_table :reading_sessions do |t|
      t.references :book, null: false, foreign_key: true
      t.integer :minutes, null: false, default: 0
      t.date :date, null: false
      t.timestamps
    end
    add_index :reading_sessions, :date
  end
end


