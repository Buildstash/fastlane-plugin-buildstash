ENV['DEBUG'] = '1'

describe Fastlane::Actions::BuildstashUploadAction do
  describe '#run' do
    it 'uploads the build artifact to Buildstash successfully' do

      # Get the api_key from ENV
      api_key = ENV['BUILDSTASH_API_KEY']
      expect(api_key).not_to be_nil

      # Setup mock parameters
      params = {
        api_key: api_key, # Replace with valid API key for tests
        primary_file_path: './spec/fixtures/appfiles/test.dmg',
        platform: 'macos',
        version_component_1_major: 1,
        version_component_2_minor: 2,
        version_component_3_patch: 0,
        version_component_extra: 'rc',
        version_component_meta: '2025.01.01',
        notes: '# Changelog\n\n## [1.2.0] - 2025-01-01\n\n### Added\n- Implemented a dark mode for better user experience.\n\n### Changed\n- Improved page loading performance.\n\n### Fixed\n- Fixed a bug preventing user settings from being saved.',
        stream: 'default',
        labels: ["to-review", "signed"],
        architectures: ["apple", "x64"]
      }

      # Mock the HTTP response
      response = instance_double(Net::HTTPSuccess, body: 'Success')
      allow(Net::HTTP).to receive(:start).and_return(response)
      allow(FastlaneCore::UI).to receive(:success)

      # Execute the action
      Fastlane::Actions::BuildstashUploadAction.run(params)

      # Verify the response
      expect(FastlaneCore::UI).to have_received(:success).with(a_string_including('✅ Upload'))
    end

    it 'raise an error if the file does not exist' do
      params = {
        api_key: 'BUILDSTASH_API_KEY', # Replace with valid API key for tests
        primary_file_path: 'non_existent_file.apk',
        platform: 'android',
        version_component_1_major: 0,
        version_component_2_minor: 1,
        version_component_3_patch: 0,
        stream: 'default'
      }

      expect do
        Fastlane::Actions::BuildstashUploadAction.run(params)
      end.to raise_error("File not found at path: non_existent_file.apk")
    end
  end

  describe '#upload_metadata_artifacts' do
    let(:api_key) { 'test_api_key' }
    let(:pending_upload_id) { 'pending_123' }

    it 'warns and truncates when more than 10 metadata artifacts are provided' do
      artifacts = (1..12).map { |i| { path: "./spec/fixtures/appfiles/test.dmg", description: "artifact #{i}" } }

      allow(FastlaneCore::UI).to receive(:important)
      allow(FastlaneCore::UI).to receive(:message)
      allow(FastlaneCore::UI).to receive(:success)

      meta_request_body = { "metadata_pending_upload_id" => "meta_123", "presigned_upload_data" => { "url" => "https://example.com/upload", "headers" => {} } }.to_json
      meta_verify_body = { "metadata_artifact_id" => "artifact_abc" }.to_json

      meta_request_response = instance_double(Net::HTTPSuccess, body: meta_request_body, is_a?: true)
      allow(meta_request_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      upload_response = instance_double(Net::HTTPSuccess, body: '')
      allow(upload_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      meta_verify_response = instance_double(Net::HTTPSuccess, body: meta_verify_body)
      allow(meta_verify_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)

      allow(Fastlane::Helper::BuildstashHelper).to receive(:post_json).and_return(meta_request_response, meta_verify_response)
      allow(Fastlane::Helper::BuildstashHelper).to receive(:upload_file).and_return(upload_response)

      Fastlane::Actions::BuildstashUploadAction.upload_metadata_artifacts(
        metadata_artifacts: artifacts,
        pending_upload_id: pending_upload_id,
        api_key: api_key
      )

      expect(FastlaneCore::UI).to have_received(:important).with(a_string_including('Skipping 2 metadata artifact(s)'))
    end

    it 'warns and skips metadata artifacts over 5MB' do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:size).and_call_original

      oversized_path = '/tmp/fake_large_file.bin'
      allow(File).to receive(:exist?).with(oversized_path).and_return(true)
      allow(File).to receive(:size).with(oversized_path).and_return(6 * 1024 * 1024)

      artifacts = [{ path: oversized_path, description: "Too large" }]

      allow(FastlaneCore::UI).to receive(:important)
      allow(FastlaneCore::UI).to receive(:message)
      allow(FastlaneCore::UI).to receive(:success)

      Fastlane::Actions::BuildstashUploadAction.upload_metadata_artifacts(
        metadata_artifacts: artifacts,
        pending_upload_id: pending_upload_id,
        api_key: api_key
      )

      expect(FastlaneCore::UI).to have_received(:important).with(a_string_including('exceeds the 5MB limit'))
    end

    it 'warns and skips metadata artifacts that do not exist' do
      artifacts = [{ path: '/nonexistent/path/file.log', description: "Missing file" }]

      allow(FastlaneCore::UI).to receive(:important)
      allow(FastlaneCore::UI).to receive(:message)
      allow(FastlaneCore::UI).to receive(:success)

      Fastlane::Actions::BuildstashUploadAction.upload_metadata_artifacts(
        metadata_artifacts: artifacts,
        pending_upload_id: pending_upload_id,
        api_key: api_key
      )

      expect(FastlaneCore::UI).to have_received(:important).with(a_string_including('not found at path'))
    end
  end
end