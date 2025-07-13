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
        stream = params[:stream]
        notes = params[:notes]

        source = params[:source]

        ci_pipeline = params[:ci_pipeline]
        ci_run_id = params[:ci_run_id]
        ci_run_url = params[:ci_run_url]

        vc_host_type = params[:vc_host_type]
        vc_host = params[:vc_host]
        vc_repo_name = params[:vc_repo_name]
        vc_repo_url = params[:vc_repo_url]
        vc_branch = params[:vc_branch]
        vc_commit_sha = params[:vc_commit_sha]
        vc_commit_url = params[:vc_commit_url]

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
          stream: stream,
          notes: notes,
          source: source,
          ci_pipeline: ci_pipeline,
          ci_run_id: ci_run_id,
          ci_run_url: ci_run_url,
          vc_host_type: vc_host_type,
          vc_host: vc_host,
          vc_repo_name: vc_repo_name,
          vc_repo_url: vc_repo_url,
          vc_branch: vc_branch,
          vc_commit_sha: vc_commit_sha,
          vc_commit_url: vc_commit_url
        }

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
          }
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
            is_expansion: false
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
            }
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
              is_expansion: true
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
              }
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
          })

        unless response.is_a?(Net::HTTPSuccess)
          UI.error("Buildstash API returned #{response.code}: #{response.body}")
          UI.user_error!("Buildstash API request failed")
        end

        if response.content_type && response.content_type != "application/json"
          UI.user_error!("Verification failed due to unexpected response type: #{response.content_type} - Response: #{response.code}: #{response.body}")
        end

        response_data = JSON.parse(response.body)

        if response_data["build_info_url"]
          UI.success("✅ Upload complete! View it at: #{response_data["build_info_url"]}")
        else
          UI.success("✅ Upload to Buildstash successful!")
        end
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
