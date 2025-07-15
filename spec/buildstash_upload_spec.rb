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
        stream: 'default'
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
end