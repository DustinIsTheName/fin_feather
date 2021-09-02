class CreateAppData < ActiveRecord::Migration[6.0]
  def change
    create_table :app_data do |t|
      t.integer :progress, required: true, default: 0

      t.timestamps
    end
  end
end
