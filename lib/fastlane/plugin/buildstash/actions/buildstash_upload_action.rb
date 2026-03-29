require 'fastlane/action'
require_relative '../helper/buildstash_helper'
require 'net/http'
require 'json'

module Fastlane
  module Actions
    class BuildstashUploadAction < Action
      def self.run(params)
        api_key = params[:api_key]
        structure = params[:structure]
        primary_file_path = params[:primary_file_path]
        version_component_1_major = params[:version_component_1_major]
        version_component_2_minor = params[:version_component_2_minor]
        version_component_3_patch = params[:version_component_3_patch]
        version_component_extra = params[:version_component_extra]
        version_component_meta = params[:version_component_meta]
        custom_build_number = params[:custom_build_number]
        platform = params[:platform]
        custom_target = params[:custom_target]
        stream = params[:stream]
        notes = params[:notes]

        labels = params[:labels]
        architectures = params[:architectures]

        source = params[:source]

        ci_pipeline = params[:ci_pipeline]
        ci_run_id = params[:ci_run_id]
        ci_run_url = params[:ci_run_url]
        ci_build_duration = params[:ci_build_duration]

        vc_host_type = params[:vc_host_type]
        vc_host = params[:vc_host]
        vc_repo_name = params[:vc_repo_name]
        vc_repo_url = params[:vc_repo_url]
        vc_branch = params[:vc_branch]
        vc_commit_sha = params[:vc_commit_sha]
        vc_commit_url = params[:vc_commit_url]

        metadata_artifacts = params[:metadata_artifacts] || []
        ssl_verify = params[:ssl_verify]

        if !structure
          structure = "file"
        end

        if !source
          source = "cli-upload"
        end

        UI.user_error!("File path must be provided.") if primary_file_path.to_s.strip.empty?
        UI.user_error!("File not found at path: #{primary_file_path}") unless File.exist?(primary_file_path)


        UI.message("Send upload request...")

        file_size = File.size(primary_file_path)
        file_name = File.basename(primary_file_path)

        request_body = {
          structure: structure,
          primary_file: {
            filename: file_name,
            size_bytes: file_size
          },
          version_component_1_major: version_component_1_major,
          version_component_2_minor: version_component_2_minor,
          version_component_3_patch: version_component_3_patch,
          version_component_extra: version_component_extra,
          version_component_meta: version_component_meta,
          custom_build_number: custom_build_number,
          platform: platform,
          custom_target: custom_target,
          stream: stream,
          notes: notes,
          source: source,
          ci_pipeline: ci_pipeline,
          ci_run_id: ci_run_id,
          ci_run_url: ci_run_url,
          ci_build_duration: ci_build_duration,
          vc_host_type: vc_host_type,
          vc_host: vc_host,
          vc_repo_name: vc_repo_name,
          vc_repo_url: vc_repo_url,
          vc_branch: vc_branch,
          vc_commit_sha: vc_commit_sha,
          vc_commit_url: vc_commit_url
        }

        request_body[:labels] = labels if labels && !labels.empty?
        request_body[:architectures] = architectures if architectures && !architectures.empty?

        expansion_file_path = params[:expansion_file_path]
        # Add expansion file info if structure is file+expansion and expansion file path provided
        if structure == 'file+expansion' && expansion_file_path
            
          # Verify expansion file exists
          unless File.exist?(expansion_file_path)
            UI.user_error!("Expansion file not found at path: #{expansion_file_path}")
          end

          # Get expansion file stats
          expansion_filename = File.basename(expansion_file_path)
          expansion_file_size = File.size(expansion_file_path)

          request_body[:expansion_files] = [{
            filename: expansion_filename,
            size_bytes: expansion_file_size
          }]
        end

        response = Helper::BuildstashHelper.post_json(
          url: "https://app.buildstash.com/api/v1/upload/request",
          body: request_body,
          headers: {
            "Authorization" => "Bearer #{api_key}",
            "Content-Type" => "application/json",
            "Accept" => "application/json"
          },
          ssl_verify: ssl_verify
        )

        unless response.is_a?(Net::HTTPSuccess)
          UI.error("Buildstash API returned #{response.code}: #{response.body}")
          UI.user_error!("Buildstash API request failed")
        end

        if response.content_type && response.content_type != "application/json"
          UI.user_error!("Upload request failed due to unexpected response type: #{response.content_type} - Response: #{response.code}: #{response.body}")
        end

        response_data = JSON.parse(response.body)
        
        UI.verbose("Response data: #{response_data.inspect}")
        
        # Verify if the response contains an error
        if response_data["errors"]
          UI.user_error!("Buildstash API Error: #{response_data["message"]} - Response: #{response.code}: #{response.body}")
        end

        pending_upload_id = response_data["pending_upload_id"]
        primary_file = response_data["primary_file"]
        expansion_files = response_data["expansion_files"]

        # Handle primary file upload
        if primary_file["chunked_upload"]
          UI.message('Uploading primary file using chunked upload...');
          primary_file_parts = Helper::BuildstashHelper.upload_chunked_file(
            file_path: primary_file_path,
            filesize: file_size,
            pending_upload_id: pending_upload_id,
            chunk_count: primary_file["chunked_number_parts"],
            chunk_size_mb: primary_file["chunked_part_size_mb"],
            api_key: api_key,
            is_expansion: false,
            ssl_verify: ssl_verify
          )

          UI.verbose("primary_file_parts=#{primary_file_parts}");
        else
          UI.message("Uploading primary file using direct upload...")

          response = Helper::BuildstashHelper.upload_file(
            url: primary_file["presigned_data"]["url"],
            file_path: primary_file_path,
            headers: {
              "Content-Disposition" => primary_file["presigned_data"]["headers"]["Content-Disposition"],
              "x-amz-acl": "private",
              "Content-Type" => primary_file["presigned_data"]["headers"]["Content-Type"],
              "Content-Length" => file_size.to_s
            },
            ssl_verify: ssl_verify
          )

          unless response.is_a?(Net::HTTPSuccess)
            UI.user_error!("Upload failed #{response.code}: #{response.body}")
          end

          UI.message("Upload done! Response code: #{response.code}")
          UI.message("Response body: #{response.body}")
        end

        if pending_upload_id.nil? || pending_upload_id.empty?
          UI.user_error!("Invalid pending_upload_id received from Buildstash.")
        end

        if expansion_file_path && response_data["expansion_files"] && response_data["expansion_files"][0]
          expansion_info = response_data["expansion_files"][0]
          expansion_file_size = File.size(expansion_file_path)

          if expansion_info["chunked_upload"]
            UI.message("Uploading expansion file using chunked upload...")

            expansion_parts = Helper::BuildstashHelper.upload_chunked_file(
              file_path: expansion_file_path,
              filesize: expansion_file_size,
              pending_upload_id: response_data["pending_upload_id"],
              chunk_count: expansion_info["chunked_number_parts"],
              chunk_size_mb: expansion_info["chunked_part_size_mb"],
              api_key: params[:api_key],
              is_expansion: true,
              ssl_verify: ssl_verify
            )

            # Store this info for later if needed
            # e.g. for upload/complete or logs
            UI.success("Expansion file uploaded in #{expansion_parts.size} parts.")
            UI.message("Expansion parts: #{expansion_parts.map { |p| p[:PartNumber] }.join(', ')}")
          else
            UI.message("Uploading expansion file using direct upload...")

            response = Helper::BuildstashHelper.upload_file(
              url: expansion_info["presigned_data"]["url"],
              file_path: expansion_file_path,
              headers: {
                "Content-Type" => expansion_info["presigned_data"]["headers"]["Content-Type"],
                "Content-Length" => expansion_info["presigned_data"]["headers"]["Content-Length"].to_s,
                "Content-Disposition" => expansion_info["presigned_data"]["headers"]["Content-Disposition"],
                "x-amz-acl" => "private"
              },
              ssl_verify: ssl_verify
            )

            unless response.is_a?(Net::HTTPSuccess)
              UI.user_error!("Expansion file upload failed: #{response.code} #{response.body}")
            end

            UI.success("Expansion file uploaded successfully.")
          end
        end

        UI.message("Verifying upload...")

        verify_body = {
          pending_upload_id: pending_upload_id
        }

        if defined?(primary_file_parts) && primary_file_parts && !primary_file_parts.empty?
          verify_body[:multipart_chunks] = primary_file_parts
        end

        # add expansion parts to the verify payload if they exist
        if defined?(expansion_parts) && expansion_parts && !expansion_parts.empty?
          verify_body[:multipart_chunks] ||= []
          verify_body[:multipart_chunks].concat(expansion_parts)
        end

        response = Helper::BuildstashHelper.post_json(
          url: "https://app.buildstash.com/api/v1/upload/verify",
          body: verify_body,
          headers: { 
            "Authorization" => "Bearer #{api_key}",
            "Content-Type" => "application/json",
            "Accept" => "application/json"
          },
          ssl_verify: ssl_verify
        )

        unless response.is_a?(Net::HTTPSuccess)
          UI.error("Buildstash API returned #{response.code}: #{response.body}")
          UI.user_error!("Buildstash API request failed")
        end

        if response.content_type && response.content_type != "application/json"
          UI.user_error!("Verification failed due to unexpected response type: #{response.content_type} - Response: #{response.code}: #{response.body}")
        end

        response_data = JSON.parse(response.body)

        # Set outputs
        Actions.lane_context[:BUILDSTASH_BUILD_ID] = response_data["build_id"]
        Actions.lane_context[:BUILDSTASH_INFO_URL] = response_data["build_info_url"]
        Actions.lane_context[:BUILDSTASH_DOWNLOAD_URL] = response_data["download_url"]

        if response_data["build_info_url"] && response_data&.dig("pending_processing") == true
          UI.success("✅ Upload complete! Build now being processed. Once ready, view it at: #{response_data["build_info_url"]}")
        elsif response_data["build_info_url"]
          UI.success("✅ Upload complete! View it at: #{response_data["build_info_url"]}")
        else
          UI.success("✅ Upload to Buildstash successful!")
        end

        # Upload metadata artifacts if provided
        unless metadata_artifacts.empty?
          upload_metadata_artifacts(
            metadata_artifacts: metadata_artifacts,
            pending_upload_id: pending_upload_id,
            api_key: api_key,
            ssl_verify: ssl_verify
          )
        end
      end

      def self.upload_metadata_artifacts(metadata_artifacts:, pending_upload_id:, api_key:, ssl_verify: true)
        max_files = 10
        max_size_bytes = 5 * 1024 * 1024

        artifacts_to_upload = metadata_artifacts.first(max_files)
        skipped_count = metadata_artifacts.length - artifacts_to_upload.length

        if skipped_count > 0
          UI.important("⚠️ Skipping #{skipped_count} metadata artifact(s) — maximum of #{max_files} files allowed per upload.")
        end

        UI.message("Uploading #{artifacts_to_upload.length} metadata artifact(s)...")

        artifacts_to_upload.each_with_index do |artifact, index|
          file_path = artifact[:path] || artifact["path"]
          description = artifact[:description] || artifact["description"]

          unless file_path
            UI.important("⚠️ Metadata artifact at index #{index} has no path — skipping.")
            next
          end

          unless File.exist?(file_path)
            UI.important("⚠️ Metadata artifact not found at path: #{file_path} — skipping.")
            next
          end

          file_size = File.size(file_path)
          if file_size > max_size_bytes
            size_mb = (file_size.to_f / (1024 * 1024)).round(2)
            UI.important("⚠️ Metadata artifact '#{File.basename(file_path)}' is #{size_mb}MB — exceeds the 5MB limit, skipping.")
            next
          end

          filename = File.basename(file_path)
          desc_text = description ? " (#{description})" : ""
          UI.message("Uploading metadata artifact #{index + 1}/#{artifacts_to_upload.length}: #{filename}#{desc_text}")

          # Request presigned upload URL for this metadata artifact
          meta_request_response = Helper::BuildstashHelper.post_json(
            url: "https://app.buildstash.com/api/v1/upload/metadata/request",
            body: {
              primary_pending_upload_id: pending_upload_id,
              filename: filename,
              size_bytes: file_size
            },
            headers: {
              "Authorization" => "Bearer #{api_key}",
              "Content-Type" => "application/json",
              "Accept" => "application/json"
            },
            ssl_verify: ssl_verify
          )

          unless meta_request_response.is_a?(Net::HTTPSuccess)
            UI.error("Failed to request metadata upload for '#{filename}': #{meta_request_response.code} #{meta_request_response.body} — skipping.")
            next
          end

          meta_request_data = JSON.parse(meta_request_response.body)
          metadata_pending_upload_id = meta_request_data["metadata_pending_upload_id"]
          presigned_data = meta_request_data["presigned_upload_data"]

          unless presigned_data && presigned_data["url"]
            UI.error("No presigned upload URL returned for metadata artifact '#{filename}' — skipping.")
            next
          end

          upload_headers = presigned_data["headers"] || {}

          # Upload the metadata file to the presigned URL
          upload_response = Helper::BuildstashHelper.upload_file(
            url: presigned_data["url"],
            file_path: file_path,
            headers: {
              "Content-Type" => upload_headers["Content-Type"] || "application/octet-stream",
              "Content-Length" => (upload_headers["Content-Length"] || file_size).to_s,
              "Content-Disposition" => upload_headers["Content-Disposition"] || "attachment; filename=\"#{filename}\"",
              "x-amz-acl" => "private"
            },
            ssl_verify: ssl_verify
          )

          unless upload_response.is_a?(Net::HTTPSuccess)
            UI.error("Metadata artifact upload failed for '#{filename}': #{upload_response.code} #{upload_response.body} — skipping.")
            next
          end

          # Verify the metadata artifact upload
          verify_body = { pending_upload_id: metadata_pending_upload_id }
          verify_body[:file_description] = description if description

          meta_verify_response = Helper::BuildstashHelper.post_json(
            url: "https://app.buildstash.com/api/v1/upload/metadata/verify",
            body: verify_body,
            headers: {
              "Authorization" => "Bearer #{api_key}",
              "Content-Type" => "application/json",
              "Accept" => "application/json"
            },
            ssl_verify: ssl_verify
          )

          unless meta_verify_response.is_a?(Net::HTTPSuccess)
            UI.error("Metadata artifact verification failed for '#{filename}': #{meta_verify_response.code} #{meta_verify_response.body} — skipping.")
            next
          end

          meta_verify_data = JSON.parse(meta_verify_response.body)
          artifact_id = meta_verify_data["metadata_artifact_id"]
          UI.success("Metadata artifact '#{filename}' uploaded successfully (ID: #{artifact_id}).")
        end

        UI.success("✅ All metadata artifacts processed.")
      end

      def self.description
        "Upload build artifacts to Buildstash"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :api_key,
            description: "Buildstash API key",
            optional: false,
            type: String
          ),

          FastlaneCore::ConfigItem.new(
            key: :structure,
            description: "Upload structure: 'file' or 'file+expansion'",
            optional: true,
            type: String,
            default_value: "file"
          ),

          FastlaneCore::ConfigItem.new(
            key: :primary_file_path,
            description: "Path to the primary file to upload",
            optional: false,
            type: String,
            verify_block: proc do |value|
              UI.user_error!("File not found: #{value}") unless File.exist?(value)
            end
          ),

          FastlaneCore::ConfigItem.new(
            key: :platform,
            description: "Platform of the build",
            optional: false,
            type: String
          ),

          FastlaneCore::ConfigItem.new(
            key: :custom_target,
            description: "Custom target for this build (must exactly match a target defined in your Buildstash app)",
            optional: true,
            type: String
          ),

          FastlaneCore::ConfigItem.new(
            key: :stream,
            description: "Buildstash stream",
            optional: false,
            type: String
          ),

          FastlaneCore::ConfigItem.new(
            key: :version_component_1_major,
            description: "Semantic version (major component)",
            optional: false,
            type: Integer
          ),

          FastlaneCore::ConfigItem.new(
            key: :version_component_2_minor,
            description: "Semantic version (minor component)",
            optional: false,
            type: Integer
          ),

          FastlaneCore::ConfigItem.new(
            key: :version_component_3_patch,
            description: "Semantic version (patch component)",
            optional: false,
            type: Integer
          ),

          FastlaneCore::ConfigItem.new(
            key: :version_component_extra,
            description: "Additional version identifier (e.g., `rc`)",
            optional: true,
            type: String
          ),

          FastlaneCore::ConfigItem.new(
            key: :version_component_meta,
            description: "Metadata related to the version",
            optional: true,
            type: String
          ),

          FastlaneCore::ConfigItem.new(
            key: :custom_build_number,
            description: "Custom build number",
            optional: true,
            type: String
          ),

          FastlaneCore::ConfigItem.new(
            key: :labels,
            description: "Labels to attach to build",
            optional: true,
            type: Array
          ),

          FastlaneCore::ConfigItem.new(
            key: :architectures,
            description: "Architectures this build supports",
            optional: true,
            type: Array
          ),

          FastlaneCore::ConfigItem.new(
            key: :notes,
            description: "Changelog or additional notes",
            optional: true,
            type: String
          ),

          FastlaneCore::ConfigItem.new(
            key: :expansion_file_path,
            description: "Path to the expansion file (if there is one)",
            optional: true,
            type: String
          ),

          FastlaneCore::ConfigItem.new(
            key: :source,
            description: "Where build was produced (e.g., `ghactions`, `jenkins`, etc.)",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :ci_pipeline,
            description: "CI pipeline name",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :ci_run_id,
            description: "CI run ID",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :ci_run_url,
            description: "CI run URL",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :ci_build_duration,
            description: "CI build duration (e.g. '00:05:00')",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :vc_host_type,
            description: "Version control host type (git, svn, hg, perforce, etc)",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :vc_host,
            description: "Version control host (github, gitlab, etc)",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :vc_repo_name,
            description: "Repository name",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :vc_repo_url,
            description: "Repository URL",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :vc_branch,
            description: "Branch name (if applicable)",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :vc_commit_sha,
            description: "Commit SHA (if applicable)",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :vc_commit_url,
            description: "Commit URL",
            optional: true,
            type: String,
          ),

          FastlaneCore::ConfigItem.new(
            key: :metadata_artifacts,
            description: "List of supplementary files to upload alongside the build (e.g. logs). Each entry is a Hash with a required `:path` key and an optional `:description` key. Maximum 10 files, 5MB per file",
            optional: true,
            type: Array,
            default_value: []
          ),

          FastlaneCore::ConfigItem.new(
            key: :ssl_verify,
            description: "Set to false to disable SSL certificate verification. Only use this if your CI runner has SSL issues (e.g. unable to verify certificate CRL)",
            optional: true,
            is_string: false,
            default_value: true
          ),

        ]
      end

      def self.output
        [
          ['BUILDSTASH_BUILD_ID', 'The build ID in Buildstash for the uploaded build'],
          ['BUILDSTASH_INFO_URL', 'Link to view uploaded build within Buildstash workspace'],
          ['BUILDSTASH_DOWNLOAD_URL', 'Link to download the build uploaded to Buildstash (requires login)']
        ]
      end

      def self.author
        'Buildstash'
      end

      def self.is_supported?(platform)
        true
      end

    end
  end
end
