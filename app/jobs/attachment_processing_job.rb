class AttachmentProcessingJob < ApplicationJob
  queue_as :attachments

  def perform(attachment_id)
    attachment = Attachment.find_by(id: attachment_id)
    return if attachment.nil? # deleted before the job ran; nothing to do

    ScanVendorClient.new.request_scan(attachment)
  end
end
