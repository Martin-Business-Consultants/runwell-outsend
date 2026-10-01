# Who mail sent through Outsend comes from, when that isn't the install's sender: Outsend sends
# only for domains verified in the Outsend account, which the install's sender may not be on.
class AddSendAsToOutsendConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :outsend_connections, :send_as_email, :string
    add_column :outsend_connections, :send_as_name, :string
  end
end
