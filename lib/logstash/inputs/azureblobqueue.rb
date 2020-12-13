# encoding: utf-8
require "logstash/inputs/base"
require "logstash/namespace"
require "stud/interval"

require "json"
require "azure/storage/common"
require "azure/storage/queue"
require "azure/storage/blob"

# Reads messages from Azure Storage Queue
class LogStash::Inputs::Azureblobqueue < LogStash::Inputs::Base
  config_name "azureblobqueue"

  default :codec, "plain"

  # Set the account name for the azure storage account.
  config :storage_account_name, :validate => :string, :required => false
  # Set the key to access the storage account.
  config :storage_access_key, :validate => :string, :required => false

  # Set the blob event queue name and related parameters
  config :blob_event_queue, :validate => :string, :required => true
  config :max_messages, :validate => :number, :default => 5
  config :visibility_timeout, :validate => :number, :default => 120

  # seconds interval for next run
  config :interval, :validate => :number, :default => 30

  public
  def register
      @logger.info("Registering azureblobqueue input", :accountname => @storage_account_name, :blob_event_queue => @blob_event_queue)
      if storage_access_key
	  common_client = Azure::Storage::Common::Client.create(
						:storage_account_name => @storage_account_name,
						:storage_access_key => @storage_access_key
						)
      else
	  #in case we support get the storage account and access key from env setting
	  common_client = Azure::Storage::Common::Client.create_from_env()
      end
      @azure_queue_service = Azure::Storage::Queue::QueueService.new(client: common_client)
      @azure_blob_service = Azure::Storage::Blob::BlobService.new(client: common_client)
  end # def register

  private
  def read_storage_object(container_name, blob_name)
	raise ArgumentError, 'container name cannot be empty' if !container_name or container_name.empty?
	raise ArgumentError, 'blob name cannot be empty' if !blob_name or blob_name.empty?

	blob, content = @azure_blob_service.get_blob(container_name, blob_name)
	if content
	    @logger.debug("Azure reads blob succeed, container_name: #{container_name}, blob: #{blob_name}.")
	    return content
	else
	    @logger.error("Azure reads blob fail, container_name: #{container_name}, blob: #{blob_name}!!!")
	end #content
  end # def read_storage_object

  private
  def emit(queue, line)
    @codec.decode(line) do |event|
        decorate(event)
        queue << event
    end
  end

  # A message text for blob creat event
  # {
  #  "topic": "/subscriptions/4d8f6383-1247-4235-bf46-b64cc2a16b03/resourceGroups/azure-elk-group/providers/Microsoft.Storage/storageAccounts/filebeatlogstashstorage",
  #  "subject": "/blobServices/default/containers/syslog-test-dbass-sap/blobs/RMA.log",
  #  "eventType": "Microsoft.Storage.BlobCreated",
  #  "eventTime": "2018-09-13T09:54:31.8871973Z",
  #  "id": "f82d3188-201e-0058-3047-4b58440683aa",
  #  "data": {
  #    "api": "PutBlob",
  #    "requestId": "f82d3188-201e-0058-3047-4b5844000000",
  #    "eTag": "0x8D6195EE75EC5A5",
  #    "contentType": "application/octet-stream",
  #    "contentLength": 4528,
  #    "blobType": "BlockBlob",
  #    "url": "https://filebeatlogstashstorage2.blob.core.windows.net/syslog-test-dbass-sap/RMA.log",
  #    "sequencer": "000000000000000000000000000000550000000000022cab",
  #    "storageDiagnostics": {
  #      "batchId": "ac807557-23d8-44fc-bae9-5f9b42f4615e"
  #    }
  #  },
  #  "dataVersion": "",
  #  "metadataVersion": "1"
  #}
  def process_msg(queue, msg)
    message_data = JSON.parse(msg.message_text)
    eventType = message_data["eventType"]
    @logger.debug("Azure blob event queue message recevied: id: #{msg.id}, text: #{message_data}.")

    if eventType == "Microsoft.Storage.BlobCreated"
	subject = message_data["subject"]

	# get the container name and blob name from the subject
	subject_prefix = "/blobServices/default/containers/"
	if subject.include?(subject_prefix)
	    subjects = subject.split("/")

	    container_name = subjects[4]
	    subject_prefix = subject_prefix + container_name + '/blobs/'
	    blob_name = subject[subject_prefix.length..subject.length]

	    data = read_storage_object(container_name, blob_name)
	    return nil unless data
	    #process the blob file's content
	    data.each_line { |line| emit(queue, line) }
	else
	    @logger.error("Azure blob event is invalid, subject: #{subject}!!!")
	end #subject.include
    else
	@logger.debug("Azure blob event queue message is not created event: id: #{msg.id}.")
    end #eventType
  end #process_msg

  public
  def run(queue)
    @current_thread = Thread.current
    Stud.interval(@interval) do
	messages = @azure_queue_service.list_messages(
					@blob_event_queue, 
					@visibility_timeout, 
					{ number_of_messages: @max_messages, decode: true }
					)

	if messages
	    messages.each do |msg|
		process_msg(queue, msg)
		#delete the message from queue in case the msg being handled
		@azure_queue_service.delete_message(
					@blob_event_queue,
					msg.id,
					msg.pop_receipt
					)
	   end # messages.each
	end
    end # Stud
  end # def run

  public
  def stop
    # @current_thread is initialized in the `#run` method,
    # this variable is needed because the `#stop` is a called in another thread
    # than the `#run` method and requiring us to call stop! with a explicit thread.
    Stud.stop!(@current_thread
  end # def stop
end # class LogStash::Inputs::Azureblobqueue
