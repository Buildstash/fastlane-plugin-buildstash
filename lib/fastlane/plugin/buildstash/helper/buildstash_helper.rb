require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?("UI")

  module Helper
    class BuildstashHelper
      # class methods that you define here become available in your action
      # as `Helper::BuildstashHelper.your_method`
      #
      def self.show_message
        UI.message("Hello from the buildstash plugin helper!")
      end

      def self.post_json(url:, body:, headers:)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        request = Net::HTTP::Post.new(uri.path, headers)
        request.body = body.to_json
        http.request(request)
      end

      def self.upload_file(url:, file_path:, headers:)
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == "https")
        request = Net::HTTP::Put.new(uri.request_uri, headers)
        request.body = File.binread(file_path)
        http.request(request)
      end

      def self.upload_chunked_file(file_path:, filesize:, pending_upload_id:, chunk_count:, chunk_size_mb:, api_key:, is_expansion: false)
        parts = []
        chunk_size = chunk_size_mb * 1024 * 1024
        endpoint = is_expansion ?
          "https://app.buildstash.com/api/v1/upload/request/multipart/expansion" :
          "https://app.buildstash.com/api/v1/upload/request/multipart"

        File.open(file_path, 'rb') do |file|
          chunk_count.times do |i|
            chunk_start = i * chunk_size
            chunk_end = [((i + 1) * chunk_size) - 1, filesize - 1].min
            content_length = chunk_end - chunk_start + 1
            part_number = i + 1

            puts "Uploading chunked upload, part: #{part_number} of #{chunk_count}"

            # Request for signed URL for the part
            uri = URI(endpoint)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true
            req = Net::HTTP::Post.new(uri.path, {
              "Authorization" => "Bearer #{api_key}",
              "Content-Type" => "application/json",
              "Accept" => "application/json"
            })
            req.body = {
              pending_upload_id: pending_upload_id,
              part_number: part_number,
              content_length: content_length
            }.to_json

            response = http.request(req)
            unless response.is_a?(Net::HTTPSuccess)
              raise "Failed to get presigned URL for part #{part_number}: #{response.code} #{response.body}"
            end

            data = JSON.parse(response.body)
            presigned_url = data["part_presigned_url"]

            # Read the chunk data from the file
            file.seek(chunk_start)
            chunk_data = file.read(content_length)

            # Upload the chunk to the presigned URL
            uri = URI(presigned_url)
            http = Net::HTTP.new(uri.host, uri.port)
            http.use_ssl = true

            upload = Net::HTTP::Put.new(uri.request_uri, {
              "Content-Type" => "application/octet-stream",
              "Content-Length" => content_length.to_s
            })
            upload.body = chunk_data

            upload_response = http.request(upload)

            unless upload_response.is_a?(Net::HTTPSuccess)
              raise "Upload failed for part #{part_number}: #{upload_response.code} #{upload_response.body}"
            end

            etag = upload_response["ETag"]
            if etag.nil?
              puts "⚠️ No ETag returned for part #{part_number}"
            end

            parts << {
              PartNumber: part_number,
              ETag: etag&.gsub('"', '')
            }
          end
        end

        parts
      end
    end
  end
end
