# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"

require "json"
require "azure/storage/queue"
require "azure/storage/common"

# Reads messages from Azure Storage Queue
class LogStash::Inputs::Azurequeue < LogStash::Inputs::Base
  config_name "azurequeue"

  default :codec, "json"

  # Set the account name for the azure storage account.
  config :storage_account_name, :validate => :string, :required => false

  # Set the key to access the storage account.
  config :storage_access_key, :validate => :string, :required => false

  # Set the queuename and related parameters
  config :queue_name, :validate => :string, :required => true
  config :max_messages, :validate => :number, :default => 5
  config :visibility_timeout, :validate => :number, :default => 120

  # seconds interval for next run
  config :interval, :validate => :number, :default => 30

  public
  def register
    @logger.info("Registering azurequeue input", :accountname => @storage_account_name, :queue_name => @queue_name)
    if storage_access_key
	@azure_queue_service = Azure::Storage::Queue::QueueService.create(:storage_account_name => @storage_account_name, :storage_access_key => @storage_access_key)
    else
        @azure_queue_service = Azure::Storage::Queue::QueueService.create_from_env()
    end	
  end # def register

  def get_from_azurequeue(queue)
    result = @azure_queue_service.list_messages(@queue_name, @visibility_timeout, { number_of_messages: @max_messages, decode: true })
    if result
	result.each do |msg|
	    msg_id = msg.id
	    json = JSON.parse(msg.message_text)
	    @logger.info("Recevied message: id #{id} text: #{json}")
	    @azure_queue_service.delete_message(queue_name, msg.id, msg.pop_receipt)
        end
    end
  end

  def run(queue)
    while !stop?
	get_from_azurequeue(queue)
    end # loop
  end # def run

  def stop
  end # def stop
end # class LogStash::Inputs::Azurequeue
